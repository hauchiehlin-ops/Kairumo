#!/usr/bin/env bash
# 開發機一鍵清理：編譯產物與外接碟上的碎片檔。只動「隨時可重建」的東西，原始碼與 git 一律不碰。
#
# 用法：
#   ./scripts/clean-dev.sh            # 清：macOS 衍生檔（._*、.DS_Store）、Xcode DerivedData（Kairumo）、Android 建置目錄
#   ./scripts/clean-dev.sh --rust     # 另外清 Rust 的 target/（重建很久，外接碟上更久，預設不清）
#   ./scripts/clean-dev.sh --gradle   # 另外停掉閒置的 Gradle daemon、清 Gradle 建置快取
#   ./scripts/clean-dev.sh --dry-run  # 只列出會清什麼、各多大，不刪
#
# 不會清：模型檔、簽章與憑證、Gradle 下載的相依套件、任何在 git 追蹤中的檔案。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DRY=0; RUST=0; GRADLE=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY=1 ;;
    --rust) RUST=1 ;;
    --gradle) GRADLE=1 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) echo "未知參數：${arg}（見 --help）"; exit 2 ;;
  esac
done

size_of() { du -sh "$1" 2>/dev/null | cut -f1; }

remove() {
  local path="$1"
  [ -e "$path" ] || return 0
  if [ "$DRY" = 1 ]; then
    echo "  會清：${path}（$(size_of "$path")）"
  else
    echo "  清除：${path}（$(size_of "$path")）"
    rm -rf "$path"
  fi
}

echo "── macOS 衍生檔（._*、.DS_Store）──"
# 跳過編譯產物與套件資料夾（target/ 有幾十萬個檔，外接碟上整棵掃一遍要很久；它們本來就隨時可重建）。
# .git 只看最上層與 refs（物件庫裡不會有 ._*，掃它也很慢）。
list_junk() {
  find "$ROOT" \( -name target -o -name node_modules -o -name build -o -name .gradle -o -path "$ROOT/.git/objects" \) -prune \
    -o \( -name '._*' -o -name '.DS_Store' \) -print 2>/dev/null
}
junk="$(list_junk)"
count=$(printf '%s' "$junk" | grep -c . || true)
echo "  共 $count 個"
if [ "$DRY" = 0 ] && [ "$count" != 0 ]; then
  printf '%s\n' "$junk" | while IFS= read -r f; do rm -f "$f"; done
fi

echo "── Xcode DerivedData（Kairumo）──"
for dir in "$HOME/Library/Developer/Xcode/DerivedData"/Kairumo-*; do
  [ -d "$dir" ] && remove "$dir"
done

echo "── Android 建置目錄 ──"
remove "$ROOT/android/app/build"
remove "$ROOT/android/build"

if [ "$GRADLE" = 1 ]; then
  echo "── Gradle ──"
  if [ "$DRY" = 0 ] && [ -x "$ROOT/android/gradlew" ]; then
    (cd "$ROOT/android" && ./gradlew --stop >/dev/null 2>&1 || true)
  fi
  remove "$ROOT/android/.gradle"
  remove "$HOME/.gradle/caches/build-cache-1"
fi

if [ "$RUST" = 1 ]; then
  echo "── Rust target/ ──"
  remove "$ROOT/target"
fi

[ "$DRY" = 1 ] && echo "（--dry-run：沒有刪任何東西）"
echo "完成。"
