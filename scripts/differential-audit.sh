#!/usr/bin/env bash
# 驗證層 L5：Mac / iPad 差分（見 docs/plans/ipad-first-verification.md）。
#
# 同一組 UI 稽核在 iPad 模擬器與 Mac Catalyst 各跑一次，**比對結果**而不是各自通過就算。
# 「Mac 過、iPad 不過」的項目列成清單 —— 這正是這個專案一再出現的形狀。
#
# 用法：
#   ./scripts/differential-audit.sh [iPad 模擬器 UDID] [測試類別，預設 InteractionMatrixAudit]
# 輸出：build/differential/{ipad,mac}.txt 與差分報告；有「Mac 過、iPad 不過」時以 1 結束。
# 注意：Mac Catalyst 的 UI 測試要在有登入桌面的機器上跑，並授權「輔助使用」給 Xcode。
set -uo pipefail
cd "$(dirname "$0")/.."

UDID="${1:-$(xcrun simctl list devices booted | grep -m1 iPad | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')}"
SUITE="${2:-InteractionMatrixAudit}"
OUT=build/differential
mkdir -p "$OUT"
[ -n "$UDID" ] || { echo "找不到已開機的 iPad 模擬器" >&2; exit 2; }

run() { # name destination
  local name="$1" dest="$2"
  echo "==> ${name}：${dest}"
  (cd apple && xcodegen generate >/dev/null && \
    xcodebuild test -scheme Kairumo -destination "$dest" \
      -only-testing:"KairumoUITests/$SUITE" 2>&1) > "$OUT/$name.log" || true
  # 一行一個測試：名稱 + 結果；失敗的另外附上稽核訊息（「[…] 物件：原因」那幾行）。
  { grep -E "Test Case .* (passed|failed)" "$OUT/$name.log" \
      | sed -E "s/.*-\[[A-Za-z]+\.([A-Za-z]+) ([A-Za-z0-9_]+)\]' (passed|failed).*/\2 \3/" | sort -u
    grep -E "^(\[[0-9]+\] )?(audio|image|text|link|shape|table|model3d)：" "$OUT/$name.log" \
      | sed -E 's/^\[[0-9]+\] //' | sort -u | sed 's/^/  detail: /'
  } > "$OUT/$name.txt"
}

run ipad "platform=iOS Simulator,id=$UDID"
run mac  "platform=macOS,variant=Mac Catalyst"

echo
echo "==== 差分 ===="
regress=0
while read -r test status; do
  [ -z "${test:-}" ] && continue
  case "$test" in detail:*) continue;; esac
  mac_status=$(grep -E "^$test " "$OUT/mac.txt" | awk '{print $2}')
  if [ "$status" = "failed" ] && [ "${mac_status:-}" = "passed" ]; then
    echo "❌ ${test}：Mac 過、iPad 不過"
    grep "detail:" "$OUT/ipad.txt" | head -20
    regress=1
  elif [ "$status" = "passed" ] && [ "${mac_status:-}" = "failed" ]; then
    echo "ℹ️  ${test}：iPad 過、Mac 不過（Mac 自己的問題）"
  else
    echo "✓ ${test}：iPad=${status} Mac=${mac_status:-缺}"
  fi
done < <(grep -vE "^  detail:" "$OUT/ipad.txt")
exit $regress
