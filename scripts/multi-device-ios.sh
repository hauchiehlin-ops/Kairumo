#!/usr/bin/env bash
# 多裝置劇本（iOS）：在指定的模擬器上跑 MultiDeviceUITests 的某一步。
#
#   scripts/multi-device-ios.sh <模擬器 UDID> <步驟名稱>
#   例：scripts/multi-device-ios.sh B5B45DAE-… testStep1_A_createsANotebook
#
# 前置：python3 scripts/fake-drive-server.py 在跑（預設 http://127.0.0.1:8765）。
# 劇本與為什麼需要它見 apple/UITests/MultiDeviceUITests.swift。
set -uo pipefail
cd "$(dirname "$0")/.."
UDID="$1"; STEP="$2"
OUT="${MD_OUT:-/tmp/kairumo-md-out}"; mkdir -p "$OUT"
run_once() {
  xcodebuild test -project apple/Kairumo.xcodeproj -scheme Kairumo \
    -destination "id=$UDID" \
    -only-testing:"KairumoUITests/MultiDeviceUITests/$STEP" \
    -resultBundlePath "$OUT/$STEP-$(date +%H%M%S).xcresult" > "$OUT/$STEP.log" 2>&1
}
run_once
code=$?
# 模擬器偶爾啟動不了測試執行器（"failed to launch …xctrunner"）：跟程式無關，關機重來一次。
if [ $code -ne 0 ] && grep -q "Simulator device failed to launch" "$OUT/$STEP.log"; then
  xcrun simctl shutdown "$UDID" 2>/dev/null; sleep 3
  run_once
  code=$?
fi
grep -E "error: |Test Case .*(passed|failed)|TEST (SUCCEEDED|FAILED)" "$OUT/$STEP.log" | grep -v textAnalyzer | sort -u | cut -c1-360
echo "step=$STEP exit=$code"
