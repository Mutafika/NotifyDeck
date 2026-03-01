#!/bin/bash
set -euo pipefail

# ============================================================
# Notipon Release Script
# ビルド → 署名 → 公証 → appcast生成 → DMG出力
#
# Usage: ./scripts/release.sh
#
# 必要な環境変数:
#   DEVELOPMENT_TEAM     - Apple Developer Team ID
#   DEVELOPER_ID_APP     - "Developer ID Application: ..." 証明書名
#   APPLE_ID             - Apple ID（公証用）
#   APPLE_TEAM_ID        - Team ID（公証用）
#   APPLE_APP_PASSWORD   - App-specific password（公証用）
#   SPARKLE_PRIVATE_KEY  - Sparkle EdDSA秘密鍵（generate_appcast用）
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="${PROJECT_DIR}/dist"
XCODEPROJ="${PROJECT_DIR}/Notipon.xcodeproj"

# バージョン取得
VERSION=$(grep 'MARKETING_VERSION' "${XCODEPROJ}/project.pbxproj" | head -1 | sed 's/.*= //' | sed 's/;//' | tr -d ' ')

echo "============================================"
echo "  Notipon Release v${VERSION}"
echo "============================================"
echo ""

# 環境変数チェック
MISSING_VARS=()
for var in DEVELOPMENT_TEAM APPLE_ID APPLE_TEAM_ID APPLE_APP_PASSWORD; do
    if [[ -z "${!var:-}" ]]; then
        MISSING_VARS+=("$var")
    fi
done

if [[ ${#MISSING_VARS[@]} -gt 0 ]]; then
    echo "エラー: 以下の環境変数が未設定です:"
    for var in "${MISSING_VARS[@]}"; do
        echo "  - $var"
    done
    echo ""
    echo "設定例:"
    echo "  export DEVELOPMENT_TEAM=\"XXXXXXXXXX\""
    echo "  export APPLE_ID=\"your@email.com\""
    echo "  export APPLE_TEAM_ID=\"XXXXXXXXXX\""
    echo "  export APPLE_APP_PASSWORD=\"xxxx-xxxx-xxxx-xxxx\""
    exit 1
fi

# Step 1: ビルド + 署名 + 公証 + DMG作成
echo "[Step 1/2] DMGビルド（署名・公証あり）"
echo "-------------------------------------------"
"${SCRIPT_DIR}/build-dmg.sh" --sign --notarize

DMG_PATH="${BUILD_DIR}/Notipon-${VERSION}.dmg"

# Step 2: appcast.xml 生成
echo ""
echo "[Step 2/2] appcast.xml 生成"
echo "-------------------------------------------"

# Sparkle の generate_appcast を探す
GENERATE_APPCAST=""
# SPM でビルドされた場合のパス
SPM_PATH="${BUILD_DIR}/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_appcast"
# Homebrew でインストールされた場合
BREW_PATH="/opt/homebrew/bin/generate_appcast"

if [[ -x "$SPM_PATH" ]]; then
    GENERATE_APPCAST="$SPM_PATH"
elif [[ -x "$BREW_PATH" ]]; then
    GENERATE_APPCAST="$BREW_PATH"
elif command -v generate_appcast &>/dev/null; then
    GENERATE_APPCAST="generate_appcast"
else
    echo "警告: generate_appcast が見つかりません"
    echo "  Sparkle のリリースから手動でダウンロードしてください:"
    echo "  https://github.com/sparkle-project/Sparkle/releases"
    echo ""
    echo "  DMGは正常に作成されています: ${DMG_PATH}"
    exit 0
fi

# appcast生成（dist/ ディレクトリ内のDMGから）
echo "generate_appcast 実行中..."
"${GENERATE_APPCAST}" "${BUILD_DIR}"

APPCAST_PATH="${BUILD_DIR}/appcast.xml"
if [[ -f "$APPCAST_PATH" ]]; then
    echo "  appcast.xml 生成完了: ${APPCAST_PATH}"
else
    echo "警告: appcast.xml が生成されませんでした"
fi

# 完了
echo ""
echo "============================================"
echo "  リリース完了!"
echo "============================================"
echo "  DMG: ${DMG_PATH}"
echo "  appcast: ${APPCAST_PATH:-（未生成）}"
echo ""
echo "次のステップ:"
echo "  1. appcast.xml を GitHub Pages にデプロイ"
echo "     cp ${APPCAST_PATH} /path/to/gh-pages/appcast.xml"
echo "  2. DMG を GitHub Releases にアップロード"
echo "  3. GitHub Pages を更新（push）"
echo "============================================"
