import SwiftUI
import AppKit

@main
struct NotiponApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(SettingsManager.shared)
                .environmentObject(StorageManager.shared)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private let updaterManager = UpdaterManager.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Dockアイコンを非表示
        NSApp.setActivationPolicy(.accessory)

        print("Notipon: Starting...")

        // メニューバーコントローラー初期化（遅延）
        DispatchQueue.main.async {
            self.menuBarController = MenuBarController()
            print("Notipon: MenuBarController initialized")

            // 権限チェック
            self.checkPermissions()

            // 古い通知の削除
            self.cleanupOldNotifications()

            // 通知監視開始
            self.startMonitoring()

            // Sparkle自動アップデートチェック（UpdaterManager初期化時に開始済み）

            print("Notipon: Started successfully")
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        NotificationMonitor.shared.stopMonitoring()
    }

    // MARK: - Setup

    private func checkPermissions() {
        let permissionManager = PermissionManager.shared
        if !permissionManager.hasFullDiskAccess() {
            // 初回起動時に権限リクエスト
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                permissionManager.showPermissionAlert()
            }
        }
    }

    private func startMonitoring() {
        let permissionManager = PermissionManager.shared
        let notificationMonitor = NotificationMonitor.shared

        // ポップアップを先にプリロード
        _ = NotificationPopupController.shared

        // Accessibility API で即時検知（メイン）
        AccessibilityNotificationObserver.shared.startObserving()

        // DB監視は履歴保存用（サブ）
        if permissionManager.hasFullDiskAccess() {
            notificationMonitor.startMonitoring()
        } else {
            // 権限が付与されるまで定期的にチェック
            Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { timer in
                if permissionManager.hasFullDiskAccess() {
                    timer.invalidate()
                    notificationMonitor.startMonitoring()
                }
            }
        }
    }

    private func cleanupOldNotifications() {
        do {
            try StorageManager.shared.deleteOldNotifications()
        } catch {
            print("Cleanup error: \(error)")
        }
    }

}
