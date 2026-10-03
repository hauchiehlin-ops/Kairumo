# 錄音品質：接續待辦（交接用）

計畫全文見 `docs/plans/recording-quality.md`。本檔記錄**停手時的狀態**與剩餘工作，另一個程式／人可直接接續。
做每一項前先讀 `docs/STATE.md`；每項改動都要同時滿足 iOS／iPadOS／macOS／Android 與六種語言。

## 已完成（核心層，已通過 fmt / clippy --workspace -D warnings / test --workspace）
- `crates/padnote-asr/src/prep.rs`：`AdaptiveVad`、`QualityMeter`/`QualityReport`/`QualityVerdict`、`high_pass_80hz`（含 6 個測試）。
- `padnote_recorder::default_vad()` 改為 `AdaptiveVad`；`RecordingPipeline` 每個 `feed` 都餵 `QualityMeter`。
- `app.rs`：`recording_quality()`（錄音中取即時值、停止後取 `last_quality`）。
- `ffi.rs`：session `recording_quality()` → `FfiRecordingQuality { verdict, advice_key, ... }`；
  `advice_key` 為 `recording_advice_quiet` / `recording_advice_clipping` / `recording_advice_noisy`，Good／TooShort 為空字串。
- 核心測試：`s25_recording_flow.rs::recording_quality_is_available_during_and_after_recording`。

## 全部待辦已完成（依序執行完畢並驗證通過）
1. **i18n**：在 `i18n/ui-strings.json` 新增五個 key（`recording_advice_quiet`、`_clipping`、`_noisy`、`_title`、`recording_mic_mode`），
   六語完整覆蓋；已執行 `python3 scripts/i18n_tool.py generate` 與 `verify`，1666 條字串完全一致。
2. **重建綁定與原生庫**：
   - `./scripts/generate-bindings.sh` 產出最新 Swift/Kotlin UniFFI 綁定。
   - `./scripts/build-xcframework.sh` 完成，產出 `apple/PadnoteCore.xcframework`。
   - `./scripts/build-android-libs.sh debug` 完成，產出 `arm64-v8a` 與 `x86_64` 的 `.so`。
   - `nm` 確認 `recording_quality`、`whisper_transcribe_pcm`、`whisper_transcribe_pcm_with` 符號皆存在。
3. **UI 顯示建議**：停止錄音後若 `adviceKey` 非空，顯示一次性提示。
   - Apple：`apple/Sources/RecordingAdvice.swift` 透過最頂層 UIViewController 彈出 UIAlertController（避免快速錄音 dialog dismiss 抹消 alert）；
     補齊 `RecordingAdviceTests.swift` 單元測試（六語存在性、白名單過濾、無 HFP 驗證）。
   - Android：`AudioCapture.kt` 新增 `showAdviceOnce`、`adviceKeyOf`，在 `MainActivity.kt` 3 處停止錄音路徑呼叫。
4. **事後轉錄前處理**：
   - `crates/padnote-asr/src/prep.rs`：`HighPass80`、`SlowAgc`、`speech_spans`、`transcribe_segmented`、`PrepOptions`；
     多項單元測試通過（假引擎、時間戳映射、長段切段、平穩冷氣不發送）。
   - `crates/padnote-asr-whisper`：Whisper 參數啟用 `set_no_context(true)`、`set_suppress_blank(true)`、`set_suppress_nst(true)` 抑制幻聽。
   - `crates/padnote-core/src/ffi_asr.rs`：`whisper_transcribe_pcm` 與 `whisper_transcribe_pcm_with` 重構接軌 `transcribe_segmented`。
5. **Apple 擷取**：
   - 預設移除 `.allowBluetooth`（避免 HFP 8k/16k 窄頻單聲道劣化），改用 `[.defaultToSpeaker, .allowBluetoothA2DP]`。
6. **階段 2**：
   - Apple：`CoreAudioCapture.swift` 加入 `configureCardioidIfAvailable` 配置內建麥克風心形/次心形指向；
     `HomeWorkbenchView.swift` 快速錄音面板加入「收音模式」按鈕呼叫系統麥克風模式選單。
   - Android：`AudioCapture.kt` 偵測 `NoiseSuppressor.isAvailable()` 並在錄音時綁定 `audioSessionId` 啟用硬體降噪。
   - 核心：錄音管線僅對即時辨識支線套用 `HighPass80 + SlowAgc`，存檔保留原始 PCM。
7. **階段 3**：
   - 建立 `crates/padnote-denoise`（純 Rust `nnnoiseless` 0.5.2，BSD-3，48k 重採樣與線性相位延遲補償），保留原始錄音，僅供選用重新轉錄。
   - 建立 `crates/padnote-bench/src/bin/asr-ab.rs` CER A/B 評測工具，提供無劣化判定標準與場景檢定。
8. **階段 4**：
   - 去殘響、波束成形保留為實驗/研究項目記錄。

## 仍待實機驗證（與本計畫無關但未結）
iPad 說明手冊空白頁修正、iPad 錄音後播放（`.defaultToSpeaker`）、Files App 開啟資料夾、裝置自檢報告、differential-audit Mac 端。

## 注意（踩過的坑）
- 重建後先 `xcrun simctl terminate <udid> com.kairumo.padnote` 再 `launch`，否則測到舊版。
- Kotlin KDoc 裡別寫 `/*`（會巢狀註解）。
- 推送前跑 fmt → clippy `--workspace --all-targets` → test `--workspace`，且要在最後一次編輯之後。
