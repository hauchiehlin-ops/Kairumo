#!/usr/bin/env bash
#
# scripts/setup-apple-credentials.sh
# 互動式 Apple 憑證設定精靈
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIG_FILE="${REPO_ROOT}/apple/ExportConfig.env"

echo "=================================================="
echo "🍎 Kairumo Apple 發布憑證設定精靈（零基礎導引）"
echo "=================================================="
echo ""

read -rp "👉 [1/5] 請輸入您的 Apple Developer Team ID (10 碼英數，例如 9X8A2BC3DE): " INPUT_TEAM_ID
read -rp "👉 [2/5] 請輸入 Bundle ID (直接按 Enter 預設使用 com.kairumo.padnote): " INPUT_BUNDLE_ID
INPUT_BUNDLE_ID="${INPUT_BUNDLE_ID:-com.kairumo.padnote}"

echo ""
echo "--- App Store Connect API Key 設定 ---"
read -rp "👉 [3/5] 請輸入 Key ID (10 碼英數，例如 2X9R4HXF34): " INPUT_KEY_ID
read -rp "👉 [4/5] 請輸入 Issuer ID (UUID 格式，例如 57246542-96fe-1a63-e053-0824d011072a): " INPUT_ISSUER_ID
read -rp "👉 [5/5] 請輸入下載的 .p8 私鑰檔案路徑 (例如 ~/Downloads/AuthKey_${INPUT_KEY_ID}.p8): " INPUT_KEY_PATH

# 展開 ~ 路徑
INPUT_KEY_PATH="${INPUT_KEY_PATH/#\~/$HOME}"

if [[ ! -f "$INPUT_KEY_PATH" ]]; then
    echo "⚠️ 找不到私鑰檔案：$INPUT_KEY_PATH"
    echo "   請確認檔案名稱與路徑是否正確，稍後亦可手動在 apple/ExportConfig.env 調整。"
fi

cat << CONFIG_EOF > "$CONFIG_FILE"
# 自動產生之 Apple 發布設定檔
APPLE_TEAM_ID="${INPUT_TEAM_ID}"
BUNDLE_ID="${INPUT_BUNDLE_ID}"
PROJECT_PATH="apple/Kairumo.xcodeproj"
SCHEME="Kairumo"

# App Store Connect API Key 憑證
APP_STORE_CONNECT_API_KEY_ID="${INPUT_KEY_ID}"
APP_STORE_CONNECT_ISSUER_ID="${INPUT_ISSUER_ID}"
APP_STORE_CONNECT_KEY_PATH="${INPUT_KEY_PATH}"
CONFIG_EOF

echo ""
echo "=================================================="
echo "✅ 設定檔已成功寫入：apple/ExportConfig.env"
echo "👉 檔案已被 .gitignore 保護，不會被上傳至公開倉庫。"
echo "=================================================="
