#!/usr/bin/env bash
# 專案放在 exFAT 外接碟時的共用輔助（由其他腳本 source，不直接執行）。
#
# exFAT 的特性：不存擴充屬性 → macOS 在每個檔案旁生出 `._*`（AppleDouble）；
# 不存權限 → 一律 rwx------。`._*` 會讓 codesign / Gradle 失敗，
# 所以「會被簽署或被工具大量寫入」的目錄一律改放本機磁碟。

# 抑制 cp/tar/zip 等工具產生 `._*`
export COPYFILE_DISABLE=1

# kairumo_on_apfs <path>：該路徑所在的磁碟是否為 APFS（或 HFS+）
kairumo_on_apfs() {
    local dev
    dev="$(df -P "$1" 2>/dev/null | awk 'NR==2{print $1}')"
    [[ -n "$dev" ]] && mount | grep -E "^${dev} on " | grep -qE '\((apfs|hfs)[,)]'
}

# kairumo_clean_source_appledouble <repo_root>
# 清掉會被 Gradle 打包的原始碼目錄裡的 `._*`。jniLibs 裡的 `._libpdfium.so`
# 之類的檔案若被當成原生函式庫收進 APK 就是真的問題；cp/Gradle 在 exFAT 上
# 隨時可能重新生出它們，所以每次進 Gradle 之前都清一次。
kairumo_clean_source_appledouble() {
    local d
    for d in "$1/android/app/src" "$1/android/prebuilt"; do
        [[ -d "$d" ]] && find "$d" -name '._*' -type f -delete 2>/dev/null || true
    done
}

# kairumo_setup_gradle_dirs <repo_root>
# 在非 APFS 磁碟上，把 Gradle 的 build 目錄與專案快取導向本機：
#   KAIRUMO_GRADLE_BUILD_ROOT  → android/build.gradle.kts 讀取
#   KAIRUMO_GRADLE_ARGS        → 傳給 ./gradlew 的額外參數（陣列）
# 產物路徑請用 ${KAIRUMO_ANDROID_APP_BUILD}（APFS 上就是 android/app/build）。
kairumo_setup_gradle_dirs() {
    local root="$1"
    KAIRUMO_GRADLE_ARGS=()
    kairumo_clean_source_appledouble "$root"
    if kairumo_on_apfs "$root"; then
        KAIRUMO_ANDROID_APP_BUILD="$root/android/app/build"
    else
        local local_root="${KAIRUMO_GRADLE_BUILD_ROOT:-$HOME/Library/Caches/Kairumo/gradle}"
        export KAIRUMO_GRADLE_BUILD_ROOT="$local_root/build"
        mkdir -p "$KAIRUMO_GRADLE_BUILD_ROOT" "$local_root/project-cache"
        KAIRUMO_GRADLE_ARGS=(--project-cache-dir "$local_root/project-cache")
        KAIRUMO_ANDROID_APP_BUILD="$KAIRUMO_GRADLE_BUILD_ROOT/app"
        echo "ℹ️  非 APFS 磁碟：Gradle 建置目錄改放 $KAIRUMO_GRADLE_BUILD_ROOT"
    fi
}
