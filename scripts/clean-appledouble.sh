#!/usr/bin/env bash
# 清掉 macOS 在 exFAT 外接碟上產生的 `._*`（AppleDouble）附屬檔與 `.DS_Store`。
#
# exFAT 不存擴充屬性，macOS 寫入任何檔案都會在旁邊生出 `._<檔名>`：
#   - .git 裡的 `._pack-*.idx` 之類會讓 git 每個指令都噴 `non-monotonic index`；
#   - 工作目錄裡的會被 codesign / Gradle 誤收，也會被 `git add -f` 之類誤加。
# 只刪檔名以 `._` 開頭的一般檔案與 `.DS_Store`，不碰任何真正的 git 物件，
# 也不碰被 git 追蹤的檔案。大型建置目錄（target、.build、Gradle 產物）略過不掃，
# 讓 hook 保持在一兩秒內；那些目錄要清請手動跑 `--all`。
#
# 由 .githooks/pre-commit、pre-push 在 commit / push 前呼叫，也可手動執行：
#   scripts/clean-appledouble.sh         # .git + 工作目錄（略過建置目錄）
#   scripts/clean-appledouble.sh --all   # 連建置目錄一起掃
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
GIT_DIR="$(git rev-parse --absolute-git-dir)"

PRUNE=(target .build build apple/.build android/.gradle android/.kotlin android/app/build)
[[ "${1:-}" == "--all" ]] && PRUNE=()

# 1. .git 內部
n_git=$(find "$GIT_DIR" -name '._*' -type f -print -delete 2>/dev/null | wc -l | tr -d ' ')

# 2. 工作目錄（略過 .git 與建置目錄）
prune_args=(-path "$REPO_ROOT/.git")
for d in "${PRUNE[@]}"; do prune_args+=(-o -path "$REPO_ROOT/$d"); done
# 「被追蹤」以 HEAD 為準：剛被誤加進暫存區的不算，照刪，第 3 步再從 index 拿掉
tracked="$(git -C "$REPO_ROOT" ls-tree -r -z --name-only HEAD 2>/dev/null \
           | tr '\0' '\n' | grep -E '(^|/)(\._[^/]*|\.DS_Store)$' || true)"
n_tree=0
while IFS= read -r -d '' f; do
    rel="${f#"$REPO_ROOT"/}"
    if [[ -n "$tracked" ]] && grep -qxF -- "$rel" <<<"$tracked"; then continue; fi
    rm -f -- "$f" && n_tree=$((n_tree + 1))
done < <(find "$REPO_ROOT" \( "${prune_args[@]}" \) -prune -o \
              -type f \( -name '._*' -o -name '.DS_Store' \) -print0 2>/dev/null)

# 3. 已誤加進暫存區的 `._*` / `.DS_Store`（工作目錄已刪，從 index 移除即可）
staged="$(git -C "$REPO_ROOT" diff --cached --name-only --diff-filter=A -z \
          | tr '\0' '\n' | grep -E '(^|/)(\._[^/]*|\.DS_Store)$' || true)"
if [[ -n "$staged" ]]; then
    while IFS= read -r f; do git -C "$REPO_ROOT" rm --cached --quiet -- "$f"; done <<<"$staged"
    echo "🧹 已從暫存區移除 $(wc -l <<<"$staged" | tr -d ' ') 個誤加的 macOS 附屬檔"
fi

if [[ $((n_git + n_tree)) -gt 0 ]]; then
    echo "🧹 已清除 macOS 附屬檔：.git 內 ${n_git} 個、工作目錄 ${n_tree} 個"
fi
