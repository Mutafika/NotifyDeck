#!/bin/bash
set -euo pipefail

# ============================================================
# Notipon DMG Builder
# Usage: ./scripts/build-dmg.sh [--skip-build] [--sign] [--notarize]
#
# 配布物:
#   dist/Notipon-<version>.dmg  … 署名・公証・staple 済み
#   dist/Notipon.zip            … staple 済み .app（Sparkle 配信用）
#
# 環境変数:
#   DEVELOPER_ID_APP  - "Developer ID Application: ..." 証明書名（未設定なら自動検出）
#   DEVELOPMENT_TEAM  - Apple Developer Team ID（未設定なら証明書から抽出）
#   NOTARY_PROFILE    - notarytool のキーチェーンプロファイル名（既定: notipon）
#   ── NOTARY_PROFILE が使えない場合のフォールバック ──
#   APPLE_ID / APPLE_TEAM_ID / APPLE_APP_PASSWORD
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="${PROJECT_DIR}/dist"
APP_NAME="Notipon"
SCHEME="Notipon"
XCODEPROJ="${PROJECT_DIR}/Notipon.xcodeproj"
NOTARY_PROFILE="${NOTARY_PROFILE:-notipon}"

VERSION=$(grep 'MARKETING_VERSION' "${XCODEPROJ}/project.pbxproj" | head -1 | sed 's/.*= //' | sed 's/;//' | tr -d ' ')
DMG_PATH="${BUILD_DIR}/${APP_NAME}-${VERSION}.dmg"
APP_PATH="${BUILD_DIR}/${APP_NAME}.app"
DIST_ZIP="${BUILD_DIR}/${APP_NAME}.zip"

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

# 公証には署名が必須
if [[ "$DO_NOTARIZE" == true && "$DO_SIGN" == false ]]; then
    echo "エラー: --notarize には --sign が必要です"
    exit 1
fi

# ------------------------------------------------------------
# 署名 ID の解決
# ------------------------------------------------------------
if [[ "$DO_SIGN" == true ]]; then
    if [[ -z "${DEVELOPER_ID_APP:-}" ]]; then
        DEVELOPER_ID_APP=$(security find-identity -v -p codesigning \
            | grep "Developer ID Application" \
            | grep -v "CSSMERR" \
            | head -1 \
            | sed 's/.*"\(.*\)".*/\1/')
        if [[ -z "$DEVELOPER_ID_APP" ]]; then
            echo "エラー: 有効な Developer ID Application 証明書が見つかりません"
            echo "  security find-identity -v -p codesigning で確認してください"
            exit 1
        fi
    fi
    # 証明書名 "... (TEAMID)" から Team ID を抽出
    if [[ -z "${DEVELOPMENT_TEAM:-}" ]]; then
        DEVELOPMENT_TEAM=$(echo "$DEVELOPER_ID_APP" | sed -n 's/.*(\([A-Z0-9]*\))$/\1/p')
    fi
fi

echo "================================================"
echo "  ${APP_NAME} DMG Builder v${VERSION}"
echo "  Sign: ${DO_SIGN} | Notarize: ${DO_NOTARIZE}"
[[ "$DO_SIGN" == true ]] && echo "  Identity: ${DEVELOPER_ID_APP}"
echo "================================================"

mkdir -p "${BUILD_DIR}"

# ------------------------------------------------------------
# notarytool の認証引数を組み立て
# ------------------------------------------------------------
notary_args() {
    if xcrun notarytool history --keychain-profile "${NOTARY_PROFILE}" &>/dev/null; then
        echo "--keychain-profile ${NOTARY_PROFILE}"
    elif [[ -n "${APPLE_ID:-}" && -n "${APPLE_TEAM_ID:-}" && -n "${APPLE_APP_PASSWORD:-}" ]]; then
        echo "--apple-id ${APPLE_ID} --team-id ${APPLE_TEAM_ID} --password ${APPLE_APP_PASSWORD}"
    else
        return 1
    fi
}

# 対象を公証して結果を待つ
notarize() {
    local target="$1"
    local args
    if ! args=$(notary_args); then
        echo "エラー: 公証の認証情報がありません"
        echo "  xcrun notarytool store-credentials \"${NOTARY_PROFILE}\" --apple-id <id> --team-id <team>"
        echo "  もしくは APPLE_ID / APPLE_TEAM_ID / APPLE_APP_PASSWORD を設定してください"
        exit 1
    fi
    # shellcheck disable=SC2086
    xcrun notarytool submit "${target}" ${args} --wait
}

# ------------------------------------------------------------
# [1/7] ビルド
# ------------------------------------------------------------
if [[ "$SKIP_BUILD" == false ]]; then
    echo ""
    echo "[1/7] ビルド中..."

    BUILD_ARGS=()
    if [[ "$DO_SIGN" == true ]]; then
        # Xcode に入れ子（Sparkle.framework / Updater.app / Autoupdate）まで
        # 正しい順序で署名させる。codesign --deep は使わない。
        BUILD_ARGS=(
            DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM}"
            CODE_SIGN_IDENTITY="${DEVELOPER_ID_APP}"
            CODE_SIGN_STYLE=Manual
            OTHER_CODE_SIGN_FLAGS="--timestamp --options=runtime"
        )
    fi

    xcodebuild \
        -project "${XCODEPROJ}" \
        -scheme "${SCHEME}" \
        -configuration Release \
        -derivedDataPath "${BUILD_DIR}/DerivedData" \
        -arch arm64 -arch x86_64 \
        ONLY_ACTIVE_ARCH=NO \
        "${BUILD_ARGS[@]}" \
        clean build 2>&1 | tail -5

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
    echo "[1/7] ビルドをスキップ"
    if [[ ! -d "$APP_PATH" ]]; then
        echo "エラー: ${APP_PATH} が見つかりません。--skip-build なしで実行してください。"
        exit 1
    fi
fi

# ------------------------------------------------------------
# [2/7] 署名の検証
# ------------------------------------------------------------
echo ""
if [[ "$DO_SIGN" == true ]]; then
    echo "[2/7] 署名を検証中..."
    codesign --verify --deep --strict --verbose=2 "${APP_PATH}"
    echo "  署名 OK"
else
    echo "[2/7] 署名をスキップ"
fi

# ------------------------------------------------------------
# [3/7] .app の公証 + staple
#   zip 配布ぶんにも staple を効かせるため、DMG とは別に .app 単体を公証する。
#   staple 済みなら証明書が将来失効してもゲートキーパーを通る。
# ------------------------------------------------------------
echo ""
if [[ "$DO_NOTARIZE" == true ]]; then
    echo "[3/7] .app を公証中..."
    NOTARIZE_ZIP="${BUILD_DIR}/${APP_NAME}-notarize.zip"
    rm -f "${NOTARIZE_ZIP}"
    ditto -c -k --keepParent "${APP_PATH}" "${NOTARIZE_ZIP}"
    notarize "${NOTARIZE_ZIP}"
    rm -f "${NOTARIZE_ZIP}"
    xcrun stapler staple "${APP_PATH}"
    echo "  .app の公証・staple 完了"
else
    echo "[3/7] .app の公証をスキップ"
fi

# ------------------------------------------------------------
# [4/7] 配布用 zip（staple 済み .app から生成）
#   ditto を使うのは Sparkle.framework のシンボリックリンクを保つため。
# ------------------------------------------------------------
echo ""
echo "[4/7] 配布用 zip 作成中..."
rm -f "${DIST_ZIP}"
ditto -c -k --keepParent "${APP_PATH}" "${DIST_ZIP}"
echo "  ${DIST_ZIP}"

# ------------------------------------------------------------
# [5/7] DMG 作成
# ------------------------------------------------------------
echo ""
echo "[5/7] DMG 作成中..."
rm -f "${DMG_PATH}"
DMG_TEMP="${BUILD_DIR}/dmg-temp"
rm -rf "${DMG_TEMP}"
mkdir -p "${DMG_TEMP}"
cp -R "${APP_PATH}" "${DMG_TEMP}/"
ln -s /Applications "${DMG_TEMP}/Applications"

hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${DMG_TEMP}" \
    -ov \
    -format UDZO \
    "${DMG_PATH}" 2>&1 | tail -3

rm -rf "${DMG_TEMP}"

# ------------------------------------------------------------
# [6/7] DMG の署名・公証・staple
# ------------------------------------------------------------
echo ""
if [[ "$DO_SIGN" == true ]]; then
    echo "[6/7] DMG を署名中..."
    codesign --force --timestamp --sign "${DEVELOPER_ID_APP}" "${DMG_PATH}"
    if [[ "$DO_NOTARIZE" == true ]]; then
        echo "  DMG を公証中..."
        notarize "${DMG_PATH}"
        xcrun stapler staple "${DMG_PATH}"
        echo "  DMG の公証・staple 完了"
    fi
else
    echo "[6/7] DMG の署名をスキップ"
fi

# ------------------------------------------------------------
# [7/7] 出荷前チェック
#   ここで落とすことで、失効証明書や未公証のビルドを配布してしまう事故を防ぐ。
# ------------------------------------------------------------
echo ""
echo "[7/7] 出荷前チェック..."
if [[ "$DO_SIGN" == true ]]; then
    # 証明書の失効はここで CSSMERR_TP_CERT_REVOKED として検出される
    codesign --verify --deep --strict "${APP_PATH}"

    if [[ "$DO_NOTARIZE" == true ]]; then
        # Gatekeeper 判定。未公証だと必ず reject されるので公証時のみ実行する。
        if ! spctl -a -vv -t exec "${APP_PATH}" 2>&1 | tee /dev/stderr | grep -q "accepted"; then
            echo ""
            echo "❌ Gatekeeper に拒否されました。この成果物は配布できません。"
            exit 1
        fi
        xcrun stapler validate "${APP_PATH}"
        xcrun stapler validate "${DMG_PATH}"
        echo "  ✅ 署名・公証・staple すべて OK。配布可能。"
    else
        echo "  署名 OK（未公証のため配布不可）"
    fi
else
    echo "  未署名ビルド（配布不可・ローカル確認用）"
fi

echo ""
echo "================================================"
echo "  DMG: ${DMG_PATH} ($(du -h "${DMG_PATH}" | cut -f1))"
echo "  ZIP: ${DIST_ZIP} ($(du -h "${DIST_ZIP}" | cut -f1))"
echo "================================================"
