#!/usr/bin/env bash
# 平板優先的驗證（見 docs/plans/ipad-first-verification.md）。
# 用法：./scripts/verify-ipad.sh [模擬器 UDID]   不給的話挑第一台已開機的 iPad。
set -euo pipefail
cd "$(dirname "$0")/.."

UDID="${1:-$(xcrun simctl list devices booted | grep -m1 iPad | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')}"
[ -n "$UDID" ] || { echo "找不到已開機的 iPad 模擬器，請先開一台或把 UDID 當參數傳進來" >&2; exit 2; }
echo "==> iPad 模擬器：$UDID"

echo "==> 1/6 規則檢查（字串、畫面對照）"
python3 scripts/i18n_tool.py verify
python3 scripts/check-screen-parity.py

(cd apple && xcodegen generate >/dev/null)
START="$(date '+%Y-%m-%d %H:%M:%S')"

echo "==> 2/6 L1 多裝置情境矩陣（刪除不復活、錄音整條、名字與秒數）"
(cd apple && xcodebuild test -scheme Kairumo -destination "platform=iOS Simulator,id=$UDID" \
  -only-testing:KairumoTests/PackageMultiDeviceTests -quiet)

echo "==> 3/6 L3 平台能力契約（播放兩次、錄完立刻播、失敗不靜默、資料夾網址、轉錄語系）"
(cd apple && xcodebuild test -scheme Kairumo -destination "platform=iOS Simulator,id=$UDID" \
  -only-testing:KairumoTests/PlatformContractTests \
  -only-testing:KairumoTests/AudioPlaybackTests \
  -only-testing:KairumoTests/TranscriptLocalizationTests -quiet)

echo "==> 4/6 L2 互動矩陣 + L3 UI 契約（檔案選擇器連開三次）+ L4 自檢"
(cd apple && xcodebuild test -scheme Kairumo -destination "platform=iOS Simulator,id=$UDID" \
  -only-testing:KairumoUITests/InteractionMatrixAudit \
  -only-testing:KairumoUITests/PlatformContractUITests -quiet)

echo "==> 5/6 執行期日誌閘門（硬規則出現一次就失敗）"
./scripts/runtime-log-gate.sh "$UDID" "$START"

echo "==> 6/6 全部單元測試"
(cd apple && xcodebuild test -scheme Kairumo -destination "platform=iOS Simulator,id=$UDID" \
  -only-testing:KairumoTests -quiet)

echo "✅ 通過。L5（Mac / iPad 差分）另跑：./scripts/differential-audit.sh"
echo "   模擬器沒有麥克風與真實的『檔案』provider —— 這兩類請在實機的『診斷 ▸ 裝置自檢』驗（L4）。"
