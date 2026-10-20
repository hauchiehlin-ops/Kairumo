#!/usr/bin/env bash
#
# scripts/mac-release.sh
# 只封裝並上傳 Mac 版。等同 `apple-release.sh --mac-only`。
#
# 以前這裡是 apple-release.sh 的整份複本、只把 iOS 那行註解掉；
# 兩份各改各的，複本就漏了後來的修正（自動抓 Team ID、上傳重試）。
#
set -euo pipefail
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/apple-release.sh" --mac-only "$@"
