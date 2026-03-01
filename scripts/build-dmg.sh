#!/bin/bash
set -euo pipefail

# ============================================================
# Notipon DMG Builder
# Usage: ./scripts/build-dmg.sh [--skip-build] [--sign] [--notarize]
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="${PROJECT_DIR}/dist"
APP_NAME="Notipon"
SCHEME="Notipon"
XCODEPROJ="${PROJECT_DIR}/Notipon.xcodeproj"

# バージョンを project.pbxproj から取得
VERSION=$(grep 'MARKETING_VERSION' "${XCODEPROJ}/project.pbxproj" | head -1 | sed 's/.*= //' | sed 's/;//' | tr -d ' ')
DMG_NAME="${APP_NAME}-${VERSION}"
DMG_PATH="${BUILD_DIR}/${DMG_NAME}.dmg"
APP_PATH="${BUILD_DIR}/${APP_NAME}.app"

# オプション解析
SKIP_BUILD=false
DO_SIGN=false
DO_NOTARIZE=false

for arg in "$@"; do
    case "$arg" in
        --skip-build) SKIP_BUILD=true ;;
        --sign) DO_SIGN=true ;;
        --notarize) DO_NOTARIZE=true ;;
    esac
done

# 署名・公証に必要な環境変数
# DEVELOPMENT_TEAM       - Apple Developer Team ID
# DEVELOPER_ID_APP       - "Developer ID Application: ..." 証明書名
# APPLE_ID               - Apple ID（公証用）
# APPLE_TEAM_ID          - Team ID（公証用）
# APPLE_APP_PASSWORD     - App-specific password（公証用）

echo "================================================"
echo "  ${APP_NAME} DMG Builder v${VERSION}"
echo "  Sign: ${DO_SIGN} | Notarize: ${DO_NOTARIZE}"
echo "================================================"

# dist ディレクトリ作成
mkdir -p "${BUILD_DIR}"

# ビルド
if [[ "$SKIP_BUILD" == false ]]; then
    echo ""
    echo "[1/6] ビルド中..."

    BUILD_SETTINGS=""
    if [[ "$DO_SIGN" == true ]]; then
        if [[ -z "${DEVELOPMENT_TEAM:-}" ]]; then
            echo "エラー: --sign には DEVELOPMENT_TEAM 環境変数が必要です"
            exit 1
        fi
        BUILD_SETTINGS="DEVELOPMENT_TEAM=${DEVELOPMENT_TEAM} CODE_SIGN_IDENTITY=\"Developer ID Application\""
    fi

    xcodebuild \
        -project "${XCODEPROJ}" \
        -scheme "${SCHEME}" \
        -configuration Release \
        -derivedDataPath "${BUILD_DIR}/DerivedData" \
        -arch arm64 -arch x86_64 \
        ONLY_ACTIVE_ARCH=NO \
        ${BUILD_SETTINGS} \
        clean build 2>&1 | tail -5

    # ビルド成果物をコピー
    BUILT_APP="${BUILD_DIR}/DerivedData/Build/Products/Release/${APP_NAME}.app"
    if [[ ! -d "$BUILT_APP" ]]; then
        echo "エラー: ビルド成果物が見つかりません: ${BUILT_APP}"
        exit 1
    fi
    rm -rf "${APP_PATH}"
    cp -R "${BUILT_APP}" "${APP_PATH}"
    echo "  ビルド完了: ${APP_PATH}"
else
    echo ""
    echo "[1/6] ビルドをスキップ"
    EXISTING_APP="${PROJECT_DIR}/build/Build/Products/Release/${APP_NAME}.app"
    if [[ -d "$EXISTING_APP" && ! -d "$APP_PATH" ]]; then
        cp -R "$EXISTING_APP" "${APP_PATH}"
    fi
    if [[ ! -d "$APP_PATH" ]]; then
        echo "エラー: ${APP_PATH} が見つかりません。--skip-build なしで実行してください。"
        exit 1
    fi
fi

# コード署名
if [[ "$DO_SIGN" == true ]]; then
    echo ""
    echo "[2/6] コード署名中..."
    SIGN_IDENTITY="${DEVELOPER_ID_APP:-Developer ID Application}"
    codesign --deep --force --verify --verbose \
        --sign "${SIGN_IDENTITY}" \
        --options runtime \
        "${APP_PATH}"
    echo "  署名完了"
    codesign --verify --verbose "${APP_PATH}"
else
    echo ""
    echo "[2/6] コード署名をスキップ"
fi

# 既存DMGを削除
rm -f "${DMG_PATH}"

# DMG用一時ディレクトリ作成
echo ""
echo "[3/6] DMGレイアウト作成中..."
DMG_TEMP="${BUILD_DIR}/dmg-temp"
rm -rf "${DMG_TEMP}"
mkdir -p "${DMG_TEMP}"

# .app をコピー
cp -R "${APP_PATH}" "${DMG_TEMP}/"

# Applications へのシンボリックリンク
ln -s /Applications "${DMG_TEMP}/Applications"

# DMG作成
echo ""
echo "[4/6] DMG作成中..."
hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${DMG_TEMP}" \
    -ov \
    -format UDZO \
    "${DMG_PATH}" 2>&1 | tail -3

# クリーンアップ
rm -rf "${DMG_TEMP}"

# DMG署名
if [[ "$DO_SIGN" == true ]]; then
    echo ""
    echo "[5/6] DMG署名中..."
    SIGN_IDENTITY="${DEVELOPER_ID_APP:-Developer ID Application}"
    codesign --force --sign "${SIGN_IDENTITY}" "${DMG_PATH}"
    echo "  DMG署名完了"
else
    echo ""
    echo "[5/6] DMG署名をスキップ"
fi

# 公証
if [[ "$DO_NOTARIZE" == true ]]; then
    echo ""
    echo "[6/6] 公証中..."
    if [[ -z "${APPLE_ID:-}" || -z "${APPLE_TEAM_ID:-}" || -z "${APPLE_APP_PASSWORD:-}" ]]; then
        echo "エラー: --notarize には APPLE_ID, APPLE_TEAM_ID, APPLE_APP_PASSWORD 環境変数が必要です"
        exit 1
    fi

    xcrun notarytool submit "${DMG_PATH}" \
        --apple-id "${APPLE_ID}" \
        --team-id "${APPLE_TEAM_ID}" \
        --password "${APPLE_APP_PASSWORD}" \
        --wait

    # Staple
    xcrun stapler staple "${DMG_PATH}"
    echo "  公証・Staple完了"
else
    echo ""
    echo "[6/6] 公証をスキップ"
fi

# 結果表示
echo ""
echo "================================================"
echo "  DMG: ${DMG_PATH}"
echo "  サイズ: $(du -h "${DMG_PATH}" | cut -f1)"
echo "================================================"
