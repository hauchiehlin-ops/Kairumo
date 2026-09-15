#!/usr/bin/env bash
#
# scripts/dist.sh
# 一鍵產出「可以直接安裝、直接發給別人」的三平台套件 —— 不經過任何商店。
#
#   macOS   → Kairumo-<版本>-mac.dmg     Developer ID 簽章 + 公證 + 釘選（別人下載即可開）
#   iOS     → Kairumo-<版本>-ios.ipa     Ad Hoc 簽章（限已登錄 UDID 的裝置）
#   Android → Kairumo-<版本>-android.apk 正式簽章的 universal APK（直接安裝）
#
# 用法：
#   ./scripts/dist.sh                 # 三個平台全做
#   ./scripts/dist.sh --mac-only
#   ./scripts/dist.sh --ios-only
#   ./scripts/dist.sh --android-only
#   ./scripts/dist.sh --skip-rust     # 略過 Rust XCFramework 重編（省十來分鐘）
#   ./scripts/dist.sh --no-notarize   # Mac 不公證（只能自己用，別人開會被 Gatekeeper 擋）
#
# 與 release.sh 的差別：
#   release.sh 是**上架**流程 —— 升版本號、建立 commit、送 App Store Connect / Play Console。
#   dist.sh 不升版、不 commit、不碰任何商店，只把「當下這份程式碼」打包成能發給人的檔案。
#
# ⚠️ iOS 的硬限制（不是這支腳本的缺陷，是 Apple 的規則）：
#   沒有企業帳號的話，.ipa 只能裝在**事先登錄 UDID** 的裝置上，一個帳號上限 100 台。
#   要給的人必須先把 UDID 給你，你到 developer.apple.com → Devices 登錄，再重跑這支腳本。
#   完全不登錄裝置就想給人裝 iOS App，只有 TestFlight 一條路（那要走 release.sh）。
#
set -euo pipefail

# 腳本輸出含中文。終端機若不是 UTF-8 locale，內嵌 python3 印中文會直接中止。
export PYTHONIOENCODING=utf-8

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

CONFIG_FILE="${REPO_ROOT}/apple/ExportConfig.env"
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

DO_MAC=1; DO_IOS=1; DO_ANDROID=1; SKIP_RUST=0; NOTARIZE=1
for arg in "$@"; do
    case "$arg" in
        --mac-only)     DO_IOS=0; DO_ANDROID=0 ;;
        --ios-only)     DO_MAC=0; DO_ANDROID=0 ;;
        --android-only) DO_MAC=0; DO_IOS=0 ;;
        --skip-rust)    SKIP_RUST=1 ;;
        --no-notarize)  NOTARIZE=0 ;;
        -h|--help)      sed -n '3,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *)
            # 打錯的旗標不能靜默吃掉 —— 使用者會以為做了某件事，實際沒有。
            echo "❌ 未知參數：$arg" >&2
            echo "   用法: $0 [--mac-only|--ios-only|--android-only] [--skip-rust] [--no-notarize]" >&2
            exit 2 ;;
    esac
done

APPLE_TEAM_ID="${APPLE_TEAM_ID:-}"
PROJECT_PATH="${PROJECT_PATH:-${REPO_ROOT}/apple/Kairumo.xcodeproj}"
[[ "$PROJECT_PATH" != /* ]] && PROJECT_PATH="${REPO_ROOT}/${PROJECT_PATH}"
SCHEME="${SCHEME:-Kairumo}"

APP_VER=$(python3 -c "import re; print(re.search(r'version\s*=\s*\"([^\"]+)\"', open('${REPO_ROOT}/Cargo.toml').read()).group(1))")
BUNDLE_VER=$(python3 -c "import re; print(re.search(r'CURRENT_PROJECT_VERSION\s*=\s*(\d+)', open('${REPO_ROOT}/apple/Kairumo.xcodeproj/project.pbxproj').read()).group(1))")

WORK_DIR="${REPO_ROOT}/build/dist-work"
OUT_DIR="${REPO_ROOT}/build/dist/v${APP_VER}-b${BUNDLE_VER}"
rm -rf "$WORK_DIR"; mkdir -p "$WORK_DIR" "$OUT_DIR"

echo "=================================================="
echo "📦 Kairumo v${APP_VER} (build ${BUNDLE_VER}) 側載打包"
echo "   產出目錄：${OUT_DIR}"
echo "=================================================="

step() { echo ""; echo "━━━ $* ━━━"; }
FAILED=()
DELIVERED=()

# 版本一致性先擋。三個平台版本號對不上的套件發出去，之後沒人分得清誰是誰。
step "前置檢查"
"${SCRIPT_DIR}/check-version-consistency.sh"
if [[ -f "${SCRIPT_DIR}/sync-docs.sh" ]]; then
    "${SCRIPT_DIR}/sync-docs.sh" >/dev/null
    echo "   ✅ 使用者文件已同步至 apple/Resources/Docs"
fi

# ───────────────────────────── Apple 共用 ─────────────────────────────
if [[ "$DO_MAC" -eq 1 || "$DO_IOS" -eq 1 ]]; then
    if [[ -z "$APPLE_TEAM_ID" ]]; then
        echo "❌ 缺少 APPLE_TEAM_ID（apple/ExportConfig.env）。Apple 端無法簽章。" >&2
        exit 1
    fi
    if [[ "$SKIP_RUST" -eq 0 ]]; then
        step "編譯 Rust 核心與 PadnoteCore.xcframework"
        "${SCRIPT_DIR}/build-xcframework.sh"
    else
        echo "   ⏩ 略過 Rust XCFramework 重編（--skip-rust）"
        [[ -d "${REPO_ROOT}/apple/PadnoteCore.xcframework" ]] || {
            echo "❌ --skip-rust 但 apple/PadnoteCore.xcframework 不存在，沒有東西可以連結。" >&2; exit 1; }
    fi
fi

# 封裝一個平台，結果路徑放進全域 EXPORT_DIR。
#
# 不用 $(archive_and_export …) 取回路徑：xcodebuild 即使加了 -quiet 仍會往
# stdout 吐東西，指令替換會把那些一起吃進變數裡，變成一個不存在的路徑。
#
# $1=人看的名稱 $2=destination $3=輸出代號 $4=ExportOptions 的 method
EXPORT_DIR=""
archive_and_export() {
    local label="$1" destination="$2" tag="$3" method="$4"
    local archive="${WORK_DIR}/${SCHEME}-${tag}.xcarchive"
    local export_dir="${WORK_DIR}/export-${tag}"
    local plist="${WORK_DIR}/ExportOptions-${tag}.plist"

    cat > "$plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key><string>${method}</string>
    <key>signingStyle</key><string>automatic</string>
    <key>teamID</key><string>${APPLE_TEAM_ID}</string>
    <key>uploadSymbols</key><false/>
    <!-- 必須 false。true 會讓 Xcode 在匯出時自行改寫 build 號，
         發出去的套件版本與 repo 對不上，事後追不回來是哪一份。 -->
    <key>manageAppVersionAndBuildNumber</key><false/>
    <!-- 側載要的是「一份裝到底」的通用套件，不做 App Thinning 變體。 -->
    <key>thinning</key><string>&lt;none&gt;</string>
</dict>
</plist>
PLIST

    echo "📦 封裝 ${label}…"
    xcodebuild archive \
        -project "$PROJECT_PATH" -scheme "$SCHEME" -configuration Release \
        -destination "$destination" -archivePath "$archive" \
        DEVELOPMENT_TEAM="${APPLE_TEAM_ID}" \
        MARKETING_VERSION="${APP_VER}" \
        CURRENT_PROJECT_VERSION="${BUNDLE_VER}" \
        INFOPLIST_KEY_CFBundleShortVersionString="${APP_VER}" \
        INFOPLIST_KEY_CFBundleVersion="${BUNDLE_VER}" \
        INFOPLIST_KEY_ITSAppUsesNonExemptEncryption="NO" \
        -allowProvisioningUpdates -quiet

    echo "📤 匯出 ${label}（${method}）…"
    xcodebuild -exportArchive \
        -archivePath "$archive" -exportPath "$export_dir" \
        -exportOptionsPlist "$plist" -allowProvisioningUpdates -quiet
    EXPORT_DIR="$export_dir"
}

# ───────────────────────────── macOS ─────────────────────────────
if [[ "$DO_MAC" -eq 1 ]]; then
    step "macOS（Developer ID + 公證，任何人下載即可開）"
    if archive_and_export "Mac" "generic/platform=macOS,variant=Mac Catalyst" "mac" "developer-id"; then
        APP_BUNDLE=$(find "$EXPORT_DIR" -maxdepth 2 -name "*.app" | head -n 1)
        if [[ -z "$APP_BUNDLE" ]]; then
            echo "❌ macOS 匯出後找不到 .app" >&2
            FAILED+=("macOS：匯出後找不到 .app")
        else
            # 做 DMG。直接發 .app 資料夾的話，經過雲端硬碟/壓縮軟體來回一趟，
            # 簽章常常就壞了（擴充屬性、符號連結被吃掉），對方打開是「已損毀」。
            # DMG 是單一檔案，整份原封不動地搬運。
            STAGE="${WORK_DIR}/dmg-stage"
            rm -rf "$STAGE"; mkdir -p "$STAGE"
            cp -R "$APP_BUNDLE" "$STAGE/"
            ln -s /Applications "$STAGE/Applications"
            DMG="${OUT_DIR}/Kairumo-${APP_VER}-mac.dmg"
            rm -f "$DMG"
            hdiutil create -volname "Kairumo ${APP_VER}" -srcfolder "$STAGE" \
                -ov -format UDZO "$DMG" >/dev/null

            # DMG 本身也簽。未簽的 DMG 在某些下載路徑會被 Gatekeeper 另外刁難。
            DEVID_HASH=$(security find-identity -v -p codesigning \
                | awk '/Developer ID Application/ {print $2; exit}')
            if [[ -n "$DEVID_HASH" ]]; then
                codesign --force --sign "$DEVID_HASH" --timestamp "$DMG"
            fi

            if [[ "$NOTARIZE" -eq 1 ]]; then
                # 沒有公證，別人下載後 macOS 會直接說「無法打開，Apple 無法驗證」。
                # 自己的機器感覺不到，因為開發機的 Gatekeeper 認得本機簽章 —— 
                # 「我這裡可以開」在這件事上完全不構成證據。
                if [[ -n "${APPLE_ID:-}" && -n "${APP_SPECIFIC_PASSWORD:-}" ]]; then
                    echo "🔏 送交 Apple 公證（通常 1–5 分鐘）…"
                    if xcrun notarytool submit "$DMG" \
                        --apple-id "$APPLE_ID" --password "$APP_SPECIFIC_PASSWORD" \
                        --team-id "$APPLE_TEAM_ID" --wait; then
                        # 釘選之後，對方的電腦離線也能通過驗證。
                        xcrun stapler staple "$DMG"
                        echo "   ✅ 公證與釘選完成"
                    else
                        FAILED+=("macOS：公證失敗（DMG 已產出但別人開會被 Gatekeeper 擋）")
                    fi
                else
                    FAILED+=("macOS：ExportConfig.env 缺 APPLE_ID / APP_SPECIFIC_PASSWORD，未公證")
                fi
            else
                echo "   ⏩ --no-notarize：未公證，只能自己用。"
            fi

            echo "🔍 驗證…"
            codesign --verify --deep --strict --verbose=1 "$STAGE/$(basename "$APP_BUNDLE")" 2>&1 | sed 's/^/   /'
            spctl -a -vvv -t install "$STAGE/$(basename "$APP_BUNDLE")" 2>&1 | sed 's/^/   /' || true
            if [[ "$NOTARIZE" -eq 1 ]]; then
                xcrun stapler validate "$DMG" 2>&1 | sed 's/^/   /' || FAILED+=("macOS：stapler validate 未通過")
            fi
            DELIVERED+=("$DMG")
        fi
    else
        FAILED+=("macOS：封裝/匯出失敗")
    fi
fi

# ───────────────────────────── iOS ─────────────────────────────
if [[ "$DO_IOS" -eq 1 ]]; then
    step "iOS / iPadOS（Ad Hoc，限已登錄 UDID 的裝置）"
    # Xcode 15.3 起 method 從 ad-hoc 改名為 release-testing，語意相同。
    if archive_and_export "iPhone / iPad" "generic/platform=iOS" "ios" "release-testing"; then
        IPA=$(find "$EXPORT_DIR" -name "*.ipa" | head -n 1)
        if [[ -z "$IPA" ]]; then
            FAILED+=("iOS：匯出後找不到 .ipa")
        else
            DEST="${OUT_DIR}/Kairumo-${APP_VER}-ios.ipa"
            cp -f "$IPA" "$DEST"

            echo "🔍 驗證…"
            PROBE="${WORK_DIR}/ipa-probe"; rm -rf "$PROBE"; mkdir -p "$PROBE"
            unzip -q -o "$DEST" "Payload/*/Info.plist" "Payload/*/embedded.mobileprovision" "Payload/*/Assets.car" -d "$PROBE" 2>/dev/null || true
            INFO=$(find "$PROBE/Payload" -maxdepth 2 -name Info.plist | head -n 1)
            if [[ -n "$INFO" ]]; then
                echo "   版本：$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO") ($(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO"))"
                /usr/libexec/PlistBuddy -c "Print :CFBundleIcons:CFBundlePrimaryIcon:CFBundleIconName" "$INFO" >/dev/null 2>&1 \
                    && echo "   ✅ App 圖示已編入" || FAILED+=("iOS：套件內找不到 App 圖示")
            fi
            PROF=$(find "$PROBE/Payload" -maxdepth 2 -name embedded.mobileprovision | head -n 1)
            if [[ -n "$PROF" ]]; then
                # 這一行是整個 iOS 側載最關鍵的資訊：描述檔裡有幾台裝置。
                # 收件人的 UDID 不在裡面，他裝不起來，而錯誤訊息不會說原因。
                DEV_COUNT=$(security cms -D -i "$PROF" 2>/dev/null \
                    | python3 -c "import sys,plistlib; d=plistlib.loads(sys.stdin.buffer.read()); print(len(d.get('ProvisionedDevices',[])))" 2>/dev/null || echo "?")
                EXPIRY=$(security cms -D -i "$PROF" 2>/dev/null \
                    | python3 -c "import sys,plistlib; d=plistlib.loads(sys.stdin.buffer.read()); print(d['ExpirationDate'])" 2>/dev/null || echo "?")
                echo "   描述檔涵蓋裝置數：${DEV_COUNT}    到期：${EXPIRY}"
                [[ "$DEV_COUNT" == "0" ]] && FAILED+=("iOS：描述檔沒有任何登錄裝置，這個 .ipa 誰也裝不了")
            fi
            rm -rf "$PROBE"
            DELIVERED+=("$DEST")
        fi
    else
        FAILED+=("iOS：封裝/匯出失敗（多半是帳號底下還沒登錄任何裝置 UDID）")
    fi
fi

# ───────────────────────────── Android ─────────────────────────────
if [[ "$DO_ANDROID" -eq 1 ]]; then
    step "Android（正式簽章的 universal APK）"
    export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
    if [[ ! -f "${REPO_ROOT}/android/app/src/main/jniLibs/arm64-v8a/libpadnote_core.so" ]]; then
        echo "   缺少 libpadnote_core.so，先建置原生函式庫"
        "${SCRIPT_DIR}/build-android-libs.sh"
    fi

    CLEANUP_KS=0
    if [[ ! -f "${REPO_ROOT}/android/keystore.properties" && -z "${KAIRUMO_STOREFILE:-}" ]]; then
        # 側載用的簽章金鑰自己產一把就好，不需要跟 Play 上架金鑰同一把。
        # 但**必須固定同一把**：Android 認金鑰不認版本，換了金鑰的新版
        # 會變成「與已安裝的應用程式衝突」，使用者只能先移除舊版（資料一起沒了）。
        # 所以這把金鑰產生後就留在 android/.local/ 並要備份，不是拋棄式的。
        KS_DIR="${REPO_ROOT}/android/.local"; mkdir -p "$KS_DIR"
        KS="${KS_DIR}/kairumo-sideload.jks"
        if [[ ! -f "$KS" ]]; then
            echo "   產生側載簽章金鑰（僅此一次，請備份 ${KS}）"
            keytool -genkeypair -v -keystore "$KS" -alias kairumo-sideload \
                -keyalg RSA -keysize 4096 -validity 10000 \
                -storepass kairumo-sideload -keypass kairumo-sideload \
                -dname "CN=Kairumo, OU=Sideload, O=Kairumo, C=TW" >/dev/null
        fi
        cat > "${REPO_ROOT}/android/keystore.properties" <<EOF
# 由 scripts/dist.sh 產生的**側載**簽章設定（非 Play 上架金鑰）。
storeFile=$KS
storePassword=kairumo-sideload
keyAlias=kairumo-sideload
keyPassword=kairumo-sideload
EOF
        CLEANUP_KS=1
        # 用完就移除設定檔。留著的話，日後任何一次 bundleRelease 都會靜默
        # 用這把側載金鑰簽 —— 簽出來的 AAB 外觀與正式版一模一樣，但 Play 會拒收。
        trap 'rm -f "${REPO_ROOT}/android/keystore.properties"' EXIT
        echo "   ⚠️ 使用側載金鑰（非上架金鑰）。要上架請改用 scripts/android-release.sh。"
    fi

    ( cd "${REPO_ROOT}/android" && ./gradlew --console=plain :app:assembleRelease )
    APK=$(find "${REPO_ROOT}/android/app/build/outputs/apk/release" -name "*.apk" | head -n 1)
    if [[ -z "$APK" ]]; then
        FAILED+=("Android：找不到建置產出的 APK")
    else
        DEST="${OUT_DIR}/Kairumo-${APP_VER}-android.apk"
        cp -f "$APK" "$DEST"

        echo "🔍 驗證…"
        APKSIGNER=$(find "${ANDROID_HOME}/build-tools" -name apksigner | sort -V | tail -n 1)
        if [[ -n "$APKSIGNER" ]]; then
            # 沒簽章或只有 v1 簽章的 APK，Android 11 以上直接拒絕安裝。
            if "$APKSIGNER" verify --print-certs "$DEST" >"${WORK_DIR}/apksig.txt" 2>&1; then
                # apksigner 的行首會是 "V2 Signer:" / "Signer #1" 等不同寫法，
                # 別去比對特定前綴：抓不到時 grep 回傳 1，set -e 會讓整支腳本
                # 在「其實驗證成功」的地方無聲中止（踩過一次，卡在這行找很久）。
                grep -E "certificate (DN|SHA-256 digest)" "${WORK_DIR}/apksig.txt" | sed 's/^/   /' || true
                echo "   ✅ 簽章驗證通過"
            else
                sed 's/^/   /' "${WORK_DIR}/apksig.txt"
                FAILED+=("Android：APK 簽章驗證失敗，裝置會拒絕安裝")
            fi
        else
            FAILED+=("Android：找不到 apksigner，未驗證簽章")
        fi
        # universal APK 必須兩個 ABI 都在，否則換一台手機就裝不起來。
        ABIS=$(unzip -l "$DEST" | awk '/lib\/.*libpadnote_core\.so/ {split($4,p,"/"); print p[2]}' | sort -u | tr '\n' ' ')
        echo "   內含 ABI：${ABIS:-（無！）}"
        [[ -z "$ABIS" ]] && FAILED+=("Android：APK 內沒有 libpadnote_core.so")
        DELIVERED+=("$DEST")
    fi
fi

# ───────────────────────────── 收尾 ─────────────────────────────
cat > "${OUT_DIR}/安裝說明.txt" <<GUIDE
Kairumo v${APP_VER} (build ${BUNDLE_VER})

■ Mac（Kairumo-${APP_VER}-mac.dmg）
  1. 打開 DMG，把 Kairumo 拖進 Applications。
  2. 直接開啟即可。已通過 Apple 公證，不需要任何額外設定。

■ iPhone / iPad（Kairumo-${APP_VER}-ios.ipa）
  只能安裝在**事先登錄過 UDID** 的裝置上。
  1. 用傳輸線把裝置接上 Mac。
  2. 打開 Apple Configurator（免費，Mac App Store），選裝置 → 加入 → App → 選這個 .ipa。
     或：Finder 側邊欄選裝置，把 .ipa 拖進去。
  尚未登錄的裝置：把 UDID 給開發者 → developer.apple.com 登錄 → 重新打包。

■ Android（Kairumo-${APP_VER}-android.apk）
  1. 把 APK 傳到手機。
  2. 開啟檔案 → 系統詢問時允許「安裝未知應用程式」。
  3. 之後更新請用同一來源的 APK；換了簽章金鑰的版本無法覆蓋安裝。
GUIDE

step "完成"
for f in "${DELIVERED[@]:-}"; do
    [[ -n "$f" ]] && ls -lh "$f" | awk '{printf "   ✅ %-52s %s\n", $9, $5}'
done
echo "   📄 ${OUT_DIR}/安裝說明.txt"

if [[ ${#FAILED[@]} -gt 0 ]]; then
    echo ""
    echo "⚠️ 以下項目未達「可以直接發給別人」的標準："
    for f in "${FAILED[@]}"; do echo "   • $f"; done
    exit 1
fi

echo ""
echo "🎉 全部通過驗證，${OUT_DIR} 裡的檔案可以直接發出去。"
