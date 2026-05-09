import AppKit

/// ポップアップ通知に同期して鳴らす効果音プレイヤー
final class SoundPlayer {
    static let shared = SoundPlayer()

    /// macOS標準のシステムサウンド一覧（/System/Library/Sounds）
    static let systemSoundNames: [String] = [
        "Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero",
        "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink"
    ]

    /// デフォルトで使うサウンド名
    static let defaultSoundName = "Tink"

    private var cache: [String: NSSound] = [:]
    private let cacheQueue = DispatchQueue(label: "com.mugendesk.notipon.soundcache")

    private init() {}

    /// 指定の音を即時再生
    func play(name: String, volume: Float = 1.0) {
        guard let sound = sound(for: name) else { return }

        // 既に再生中なら停止して再生位置をリセット
        if sound.isPlaying {
            sound.stop()
        }
        sound.volume = max(0, min(1, volume))
        sound.play()
    }

    /// NSSoundをキャッシュから取得（無ければロード）
    private func sound(for name: String) -> NSSound? {
        var cached: NSSound?
        cacheQueue.sync { cached = cache[name] }
        if let cached { return cached }

        guard let sound = NSSound(named: NSSound.Name(name))?.copy() as? NSSound else {
            NSLog("SoundPlayer: '%@' が見つかりません", name)
            return nil
        }
        cacheQueue.sync { cache[name] = sound }
        return sound
    }
}
