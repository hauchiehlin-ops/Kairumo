#!/usr/bin/env bash
# 執行期日誌閘門（驗證層 L2/L3 的補充，見 docs/plans/ipad-first-verification.md）。
#
# 為什麼：很多「iPad 不行」的真因只在系統日誌裡留下一行，畫面與測試都看不出來 ——
#   · `category option 'defaultToSpeaker' is only applicable with category 'playAndRecord'`
#     → 播放用的 audio session 設定失敗，引擎起不來（Mac 的分支沒帶這個選項，所以 Mac 一直是好的）。
#   · `Modifying state during view update` → 在畫面更新途中改狀態（未定義行為）。
#   · `No symbol named '…'` → 圖示根本不存在，畫面上是空白。
# 這些是『硬』規則：出現一次就失敗。另有幾條『軟』規則只回報數量（目前還有已知的存量）。
#
# 用法：./scripts/runtime-log-gate.sh <模擬器 UDID> "<開始時間 YYYY-MM-DD HH:MM:SS>"
set -uo pipefail
UDID="$1"; START="$2"
LOG=$(xcrun simctl spawn "$UDID" log show --start "$START" --style compact \
  --predicate 'process == "Kairumo" AND (messageType == fault OR messageType == error)' 2>/dev/null)

HARD=(
  "category option 'defaultToSpeaker' is only applicable"
  "Modifying state during view update"
  "No symbol named"
)
SOFT=(
  "Accessing FocusState's value outside of the body of a View"
  "Unable to render flattened version of PlatformViewRepresentableAdaptor"
)

fail=0
for sig in "${HARD[@]}"; do
  n=$(printf '%s\n' "$LOG" | grep -c -F -- "$sig" || true)
  if [ "${n:-0}" -gt 0 ]; then echo "❌ $n 次：$sig"; fail=1; else echo "✓ 0 次：$sig"; fi
done
for sig in "${SOFT[@]}"; do
  n=$(printf '%s\n' "$LOG" | grep -c -F -- "$sig" || true)
  echo "ℹ️  $n 次（已知存量，尚未列為硬規則）：$sig"
done
exit $fail
