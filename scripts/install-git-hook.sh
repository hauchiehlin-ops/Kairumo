#!/usr/bin/env bash
#
# scripts/install-git-hook.sh
# 安裝 pre-push hook：推送前做一致性檢查。
#
# 這支 hook 以前會在 push 時自動 patch 升版並 commit，已經移除，原因有二：
#   1. 版本號改由 ./scripts/release.sh 單一入口負責。兩套機制各自改版本號，
#      就是 2.8.0 (20) 那顆 TestFlight 裝不起來的 build 的來源。
#   2. 更根本的問題：pre-push 執行時，要推送的 ref 清單早就定好了。
#      hook 在這個階段建立的 commit 不會被這次 push 帶出去，只會留在本機，
#      下次 push 才補上 —— 遠端看到的版本因此永遠落後一拍。
#
# 現在它只做檢查、不改任何檔案，所以也不再需要 PADNOTE_NO_BUMP 逃生口。

set -euo pipefail
export PYTHONIOENCODING=utf-8

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
HOOK_FILE="${REPO_ROOT}/.git/hooks/pre-push"

cat << 'HOOK_EOF' > "$HOOK_FILE"
#!/usr/bin/env bash
#
# Padnote pre-push hook：只做檢查，不改任何檔案。
# 版本號一律由 ./scripts/release.sh 負責。
#
set -uo pipefail
export PYTHONIOENCODING=utf-8

REPO_ROOT="$(git rev-parse --show-toplevel)"

# 介面字串必須與 catalog 一致 —— 有人手改了產生檔就在這裡擋下來，
# 不要等到 Android 與 Apple 的用語各說各話才發現。
if [[ -f "${REPO_ROOT}/scripts/i18n_tool.py" ]]; then
    if ! python3 "${REPO_ROOT}/scripts/i18n_tool.py" verify; then
        echo "❌ 介面字串表與 i18n/ui-strings.json 不一致，請改 catalog 後重跑 generate。" >&2
        exit 1
    fi
fi

# 只在 UTF-8 終端機才發作的 shell 寫法（$VAR 緊接中文字），在這裡擋。
if [[ -x "${REPO_ROOT}/scripts/check-shell-cjk-vars.sh" ]]; then
    if ! "${REPO_ROOT}/scripts/check-shell-cjk-vars.sh"; then
        exit 1
    fi
fi

# 版本號漂移在這裡就攔下來，不要等到發版才發現遠端是壞的。
if [[ -x "${REPO_ROOT}/scripts/check-version-consistency.sh" ]]; then
    if ! "${REPO_ROOT}/scripts/check-version-consistency.sh"; then
        echo "   （要跳過這次檢查：git push --no-verify）" >&2
        exit 1
    fi
fi

exit 0
HOOK_EOF

chmod +x "$HOOK_FILE"
echo "✅ pre-push hook 已安裝：僅做 i18n 與版本一致性檢查，不會自動升版。"
echo "👉 升版與發版請用：./scripts/release.sh [patch|minor|major]"
