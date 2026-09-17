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
# 預設額外開啟 relay：Android 走核心的協同中繼。
# Apple 版不受影響 —— 它走 padnote-core 的預設 features（asr + pdf 全開）。

set -euo pipefail

# 腳本輸出含中文。使用者的終端機若不是 UTF-8 locale，內嵌 python3 印中文會
# UnicodeEncodeError 直接中止（實際踩過）。強制輸出編碼，與終端機 locale 脫鉤。
export PYTHONIOENCODING=utf-8

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

PROFILE="${1:-release}"
ABIS=(arm64-v8a x86_64)
OUT_DIR="android/app/src/main/jniLibs"
# relay：Android 用核心的中繼實作（Apple 版維持自己的 Swift 實作，不受影響）
EXTRA_FEATURES="${KAIRUMO_ANDROID_FEATURES:-relay}"

# --- NDK 位置 ------------------------------------------------------------
#
# **版本要釘死，不要取最新的那一個。**
#
# 原本是 `ls | sort -V | tail -1`（取版本號最大的）。CI 釘的是 28.2，
# 開發機上多裝了 NDK 30 之後，同一份程式碼在兩台機器上就產出不同的
# libpadnote_core.so —— 而 NDK 30 那份少連了 C++ 執行期，App 一啟動就死在
# `dlopen failed: cannot locate symbol "__gxx_personality_v0"`。
#
# 而且它是**執行期**才炸：編譯、打包、安裝全部成功，開啟才閃退。
# 要跟 CI 一致就得跟死，浮動的工具鏈等於沒有可重現的建置。
PINNED_NDK="${KAIRUMO_NDK_VERSION:-28.2.13676358}"

if [[ -z "${ANDROID_NDK_HOME:-}" ]]; then
    SDK="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
    if [[ -d "$SDK/ndk/$PINNED_NDK" ]]; then
        export ANDROID_NDK_HOME="$SDK/ndk/$PINNED_NDK"
        export ANDROID_HOME="$SDK"
    elif [[ -d "$SDK/ndk" ]]; then
        echo "❌ 找不到釘定的 NDK ${PINNED_NDK}。已安裝的有：" >&2
        ls -1 "$SDK/ndk" | sed 's/^/     /' >&2
        echo "   sdkmanager --install 'ndk;$PINNED_NDK'" >&2
        echo "   （真的要用別版：KAIRUMO_NDK_VERSION=... 但請先確認能開得起來）" >&2
        exit 1
    fi
fi

if [[ -z "${ANDROID_NDK_HOME:-}" || ! -d "$ANDROID_NDK_HOME" ]]; then
    echo "❌ 找不到 Android NDK。請安裝後設定 ANDROID_NDK_HOME。" >&2
    echo "   sdkmanager --install 'ndk;$PINNED_NDK'" >&2
    exit 1
fi

command -v cargo-ndk >/dev/null 2>&1 || {
    echo "❌ 缺少 cargo-ndk：cargo install cargo-ndk" >&2
    exit 1
}

# cargo-ndk 兩個變數都看。CI 的 runner 預設 ANDROID_NDK_ROOT 指向 27.3，
# 而我們釘的是 28.2 —— 不對齊的話它會警告，而且可能真的用另一版建置，
# 於是「本機用 28.2、CI 用 27.3」又變回不可重現的建置。
export ANDROID_NDK_ROOT="$ANDROID_NDK_HOME"

echo "==> NDK: $ANDROID_NDK_HOME"
echo "==> ABI: ${ABIS[*]}　profile: $PROFILE"

FEATURE_ARGS=(--no-default-features)
if [[ -n "$EXTRA_FEATURES" ]]; then
    FEATURE_ARGS+=(--features "$EXTRA_FEATURES")
    echo "==> 額外 features: $EXTRA_FEATURES"
fi

# debug 時這個陣列是空的，而 macOS 內建的 bash 3.2 在 `set -u` 下會把
# `"${PROFILE_ARGS[@]}"` 當成未設定的變數直接中止（`unbound variable`）——
# 所以下面用到它的地方一律寫成 `${PROFILE_ARGS[@]+"${PROFILE_ARGS[@]}"}`。
# release 路徑不會踩到，所以這個坑可以活很久。
PROFILE_ARGS=()
[[ "$PROFILE" == "release" ]] && PROFILE_ARGS+=(--release)

# libopus 必須先備妥：Android 沒有系統 libopus，缺了它 .so 會帶著未定義符號出貨
"$REPO_ROOT/scripts/build-android-opus.sh"

mkdir -p "$OUT_DIR"
# 逐 ABI 建置 —— OPUS_LIB_DIR 是 per-ABI 的，不能一次丟給多個 target
for abi in "${ABIS[@]}"; do
    export OPUS_LIB_DIR="$REPO_ROOT/android/prebuilt/opus/$abi"
    export LIBOPUS_LIB_DIR="$OPUS_LIB_DIR"
    echo "==> 建置 ${abi}（libopus: ${OPUS_LIB_DIR}）"
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
    # `-lc++_shared` 是必要的，不是保險。
    #
    # 函式庫參照 `__gxx_personality_v0`（Rust 在 Android 做 panic unwinding 的
    # 個性函式）。光把 libc++_shared.so 放進 APK **沒有用** —— ELF 裡沒有對應的
    # NEEDED 項目，動態載入器就不會去載它，dlopen 依然找不到符號。
    # 一定要在連結時真的連上去，NEEDED 才會出現。
    #
    # **要用全域 RUSTFLAGS，不能用 CARGO_TARGET_<TRIPLE>_RUSTFLAGS。**
    #
    # 我一度改成 target 範圍的版本，理由是「全域會汙染 host 的 build script」——
    # 那個理由是錯的：`cargo ndk` 會傳 `--target`，而 cargo 在有 `--target` 時
    # 本來就不會把 RUSTFLAGS 套到 build script 與 proc-macro。
    #
    # 而且 target 範圍那版在 CI 上**完全失效**：cargo 只要看到 `RUSTFLAGS`
    # 有值，就會忽略 CARGO_TARGET_<TRIPLE>_RUSTFLAGS ——
    # CI 正好設了 `RUSTFLAGS: -D warnings`。本機沒設，所以本機看起來是好的。
    #
    # 用 `${RUSTFLAGS:-}` 前綴保留呼叫端原本的旗標（例如 CI 的 -D warnings），
    # 不要整個蓋掉。
    RUSTFLAGS="${RUSTFLAGS:-} -C link-arg=-lc++_shared" \
        cargo ndk -t "$abi" -o "$OUT_DIR" build -p padnote-core "${FEATURE_ARGS[@]}" \
            ${PROFILE_ARGS[@]+"${PROFILE_ARGS[@]}"}
done

# 相依 crate 順帶產生的 cdylib 不是我們的執行期相依，留著只會讓 APK 變大。
# 但**不能連 libc++_shared.so 一起刪** —— 見下面那段。
find "$OUT_DIR" -name "*.so" ! -name "libpadnote_core.so" -delete

# --- C++ 執行期 ---------------------------------------------------------
#
# 這裡原本寫著「libpadnote_core.so 只 NEEDED libc/libm/libdl」並據此把其他
# .so 全刪掉。那個假設現在不成立：函式庫參照 `__gxx_personality_v0`
# （Rust 在 Android 上做 panic unwinding 要用的個性函式），而 Android 系統
# 沒有內建提供它的函式庫。
#
# 症狀極度誤導：編譯過、打包過、安裝過，**開啟才閃退**，而且錯誤是
# `dlopen failed: cannot locate symbol ...`，看起來像 App 壞了而不是建置漏東西。
for abi in "${ABIS[@]}"; do
    case "$abi" in
        arm64-v8a)   TRIPLE=aarch64-linux-android ;;
        x86_64)      TRIPLE=x86_64-linux-android ;;
        armeabi-v7a) TRIPLE=arm-linux-androideabi ;;
        *) continue ;;
    esac
    CXX_SO="$(find "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt" \
        -path "*/sysroot/usr/lib/$TRIPLE/libc++_shared.so" | head -1)"
    if [[ -z "$CXX_SO" ]]; then
        echo "❌ 在 NDK 裡找不到 $TRIPLE 的 libc++_shared.so" >&2
        exit 1
    fi
    cp -f "$CXX_SO" "$OUT_DIR/$abi/"
done

# --- libpdfium：PDF 的執行期庫（docs/TODO.md H8，D-11 已決定隨 App 出貨）--
#
# `pdfium-render` 只是 Rust 綁定，**裡面沒有 PDFium 本身**。少了這個 .so，
# 任何開 PDF 的動作都會在執行期失敗，而編譯完全不會報錯 ——
# 與上面 libc++_shared 那一段是同一類的坑。
#
# 來源與雜湊由 `scripts/fetch-pdfium.sh` 負責（版本釘死、逐檔驗雜湊）。
# 這裡只做「複製到 jniLibs」。沒抓過就跳過並**明講**，不要靜靜略過 ——
# 靜靜略過的話，下一個發現的人是使用者。
PDFIUM_DIR="${PDFIUM_DIR:-third_party/pdfium}"
for abi in "${ABIS[@]}"; do
    case "$abi" in
        arm64-v8a)   PDFIUM_PKG=pdfium-android-arm64 ;;
        x86_64)      PDFIUM_PKG=pdfium-android-x64 ;;
        armeabi-v7a) PDFIUM_PKG=pdfium-android-arm ;;
        *) continue ;;
    esac
    SO="$PDFIUM_DIR/$PDFIUM_PKG/lib/libpdfium.so"
    if [[ -f "$SO" ]]; then
        cp -f "$SO" "$OUT_DIR/$abi/"
        echo "   libpdfium.so → $abi"
    else
        echo "⚠️  ${abi} 沒有 libpdfium.so（找不到 ${SO}）。"
        echo "    PDF 功能在執行期會失敗。先跑：./scripts/fetch-pdfium.sh all"
    fi
done

# --- 驗證：每一個 NEEDED 都要找得到 -------------------------------------
#
# 這道檢查存在的理由就是上面那段。假設寫在註解裡會過期，寫成檢查才不會 ——
# 下次再多出一個執行期相依，會在這裡當場失敗，不是在使用者手上閃退。
READELF="$(find "$ANDROID_NDK_HOME" -name "llvm-readelf" | head -1)"
if [[ -n "$READELF" ]]; then
    # Android 系統本來就提供的，不需要我們打包。
    SYSTEM_LIBS="libc.so libm.so libdl.so liblog.so libz.so libandroid.so libOpenSLES.so libaaudio.so"
    for abi in "${ABIS[@]}"; do
        SO="$OUT_DIR/$abi/libpadnote_core.so"
        [[ -f "$SO" ]] || continue
        NEEDED="$("$READELF" -d "$SO" 2>/dev/null \
                  | sed -n 's/.*NEEDED.*Shared library: \[\(.*\)\]/\1/p')"

        # (a) 宣告的相依都要打包進來。
        for need in $NEEDED; do
            if [[ " $SYSTEM_LIBS " == *" $need "* ]]; then continue; fi
            if [[ ! -f "$OUT_DIR/$abi/$need" ]]; then
                echo "❌ ${abi}：libpadnote_core.so 需要 ${need}，但 jniLibs 裡沒有它。" >&2
                echo "   這會在 App 啟動時以 dlopen failed 閃退，而不是在這裡失敗。" >&2
                exit 1
            fi
        done

        # (b) **更重要的一半**：有未定義的 C++ 執行期符號，就一定要宣告
        # NEEDED libc++_shared.so。只把檔案放進 APK 是不夠的 ——
        # 沒有 NEEDED，載入器根本不會去載它，而 (a) 這種只看宣告的檢查
        # 完全抓不到（第一版就是這樣放行的）。
        NM_BIN="$(find "$ANDROID_NDK_HOME" -name "llvm-nm" | head -1)"
        if [[ -n "$NM_BIN" ]] && "$NM_BIN" -u "$SO" 2>/dev/null | grep -q "__gxx_personality_v0"; then
            if [[ "$NEEDED" != *"libc++_shared.so"* ]]; then
                echo "❌ ${abi}：函式庫用到 C++ 執行期（__gxx_personality_v0 未定義），" >&2
                echo "   但沒有連上 libc++_shared.so。App 會在啟動時 dlopen failed。" >&2
                exit 1
            fi
        fi
    done
    echo "==> 執行期相依檢查通過"
fi

echo "==> 產生 Kotlin 綁定 → android/app/src/main/java"
# 綁定必須由「與 Android 版相同 feature 組合」的函式庫產生 ——
# 用預設 feature 產出的綁定會少掉 relay 之類只在 Android 開啟的型別，
# Kotlin 端就會出現 Unresolved reference。
cargo build -p padnote-core "${FEATURE_ARGS[@]}" >/dev/null
LIB="target/debug/libpadnote_core.dylib"
[[ -f "$LIB" ]] || LIB="target/debug/libpadnote_core.so"
mkdir -p android/app/src/main/java
cargo run -q -p padnote-core --bin uniffi-bindgen -- generate \
  --library "$LIB" --language kotlin --out-dir android/app/src/main/java

echo "==> 完成"
find "$OUT_DIR" -name "*.so" -exec ls -lh {} \; | awk '{print "   " $9 "  " $5}'
