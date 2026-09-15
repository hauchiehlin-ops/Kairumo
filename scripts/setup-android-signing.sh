#!/usr/bin/env bash
#
# scripts/setup-android-signing.sh
# 建立 Android 的**上傳金鑰**（upload key）與 android/keystore.properties。
#
# 用法：
#   ./scripts/setup-android-signing.sh
#
# 這支腳本只做一次。做完之後 ./scripts/release.sh 與 ./scripts/dist.sh
# 就能簽出 Play Console 收得下、手機裝得起來的檔案。
#
# 關於「弄丟會怎樣」，兩件事要分清楚 —— 嚴重程度差很多：
#
#   Play 上架：Google 的 Play App Signing 保管真正的 app signing key，
#     這裡產生的只是**上傳金鑰**。上傳金鑰弄丟可以向 Google 申請重設，
#     使用者端不受影響。麻煩，但救得回來。
#
#   側載 APK：沒有任何人幫你保管。換一把金鑰，舊版就升不上去，
#     使用者只能移除重裝 —— 資料一起消失。這種才是真的救不回來。
#
# 兩種情況都一樣：金鑰檔與密碼要進密碼管理器，不要只留在這台電腦上。
#
set -euo pipefail
export PYTHONIOENCODING=utf-8

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

KS_DIR="${REPO_ROOT}/android/.local"
KS="${KS_DIR}/kairumo-release.jks"
ALIAS="kairumo"
PROPS="${REPO_ROOT}/android/keystore.properties"

# Gradle 找 JDK 的順序是 JAVA_HOME → PATH，keytool 也一樣。
if [[ -z "${JAVA_HOME:-}" ]]; then
    if JAVA_BIN="$(command -v keytool)"; then
        JAVA_HOME="$(cd "$(dirname "$JAVA_BIN")/.." && pwd)"; export JAVA_HOME
    else
        echo "❌ 找不到 keytool（JDK 沒裝，或不在 PATH 上）。" >&2
        echo "   brew install openjdk@17" >&2
        exit 1
    fi
fi

echo "=================================================="
echo "🔐 Android 上傳金鑰設定"
echo "=================================================="

# 已經有設定就不要動它。覆蓋掉一把在用的金鑰，後果是使用者端升不上去。
if [[ -f "$PROPS" ]]; then
    echo "ℹ️  android/keystore.properties 已經存在："
    sed 's/Password=.*/Password=（略）/' "$PROPS" | sed 's/^/     /'
    echo ""
    echo "   要換金鑰的話請自己確認清楚後刪掉它，這支腳本不會覆蓋。"
    exit 0
fi

if [[ -f "$KS" ]]; then
    echo "ℹ️  金鑰檔已存在：$KS"
    echo "   只補寫 keystore.properties（需要你輸入這把金鑰的密碼）。"
    NEED_GEN=0
else
    NEED_GEN=1
fi

if [[ "$NEED_GEN" -eq 1 ]]; then
    cat <<'INTRO'

接下來會產生一把金鑰。keytool 會問你一串問題，照下面回答：

  Enter keystore password    ← 自己想一個密碼，打字時螢幕不會有任何顯示，
                                這是正常的。打完按 Enter。
  Re-enter new password      ← 同一個密碼再打一次
  名字與姓氏 (CN)             ← 打 Kairumo
  組織單位 (OU)               ← 直接按 Enter 跳過
  組織 (O)                   ← 打 Kairumo
  城市 (L) / 州別 (ST)        ← 直接按 Enter 跳過
  國家代碼 (C)                ← 打 TW
  以上正確嗎                  ← 打 y 再按 Enter

密碼請當場存進密碼管理器。這支腳本不會、也不應該替你記住它。

INTRO
    read -r -p "準備好了就按 Enter 開始（Ctrl-C 取消）…" _

    mkdir -p "$KS_DIR"
    keytool -genkeypair -v \
        -keystore "$KS" \
        -alias "$ALIAS" \
        -keyalg RSA -keysize 4096 -validity 10000
fi

# keystore.properties 要放明文密碼（Gradle 就是這樣讀的），所以這個檔案
# 不進版控 —— .gitignore 已經擋著。密碼由使用者自己打進來，不經過任何人。
echo ""
echo "接著把密碼寫進 android/keystore.properties（Gradle 要讀它）。"
echo "輸入時螢幕一樣不會顯示。"
echo ""
read -r -s -p "keystore 密碼：" STOREPASS; echo
if [[ -z "$STOREPASS" ]]; then
    echo "❌ 密碼是空的，中止。" >&2
    exit 1
fi

# 先驗證密碼是對的，再寫檔。密碼打錯卻寫進去的話，要到 gradle 建置那一步
# 才會以一個看不出原因的錯誤失敗。
if ! keytool -list -keystore "$KS" -alias "$ALIAS" -storepass "$STOREPASS" >/dev/null 2>&1; then
    echo "❌ 這個密碼打不開 ${KS}，沒有寫入任何檔案。" >&2
    echo "   密碼忘了的話，刪掉那個 .jks 重跑這支腳本 —— 但**只有在還沒發布過**的前提下。" >&2
    exit 1
fi

umask 077
cat > "$PROPS" <<EOF
# Kairumo Android 上傳金鑰設定。
# 由 scripts/setup-android-signing.sh 產生。不進版控（.gitignore 已擋）。
storeFile=$KS
storePassword=$STOREPASS
keyAlias=$ALIAS
keyPassword=$STOREPASS
EOF

echo ""
echo "✅ 設定完成"
echo "   金鑰檔：$KS"
echo "   設定檔：${PROPS}（權限 $(stat -f '%Lp' "$PROPS")，不進版控）"
echo ""
echo "   憑證指紋（Play Console 對照用）："
keytool -list -v -keystore "$KS" -alias "$ALIAS" -storepass "$STOREPASS" 2>/dev/null \
    | grep -E "SHA1:|SHA256:" | sed 's/^/     /'
echo ""
echo "⚠️  現在就去做這兩件事，之後很難補救："
echo "     1. 把 $KS 備份到密碼管理器或另一台機器"
echo "     2. 把剛才那個密碼存進密碼管理器"
echo ""
echo "👉 接著：./scripts/release.sh all minor    或    ./scripts/dist.sh --mac --android"
