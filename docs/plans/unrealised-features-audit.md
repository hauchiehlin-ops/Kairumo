# 虛位盤點：設計裡有、實際上沒有落實的項目

> 2026-09-21。方法：把核心 338 個 `#[uniffi::export]` 的函式與方法，
> 逐一到 `apple/Sources`、`apple/Examples` 與 `android/.../com/kairumo` 找呼叫端，
> 再對可疑的項目逐一讀程式碼確認。腳本見本文末。
>
> **這份是盤點，不是修正計畫。** 每一項都標了證據位置，可以自己驗。

---

## A. 介面宣稱有、實際是空殼（最該先處理）

### A1. Android 的語音轉錄是假的

`android/.../audio/AudioTranscriber.kt` 的 `transcribe()` **沒有做任何語音辨識**。
它組一段標頭（標題、長度、日期）再把**檔名**當成內容回傳：

```
🎙️ <title>
⏱️ 03:21 · 2026-09-20 21:23
─────────────────
📝 [Audio Transcript]
<檔名（不含副檔名）>
```

而呼叫端成功後顯示 `transcribe_success`（「轉錄成功」）。整個檔案 56 行。

對照 Apple：551 行，真的走核心的 `whisper_transcribe_pcm`，模型不在時
**降級到 Apple Speech 系統聽寫**，而且會標明用了哪個引擎。

核心的 `whisper_transcribe_pcm` / `whisper_is_model_available` **只有 Apple 呼叫**。

> 這是整份盤點裡最嚴重的一項：它不是「還沒做」，是**做了一個會回報成功的假東西**。
> 使用者會以為轉錄壞掉（內容莫名其妙），而不是以為這個功能還沒有。

### A2. 模型下載繞過了核心，缺了 D4 要求的驗證與續傳

> **更正**：初版盤點寫成「兩個平台都沒有任何下載入口」，那是錯的 ——
> Apple 有（`AudioTranscriber.downloadWhisperModel`）。錯在只比對了核心的
> FFI 呼叫端，而 Apple 那條路根本沒有經過核心。這正是「只有一邊走核心」
> 那一類問題最容易騙過盤點的地方。

決策 D4 是「模型按需下載，HF / GitHub Releases + SHA-256 + 續傳」，
`crates/padnote-models` 有完整的 `catalog.rs` / `download.rs` / `provenance.rs`
（驗證、續傳、大小比對、失敗刪檔、磁碟用量、移除）。**零呼叫端。**

Apple 實際走的是 `AudioTranscriber` 裡自己寫的一段 `URLSession.downloadTask`：

- **沒有 SHA-256 驗證**（整個檔案 grep 不到任何雜湊計算）
- **沒有續傳**（沒有 Range、沒有 resumeData）
- 網址寫死在 Swift 裡，與 `models/manifest.json` 各存一份

實際後果：574 MB 在行動網路上斷一次就從頭來（這次盤點時我自己下載這個模型，
就在 63 MB 處逾時斷掉）；而沒有驗證代表傳輸損毀或被替換不會被發現，
使用者只會覺得「轉錄出來的東西很奇怪」。

Android 則兩者都沒有（見 A1）。

### A2-bis. 模型清單本身有四筆是假的

順著 A2 逐一實際請求 `models/manifest.json` 裡的六個網址：

| 模型 | 實測 | 清單宣告的大小 | 實際 |
|---|---|---|---|
| silero-vad-v4 | ✅ 200 | 1807522 | 1807522（且雜湊早已驗過） |
| whisper-large-v3-turbo-q5 | ✅ 200 | 574041600 | **574041195** |
| paraformer-zh | ❌ **404** | 230686720 | — |
| ct-punct-zh | ❌ **401** | 293601280 | — |
| ppocr-v5 | ❌ **401**（網址是 `huggingface.co/example/rapidocr/…`，`example` 是佔位字串） | 16777216（＝ 16 MiB 整） | — |
| qwen3-4b-instruct-q4 | ❌ **401** | 2621440000 | — |

那些大小全是整數（16 MiB、2621440000…）—— 是**估的，不是量的**。
這正是 `STATE.md` 常犯錯誤清單裡「相信 manifest 裡沒下載驗證過的 URL」那一條。

### A3. 套件加密完全沒有出口

`padnote-crypto` 有完整的信封加密（Argon2id + XChaCha20-Poly1305 + BIP39 復原碼，
`docs/TODO.md` 的 S-07 標成已完成），`manifest.json` 也有 `encryption` 欄位。

但是：

- `Manifest::new()` 一律寫 `Encryption::None`，**沒有任何程式碼會把它改成加密**。
- `padnote_crypto` 的 envelope API **沒有任何 `#[uniffi::export]`**，
  平台層根本呼叫不到。
- 唯一用到 `Dek` 的是 `SyncEngine`，而 `SyncEngine` 本身沒有任何正式呼叫端
  （只有測試用），正式的 Drive 同步走的是另一條路。

而身分頁上有一列寫著「資料加密 / 端對端本地隔離」（`encryption` / `encryption_desc`）。
那行字描述的是「資料留在本機」，但鍵名與標題是「加密」——**很容易被讀成內容有加密**。
要嘛把加密接上，要嘛把那行字改成不會被誤讀的說法。

---

## B. 核心做好了、兩個平台都沒接

這一類的共同特徵是：邏輯下沉到核心是為了跨平台一致，結果沒有人用它 ——
於是「一致」只存在於核心的測試裡。

| 項目 | 核心位置 | 狀況 |
|---|---|---|
| **壓感曲線** | `ffi_input`：`set_pressure_curve` / `width_scale` / `opacity_scale` / `is_deep_press` / `FfiPressureAction` | 零呼叫端。Apple 另外在 `InkInterop.swift` **寫死一條**曲線（`0.35 + 0.65 × pressure`）。所以「壓感影響線寬還是濃度」這個設計沒有任何效果，而且曲線有兩份 |
| **觸控筆懸停** | `ffi_input`：`is_pen_hovering` / `hover_position` / `is_pen_down` | 零呼叫端 |
| **版面尺寸級別** | `ffi_layout`：`layout_columns` / `layout_gutter` / `layout_size_class` / `sidebar_width_bounds` | 零呼叫端。模組註解自己就寫著「尺寸級別本身兩邊都沒有」 |
| **PDF 座標互通** | `ffi_interop`：`page_point_to_pdf` / `pdf_point_to_page` / `highlight_quad_points` | 零呼叫端 |
| **匯入** | `ffi.rs`：`import_json` / `import_markdown` / `import_embedded`、`supported_import_formats` | 零呼叫端 |
| **物件旋轉縮放** | `ffi.rs`：`rotate_object` / `scale_object` / `create_stroke_object` / `stroke_detail` | 零呼叫端（兩邊各自在平台層做） |
| **轉錄進度與 VAD** | `ffi.rs`：`add_transcript` / `transcription_backlog_us` / `set_vad_model` / `uses_neural_vad` | 零呼叫端。「轉錄落後 N 秒」這個設計沒有畫面在用 |
| **session 加密** | `ffi.rs`：`session_key_generate` / `session_seal` / `session_open` | 只有 Android 的**診斷自我測試**在用。真正的協同走 `collab_encrypt` / `collab_decrypt`（兩邊都用）—— 同一件事有兩份實作，而「正式」那份沒在用 |

### B-bis. 這次同步大修留下的死碼（我自己造成的）

- `gdrive_sync_notebook` / `gdrive_sync_media` / `gdrive_sync_metadata` /
  `gdrive_clone_notebook`：P1 之後平台層全部改走 `FfiSyncSession`，
  這四個自由函式**已經沒有呼叫端**（我當時留成 legacy wrapper）。
- `FfiSyncSession.diagnose`：改用免權杖的自由函式 `sync_diagnose` 之後沒人用。
- `FfiSyncScheduler.has_pending`、`sync_debounce_ms`：沒有呼叫端。
- `sync_settings_path` / `sync_index_path` / `sync_plan_is_empty`：一直都沒有呼叫端。

> 這幾項該刪。留著死碼的代價不是磁碟空間，是**下一個人會以為它是活的**，
> 然後照著它推論行為。

---

## C. 只有一邊走核心，另一邊自己寫一份

這一類**不是缺功能**，是同一個行為有兩份實作。兩份現在可能一樣，
但沒有任何東西擋著它們分岔 —— 而分岔的症狀永遠是「同一份筆記在兩台裝置上不一樣」。

| 行為 | Apple | Android |
|---|---|---|
| 文字編輯、表格儲存格 | Swift 自己做 | 走核心 `insert_text` / `delete_text` / `set_table_cell` / `insert_table_row` … |
| 套索（複製／刪除／貼上／位移） | `LassoSelection.swift` | 走核心 `lasso_copy` / `lasso_delete` / `lasso_paste` / `lasso_translate` |
| 縮放與平移夾制 | Swift 自己算 | 走核心 `clamp_zoom` / `max_pan_offset` |
| 掌拒門檻 | 沒有設定（用預設） | 走核心 `set_palm_thresholds` |
| 頁面搬移／跨本轉移的運算 | 走核心 `page_index_after_*` / `page_transfer_plan` / `page_move_is_valid` | Kotlin 自己算 |
| 幾何吸附、可列印範圍 | 走核心 `snap_object` / `is_outside_printable` | Kotlin 的 `PageGeometry` |
| PDF 匯出 | 走核心 `export_pdf` | 走核心 `export_page_pdf_with_layout` —— **兩支不同的函式** |
| 語系清單 | 走核心 `supported_locales` / `set_locale` | 自己的 `LocalizationStrings.kt` |
| 能力回報 | 走核心 `report_capability` / `feature_status` | 沒有 |
| 3D 模型型別 | 沒有走核心 | 走核心 `model3d_kinds` / `model3d_faces` |
| 全文搜尋 | 記憶體附件逐項比對（標題、文字方塊、表格、形狀標籤、手寫辨識） | 走核心 bigram 索引（**另外還涵蓋轉錄文字、PDF、OCR**） |

搜尋那一列值得單獨說：Apple 端的做法在程式碼裡有明確的理由（內容就在記憶體裡），
**但涵蓋範圍不同** —— Apple 搜不到錄音轉錄的文字與 PDF 內容。這不是實作細節差異，
是使用者搜得到／搜不到的差異。

---

## D. 刻意的平台差異（不是虛位，列出來以免被誤判）

- **Android 的 AI 摘要回報「沒有可用的模型」**：`NoteIntelligence.kt` 的註解
  把兩條路的代價寫得很清楚（Gemini Nano 是實驗版且要帶進 Guava；
  llama.cpp 要使用者下載 2.4 GB）。它**誠實地回報沒有**，畫面也照著顯示 ——
  與 A1 的「回報成功的假東西」是相反的做法。
- **`ffi_screens`（畫面對照表）看起來零呼叫端**，實際上由 CI 的
  `scripts/check-screen-parity.py` 透過 `screen-spec` 執行檔使用，目前 0 缺口。

---

## 建議的優先序

1. **A1**（Android 假轉錄）—— 會回報成功的假功能比缺功能更傷。
   最小修法：接上核心的 whisper（與 Apple 同一條），模型不在時**明講沒有**，
   不要產生假文字。
2. **A2**（模型下載）—— A1 的正解依賴它；而且 D4 是已拍板的決策。
3. **A3**（加密）—— 不接就改文案。兩者擇一，現況是最糟的組合。
4. **B-bis**（刪死碼）—— 十分鐘的事，而且是我這次留下的。
5. **C 的搜尋那一列** —— 使用者可見的差異。
6. B 的其餘與 C 的其餘 —— 逐項判斷「下沉」還是「明確標成平台差異」，
   不要留在中間狀態。

---

## 附：盤點方法

```bash
# 列出核心所有 FFI 匯出，分成「兩邊都沒呼叫 / 只有 Apple / 只有 Android」
python3 scripts/audit-ffi-coverage.py
```

呼叫端比對是**字面比對 camelCase 名稱**，所以：
- 同名的平台自有函式會造成偽陰性（已逐項讀程式碼排除）；
- 透過反射或字串組出來的呼叫會被漏掉（本專案沒有這種用法）。
