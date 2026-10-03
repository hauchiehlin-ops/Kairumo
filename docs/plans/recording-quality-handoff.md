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

## 待辦（依序）
1. **i18n**：在 `i18n/ui-strings.json` 新增三個 key（`recording_advice_quiet`／`_clipping`／`_noisy`），
   六語（zh-Hant、en、zh-Hans、ja、ko、th）；再跑 `python3 scripts/i18n_tool.py generate` 與 `verify`。
   建議文案：太小聲→「聲音偏小，請把裝置靠近講者」；削波→「聲音過大破音，請拉遠一些或調低增益」；
   雜訊→「背景雜訊偏高，請靠近講者或關掉冷氣／風扇」。
2. **重建綁定與原生庫**：`./scripts/generate-bindings.sh`、`./scripts/build-xcframework.sh`（約 2 分鐘）、
   `./scripts/build-android-libs.sh debug`（約 5 分鐘），用 `nm` 確認 `recording_quality` 符號。
3. **UI 顯示建議**：停止錄音後若 `adviceKey` 非空，顯示一次性提示。
   Apple：`stopAndSaveRecording` 與首頁快速錄音停止處；Android：MainActivity.kt 的停止路徑。
   補 UI 測試／`objectProbe`，六語檢查。
4. **事後轉錄前處理**：`ffi_asr.rs::whisper_transcribe_pcm` 對 PCM 先套 `high_pass_80hz`；
   再用 VAD 切段後才送 Whisper（抑制幻聽／重複迴圈）。Whisper 模型本機不可測，需補以假引擎驗證的單元測試。
5. **Apple 擷取**：不要預設開 Bluetooth HFP 輸入（`CoreAudioCapture.swift` ~171、`AudioRecorderManager.swift` ~200/458）。
6. **階段 2**：Apple 心形指向資料源 + 「收音模式」按鈕；Android 有支援時啟用 `NoiseSuppressor`；核心加慢速 AGC。
7. **階段 3**：RNNoise／DeepFilterNet 僅作為「重新轉錄」的選用分支（降噪常傷害 ASR，不可預設開）。
   開啟前**必須**用 `padnote-bench` CER 工具在真實教室／會議室做 A/B。
8. **階段 4**：去殘響、波束成形（研究項）。

## 仍待實機驗證（與本計畫無關但未結）
iPad 說明手冊空白頁修正、iPad 錄音後播放（`.defaultToSpeaker`）、Files App 開啟資料夾、裝置自檢報告、differential-audit Mac 端。

## 注意（踩過的坑）
- 重建後先 `xcrun simctl terminate <udid> com.kairumo.padnote` 再 `launch`，否則測到舊版。
- Kotlin KDoc 裡別寫 `/*`（會巢狀註解）。
- 推送前跑 fmt → clippy `--workspace --all-targets` → test `--workspace`，且要在最後一次編輯之後。
