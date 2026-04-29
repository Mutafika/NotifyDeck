import Foundation
import GRDB
import Combine

/// ローカルストレージ管理（GRDB）
final class StorageManager: ObservableObject {
    static let shared = StorageManager()

    private var dbQueue: DatabaseQueue?
    private let settingsManager = SettingsManager.shared

    @Published private(set) var notifications: [NotificationItem] = []
    @Published private(set) var unreadCount: Int = 0
    @Published private(set) var apps: [(identifier: String, name: String, count: Int)] = []
    @Published private(set) var storageInfo: StorageInfo = StorageInfo()

    struct StorageInfo {
        var count: Int = 0
        var sizeBytes: Int64 = 0

        var sizeString: String {
            ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
        }
    }

    private init() {
        setupDatabase()
    }

    // MARK: - Database Setup

    private var databasePath: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("Notipon")

        if !FileManager.default.fileExists(atPath: appFolder.path) {
            try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        }

        return appFolder.appendingPathComponent("notifications.db")
    }

    private func setupDatabase() {
        do {
            dbQueue = try DatabaseQueue(path: databasePath.path)

            try dbQueue?.write { db in
                try db.create(table: "notifications", ifNotExists: true) { t in
                    t.column("id", .text).primaryKey()
                    t.column("app_identifier", .text).notNull()
                    t.column("app_name", .text).notNull()
                    t.column("title", .text).notNull()
                    t.column("body", .text).notNull()
                    t.column("subtitle", .text)
                    t.column("timestamp", .datetime).notNull()
                    t.column("is_read", .boolean).notNull().defaults(to: false)
                    t.column("thread_identifier", .text)
                    t.column("category_identifier", .text)
                    t.column("image_data", .blob)
                }

                // マイグレーション: image_dataカラムを追加
                if try db.columns(in: "notifications").first(where: { $0.name == "image_data" }) == nil {
                    try db.alter(table: "notifications") { t in
                        t.add(column: "image_data", .blob)
                    }
                }

                // インデックス作成
                try db.create(
                    index: "idx_notifications_timestamp",
                    on: "notifications",
                    columns: ["timestamp"],
                    ifNotExists: true
                )
                try db.create(
                    index: "idx_notifications_app",
                    on: "notifications",
                    columns: ["app_identifier"],
                    ifNotExists: true
                )
            }

            refreshNotifications()
            updateStorageInfo()
        } catch {
            print("Database setup error: \(error)")
        }
    }

    // MARK: - CRUD Operations

    /// 通知を保存
    func save(_ notification: NotificationItem) throws {
        guard !settingsManager.isAppExcluded(notification.appIdentifier) else { return }

        try dbQueue?.write { db in
            try notification.save(db)
        }
        // 既存の同IDを除去してから挿入（upsert相当）
        notifications.removeAll { $0.id == notification.id }
        let index = notifications.firstIndex { $0.timestamp <= notification.timestamp } ?? notifications.endIndex
        notifications.insert(notification, at: index)
        rebuildDerivedState()
    }

    /// 複数の通知を一括保存
    func saveAll(_ items: [NotificationItem]) throws {
        let filtered = items.filter { !settingsManager.isAppExcluded($0.appIdentifier) }
        guard !filtered.isEmpty else { return }

        try dbQueue?.write { db in
            for notification in filtered {
                try notification.save(db)
            }
        }
        // 既存の同IDを除去してから追加（upsert相当）
        let newIds = Set(filtered.map { $0.id })
        notifications.removeAll { newIds.contains($0.id) }
        notifications.append(contentsOf: filtered)
        notifications.sort { $0.timestamp > $1.timestamp }
        rebuildDerivedState()
    }

    /// 通知を既読にする
    func markAsRead(_ id: String) throws {
        try dbQueue?.write { db in
            try db.execute(
                sql: "UPDATE notifications SET is_read = 1 WHERE id = ?",
                arguments: [id]
            )
        }
        if let idx = notifications.firstIndex(where: { $0.id == id }), !notifications[idx].isRead {
            notifications[idx].isRead = true
            unreadCount = max(unreadCount - 1, 0)
        }
    }

    /// 全て既読にする
    func markAllAsRead() throws {
        try dbQueue?.write { db in
            try db.execute(sql: "UPDATE notifications SET is_read = 1")
        }
        for i in notifications.indices {
            notifications[i].isRead = true
        }
        unreadCount = 0
    }

    /// 通知を削除
    func delete(_ id: String) throws {
        try dbQueue?.write { db in
            try db.execute(
                sql: "DELETE FROM notifications WHERE id = ?",
                arguments: [id]
            )
        }
        notifications.removeAll { $0.id == id }
        rebuildDerivedState()
    }

    /// 古い通知を削除
    func deleteOldNotifications() throws {
        guard let days = settingsManager.retentionPeriod.days else { return }

        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!

        try dbQueue?.write { db in
            try db.execute(
                sql: "DELETE FROM notifications WHERE timestamp < ?",
                arguments: [cutoffDate]
            )
            try db.execute(sql: "VACUUM")
        }
        notifications.removeAll { $0.timestamp < cutoffDate }
        rebuildDerivedState()
        updateStorageInfo()
    }

    /// 全ての通知を削除
    func deleteAll() throws {
        try dbQueue?.write { db in
            try db.execute(sql: "DELETE FROM notifications")
            try db.execute(sql: "VACUUM")
        }
        notifications.removeAll()
        rebuildDerivedState()
        updateStorageInfo()
    }

    // MARK: - Fetch Operations

    /// 通知一覧をDBから全件再取得（初回起動・大量削除後のみ使用）
    func refreshNotifications() {
        do {
            notifications = try dbQueue?.read { db in
                let columns: [NotificationItem.Columns] = [
                    .id, .appIdentifier, .appName, .title, .body,
                    .subtitle, .timestamp, .isRead, .threadIdentifier, .categoryIdentifier
                ]
                return try NotificationItem
                    .select(columns)
                    .order(NotificationItem.Columns.timestamp.desc)
                    .fetchAll(db)
            } ?? []

            rebuildDerivedState()
            updateStorageInfo()
        } catch {
            print("Fetch error: \(error)")
        }
    }

    /// unreadCount / apps を notifications から再計算
    private func rebuildDerivedState() {
        unreadCount = notifications.reduce(0) { $0 + ($1.isRead ? 0 : 1) }

        var appMap: [String: (name: String, count: Int)] = [:]
        for n in notifications {
            if let existing = appMap[n.appIdentifier] {
                appMap[n.appIdentifier] = (existing.name, existing.count + 1)
            } else {
                appMap[n.appIdentifier] = (n.appName, 1)
            }
        }
        apps = appMap.map { (identifier: $0.key, name: $0.value.name, count: $0.value.count) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// 指定IDの通知の画像データを取得
    func fetchImageData(for id: String) -> Data? {
        try? dbQueue?.read { db in
            try Data.fetchOne(
                db,
                sql: "SELECT image_data FROM notifications WHERE id = ?",
                arguments: [id]
            )
        }
    }

    /// フィルタを適用して取得（画像データ除外）
    func fetch(filter: NotificationFilter) -> [NotificationItem] {
        do {
            return try dbQueue?.read { db in
                let columns: [NotificationItem.Columns] = [
                    .id, .appIdentifier, .appName, .title, .body,
                    .subtitle, .timestamp, .isRead, .threadIdentifier, .categoryIdentifier
                ]
                var query = NotificationItem.select(columns)

                // アプリフィルタ
                if let apps = filter.appIdentifiers, !apps.isEmpty {
                    query = query.filter(apps.contains(NotificationItem.Columns.appIdentifier))
                }

                // 既読/未読フィルタ
                if let isRead = filter.isReadFilter {
                    query = query.filter(NotificationItem.Columns.isRead == isRead)
                }

                // 日付範囲
                if let range = filter.dateRange {
                    query = query.filter(
                        NotificationItem.Columns.timestamp >= range.lowerBound &&
                        NotificationItem.Columns.timestamp <= range.upperBound
                    )
                }

                var results = try query
                    .order(NotificationItem.Columns.timestamp.desc)
                    .fetchAll(db)

                // 検索クエリ（メモリ内フィルタ）
                if let searchQuery = filter.searchQuery, !searchQuery.isEmpty {
                    let lowercased = searchQuery.lowercased()
                    results = results.filter {
                        $0.title.lowercased().contains(lowercased) ||
                        $0.body.lowercased().contains(lowercased) ||
                        $0.appName.lowercased().contains(lowercased)
                    }
                }

                return results
            } ?? []
        } catch {
            print("Filter fetch error: \(error)")
            return []
        }
    }

    /// 直近N件を取得
    func fetchRecent(count: Int) -> [NotificationItem] {
        Array(notifications.prefix(count))
    }

    /// 未読のみ取得
    func fetchUnread() -> [NotificationItem] {
        notifications.filter { !$0.isRead }
    }



    // MARK: - Storage Info

    private func updateStorageInfo() {
        storageInfo.count = notifications.count

        if let attributes = try? FileManager.default.attributesOfItem(atPath: databasePath.path),
           let size = attributes[.size] as? Int64 {
            storageInfo.sizeBytes = size
        }
    }

    // MARK: - Export

    /// JSONとしてエクスポート
    func exportAsJSON() -> Data? {
        try? JSONEncoder().encode(notifications)
    }

    /// CSVとしてエクスポート
    func exportAsCSV() -> String {
        var csv = "ID,App,Title,Body,Timestamp,IsRead\n"

        for n in notifications {
            let row = [
                n.id,
                n.appName,
                n.title.replacingOccurrences(of: ",", with: ";"),
                n.body.replacingOccurrences(of: ",", with: ";").replacingOccurrences(of: "\n", with: " "),
                ISO8601DateFormatter().string(from: n.timestamp),
                n.isRead ? "true" : "false"
            ].joined(separator: ",")
            csv += row + "\n"
        }

        return csv
    }

    // MARK: - Test Data Generation

    /// 負荷テスト用の通知を生成
    /// - Parameter count: 生成する件数
    /// - Throws: データベースエラー
    func generateTestNotifications(count: Int) throws {
        let notifications = (0..<count).map { index -> NotificationItem in
            // ランダムなアプリ選択
            let app = AppConstants.testApps.randomElement()!

            // 過去30日間のランダムなタイムスタンプ
            let daysAgo = Double.random(in: 0...30)
            let secondsAgo = daysAgo * 24 * 60 * 60
            let timestamp = Date().addingTimeInterval(-secondsAgo)

            // 30%の確率で既読
            let isRead = Double.random(in: 0...1) < 0.3

            // ランダムなタイトル・本文
            let title = AppConstants.testTitles.randomElement()!
            let body = AppConstants.testBodies.randomElement()!

            return NotificationItem(
                appIdentifier: app.identifier,
                appName: app.name,
                title: "\(title) #\(index + 1)",
                body: body,
                timestamp: timestamp,
                isRead: isRead
            )
        }

        // バックグラウンドで一括保存
        try dbQueue?.write { db in
            for notification in notifications {
                // 除外アプリチェックをスキップ（テストデータなので）
                try notification.save(db)
            }
        }

        // UI更新
        DispatchQueue.main.async {
            self.refreshNotifications()
        }
    }
}
