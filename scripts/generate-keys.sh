#!/bin/bash
set -euo pipefail

# ============================================================
# Sparkle EdDSA 鍵ペア生成（初回セットアップ用）
#
# Usage: ./scripts/generate-keys.sh
#
# 生成されるもの:
#   - EdDSA秘密鍵（Keychainに保存 or 環境変数 SPARKLE_PRIVATE_KEY で管理）
#   - EdDSA公開鍵（Info.plist の SUPublicEDKey に設定）
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="${PROJECT_DIR}/dist"

echo "============================================"
echo "  Sparkle EdDSA 鍵ペア生成"
echo "============================================"
echo ""

# generate_keys を探す
GENERATE_KEYS=""
SPM_PATH="${BUILD_DIR}/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys"
BREW_PATH="/opt/homebrew/bin/generate_keys"

if [[ -x "$SPM_PATH" ]]; then
    GENERATE_KEYS="$SPM_PATH"
elif [[ -x "$BREW_PATH" ]]; then
    GENERATE_KEYS="$BREW_PATH"
elif command -v generate_keys &>/dev/null; then
    GENERATE_KEYS="generate_keys"
else
    echo "エラー: generate_keys が見つかりません"
    echo ""
    echo "以下のいずれかの方法でインストールしてください:"
    echo "  1. Xcode でプロジェクトをビルド（SPM で Sparkle がダウンロードされます）"
    echo "  2. Sparkle のリリースから手動でダウンロード:"
    echo "     https://github.com/sparkle-project/Sparkle/releases"
    exit 1
fi

echo "generate_keys を実行します..."
echo "（初回実行時は Keychain にアクセス許可を求められる場合があります）"
echo ""

"${GENERATE_KEYS}"

echo ""
echo "============================================"
echo "  セットアップ手順"
echo "============================================"
echo ""
echo "1. 上記の公開鍵を Info.plist の SUPublicEDKey に設定:"
echo "   <key>SUPublicEDKey</key>"
echo "   <string>ここに公開鍵を貼り付け</string>"
echo ""
echo "2. 秘密鍵は Keychain に保存されています"
echo "   CI/CD で使う場合は SPARKLE_PRIVATE_KEY 環境変数に設定"
echo ""
echo "3. 鍵は一度生成したら変更しないでください"
echo "   （既存ユーザーがアップデートできなくなります）"
echo "============================================"
