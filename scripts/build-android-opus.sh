#!/usr/bin/env bash
#
# scripts/build-android-opus.sh
# 為 Android 各 ABI 交叉編譯 libopus 靜態函式庫（工作包 WP1）。
#
# 為什麼需要這支腳本：Android 沒有系統 libopus，而 `audiopus-sys` 在
# 交叉編譯時不會自己把 libopus 建起來 —— 結果是 libpadnote_core.so 帶著
# 未定義符號 `opus_encoder_create` 之類的出貨，App 一啟動就 dlopen 失敗。
# 這裡用 NDK 的 CMake 工具鏈把 libopus 編成靜態庫，再由 build-android-libs.sh
# 透過 OPUS_LIB_DIR 指給 audiopus-sys 靜態連結進去。
#
# 產物在 android/prebuilt/opus/<abi>/libopus.a（衍生檔，不進版控）。

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

OPUS_VERSION="1.5.2"
TARBALL="opus-${OPUS_VERSION}.tar.gz"
BASE_URL="https://downloads.xiph.org/releases/opus"
ABIS=(arm64-v8a x86_64)
API_LEVEL=29          # 與 android/app 的 minSdk 一致
OUT_ROOT="android/prebuilt/opus"
WORK_DIR="target/android-opus"

if [[ -z "${ANDROID_NDK_HOME:-}" ]]; then
    SDK="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
    if [[ -d "$SDK/ndk" ]]; then
        export ANDROID_NDK_HOME="$SDK/ndk/$(ls -1 "$SDK/ndk" | sort -V | tail -1)"
    fi
fi
[[ -d "${ANDROID_NDK_HOME:-}" ]] || { echo "❌ 找不到 Android NDK" >&2; exit 1; }

TOOLCHAIN="$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake"
[[ -f "$TOOLCHAIN" ]] || { echo "❌ 找不到 NDK CMake 工具鏈：$TOOLCHAIN" >&2; exit 1; }

# 若每個 ABI 都已經有產物就直接結束（重跑很快）
ALL_PRESENT=1
for abi in "${ABIS[@]}"; do
    [[ -f "$OUT_ROOT/$abi/libopus.a" ]] || ALL_PRESENT=0
done
if [[ "$ALL_PRESENT" == "1" && "${1:-}" != "--force" ]]; then
    echo "==> libopus 已存在，略過（要重建請加 --force）"
    exit 0
fi

mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# --- 下載並驗證 ----------------------------------------------------------
# 校驗和取自 xiph 官方的 SHA256SUMS，與 D4「下載一律驗 SHA-256」的規則一致。
if [[ ! -f "$TARBALL" ]]; then
    echo "==> 下載 libopus ${OPUS_VERSION}"
    curl -fsSL -O "${BASE_URL}/${TARBALL}"
fi

echo "==> 驗證 SHA-256"
curl -fsSL "${BASE_URL}/SHA256SUMS.txt" -o SHA256SUMS.txt 2>/dev/null || \
  curl -fsSL "${BASE_URL}/SHA256SUMS" -o SHA256SUMS.txt
EXPECTED="$(grep -E "  ?opus-${OPUS_VERSION}\.tar\.gz$" SHA256SUMS.txt | awk '{print $1}' | head -1)"
ACTUAL="$(shasum -a 256 "$TARBALL" | awk '{print $1}')"
if [[ -z "$EXPECTED" ]]; then
    echo "❌ 官方校驗和清單裡找不到 ${TARBALL}" >&2
    exit 1
fi
if [[ "$EXPECTED" != "$ACTUAL" ]]; then
    echo "❌ SHA-256 不符：預期 $EXPECTED，實得 $ACTUAL" >&2
    exit 1
fi
echo "   OK  $ACTUAL"

[[ -d "opus-${OPUS_VERSION}" ]] || tar xzf "$TARBALL"

# --- 逐 ABI 編譯 ---------------------------------------------------------
cd "$REPO_ROOT"
for abi in "${ABIS[@]}"; do
    echo "==> 編譯 libopus（$abi）"
    BUILD_DIR="$WORK_DIR/build-$abi"
    rm -rf "$BUILD_DIR"
    cmake -S "$WORK_DIR/opus-${OPUS_VERSION}" -B "$BUILD_DIR" \
        -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
        -DANDROID_ABI="$abi" \
        -DANDROID_PLATFORM="android-${API_LEVEL}" \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_SHARED_LIBS=OFF \
        -DOPUS_BUILD_PROGRAMS=OFF \
        -DOPUS_BUILD_TESTING=OFF \
        > /dev/null
    cmake --build "$BUILD_DIR" --target opus -j "$(sysctl -n hw.ncpu 2>/dev/null || nproc)" > /dev/null

    mkdir -p "$OUT_ROOT/$abi"
    find "$BUILD_DIR" -name "libopus.a" -exec cp {} "$OUT_ROOT/$abi/libopus.a" \;
    ls -lh "$OUT_ROOT/$abi/libopus.a" | awk '{print "   " $9 "  " $5}'
done

echo "==> 完成"
