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
#   ./scripts/dist.sh --mac --android # 只要 DMG 與 APK（跳過需要 UDID 的 iOS）
#   ./scripts/dist.sh --mac
#   ./scripts/dist.sh --ios
#   ./scripts/dist.sh --android
#   ./scripts/dist.sh --ios-install   # 不產 .ipa，直接裝進接上線的 iPhone / iPad
#   ./scripts/dist.sh --preflight     # 只檢查環境（憑證、JDK、SDK），不打包
#   ./scripts/dist.sh --skip-rust     # 略過 Rust XCFramework 重編（省十來分鐘）
#   ./scripts/dist.sh --no-notarize   # Mac 不公證（只能自己用，別人開會被 Gatekeeper 擋）
#
# 與 release.sh 的差別：
#   release.sh 是**上架**流程 —— 升版本號、建立 commit、送 App Store Connect / Play Console。
#   dist.sh 不升版、不 commit、不碰任何商店，只把「當下這份程式碼」打包成能發給人的檔案。
#
# ⚠️ iOS 有兩條完全不同的路，先選對再跑：
#
#   (a) 裝進**你自己手上**的 iPhone / iPad → `--ios-install`
#       接上傳輸線、裝置解鎖並信任這台 Mac，跑下去就直接裝好了。
#       Xcode 會順手把這台裝置登錄進你的帳號，不需要你先去查 UDID。
#       全程不產生 .ipa —— 因為 .ipa **不是** iOS 能直接開啟的格式：
#       AirDrop 或丟進「檔案」App 再點下去，iOS 不會有任何反應，那不是壞掉。
#
#   (b) 發給**別人** → 預設模式產出的 .ipa，或走 TestFlight
#       .ipa 只能裝在事先登錄 UDID 的裝置上（一個帳號上限 100 台），
#       而且對方得用 Mac 上的 Apple Configurator / Finder 才裝得進去。
#       對方沒有 Mac、或你不想收 UDID 的話，只有 TestFlight 一條路
#       —— 那要走 scripts/release.sh。
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
# iOS 預設走 Ad Hoc（產出 .ipa 給人）。--ios-install 改走 development 簽章
# 並直接裝進接上線的裝置 —— 那條路完全不需要碰 .ipa 檔案。
IOS_INSTALL=0; IOS_METHOD="release-testing"; PREFLIGHT_ONLY=0

# --mac / --ios / --android 是可以疊加的選取器：給了任何一個，就從「全都不做」
# 開始，只打開被點名的平台。--*-only 是它們的單數別名，保留是因為既有筆記
# 與說明文件都那樣寫。
#
# 為什麼需要疊加：最常見的需求是「DMG + APK，不要 iOS」——
# 而 iOS 那條路需要事先登錄 UDID，用不到卻硬跑，要多花十來分鐘才失敗。
# 舊寫法沒有辦法表達這件事（--mac-only --android-only 兩個互相關掉，變成什麼都不做）。
SELECTED=0
select_only() {
    if [[ "$SELECTED" -eq 0 ]]; then
        DO_MAC=0; DO_IOS=0; DO_ANDROID=0; SELECTED=1
    fi
}
for arg in "$@"; do
    case "$arg" in
        --mac|--mac-only)         select_only; DO_MAC=1 ;;
        --ios|--ios-only)         select_only; DO_IOS=1 ;;
        --android|--android-only) select_only; DO_ANDROID=1 ;;
        --skip-rust)    SKIP_RUST=1 ;;
        --no-notarize)  NOTARIZE=0 ;;
        --preflight)    PREFLIGHT_ONLY=1 ;;
        --ios-install)  IOS_INSTALL=1; IOS_METHOD="development" ;;
        -h|--help)      sed -n '3,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *)
            # 打錯的旗標不能靜默吃掉 —— 使用者會以為做了某件事，實際沒有。
            echo "❌ 未知參數：$arg" >&2
            echo "   用法: $0 [--mac] [--ios] [--android] [--ios-install] [--preflight] [--skip-rust] [--no-notarize]" >&2
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
# 環境缺件在這裡就全部攤開。擺到各平台自己那一段才檢查的話，
# Rust 與 Apple 已經先跑掉十幾分鐘，才因為一個環境變數整趟白費。
if [[ "$DO_ANDROID" -eq 1 ]]; then
    # Gradle 找 JDK 的順序是 JAVA_HOME → PATH。這台機器的 java 來自 keg-only 的
    # homebrew openjdk，沒有連進 /usr/bin —— 所以 /usr/libexec/java_home 找不到它
    # （登入時那句 "Unable to locate a Java Runtime" 就是這樣來的）。
    # 互動 shell 靠 .zshrc 補 PATH 才看得到；換個執行環境（cron、CI、別的 shell）
    # 就會在 gradle 那一步才爆。
    if [[ -z "${JAVA_HOME:-}" ]]; then
        if JAVA_BIN="$(command -v java)"; then
            JAVA_HOME="$(cd "$(dirname "$JAVA_BIN")/.." && pwd)"
            export JAVA_HOME
        else
            echo "❌ 找不到 java，Gradle 無法執行。" >&2
            echo "   brew install openjdk@17 後，把它的 bin 加進 PATH 或設定 JAVA_HOME。" >&2
            exit 1
        fi
    fi
    echo "   ✅ JDK：${JAVA_HOME}"

    export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
    if [[ ! -d "$ANDROID_HOME" ]]; then
        echo "❌ 找不到 Android SDK（${ANDROID_HOME}）。" >&2
        exit 1
    fi
    # apksigner 是驗證那一步唯一的依據。沒有它，APK 做得出來卻無法確認能不能裝，
    # 那就不叫「已驗證」了 —— 寧可現在停。
    if [[ -z "$(find "${ANDROID_HOME}/build-tools" -name apksigner 2>/dev/null | head -n 1)" ]]; then
        echo "❌ ${ANDROID_HOME}/build-tools 底下找不到 apksigner，APK 簽章無法驗證。" >&2
        exit 1
    fi
    echo "   ✅ Android SDK 與 apksigner"
fi

# 公證要 Apple 帳號與 App 專用密碼，或 App Store Connect API Key。多了它，
# 別人下載後 macOS 才能直接開啟，不會被 Gatekeeper 阻擋。
if [[ "$DO_MAC" -eq 1 && "$NOTARIZE" -eq 1 ]]; then
    HAS_NOTARY_CREDS=0
    if [[ -n "${APP_STORE_CONNECT_KEY_PATH:-}" && -f "${APP_STORE_CONNECT_KEY_PATH:-}" && -n "${APP_STORE_CONNECT_API_KEY_ID:-}" && -n "${APP_STORE_CONNECT_ISSUER_ID:-}" ]]; then
        HAS_NOTARY_CREDS=1
    elif [[ -n "${APPLE_ID:-}" && -n "${APP_SPECIFIC_PASSWORD:-}" ]]; then
        HAS_NOTARY_CREDS=1
    fi

    if [[ "$HAS_NOTARY_CREDS" -eq 0 ]]; then
        echo "❌ apple/ExportConfig.env 缺 App Store Connect API Key 或 APPLE_ID / APP_SPECIFIC_PASSWORD，無法公證。" >&2
        echo "   只給自己用的話：加上 --no-notarize。" >&2
        exit 1
    fi
    if [[ -z "$(security find-identity -v -p codesigning | awk '/Developer ID Application/ {print $2; exit}')" ]]; then
        echo "❌ 鑰匙圈裡沒有 Developer ID Application 憑證，簽不出能發給別人的 Mac 版。" >&2
        exit 1
    fi
    echo "   ✅ Developer ID 憑證與公證帳號"
fi

if [[ -f "${SCRIPT_DIR}/sync-docs.sh" ]]; then
    "${SCRIPT_DIR}/sync-docs.sh" >/dev/null
    echo "   ✅ 使用者文件已同步至 apple/Resources/Docs"
fi

# 只跑前置檢查就結束 —— 用來確認環境是好的，不花二十分鐘打包。
if [[ "$PREFLIGHT_ONLY" -eq 1 ]]; then
    echo ""
    echo "✅ --preflight：環境檢查全數通過，未進行打包。"
    exit 0
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
                NOTARY_CMD=()
                if [[ -n "${APP_STORE_CONNECT_KEY_PATH:-}" && -f "${APP_STORE_CONNECT_KEY_PATH:-}" && -n "${APP_STORE_CONNECT_API_KEY_ID:-}" && -n "${APP_STORE_CONNECT_ISSUER_ID:-}" ]]; then
                    NOTARY_CMD=(xcrun notarytool submit "$DMG" --key "$APP_STORE_CONNECT_KEY_PATH" --key-id "$APP_STORE_CONNECT_API_KEY_ID" --issuer "$APP_STORE_CONNECT_ISSUER_ID" --wait)
                elif [[ -n "${APPLE_ID:-}" && -n "${APP_SPECIFIC_PASSWORD:-}" && -n "${APPLE_TEAM_ID:-}" ]]; then
                    NOTARY_CMD=(xcrun notarytool submit "$DMG" --apple-id "$APPLE_ID" --password "$APP_SPECIFIC_PASSWORD" --team-id "$APPLE_TEAM_ID" --wait)
                fi

                if [[ ${#NOTARY_CMD[@]} -gt 0 ]]; then
                    echo "🔏 送交 Apple 公證（通常 1–5 分鐘）…"
                    if "${NOTARY_CMD[@]}"; then
                        # 釘選之後，對方的電腦離線也能通過驗證。
                        xcrun stapler staple "$DMG"
                        echo "   ✅ 公證與釘選完成"
                    else
                        FAILED+=("macOS：公證失敗（DMG 已產出但別人開會被 Gatekeeper 擋）")
                    fi
                else
                    FAILED+=("macOS：ExportConfig.env 缺 App Store Connect API Key 或 Apple ID 憑證，未公證")
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
    if [[ "$IOS_INSTALL" -eq 1 ]]; then
        step "iOS / iPadOS（直接安裝到接上線的裝置）"
        # 先確認真的有裝置，再花十分鐘編譯。沒接裝置就編完才發現，很浪費。
        DEVJSON="${WORK_DIR}/devices.json"
        xcrun devicectl list devices --json-output "$DEVJSON" >/dev/null 2>&1 || true
        # 只要實體且連得上的。模擬器不算 —— 模擬器上跑的不是給人用的版本。
        #
        # 不用 mapfile：macOS 內建的是 bash 3.2，沒有這個內建指令，
        # 腳本會在「找不到裝置」這種看起來很像正常情況的地方莫名其妙失敗。
        IOS_DEVICES=(); IOS_OFFLINE=()
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            if [[ "$(echo "$line" | cut -f4)" == "online" ]]; then
                IOS_DEVICES+=("$line")
            else
                IOS_OFFLINE+=("$line")
            fi
        done < <(python3 - "$DEVJSON" <<'PYDEV'
import json, sys
try:
    devs = json.load(open(sys.argv[1]))["result"]["devices"]
except Exception:
    sys.exit(0)
for d in devs:
    hw = d.get("hardwareProperties", {})
    conn = d.get("connectionProperties", {})
    props = d.get("deviceProperties", {})
    # reality 才是模擬器與實機的分界。別拿 platform 或 pairingState 判斷：
    # 模擬器的 platform 同樣是 "iOS"、pairingState 同樣是 "paired"，
    # 照樣會被撈進來，然後在安裝時才報 "capability not supported"。
    if hw.get("reality") != "physical":
        continue
    udid = hw.get("udid")
    if not udid:
        continue
    # 沒接線的實機 tunnelState 是 unavailable，裝不進去。
    # 但仍然回報出來，好讓使用者知道「就是這台，去插線」。
    state = "online" if conn.get("tunnelState") not in (None, "unavailable") else "offline"
    name = props.get("name") or "?"
    model = hw.get("marketingName") or hw.get("productType") or "?"
    print("\t".join([udid, name, model, state]))
PYDEV
)
        if [[ ${#IOS_DEVICES[@]:-0} -eq 0 ]]; then
            echo "❌ 沒有連線中的 iPhone / iPad（模擬器不算）。" >&2
            if [[ ${#IOS_OFFLINE[@]:-0} -gt 0 ]]; then
                echo "   這些實機這台 Mac 認得，但現在沒連上：" >&2
                for d in "${IOS_OFFLINE[@]:-}"; do
                    echo "     • $(echo "$d" | cut -f2)（$(echo "$d" | cut -f3)）" >&2
                done
            fi
            echo "   請用傳輸線接上這台 Mac、解鎖裝置，並在跳出的對話框按「信任這部電腦」。" >&2
            echo "   接好之後用 xcrun devicectl list devices 確認 Reality 那欄是 physical、" >&2
            echo "   State 不是 unavailable，再重跑。" >&2
            FAILED+=("iOS：沒有可安裝的實體裝置")
            DO_IOS=0
        else
            echo "   偵測到裝置："
            for d in "${IOS_DEVICES[@]:-}"; do
                echo "     • $(echo "$d" | cut -f2)（$(echo "$d" | cut -f3)）  $(echo "$d" | cut -f1)"
            done
        fi
    else
        step "iOS / iPadOS（Ad Hoc .ipa，限已登錄 UDID 的裝置）"
    fi
fi

if [[ "$DO_IOS" -eq 1 ]]; then
    # Xcode 15.3 起 method 從 ad-hoc 改名為 release-testing，語意相同。
    if archive_and_export "iPhone / iPad" "generic/platform=iOS" "ios" "$IOS_METHOD"; then
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

            if [[ "$IOS_INSTALL" -eq 1 ]]; then
                # 解出 .app 再交給 devicectl。devicectl 吃的是 .app 套件，
                # 不是 .ipa —— 直接餵 .ipa 會被拒絕。
                APPDIR="${WORK_DIR}/ios-app"; rm -rf "$APPDIR"; mkdir -p "$APPDIR"
                unzip -q -o "$DEST" -d "$APPDIR"
                IOS_APP=$(find "$APPDIR/Payload" -maxdepth 1 -name "*.app" | head -n 1)
                INSTALLED_ANY=0
                for d in "${IOS_DEVICES[@]:-}"; do
                    [[ -z "$d" ]] && continue
                    udid=$(echo "$d" | cut -f1); name=$(echo "$d" | cut -f2)
                    echo "📲 安裝到 ${name}…"
                    if xcrun devicectl device install app --device "$udid" "$IOS_APP"; then
                        echo "   ✅ ${name} 安裝完成，主畫面上就有 Kairumo 了"
                        INSTALLED_ANY=1
                    else
                        FAILED+=("iOS：安裝到 ${name} 失敗")
                    fi
                done
                # --ios-install 的產物是「裝置上跑得起來的 App」，不是檔案。
                # .ipa 是中間產物，留著只會讓人以為那是可以轉發的東西。
                rm -f "$DEST"
                [[ "$INSTALLED_ANY" -eq 0 ]] && FAILED+=("iOS：沒有任何裝置安裝成功")
            else
                DELIVERED+=("$DEST")
            fi
        fi
    else
        if [[ "$IOS_INSTALL" -eq 1 ]]; then
            FAILED+=("iOS：封裝/匯出失敗（裝置可能未信任這台 Mac，或帳號無法自動建立描述檔）")
        else
            FAILED+=("iOS：封裝/匯出失敗（多半是帳號底下還沒登錄任何裝置 UDID）")
        fi
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
# 說明書只寫實際產出的平台。三個平台照抄的話，只做了 DMG + APK 的那一包
# 裡會有一段教人安裝根本不存在的 .ipa —— 收件人會去找那個檔案。
GUIDE_FILE="${OUT_DIR}/安裝說明.txt"
cat > "$GUIDE_FILE" <<GUIDE
Kairumo v${APP_VER} (build ${BUNDLE_VER})
GUIDE

if [[ "$DO_MAC" -eq 1 ]]; then
cat >> "$GUIDE_FILE" <<GUIDE

■ Mac（Kairumo-${APP_VER}-mac.dmg）
  1. 打開 DMG，把 Kairumo 拖進 Applications。
  2. 直接開啟即可。已通過 Apple 公證，不需要任何額外設定。
GUIDE
fi

if [[ "$DO_IOS" -eq 1 && "$IOS_INSTALL" -eq 0 ]]; then
cat >> "$GUIDE_FILE" <<GUIDE

■ iPhone / iPad（Kairumo-${APP_VER}-ios.ipa）
  ⚠️ .ipa 不能直接在 iPhone / iPad 上點開。
     AirDrop 過去、或丟進「檔案」App 再點兩下，iOS 不會有任何反應 ——
     那不是檔案壞了，是 iOS 本來就沒有安裝 .ipa 的功能。必須透過 Mac：
  1. 用傳輸線把裝置接上一台 Mac。
  2. 打開 Apple Configurator（免費，Mac App Store），選裝置 → 加入 → App →
     左下角「選擇來自我的 Mac」→ 選這個 .ipa。
     或：Finder 側邊欄選裝置，把 .ipa 拖到裝置上。
  3. 而且這台裝置的 UDID 必須**事先登錄**在開發者帳號裡，否則裝上去也開不起來。
     未登錄的話：把 UDID 給開發者 → developer.apple.com → Devices 登錄 → 重新打包。

  裝置就在開發者手邊的話，最省事的是跳過 .ipa：
     接上線後在專案目錄執行 ./scripts/dist.sh --ios-install
  完全不想碰傳輸線與 UDID 的話，只有 TestFlight（走 scripts/release.sh）。
GUIDE
fi

if [[ "$DO_ANDROID" -eq 1 ]]; then
cat >> "$GUIDE_FILE" <<GUIDE

■ Android（Kairumo-${APP_VER}-android.apk）
  1. 把 APK 傳到手機。
  2. 開啟檔案 → 系統詢問時允許「安裝未知應用程式」。
  3. 之後更新請用同一來源的 APK；換了簽章金鑰的版本無法覆蓋安裝。
GUIDE
fi

step "完成"
for f in "${DELIVERED[@]:-}"; do
    [[ -n "$f" ]] && ls -lh "$f" | awk '{printf "   ✅ %-52s %s\n", $9, $5}'
done
echo "   📄 ${GUIDE_FILE}"

if [[ ${#FAILED[@]} -gt 0 ]]; then
    echo ""
    echo "⚠️ 以下項目未達「可以直接發給別人」的標準："
    for f in "${FAILED[@]}"; do echo "   • $f"; done
    exit 1
fi

echo ""
echo "🎉 全部通過驗證，${OUT_DIR} 裡的檔案可以直接發出去。"
