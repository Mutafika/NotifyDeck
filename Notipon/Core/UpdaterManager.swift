import Foundation
import Sparkle

/// Sparkle自動アップデート管理
final class UpdaterManager: ObservableObject {
    static let shared = UpdaterManager()

    private let updaterController: SPUStandardUpdaterController

    /// 自動アップデートチェックが有効か
    var automaticallyChecksForUpdates: Bool {
        get { updaterController.updater.automaticallyChecksForUpdates }
        set { updaterController.updater.automaticallyChecksForUpdates = newValue }
    }

    /// アップデートチェック中か
    @Published var canCheckForUpdates = false

    private init() {
        // startingUpdater: true で起動時に自動チェック開始
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        // canCheckForUpdates を監視
        updaterController.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }

    /// 手動でアップデートを確認（設定画面のボタン用）
    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}
