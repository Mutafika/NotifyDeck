# Notipon ビルド & 配布ガイド

## 必要環境

- macOS 13.0+
- Xcode 15.0+
- Swift 5.9+

## ビルド & DMG作成

### ワンコマンドでDMG作成（フルビルド）

```bash
./scripts/build-dmg.sh
```

### 既存ビルドからDMG作成（ビルドスキップ）

```bash
./scripts/build-dmg.sh --skip-build
```

### 出力

```
dist/Notipon-{VERSION}.dmg
```

バージョンは `Notipon.xcodeproj/project.pbxproj` の `MARKETING_VERSION` から自動取得されます。

## リリース手順

### 1. バージョン更新

Xcode で `MARKETING_VERSION` を更新するか、`project.pbxproj` を直接編集:

```
MARKETING_VERSION = 1.1.0;
```

### 2. DMG作成

```bash
./scripts/build-dmg.sh
```

### 3. GitHub Releases にアップロード

```bash
# タグ作成 & プッシュ
git tag v1.1.0
git push origin v1.1.0

# リリース作成 & DMGアップロード
gh release create v1.1.0 \
  dist/Notipon-1.1.0.dmg \
  --title "Notipon v1.1.0" \
  --notes "リリースノートをここに記載"
```

### 4. LP のダウンロードリンク

GitHub Releases のダウンロードURL:

```
https://github.com/Mugendesk/Notipon/releases/latest/download/Notipon-{VERSION}.dmg
```

最新版への固定リンク（LP向け）:

```
https://github.com/Mugendesk/Notipon/releases/latest
```

## ディレクトリ構成

```
Notipon/
├── scripts/
│   └── build-dmg.sh    # DMGビルドスクリプト
├── dist/               # 出力先（.gitignore済み）
│   └── Notipon-x.x.x.dmg
└── docs/
    └── BUILD.md        # このファイル
```

## 注意事項

- **未署名アプリ**: 現在コード署名なし。ユーザーは `xattr -cr` で quarantine を解除する必要があります
- **Apple Developer Program** に加入すれば、署名 & 公証（Notarization）が可能になり、quarantine 解除が不要になります
- `dist/` ディレクトリは `.gitignore` に追加済みのため、DMGファイルはリポジトリに含まれません
