#!/usr/bin/env bash
#
# scripts/publish-pages.sh
# 把使用者文件發佈到 GitHub Pages（gh-pages 分支）。
#
# 產生的網址：
#   https://<帳號>.github.io/<repo>/legal/privacy.html   ← App Store Connect 要填的隱私權政策網址
#   https://<帳號>.github.io/<repo>/manual/              ← 使用手冊
#
# 用法：
#   ./scripts/publish-pages.sh            # 發佈
#   ./scripts/publish-pages.sh --dry-run  # 只組出內容，不推送
#
# ⚠️ **只發佈 docs/legal 與 docs/manual。**
# 不要改成整個 docs/ —— DEVLOG、TODO、ADR、內部計畫會全部變成可被搜尋引擎索引的
# 網頁。repo 是公開的沒錯，但「在 repo 裡看得到」跟「被做成網站」不是同一件事。
# （android/app/build.gradle.kts 的 assets 複製是同一個理由。）
#
set -euo pipefail
export PYTHONIOENCODING=utf-8

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        -h|--help) sed -n '3,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "❌ 未知參數：$arg" >&2; exit 2 ;;
    esac
done

BRANCH="gh-pages"
# 純 bash 展開拆 owner/repo。別用 sed -E 配 `+?` —— macOS 的 sed 不支援惰性
# 量詞，會直接噴 "repetition-operator operand invalid"（踩過）。
ORIGIN="$(git config --get remote.origin.url)"
ORIGIN="${ORIGIN%.git}"
REPO="${ORIGIN##*/}"
OWNER_PATH="${ORIGIN%/*}"
OWNER="${OWNER_PATH##*[:/]}"
# ${OWNER,,} 是 bash 4 的小寫展開，macOS 內建的是 3.2，會直接語法錯誤。
OWNER_LC="$(printf '%s' "$OWNER" | tr '[:upper:]' '[:lower:]')"
BASE="https://${OWNER_LC}.github.io/${REPO}"

# 文件先同步，免得發出去的是舊版本號的那一份。
[[ -x "${SCRIPT_DIR}/sync-docs.sh" ]] && "${SCRIPT_DIR}/sync-docs.sh" >/dev/null

WORK="$(mktemp -d)"
cleanup() { git worktree remove --force "$WORK" 2>/dev/null || true; rm -rf "$WORK"; }
trap cleanup EXIT

git fetch origin "$BRANCH" --quiet 2>/dev/null || true
if git show-ref --verify --quiet "refs/remotes/origin/${BRANCH}"; then
    git worktree add --quiet "$WORK" -B "$BRANCH" "origin/${BRANCH}"
else
    echo "==> ${BRANCH} 尚不存在，建立孤立分支"
    git worktree add --quiet --detach "$WORK"
    git -C "$WORK" checkout --quiet --orphan "$BRANCH"
    git -C "$WORK" rm -rqf . 2>/dev/null || true
fi

# 每次都從乾淨狀態重組。用增量複製的話，docs/ 裡刪掉的檔案會永遠留在網站上。
find "$WORK" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +

mkdir -p "$WORK/legal" "$WORK/manual"
cp -R "${REPO_ROOT}/docs/legal/." "$WORK/legal/"
cp -R "${REPO_ROOT}/docs/manual/." "$WORK/manual/"

# .nojekyll：不加的話 GitHub 會跑 Jekyll，底線開頭的檔案會被靜默略過，
# 而且建置失敗時網站只會回 404，不會告訴你原因。
touch "$WORK/.nojekyll"

APP_VER=$(python3 -c "import re;print(re.search(r'version\s*=\s*\"([^\"]+)\"',open('${REPO_ROOT}/Cargo.toml').read()).group(1))")
cat > "$WORK/index.html" <<HTML
<!DOCTYPE html>
<html lang="zh-Hant">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Kairumo</title>
<style>
  :root { color-scheme: light dark; }
  body { margin:0; padding:48px 20px; font:16px/1.7 -apple-system,BlinkMacSystemFont,
         "PingFang TC","Noto Sans TC",sans-serif; display:flex; justify-content:center; }
  main { width:100%; max-width:34rem; }
  h1 { font-size:1.6rem; margin:0 0 .25rem; }
  p.sub { color:#6B7789; margin:0 0 2rem; }
  a.card { display:block; padding:16px 18px; margin-bottom:12px; border:1px solid #DBE1E9;
           border-radius:12px; text-decoration:none; color:inherit; }
  a.card:hover { border-color:#1F4FD8; }
  a.card b { display:block; font-size:1.05rem; }
  a.card span { color:#6B7789; font-size:.9rem; }
  @media (prefers-color-scheme: dark) { a.card { border-color:#242C37; } }
</style>
</head>
<body><main>
  <h1>Kairumo</h1>
  <p class="sub">手寫、打字與錄音轉文字筆記　·　v${APP_VER}</p>
  <a class="card" href="legal/privacy.html"><b>隱私權政策</b><span>Privacy Policy</span></a>
  <a class="card" href="manual/"><b>使用手冊</b><span>User Manual</span></a>
</main></body>
</html>
HTML

echo "==> 將發佈的內容"
( cd "$WORK" && find . -path ./.git -prune -o -type f -print | sed 's|^\./|   |' | sort | head -40 )
echo "   檔案總數：$(cd "$WORK" && find . -path ./.git -prune -o -type f -print | wc -l | tr -d ' ')"

if [[ "$DRY_RUN" -eq 1 ]]; then
    echo ""
    echo "--dry-run：不推送。內容組在 $WORK（結束時會清掉）"
    exit 0
fi

git -C "$WORK" add -A
if git -C "$WORK" diff --cached --quiet; then
    echo "==> 內容與線上版本相同，不需要推送"
else
    git -C "$WORK" commit -q -m "docs(pages): 發佈使用者文件 v${APP_VER}"
    git -C "$WORK" push -q origin "$BRANCH"
    echo "==> 已推送 ${BRANCH}"
fi

cat <<NEXT

════════════════════════════════════════════
✅ 完成
════════════════════════════════════════════
隱私權政策（填進 App Store Connect 的就是這個）：
  ${BASE}/legal/privacy.html

使用手冊：
  ${BASE}/manual/

首次啟用後 GitHub 需要 1–2 分鐘才會真的上線。
NEXT
