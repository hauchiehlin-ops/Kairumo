# NDK 工具鏈的包裝（H-ASR-ANDROID）。
#
# # 為什麼需要包一層
#
# `whisper-rs-sys` 用 `cmake-rs` 建 whisper.cpp，而 `cmake-rs` 只會從環境變數
# 讀 `CMAKE_TOOLCHAIN_FILE`，**沒有辦法傳任意的 `-D`**。
#
# 但 NDK 的 `android.toolchain.cmake` 需要 `ANDROID_ABI` 與 `ANDROID_PLATFORM`
# 這兩個快取變數才知道要編哪個架構 —— 少了它們，cmake 會拿 host 的預設值去
# 測試編譯器，然後回報
# `Check for working C compiler: … - broken`，而錯誤訊息完全不會提到 ABI。
#
# 所以這裡先把兩個變數設好，再 include 真正的 NDK 工具鏈。
# 值從環境變數來，由 `scripts/build-android-libs.sh` 逐 ABI 設定。

# **一定要用 CACHE FORCE。** 普通的 `set()` 在 cmake 為了測試編譯器而起的
# try_compile 子專案裡不會留下來 —— 那個子專案會重新 include 這個檔案，
# 而 `ANDROID_ABI` 已經被 NDK 的工具鏈設成預設的 armeabi-v7a，
# 於是 `if(NOT DEFINED ...)` 不成立，我們設的值被跳過。
# 症狀是 `clang: error: unsupported argument 'armv7-a' to option '-march='`。
set(ANDROID_ABI "$ENV{KAIRUMO_ANDROID_ABI}" CACHE STRING "Android ABI" FORCE)
set(ANDROID_PLATFORM "android-$ENV{KAIRUMO_ANDROID_API}" CACHE STRING "Android API" FORCE)

if("${ANDROID_ABI}" STREQUAL "")
    message(FATAL_ERROR "KAIRUMO_ANDROID_ABI 未設定 —— 見 scripts/build-android-libs.sh")
endif()

include("$ENV{ANDROID_NDK_HOME}/build/cmake/android.toolchain.cmake")
