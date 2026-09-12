#!/usr/bin/env bash
#
# scripts/apple-release.sh
# 一鍵式終端機指令：編譯 Rust 核心、Xcode 封裝（Mac Catalyst/iOS 通用）並自動上傳至 App Store Connect
#
# 用法：
#   ./scripts/apple-release.sh                  # 完整建置、封裝並上傳
#   ./scripts/apple-release.sh --validate-only  # 僅驗證不真正上傳
#   ./scripts/apple-release.sh --skip-rust      # 略過 Rust XCFramework 編譯以節省時間
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIG_FILE="${REPO_ROOT}/apple/ExportConfig.env"

# 載入使用者設定檔（若存在）
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

VALIDATE_ONLY=0
SKIP_RUST=0

for arg in "$@"; do
    case "$arg" in
        --validate-only)
            VALIDATE_ONLY=1
            ;;
        --skip-rust)
            SKIP_RUST=1
            ;;
        -h|--help)
            echo "用法: $0 [--validate-only] [--skip-rust]"
            exit 0
            ;;
    esac
done

echo "=================================================="
echo "🍎 Kairumo Apple 通用應用程式（iOS / iPadOS / Mac）一鍵打包與上傳"
echo "=================================================="

# 1. 檢查必要變數
APPLE_TEAM_ID="${APPLE_TEAM_ID:-}"
PROJECT_PATH="${PROJECT_PATH:-${REPO_ROOT}/apple/Kairumo.xcodeproj}"
SCHEME="${SCHEME:-Kairumo}"

if [[ -z "$APPLE_TEAM_ID" ]]; then
    echo "⚠️ 尚未設定 APPLE_TEAM_ID。"
    echo "   請複製 apple/ExportConfig.env.template 為 apple/ExportConfig.env 並填寫您的資訊："
    echo "   cp apple/ExportConfig.env.template apple/ExportConfig.env"
    echo ""
fi

# 2. 步驟一：編譯 Rust 核心與 XCFramework
if [[ "$SKIP_RUST" -eq 0 ]]; then
    echo "⚙️ [1/4] 編譯 Rust 核心與生成 PadnoteCore.xcframework..."
    if [[ -f "${SCRIPT_DIR}/build-xcframework.sh" ]]; then
        "${SCRIPT_DIR}/build-xcframework.sh"
    else
        echo "❌ 找不到 ${SCRIPT_DIR}/build-xcframework.sh" >&2
        exit 1
    fi
else
    echo "⏩ [1/4] 略過 Rust XCFramework 編譯 (--skip-rust)"
fi

# 檢查 Xcode 專案
if [[ ! -d "$PROJECT_PATH" ]]; then
    echo "--------------------------------------------------"
    echo "⚠️ 目前未偵測到 Xcode 專案：$PROJECT_PATH"
    echo "   若您已建立 Xcode 專案，請於 apple/ExportConfig.env 指定 PROJECT_PATH。"
    echo "   若尚未建立 Xcode 專案，請先在 Xcode 中開啟/建立專案，"
    echo "   並確認 Target 勾選支援：iPhone、iPad 與 Mac (Mac Catalyst)。"
    echo "--------------------------------------------------"
    exit 1
fi

BUILD_DIR="${REPO_ROOT}/build/apple"
ARCHIVE_PATH="${BUILD_DIR}/${SCHEME}.xcarchive"
EXPORT_PATH="${BUILD_DIR}/export"
EXPORT_PLIST="${BUILD_DIR}/ExportOptions.plist"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# 3. 步驟二：自動產生 ExportOptions.plist
echo "📄 [2/4] 產生 ExportOptions.plist..."
cat << PLIST_EOF > "$EXPORT_PLIST"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>teamID</key>
    <string>${APPLE_TEAM_ID}</string>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
    <key>manageAppVersionAndBuildNumber</key>
    <true/>
</dict>
</plist>
PLIST_EOF

# 4. 步驟三：xcodebuild archive 封裝
APP_VER=$(python3 -c "import re; m=re.search(r'version\s*=\s*\"([^\"]+)\"', open('${REPO_ROOT}/Cargo.toml').read()); print(m.group(1) if m else '0.1.7')")
echo "📦 [3/4] 執行 xcodebuild archive 封裝通用應用程式 (版本: v${APP_VER})..."
xcodebuild archive \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination "generic/platform=iOS" \
    -archivePath "$ARCHIVE_PATH" \
    DEVELOPMENT_TEAM="${APPLE_TEAM_ID}" \
    MARKETING_VERSION="${APP_VER}" \
    CURRENT_PROJECT_VERSION="1" \
    INFOPLIST_KEY_CFBundleShortVersionString="${APP_VER}" \
    INFOPLIST_KEY_CFBundleVersion="1" \
    INFOPLIST_KEY_ITSAppUsesNonExemptEncryption="NO" \
    -quiet

# 5. 導出 IPA
echo "📤 導出 App Store 發行套件 (IPA)..."
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_PLIST" \
    -allowProvisioningUpdates \
    -quiet

IPA_FILE=$(find "$EXPORT_PATH" -name "*.ipa" | head -n 1)

if [[ -z "$IPA_FILE" || ! -f "$IPA_FILE" ]]; then
    echo "❌ 導出失敗：在 $EXPORT_PATH 未找到 IPA 檔案" >&2
    exit 1
fi

echo "✅ 成功產出發行檔案：$IPA_FILE"

# 6. 步驟四：上傳至 App Store Connect
ACTION_NAME="上傳"
ALTOOL_ACTION="--upload-app"
if [[ "$VALIDATE_ONLY" -eq 1 ]]; then
    ACTION_NAME="驗證"
    ALTOOL_ACTION="--validate-app"
fi

echo "🚀 [4/4] 正在${ACTION_NAME}至 App Store Connect..."

if [[ -n "${APP_STORE_CONNECT_API_KEY_ID:-}" && -n "${APP_STORE_CONNECT_ISSUER_ID:-}" && -n "${APP_STORE_CONNECT_KEY_PATH:-}" ]]; then
    # 使用 API Key 模式
    echo "🔐 使用 App Store Connect API Key (Key ID: $APP_STORE_CONNECT_API_KEY_ID)..."
    # altool 預設會尋找 ~/.appstoreconnect/private_keys 或 ~/.private_keys
    KEYS_DIR="${HOME}/.appstoreconnect/private_keys"
    mkdir -p "$KEYS_DIR"
    cp -f "$APP_STORE_CONNECT_KEY_PATH" "${KEYS_DIR}/AuthKey_${APP_STORE_CONNECT_API_KEY_ID}.p8"

    xcrun altool "$ALTOOL_ACTION" \
        -f "$IPA_FILE" \
        -t ios \
        --apiKey "$APP_STORE_CONNECT_API_KEY_ID" \
        --apiIssuer "$APP_STORE_CONNECT_ISSUER_ID"
elif [[ -n "${APPLE_ID:-}" && -n "${APP_SPECIFIC_PASSWORD:-}" ]]; then
    if [[ "$APPLE_ID" == *"您的Apple帳號Email"* || "$APPLE_ID" == *"example.com"* ]]; then
        echo "❌ 請先在 apple/ExportConfig.env 中將 APPLE_ID 修改為您真實的 Apple 帳號 Email！" >&2
        echo "   目前套件 $IPA_FILE 已打包完成，填寫正確 Email 後即可上傳，或直接用 Transporter App 上傳。" >&2
        exit 1
    fi
    # 使用帳號密碼模式
    echo "🔐 使用 Apple ID ($APPLE_ID) 與 App 專用密碼..."
    xcrun altool "$ALTOOL_ACTION" \
        -f "$IPA_FILE" \
        -t ios \
        -u "$APPLE_ID" \
        -p "$APP_SPECIFIC_PASSWORD"
else
    echo "❌ 缺少上傳憑證資訊！"
    echo "   請在 apple/ExportConfig.env 中填入【方式 A: API Key】或【方式 B: 專用密碼】。"
    echo "   檔案路徑：$IPA_FILE 已保留，您亦可使用 Transporter App 手動上傳。"
    exit 1
fi

echo "=================================================="
echo "🎉 恭喜！Kairumo 通用應用程式已成功${ACTION_NAME}至 App Store Connect！"
echo "   iPhone、iPad 與 Mac 使用者即將可以在 App Store 下載。"
echo "=================================================="
