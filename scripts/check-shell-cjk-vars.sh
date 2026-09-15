#!/usr/bin/env bash
#
# scripts/check-shell-cjk-vars.sh
# 擋下「變數展開後面緊接中文字」這種寫法。
#
# 為什麼要有這支：
#   macOS 內建的 /bin/bash 是 3.2。在 UTF-8 locale 下，它判斷變數名邊界時
#   會把後面那個全形字（「，」「。」「：」…）的位元組也吃進變數名裡，
#   於是那個展開被當成一個名字帶亂碼的變數，配上 set -u 就是
#   "unbound variable" 當場中止 —— 而且只在使用者的 UTF-8 終端機發作，
#   在 LC_ALL=C 的環境（CI、某些 agent shell）完全複現不出來。
#   實際發生過：v3.6.0 發版時 bump-version.sh:203 就是這樣掛掉的。
#
# 解法只有一個：這種位置一律加大括號寫成 ${VAR}。
#
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export SELF="./$(basename "${BASH_SOURCE[0]}")"

# 用 perl 不用 grep -P：macOS 內建的 BSD grep 沒有 -P，
# 而 hook 執行時的 PATH 不保證有 GNU grep。
HITS="$(
    cd "${REPO_ROOT}/scripts" && perl -CSD -ne '
        next if $ARGV eq $ENV{SELF};
        (my $f = $ARGV) =~ s{^\./}{}; print "scripts/$f:$.: $_" if /\$[A-Za-z_][A-Za-z0-9_]*(?=[^\x00-\x7F])/;
        close ARGV if eof;
    ' ./*.sh
)"


if [[ -n "$HITS" ]]; then
    echo "❌ 有變數展開直接接中文字，在 macOS bash 3.2 + UTF-8 終端機會炸成 unbound variable：" >&2
    echo "$HITS" | sed 's/^/   /' >&2
    echo "   請改成大括號寫法。" >&2
    exit 1
fi

exit 0
