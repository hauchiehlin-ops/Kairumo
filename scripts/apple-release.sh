#!/usr/bin/env bash
#
# scripts/apple-release.sh
# 一鍵式終端機指令：編譯 Rust 核心、Xcode 封裝（Mac Catalyst/iOS 通用）並自動上傳至 App Store Connect
#
# 用法：
#   ./scripts/apple-release.sh                  # 完整建置、封裝並上傳
#   ./scripts/apple-release.sh --validate-only  # 僅驗證不真正上傳
#   ./scripts/apple-release.sh --skip-rust      # 略過 Rust XCFramework 編譯以節省時間
#   ./scripts/apple-release.sh --ios-only       # 只做 iOS 版（不產 Mac 版）
#
# ⚠️ Mac 版是**另一個組建**，不是同一個。
#
# iOS 的 .ipa 上傳之後，Mac 版的 TestFlight 是看不到的 —— 使用者按下安裝會得到
# 「要求的 App 無法使用或不存在」。那不是 App Store Connect 的狀態問題，
# 是根本沒有 macOS 的組建可以給它。Mac Catalyst 必須用
# `generic/platform=macOS,variant=Mac Catalyst` 另外封裝，並以 `-t macos` 上傳。
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
# 預設兩個平台都做。使用者在 Mac 上裝不到 App 的那次，就是因為只有 iOS 組建。
BUILD_MAC=1

for arg in "$@"; do
    case "$arg" in
        --validate-only)
            VALIDATE_ONLY=1
            ;;
        --skip-rust)
            SKIP_RUST=1
            ;;
        --ios-only)
            BUILD_MAC=0
            ;;
        -h|--help)
            echo "用法: $0 [--validate-only] [--skip-rust] [--ios-only]"
            exit 0
            ;;
        *)
            # 沒有這個分支時，打錯的旗標會被靜默吃掉，然後直接**真的上傳**。
            # 踩過一次：想跑 --validate-app（那是 altool 的動作名，不是本腳本的旗標），
            # 結果整包送上 App Store Connect。寧可在這裡停下來。
            echo "❌ 未知參數：$arg" >&2
            echo "   用法: $0 [--validate-only] [--skip-rust] [--ios-only]" >&2
            exit 2
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

# 版本閘門。android-release.sh 本來就有這道，apple 這邊沒有 —— 2.8.0 (20)
# 那顆裝不起來的 build 就是這樣送出去的。放在編譯前，錯了就別浪費那十分鐘。
echo "==> 檢查版本一致性"
"${SCRIPT_DIR}/check-version-consistency.sh"

# 打包進 App 的手冊是 apple/Resources/Docs 底下的副本。改了 docs/ 卻忘了同步，
# 兩邊檔案都在、都不會報錯，只有使用者會看到舊版本號。同步是冪等的，直接跑。
if [[ -f "${SCRIPT_DIR}/sync-docs.sh" ]]; then
    "${SCRIPT_DIR}/sync-docs.sh" > /dev/null
    echo "==> 使用者文件已同步至 apple/Resources/Docs"
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
APP_VER=$(python3 -c "import re; m=re.search(r'version\s*=\s*\"([^\"]+)\"', open('${REPO_ROOT}/Cargo.toml').read()); print(m.group(1) if m else '1.0.0')")
BUNDLE_VER=$(python3 -c "import re, os; f='${REPO_ROOT}/apple/Kairumo.xcodeproj/project.pbxproj'; content=open(f).read() if os.path.exists(f) else ''; m=re.search(r'CURRENT_PROJECT_VERSION\s*=\s*(\d+)', content); print(m.group(1) if m else '1')")
echo "📦 [3/4] 封裝 (版本: v${APP_VER}, Bundle: ${BUNDLE_VER})..."

ACTION_NAME="上傳"
ALTOOL_ACTION="--upload-app"
if [[ "$VALIDATE_ONLY" -eq 1 ]]; then
    ACTION_NAME="驗證"
    ALTOOL_ACTION="--validate-app"
fi

# 把「封裝 → 匯出 → 上傳」抽成一段，兩個平台走同一條路。
#
# $1 = 人看的名稱、$2 = xcodebuild 的 destination、$3 = altool 的平台代號
archive_export_upload() {
    local label="$1" destination="$2" altool_platform="$3"
    local archive="${BUILD_DIR}/${SCHEME}-${altool_platform}.xcarchive"
    local export_dir="${BUILD_DIR}/export-${altool_platform}"

    echo "──────────────────────────────────────────────────"
    echo "📦 封裝 ${label}（${destination}）"
    xcodebuild archive \
        -project "$PROJECT_PATH" \
        -scheme "$SCHEME" \
        -configuration Release \
        -destination "$destination" \
        -archivePath "$archive" \
        DEVELOPMENT_TEAM="${APPLE_TEAM_ID}" \
        MARKETING_VERSION="${APP_VER}" \
        CURRENT_PROJECT_VERSION="${BUNDLE_VER}" \
        INFOPLIST_KEY_CFBundleShortVersionString="${APP_VER}" \
        INFOPLIST_KEY_CFBundleVersion="${BUNDLE_VER}" \
        INFOPLIST_KEY_ITSAppUsesNonExemptEncryption="NO" \
        -quiet

    echo "📤 匯出 ${label} 發行套件..."
    xcodebuild -exportArchive \
        -archivePath "$archive" \
        -exportPath "$export_dir" \
        -exportOptionsPlist "$EXPORT_PLIST" \
        -allowProvisioningUpdates \
        -quiet

    # iOS 匯出 .ipa，Mac Catalyst 匯出 .pkg —— 兩種都要找得到。
    local package
    package=$(find "$export_dir" \( -name "*.ipa" -o -name "*.pkg" \) | head -n 1)
    if [[ -z "$package" || ! -f "$package" ]]; then
        echo "❌ ${label} 匯出失敗：在 $export_dir 找不到 .ipa 或 .pkg" >&2
        return 1
    fi
    echo "✅ ${label} 產出：$package"

    echo "🚀 正在${ACTION_NAME} ${label} 至 App Store Connect..."
    if [[ -n "${APP_STORE_CONNECT_API_KEY_ID:-}" && -n "${APP_STORE_CONNECT_ISSUER_ID:-}" && -n "${APP_STORE_CONNECT_KEY_PATH:-}" ]]; then
        local keys_dir="${HOME}/.appstoreconnect/private_keys"
        mkdir -p "$keys_dir"
        cp -f "$APP_STORE_CONNECT_KEY_PATH" "${keys_dir}/AuthKey_${APP_STORE_CONNECT_API_KEY_ID}.p8"
        xcrun altool "$ALTOOL_ACTION" \
            -f "$package" \
            -t "$altool_platform" \
            --apiKey "$APP_STORE_CONNECT_API_KEY_ID" \
            --apiIssuer "$APP_STORE_CONNECT_ISSUER_ID"
    elif [[ -n "${APPLE_ID:-}" && -n "${APP_SPECIFIC_PASSWORD:-}" ]]; then
        if [[ "$APPLE_ID" == *"您的Apple帳號Email"* || "$APPLE_ID" == *"example.com"* ]]; then
            echo "❌ 請先在 apple/ExportConfig.env 中將 APPLE_ID 改成真實的 Apple 帳號 Email。" >&2
            echo "   $package 已打包完成，填好之後即可上傳，或用 Transporter App 手動上傳。" >&2
            return 1
        fi
        xcrun altool "$ALTOOL_ACTION" \
            -f "$package" \
            -t "$altool_platform" \
            -u "$APPLE_ID" \
            -p "$APP_SPECIFIC_PASSWORD"
    else
        echo "❌ 缺少上傳憑證資訊。" >&2
        echo "   請在 apple/ExportConfig.env 填入【方式 A: API Key】或【方式 B: 專用密碼】。" >&2
        echo "   $package 已保留，也可以用 Transporter App 手動上傳。" >&2
        return 1
    fi
}

echo "🚀 [4/4] ${ACTION_NAME}至 App Store Connect"
archive_export_upload "iPhone / iPad" "generic/platform=iOS" "ios"

if [[ "$BUILD_MAC" -eq 1 ]]; then
    # Mac 版必須另外封裝。只上傳 iOS 的話，Mac 的 TestFlight 會顯示
    # 「要求的 App 無法使用或不存在」—— 因為那裡根本沒有可安裝的組建。
    archive_export_upload "Mac" "generic/platform=macOS,variant=Mac Catalyst" "macos"
else
    echo "⏩ 略過 Mac 版（--ios-only）。Mac 的 TestFlight 將看不到這個版本。"
fi

echo "=================================================="
echo "🎉 Kairumo 已成功${ACTION_NAME}至 App Store Connect。"
if [[ "$BUILD_MAC" -eq 1 ]]; then
    echo "   iPhone / iPad 與 Mac 兩個組建都已送出 —— 兩邊的 TestFlight 都會看到。"
else
    echo "   只送出了 iPhone / iPad 組建。"
fi
echo "=================================================="
