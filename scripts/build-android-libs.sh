#!/usr/bin/env bash
#
# scripts/build-android-libs.sh
# 產生 Android 用的 libpadnote_core.so 與 Kotlin 綁定（工作包 WP1）。
#
# 用法：
#   ./scripts/build-android-libs.sh                 # release，arm64-v8a + x86_64
#   ./scripts/build-android-libs.sh debug           # debug 版
#   KAIRUMO_ANDROID_FEATURES="asr" ./scripts/build-android-libs.sh   # 額外開啟 feature
#
# 預設用 `--no-default-features`：
#   - asr（Silero VAD + 中文標點）需要 ONNX Runtime，而 `ort` 目前沒有
#     aarch64-linux-android 的預編譯二進位（第一版不含語音轉錄）。
#   - pdf（PDFium）需要各 ABI 的 libpdfium.so，尚未納入打包。
# Apple 版不受影響 —— 它走 padnote-core 的預設 features（asr + pdf 全開）。

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

PROFILE="${1:-release}"
ABIS=(arm64-v8a x86_64)
OUT_DIR="android/app/src/main/jniLibs"
EXTRA_FEATURES="${KAIRUMO_ANDROID_FEATURES:-}"

# --- NDK 位置 ------------------------------------------------------------
if [[ -z "${ANDROID_NDK_HOME:-}" ]]; then
    SDK="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
    if [[ -d "$SDK/ndk" ]]; then
        # 取版本號最大的一個
        LATEST_NDK="$(ls -1 "$SDK/ndk" | sort -V | tail -1)"
        export ANDROID_NDK_HOME="$SDK/ndk/$LATEST_NDK"
        export ANDROID_HOME="$SDK"
    fi
fi

if [[ -z "${ANDROID_NDK_HOME:-}" || ! -d "$ANDROID_NDK_HOME" ]]; then
    echo "❌ 找不到 Android NDK。請安裝後設定 ANDROID_NDK_HOME。" >&2
    echo "   sdkmanager --install 'ndk;28.2.13676358'" >&2
    exit 1
fi

command -v cargo-ndk >/dev/null 2>&1 || {
    echo "❌ 缺少 cargo-ndk：cargo install cargo-ndk" >&2
    exit 1
}

echo "==> NDK: $ANDROID_NDK_HOME"
echo "==> ABI: ${ABIS[*]}　profile: $PROFILE"

FEATURE_ARGS=(--no-default-features)
if [[ -n "$EXTRA_FEATURES" ]]; then
    FEATURE_ARGS+=(--features "$EXTRA_FEATURES")
    echo "==> 額外 features: $EXTRA_FEATURES"
fi

PROFILE_ARGS=()
[[ "$PROFILE" == "release" ]] && PROFILE_ARGS+=(--release)

# libopus 必須先備妥：Android 沒有系統 libopus，缺了它 .so 會帶著未定義符號出貨
"$REPO_ROOT/scripts/build-android-opus.sh"

mkdir -p "$OUT_DIR"
# 逐 ABI 建置 —— OPUS_LIB_DIR 是 per-ABI 的，不能一次丟給多個 target
for abi in "${ABIS[@]}"; do
    export OPUS_LIB_DIR="$REPO_ROOT/android/prebuilt/opus/$abi"
    export LIBOPUS_LIB_DIR="$OPUS_LIB_DIR"
    echo "==> 建置 $abi（libopus: $OPUS_LIB_DIR）"
    # audiopus-sys 沒有宣告 rerun-if-env-changed，換 ABI 時 cargo 會沿用上一個
    # ABI 的建置結果 —— 結果就是 .so 帶著未定義的 opus 符號出貨。強制重建它。
    case "$abi" in
        arm64-v8a) RUST_TARGET=aarch64-linux-android ;;
        x86_64)    RUST_TARGET=x86_64-linux-android ;;
        armeabi-v7a) RUST_TARGET=armv7-linux-androideabi ;;
        *) RUST_TARGET="" ;;
    esac
    if [[ -n "$RUST_TARGET" ]]; then
        cargo clean -p audiopus_sys --target "$RUST_TARGET" ${PROFILE_ARGS[@]+"${PROFILE_ARGS[@]}"} 2>/dev/null || true
    fi
    cargo ndk -t "$abi" -o "$OUT_DIR" build -p padnote-core "${FEATURE_ARGS[@]}" "${PROFILE_ARGS[@]}"
done

# 相依 crate 順帶產生的 cdylib 不是我們的執行期相依（libpadnote_core.so 只 NEEDED
# libc/libm/libdl），留著只會讓 APK 變大。
find "$OUT_DIR" -name "*.so" ! -name "libpadnote_core.so" -delete

echo "==> 產生 Kotlin 綁定 → android/app/src/main/java"
cargo build -p padnote-core >/dev/null
LIB="target/debug/libpadnote_core.dylib"
[[ -f "$LIB" ]] || LIB="target/debug/libpadnote_core.so"
mkdir -p android/app/src/main/java
cargo run -q -p padnote-core --bin uniffi-bindgen -- generate \
  --library "$LIB" --language kotlin --out-dir android/app/src/main/java

echo "==> 完成"
find "$OUT_DIR" -name "*.so" -exec ls -lh {} \; | awk '{print "   " $9 "  " $5}'
