# Notipon

> A [Mugendesk](https://github.com/Mugendesk/Notipon) Project

macOS通知のカスタムポップアップ — 表示位置・サイズ・透過率・表示時間を自由にカスタマイズ。通知履歴の保存・検索・エクスポートも。

![macOS](https://img.shields.io/badge/macOS-13.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

**[English](README.md)**

## Notiponとは？

macOSの通知はすぐ消えてしまい、見た目や表示位置もカスタマイズできません。Notiponはその両方を解決します：

1. **カスタムポップアップ** - 通知を好きな場所に、好きなサイズで、好きな時間だけ表示
2. **通知履歴** - すべての通知を自動保存。検索・フィルタでいつでも確認

配信者、マルチモニター環境、通知を見逃したくない方に最適です。

## 主な機能

### カスタムポップアップ
- **表示位置** - 画面上の任意の位置に配置（X/Y座標）
- **サイズ** - 幅200-1200px、高さ60-400px
- **透過率** - 30-100%
- **文字サイズ** - 10-30pt
- **表示時間** - 0-30秒（0=手動で閉じるまで表示）
- **アプリアイコン・画像** - アプリアイコンと通知画像を表示

### 通知履歴
- **自動保存** - macOSの通知をリアルタイムで保存
- **検索** - タイトル・本文・アプリ名で検索
- **アプリ別フィルタ** - 特定アプリの通知のみ表示
- **日付グループ化** - 「今日」「昨日」「M月d日」で自動整理
- **エクスポート** - JSON/CSV形式で書き出し

### メニューバー
- **ホバー** - 直近5件をプレビュー
- **クリック** - 直近20件のドロップダウン表示
- **右クリック** - 全履歴ウィンドウを開く
- **未読バッジ** - 未読数を一目で確認

### その他
- **自動削除** - 保存後に通知センターから削除
- **除外アプリ** - 特定アプリの通知を保存しない
- **自動起動** - ログイン時に起動
- **保存期間** - 24時間 / 7日 / 30日 / 無制限

## スクリーンショット

### カスタムポップアップ
<img width="480" alt="カスタムポップアップ" src="docs/screenshots/popup.png">

### メニューバー
<img width="300" alt="メニューバー" src="docs/screenshots/menubar.png">

### 履歴ウィンドウ
<img width="700" alt="履歴ウィンドウ" src="docs/screenshots/history.png">

### 設定画面
<img width="480" alt="設定画面" src="docs/screenshots/settings.png">

## インストール

### Homebrew（推奨）

```bash
brew tap mugendesk/tap
brew install --cask notipon
```

インストール時にquarantine属性が自動除去されるため、追加の手順は不要です。

### 手動ダウンロード

1. [最新リリース](https://github.com/Mugendesk/Notipon/releases/latest)から`Notipon.zip`をダウンロード
2. ZIPファイルを展開
3. `Notipon.app`を`/Applications`フォルダに移動
4. 初回起動前にquarantine属性を除去：
   ```bash
   xattr -cr /Applications/Notipon.app
   ```
5. アプリを起動

### なぜこの手順が必要？

現在このアプリは署名されていないため、macOSがデフォルトでブロックします（Gatekeeper）。`xattr -cr` コマンドでquarantineフラグを除去すれば正常に起動できます。

## 必要な権限

### 1. フルディスクアクセス（必須）

macOSの通知データベースを読み取るために必要です。

**設定方法：**
1. `システム設定` → `プライバシーとセキュリティ` → `フルディスクアクセス`
2. 左下の鍵アイコンをクリックして認証
3. `+`ボタンをクリック
4. `/Applications/Notipon.app`を選択
5. Notiponを再起動

### 2. アクセシビリティ（推奨）

リアルタイム通知検知のために推奨します（なくても動作しますが、遅延が発生します）。

**設定方法：**
1. `システム設定` → `プライバシーとセキュリティ` → `アクセシビリティ`
2. 左下の鍵アイコンをクリックして認証
3. `+`ボタンをクリック
4. `/Applications/Notipon.app`を選択
5. Notiponを再起動

## 技術仕様

### アーキテクチャ
- **言語**: Swift 5.9
- **フレームワーク**: SwiftUI, AppKit
- **データベース**: SQLite (GRDB.swift)
- **通知検知**: Accessibility API + アダプティブポーリング

### パフォーマンス
| 項目 | 性能 |
|------|------|
| 通知検知遅延 | 平均50-200ms |
| アイドル時CPU | 0% |
| メモリ | 約50MB |
| Energy Impact | Low |

### データ保存場所
```
~/Library/Application Support/Notipon/notifications.db
```

## トラブルシューティング

### 通知が保存されない

1. **フルディスクアクセス権限**を確認してください
2. Notiponを再起動してください
3. ターミナルで以下を実行して、データベースが作成されているか確認：
   ```bash
   ls ~/Library/Application\ Support/Notipon/
   ```

### 検知が遅い

1. **アクセシビリティ権限**を追加してください
2. リアルタイム検知が有効になり、遅延が改善されます

### アプリが起動しない

1. 右クリック→「開く」で起動してください
2. macOS 13.0以降が必要です
3. コンソールアプリでエラーログを確認してください

## コントリビューション

プルリクエストを歓迎します！

```bash
git clone https://github.com/Mugendesk/Notipon.git
cd Notipon
open Notipon.xcodeproj
```

### 開発要件
- Xcode 15.0以降
- Swift 5.9以降

## ライセンス

MIT License

Copyright (c) 2026 Mugendesk

詳細は[LICENSE](LICENSE)ファイルをご覧ください。

## リンク

- [GitHub リポジトリ](https://github.com/Mugendesk/Notipon)
- [問題報告](https://github.com/Mugendesk/Notipon/issues)
- [最新リリース](https://github.com/Mugendesk/Notipon/releases)

---

Made by [Mugendesk](https://github.com/Mugendesk/Notipon)
