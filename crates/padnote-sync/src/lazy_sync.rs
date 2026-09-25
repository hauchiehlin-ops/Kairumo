//! 懶載入與分頁優先同步 (Lazy Loading Sync) - Phase 4 (進階 4)
//!
//! # 不破壞性設計
//! 傳統同步是「拿到所有 Oplog 才允許渲染」。
//! 這裡實作一個優先權佇列 (Priority Queue)，允許 UI 宣告「我現在正在看第 50 頁」，
//! 網路層就會在與對方 P2P / Cloud 同步時，優先索取影響第 50 頁的 Oplog 或 Snapshot。

use std::collections::HashSet;

pub struct LazySyncManager {
    /// 記錄使用者目前正在觀看或編輯的頁面 UUID
    active_pages: HashSet<String>,
}

impl LazySyncManager {
    pub fn new() -> Self {
        Self {
            active_pages: HashSet::new(),
        }
    }
    
    /// 由 UI 層呼叫，宣告使用者翻到了哪些頁面
    pub fn focus_pages(&mut self, page_ids: Vec<String>) {
        self.active_pages.clear();
        for id in page_ids {
            self.active_pages.insert(id);
        }
        // TODO: 觸發 WebRTC 或 Cloud 拉取任務的優先權重排
        // 優先抓取與 active_pages 相關的 Oplog 檔案
    }
    
    /// 取得當前的優先同步名單
    pub fn get_priorities(&self) -> Vec<String> {
        self.active_pages.iter().cloned().collect()
    }
}
