#!/usr/bin/env bash
# 在 android/ 跑 Gradle 的入口：先清 `._*`，exFAT 上把建置目錄與專案快取導到本機磁碟。
#
#   scripts/gradle.sh :app:testDebugUnitTest
#   scripts/gradle.sh :app:assembleDebug
#
# 直接跑 android/gradlew 也會清（見 android/settings.gradle.kts），但 Gradle 的專案快取
# （android/.gradle）只能用命令列參數搬，這支腳本兩件事一起做。產物位置在
# ${KAIRUMO_ANDROID_APP_BUILD}（APFS 上就是 android/app/build）。
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib-exfat.sh
source "${REPO_ROOT}/scripts/lib-exfat.sh"

export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
if ! kairumo_on_apfs "$REPO_ROOT" && [[ -z "${KAIRUMO_GRADLE_BUILD_ROOT:-}" ]]; then
    # 主目錄與各 worktree 各用一份，不互相蓋掉產物（與 settings.gradle.kts 同一個想法）。
    tag="$(printf '%s' "${REPO_ROOT}/android" | shasum | cut -c1-8)"
    export KAIRUMO_GRADLE_BUILD_ROOT="$HOME/Library/Caches/Kairumo/gradle/$tag"
fi
kairumo_setup_gradle_dirs "$REPO_ROOT"
echo "📦 Android 產物：${KAIRUMO_ANDROID_APP_BUILD}"

cd "${REPO_ROOT}/android"
exec ./gradlew ${KAIRUMO_GRADLE_ARGS[@]+"${KAIRUMO_GRADLE_ARGS[@]}"} "$@"
