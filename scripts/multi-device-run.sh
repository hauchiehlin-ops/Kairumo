#!/usr/bin/env bash
# 三台裝置（iPad、iPhone、Android）共用一個假雲端，把多裝置劇本從頭跑一遍。
#
#   scripts/multi-device-run.sh                # 從頭跑（會重置環境）
#   MD_FROM=5 scripts/multi-device-run.sh      # 從第 5 步繼續，**不重置**環境
#
# 會做的事：重置假雲端與兩台 iOS 模擬器、開 Android 模擬器，然後依序跑劇本的每一步，
# 第一個失敗的步驟會停下來。劇本是什麼、為什麼需要它，見 `apple/UITests/MultiDeviceUITests.swift`
# 與 `android/.../MultiDeviceSyncTest.kt`。
set -uo pipefail
cd "$(dirname "$0")/.."

IPAD="${MD_IPAD:-B5B45DAE-80CD-4842-8417-C50D5CE89C9F}"        # iPad Pro 11-inch (M5)
IPHONE="${MD_IPHONE:-E48E2FB8-9349-4E9D-91F7-C9B6F0502AA6}"    # iPhone 17 Pro
AVD="${MD_AVD:-kairumo35}"
SDK="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
SERVER=http://127.0.0.1:8765
export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@17}"

curl -s "$SERVER/_admin/files" >/dev/null || { echo "假 Drive 沒在跑：python3 scripts/fake-drive-server.py"; exit 2; }
if [ -z "${MD_FROM:-}" ]; then
  curl -s -X POST "$SERVER/_admin/reset" >/dev/null; rm -rf /tmp/kairumo-md
  for u in "$IPAD" "$IPHONE"; do xcrun simctl shutdown "$u" 2>/dev/null; xcrun simctl erase "$u"; done
fi

if ! "$SDK/platform-tools/adb" devices | grep -q emulator; then
  nohup "$SDK/emulator/emulator" -avd "$AVD" -no-window -no-audio -no-boot-anim -no-snapshot-save >/dev/null 2>&1 &
  "$SDK/platform-tools/adb" wait-for-device
  until [ "$("$SDK/platform-tools/adb" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do sleep 5; done
fi
if [ -z "${MD_FROM:-}" ]; then
  ( cd android && ./gradlew --offline :app:installDebug :app:installDebugAndroidTest -q ) >/tmp/kairumo-md-out/android-install.log 2>&1 \
    || { echo "Android 安裝失敗，見 /tmp/kairumo-md-out/android-install.log"; exit 2; }
  "$SDK/platform-tools/adb" shell pm clear com.kairumo.padnote >/dev/null 2>&1
fi

fail=0
ios()     { out=$(./scripts/multi-device-ios.sh "$1" "$2"); echo "$out" | tail -4; echo "$out" | grep -q "exit=0" || fail=1; }
android() {
  # **不用 gradle 的 connectedAndroidTest**：它每次跑完都會把 App 解除安裝，
  # 上一步下載的筆記本就跟著沒了。改成先裝一次，每一步用 `am instrument` 直接跑。
  out=$("$SDK/platform-tools/adb" shell am instrument -w -r \
      -e multiDevice true -e class "com.kairumo.padnote.library.MultiDeviceSyncTest#$1" \
      com.kairumo.padnote.test/androidx.test.runner.AndroidJUnitRunner 2>&1)
  if echo "$out" | grep -q "^OK (1 test)\|OK (1 tests)"; then echo "PASS android $1"; else
    echo "FAIL android $1"; echo "$out" | grep -E "stack=|INSTRUMENTATION_RESULT|Failure|Assertion" | head -5 | cut -c1-300; fail=1; fi
}
reached=${MD_FROM:+0}; reached=${reached:-1}
step() {
  local label="$1"; shift
  # `MD_FROM=<編號>`：跳過編號之前的步驟（標籤的第一個詞就是編號）。
  if [ "$reached" = 0 ] && [ "${label%% *}" = "$MD_FROM" ]; then reached=1; fi
  [ "$reached" = 1 ] || { echo "--- 略過 $label"; return; }
  echo "=== $label"; "$@"; [ $fail -eq 0 ] || { echo "停在這一步"; exit 1; }
}

step "1  iPad 建立筆記本"            ios     "$IPAD"   testStep1_A_createsANotebook
step "2  iPhone 收到"                ios     "$IPHONE" testStep2_B_seesTheNotebook
step "C1 Android 加入、標題一致"     android stepC1_pullsTheNotebookAndShowsTheCurrentTitle
step "3  iPad 更名"                  ios     "$IPAD"   testStep3_A_renamesIt
step "4  iPhone 看到更名"            ios     "$IPHONE" testStep4_B_seesTheRename
step "C1b Android 看到 iPad 的更名"  android stepC1b_seesTheRenameMadeElsewhere
step "C2 Android 更名"               android stepC2_renamesIt
step "4b iPad 看到 Android 的更名"   ios     "$IPAD"   testStep4b_A_seesTheAndroidRename
step "5  iPad 刪除"                  ios     "$IPAD"   testStep5_A_deletesIt
step "7  iPad 在別台落後時清空"      ios     "$IPAD"   testStep7_A_emptiesTheTrashWhileBIsBehind
step "8  iPhone 同步刪除並確認"      ios     "$IPHONE" testStep8_B_syncsTheDeletionAndConfirms
step "C3 Android 同步刪除並確認"     android stepC3_syncsTheDeletionConfirmsAndPurgesItsLocalCopy
step "9  iPad：雲端被清掉"           ios     "$IPAD"   testStep9_A_cloudIsPurgedOnceBHasConfirmed
step "10 iPhone：本機副本被清掉"     ios     "$IPHONE" testStep10_B_localCopyIsPurged
echo "劇本全部通過"
