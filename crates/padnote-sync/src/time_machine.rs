//! 時光機與貢獻者高亮 (Time Machine & Contributor Highlight) - Phase 4 (進階 3)
//!
//! # 不破壞性設計
//! 這個模組提供「唯讀」的視角，不會去修改 `padnote-doc` 內任何既有的 `App` 或 `NotebookSession` 狀態。
//! 它透過篩選特定 Lamport 以前的 Oplog 來重播，從而建構出「過去某個時間點」的筆記本狀態。

use std::collections::HashMap;

#[derive(Debug)]
pub struct TimeMachine {
    // 預留：持有該筆記本的所有 Oplog 歷史
}

impl TimeMachine {
    pub fn new() -> Self {
        Self {}
    }

    /// 根據目標的 Lamport 時戳，重播並回傳該時間點的「唯讀」文件狀態
    ///
    /// 在 UI 上可以實作一個時間軸拉桿，每次拖動就呼叫此方法，
    /// 瞬間呈現過去的筆記本樣貌。
    pub fn replay_to_lamport(
        &self,
        _notebook_id: &str,
        _target_lamport: u64,
    ) -> Result<(), String> {
        // TODO: 載入所有的 oplog
        // TODO: 過濾出 lamport <= target_lamport 的操作
        // TODO: 將過濾後的操作丟給一個全新的、獨立的 NotebookSession 進行 Apply
        // TODO: 回傳重播完成的狀態供 UI 唯讀渲染
        Ok(())
    }

    /// 查詢特定文字區塊中，某段文字的「貢獻者 (Device ID)」
    ///
    /// 因為 TextCrdt 底層使用了 `OpId { seq, site }`，
    /// 我們可以直接將 `site` 對應到某個人的 `device_id`。
    /// UI 可據此為不同人寫的字塗上不同顏色的螢光高亮。
    pub fn get_text_contributors(&self, _block_id: &str) -> HashMap<usize, u32> {
        // TODO: 讀取該 block_id 的 TextCrdt
        // TODO: 遍歷可見字元，解析其 OpId 的 site 屬性
        // TODO: 回傳 index -> device_id 的映射，讓 Swift / Kotlin 能畫出高亮
        HashMap::new()
    }
}
