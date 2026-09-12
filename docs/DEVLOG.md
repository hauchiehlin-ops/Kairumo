# 開發日誌

> 反序排列（最新在上）。每個開發階段結束時追加一筆。
> 記錄**為什麼**這樣做，而不只是做了什麼 —— 「做了什麼」看 git log 就好。

---

## 2026-09-12 · M0 工程地基

### 做了什麼
- `docs/format-spec.md` v0.1 定稿
- Rust workspace 11 crates，55 測試通過、clippy 零警告
- CI：三平台 fmt/clippy/test + cargo-deny + 格式相容性
- S3 同步收斂驗證 **Go**；S4 授權稽核完成
- S1（Swift 墨跡 spike）與 S2（CER 評測工具）程式就緒，待硬體與資料

### 為什麼這樣做

**先做 format-spec 而非先寫 UI。**
統一時間軸是 C1/C4/A10/B6 四個功能的共同地基，事後更動等於重寫文件層。
在還沒有任何程式依賴它之前定稿，成本最低。

**S3 排在 S1 之前完成。**
風險登記簿上 S3 是唯一標「影響極高」的項目 —— 它決定整個「用雲端硬碟同步」
的架構是否成立。而且它純軟體、當場可驗證，不像 S1 要等硬體。先殲滅可驗證的最大風險。

**筆畫不進 CRDT（ADR-0002）。**
一筆畫數百個點，全進 CRDT 會讓 op 爆炸。改用 append-only + 墓碑 —— 新增與刪除
天生可交換冪等，這正是收斂所需的全部性質，不需要完整 CRDT 的機制。

**刻意先不引入外部相依。**
M0 全程零 crates.io 相依，確保任何環境都能 build。等真正需要（serde/sha2）
才引入，且每個都要過 `deny.toml` 白名單。

### 踩到的坑
- 自訂 `Display` 用 `f.write_str` 會忽略 `{:<12}` 寬度 → 必須用 `f.pad()`
- doc comment 裡放真實 Tab 會觸發 clippy 警告
- `cargo` workspace 成員缺 `src/lib.rs` 會讓整個 workspace 無法載入

### 下一步
依「先把功能全部建起來、之後再 debug」的方針，推進 storage / doc / search /
asr 編排 / export 等純邏輯層。需要實機的一律記進 `TODO.md`。
