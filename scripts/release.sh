#!/bin/bash
set -euo pipefail

# ============================================================
# Notipon Release Script
# ビルド → 署名 → 公証 → staple → appcast生成 → 配布物出力
#
# Usage: ./scripts/release.sh
#
# 事前準備（初回のみ）:
#   xcrun notarytool store-credentials "notipon" \
#       --apple-id <Apple ID> --team-id <Team ID>
#
# 環境変数（任意）:
#   NOTARY_PROFILE  - notarytool プロファイル名（既定: notipon）
#   DEVELOPER_ID_APP - 証明書名（未設定なら自動検出）
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="${PROJECT_DIR}/dist"
DOCS_DIR="${PROJECT_DIR}/docs"
XCODEPROJ="${PROJECT_DIR}/Notipon.xcodeproj"
NOTARY_PROFILE="${NOTARY_PROFILE:-notipon}"
REPO="Mugendesk/Notipon"

VERSION=$(grep 'MARKETING_VERSION' "${XCODEPROJ}/project.pbxproj" | head -1 | sed 's/.*= //' | sed 's/;//' | tr -d ' ')
TAG="v${VERSION}"

echo "============================================"
echo "  Notipon Release ${TAG}"
echo "============================================"
echo ""

# ------------------------------------------------------------
# 事前チェック: 公証の認証情報
# ------------------------------------------------------------
if ! xcrun notarytool history --keychain-profile "${NOTARY_PROFILE}" &>/dev/null; then
    if [[ -z "${APPLE_ID:-}" || -z "${APPLE_TEAM_ID:-}" || -z "${APPLE_APP_PASSWORD:-}" ]]; then
        echo "エラー: 公証の認証情報がありません。"
        echo ""
        echo "  xcrun notarytool store-credentials \"${NOTARY_PROFILE}\" \\"
        echo "      --apple-id \"<Apple ID>\" --team-id \"<Team ID>\""
        echo ""
        echo "を一度実行してください（App用パスワードは appleid.apple.com で発行）。"
        exit 1
    fi
fi

# ------------------------------------------------------------
# Step 1: ビルド + 署名 + 公証 + staple
# ------------------------------------------------------------
echo "[Step 1/3] ビルド（署名・公証・staple）"
echo "-------------------------------------------"
"${SCRIPT_DIR}/build-dmg.sh" --sign --notarize

DMG_PATH="${BUILD_DIR}/Notipon-${VERSION}.dmg"
ZIP_PATH="${BUILD_DIR}/Notipon.zip"

# ------------------------------------------------------------
# Step 2: appcast.xml 生成
#   Sparkle の配信対象は zip。ダウンロード先は GitHub Releases なので
#   --download-url-prefix でタグ付き URL を埋め込む。
# ------------------------------------------------------------
echo ""
echo "[Step 2/3] appcast.xml 生成"
echo "-------------------------------------------"

GENERATE_APPCAST=""
for candidate in \
    "${BUILD_DIR}/DerivedData/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_appcast" \
    "/opt/homebrew/bin/generate_appcast"; do
    if [[ -x "$candidate" ]]; then
        GENERATE_APPCAST="$candidate"
        break
    fi
done
if [[ -z "$GENERATE_APPCAST" ]] && command -v generate_appcast &>/dev/null; then
    GENERATE_APPCAST="generate_appcast"
fi

if [[ -z "$GENERATE_APPCAST" ]]; then
    echo "エラー: generate_appcast が見つかりません"
    echo "  https://github.com/sparkle-project/Sparkle/releases から入手してください"
    echo "  配布物自体は作成済みです: ${DMG_PATH}"
    exit 1
fi

# 今回のバージョンだけを入れたステージングディレクトリで生成する
# （dist/ を直接渡すと旧バージョンの成果物まで拾ってしまうため）
APPCAST_SRC="${BUILD_DIR}/appcast-src"
rm -rf "${APPCAST_SRC}"
mkdir -p "${APPCAST_SRC}"
cp "${ZIP_PATH}" "${APPCAST_SRC}/Notipon-${VERSION}.zip"

"${GENERATE_APPCAST}" \
    --download-url-prefix "https://github.com/${REPO}/releases/download/${TAG}/" \
    "${APPCAST_SRC}"

APPCAST_PATH="${APPCAST_SRC}/appcast.xml"
if [[ ! -f "$APPCAST_PATH" ]]; then
    echo "エラー: appcast.xml が生成されませんでした"
    exit 1
fi

# GitHub Pages（main ブランチの docs/ を公開）へ配置
mkdir -p "${DOCS_DIR}"
cp "${APPCAST_PATH}" "${DOCS_DIR}/appcast.xml"
echo "  ${DOCS_DIR}/appcast.xml を更新"

# ------------------------------------------------------------
# Step 3: 次の手順を表示
# ------------------------------------------------------------
echo ""
echo "============================================"
echo "  ビルド完了 ${TAG}"
echo "============================================"
echo "  DMG: ${DMG_PATH}"
echo "  ZIP: ${ZIP_PATH}"
echo "  appcast: ${DOCS_DIR}/appcast.xml"
echo ""
echo "次の手順:"
echo "  1. appcast をコミット & push（GitHub Pages が更新される）"
echo "     git add docs/appcast.xml && git commit -m \"chore: appcast を ${TAG} に更新\" && git push"
echo ""
echo "  2. リリース作成（zip の名前は appcast の enclosure と一致させること）"
echo "     cp \"${ZIP_PATH}\" \"${BUILD_DIR}/Notipon-${VERSION}.zip\""
echo "     gh release create ${TAG} -R ${REPO} \\"
echo "         \"${DMG_PATH}\" \"${BUILD_DIR}/Notipon-${VERSION}.zip\""
echo "============================================"
