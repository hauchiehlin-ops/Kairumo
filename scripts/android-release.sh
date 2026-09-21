#!/usr/bin/env bash
#
# scripts/android-release.sh
# 產出 Android 的上架檔（AAB）與可直接安裝的 APK（工作包 WP8）。
#
# 用法：
#   ./scripts/android-release.sh                # 用正式金鑰建置（需 keystore.properties）
#   ./scripts/android-release.sh --unsigned     # 不簽章，只確認建得起來
#   ./scripts/android-release.sh --test-sign    # 用**拋棄式測試金鑰**簽，僅供本機驗證流程
#
# 金鑰設定（android/keystore.properties，已在 .gitignore 內）：
#   storeFile=/絕對路徑/kairumo-release.jks
#   storePassword=…
#   keyAlias=kairumo
#   keyPassword=…
# 也可以改用環境變數 KAIRUMO_STOREFILE / KAIRUMO_STOREPASSWORD /
# KAIRUMO_KEYALIAS / KAIRUMO_KEYPASSWORD。
#
# ⚠️ 正式金鑰請自己產生與保管：
#   keytool -genkeypair -v -keystore kairumo-release.jks -alias kairumo \
#           -keyalg RSA -keysize 4096 -validity 10000
# 這支腳本不會替你產生正式金鑰，也不會把任何密碼寫進版控 ——
# 上架金鑰弄丟等於這個 applicationId 再也更新不了。

set -euo pipefail

# 腳本輸出含中文。使用者的終端機若不是 UTF-8 locale，內嵌 python3 印中文會
# UnicodeEncodeError 直接中止（實際踩過）。強制輸出編碼，與終端機 locale 脫鉤。
export PYTHONIOENCODING=utf-8

# 路徑要在**任何 cd 之前**解析成絕對路徑並存起來。
#
# 底下原本有一行在 cd 到 android/ 之後才用 `dirname "${BASH_SOURCE[0]}"`
# 重新推腳本位置 —— 以相對路徑呼叫時（CI 用的是 ./scripts/android-release.sh）
# 那個值是 "./scripts"，而當下的工作目錄已經是 android/，於是 cd 失敗、
# 版本檢查整個沒跑，只留下一行 exit 127。
# 用絕對路徑呼叫（release.sh 就是）剛好沒事 —— 所以本機從來看不到。
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT/android"

MODE="${1:-signed}"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"

# --- 1. 版本一致性 -------------------------------------------------------
# 上架前最不該發生的事，就是 Play Console 收到的 versionCode 跟你以為的不一樣。
echo "==> 檢查版本一致性"
"$SCRIPT_DIR/check-version-consistency.sh"

# --- 2. 原生函式庫 -------------------------------------------------------
NEED_BUILD_SO=0
SO_PATH="app/src/main/jniLibs/arm64-v8a/libpadnote_core.so"
if [[ ! -f "$SO_PATH" ]]; then
    NEED_BUILD_SO=1
elif [[ $(find "$REPO_ROOT/crates" -type f -name "*.rs" -newer "$SO_PATH" 2>/dev/null | head -n 1) ]]; then
    NEED_BUILD_SO=1
fi

if [[ "$NEED_BUILD_SO" -eq 1 ]]; then
    echo "==> 偵測到核心原始碼異動或缺少 .so，建置 Android 原生函式庫 (release)"
    "$REPO_ROOT/scripts/build-android-libs.sh" release
fi

# --- 3. 簽章 -------------------------------------------------------------
case "$MODE" in
  --unsigned)
    echo "==> 不簽章（只確認建得起來）"
    ;;
  --test-sign)
    # 拋棄式金鑰，只為了在本機驗證「簽章 → 安裝 → 啟動」這條路是通的。
    # 絕對不要拿它上架：它的密碼就寫在這支腳本裡。
    LOCAL_DIR="$REPO_ROOT/android/.local"
    mkdir -p "$LOCAL_DIR"
    KS="$LOCAL_DIR/test-only.jks"
    if [[ ! -f "$KS" ]]; then
        echo "==> 產生拋棄式測試金鑰（test-only，不可用於上架）"
        keytool -genkeypair -v -keystore "$KS" -alias test-only \
            -keyalg RSA -keysize 2048 -validity 3650 \
            -storepass testonly -keypass testonly \
            -dname "CN=Kairumo Test Only, OU=Dev, O=Kairumo, C=TW" >/dev/null
    fi
    cat > "$REPO_ROOT/android/keystore.properties" <<EOF
# ⚠️ 由 android-release.sh --test-sign 產生的**拋棄式**設定，不可用於上架。
storeFile=$KS
storePassword=testonly
keyAlias=test-only
keyPassword=testonly
EOF
    # 用完就刪掉。留在原地的話，之後任何一次 `./gradlew bundleRelease`
    # 都會靜默用這把測試金鑰簽下去 —— 而簽出來的東西看起來跟正式版一模一樣。
    trap 'rm -f "$REPO_ROOT/android/keystore.properties"' EXIT
    echo "==> 使用拋棄式測試金鑰（建置結束後會自動移除設定檔）"
    ;;
  *)
    if [[ ! -f "$REPO_ROOT/android/keystore.properties" && -z "${KAIRUMO_STOREFILE:-}" ]]; then
        echo "❌ 找不到簽章設定。請建立 android/keystore.properties 或設定 KAIRUMO_* 環境變數。" >&2
        echo "   只想確認建得起來的話：./scripts/android-release.sh --unsigned" >&2
        exit 1
    fi
    ;;
esac

# --- 4. 建置 -------------------------------------------------------------
echo "==> 建置 AAB 與 APK"
./gradlew :app:bundleRelease :app:assembleRelease

AAB="app/build/outputs/bundle/release/app-release.aab"
APK_DIR="app/build/outputs/apk/release"

echo "==> 完成"
ls -lh "$AAB" | awk '{print "   AAB  " $9 "  " $5}'
find "$APK_DIR" -name "*.apk" -exec ls -lh {} \; | awk '{print "   APK  " $9 "  " $5}'

cat <<'NEXT'

下一步（人要做的部分）：
  1. Play Console → 內部測試 → 上傳 AAB
  2. 隱私權政策網址：https://hauchiehlin-ops.github.io/Kairumo/legal/privacy.html
     （由 scripts/publish-pages.sh 發佈，改了 docs/legal 之後重跑一次即可更新）
  3. 首次上傳會啟用 Play App Signing —— 你上傳的金鑰是「上傳金鑰」，
     Google 另外保管實際的簽章金鑰。上傳金鑰遺失可以申請重設，
     但**沒有啟用 Play App Signing 而弄丟正式金鑰的話，這個 applicationId 就再也更新不了**。
NEXT
