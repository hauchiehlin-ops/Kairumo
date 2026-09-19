#!/usr/bin/env bash
#
# scripts/release-commit.sh
# 建立發版 commit 與 tag。由 release.sh 呼叫，也可以單獨用。
#
# 用法：./scripts/release-commit.sh <版本號> <build號>
#
set -euo pipefail
export PYTHONIOENCODING=utf-8

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

VERSION="${1:?需要版本號}"
BUNDLE="${2:?需要 build 號}"

# **只暫存版本相關的檔案。**
#
# 原本是 git add -A，結果把當下工作目錄裡任何進行中的改動都掃進了發版
# commit（實際發生過兩次：一次混進整批 CI 修正，一次把 344MB 的 Xcode
# 衍生資料整包提交進公開 repo）。發版 commit 就該只有版本號。
git -C "$REPO_ROOT" add -- \
    "${REPO_ROOT}/Cargo.toml" \
    "${REPO_ROOT}/Cargo.lock" \
    "${REPO_ROOT}/apple/project.yml" \
    "${REPO_ROOT}/apple/Kairumo.xcodeproj/project.pbxproj" \
    "${REPO_ROOT}/android/app/build.gradle.kts" \
    "${REPO_ROOT}/docs/manual/manual.js" \
    "${REPO_ROOT}/docs/manual/manual-apple.js" \
    "${REPO_ROOT}/docs/manual/manual-android.js" \
    "${REPO_ROOT}/docs/legal/privacy.html" \
    "${REPO_ROOT}/docs/legal/privacy-apple.html" \
    "${REPO_ROOT}/docs/legal/privacy-android.html" \
    "${REPO_ROOT}/apple/Resources/Docs" \
    "${REPO_ROOT}/apple/Resources/Templates" \
    "${REPO_ROOT}/templates/document-templates.json"

if git -C "$REPO_ROOT" diff --cached --quiet; then
    echo "   （版本相關檔案沒有改動，不建立 commit）"
    exit 0
fi

git -C "$REPO_ROOT" commit -q -m "chore(release): bump version to v${VERSION} (build ${BUNDLE})"
git -C "$REPO_ROOT" tag -f "v${VERSION}" >/dev/null
echo "   ✅ 已建立 commit 與 tag v${VERSION}"
