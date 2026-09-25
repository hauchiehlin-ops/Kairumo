//! Oplog 壓實與狀態快照 (Phase 3 效能優化)。
//!
//! 當筆記本累積了上千個 `.oplog` 檔案時，初次載入或新設備同步
//! 會遇到嚴重的 I/O 與網路瓶頸。此模組負責背景壓實 (Compaction)。
//! 
//! # 實作原理
//! 1. 掃描 `doc/ops/` 收集所有 `.oplog`。
//! 2. 如果數量超過 `COMPACTION_THRESHOLD` (例如 500)，則觸發壓實。
//! 3. 將所有 `DocOp` 解碼後交由 CRDT 引擎計算出一個「當前最終狀態」。
//! 4. 將該最終狀態打包為單一的基準快照檔（Snapshot），並清理舊的 `.oplog` 碎片。

use std::path::Path;

pub const COMPACTION_THRESHOLD: usize = 500;

/// 壓實引擎
pub struct OplogCompactor {
    // 預留：將相依 padnote-doc 的解碼與合併邏輯
}

impl OplogCompactor {
    pub fn new() -> Self {
        Self {}
    }

    /// 評估是否需要對指定的筆記本執行壓實。
    pub fn should_compact(&self, oplog_count: usize) -> bool {
        oplog_count > COMPACTION_THRESHOLD
    }

    /// 執行壓實作業。
    /// 回傳新生成的基準檔案名稱。
    pub fn compact_notebook(&self, notebook_id: &str, _oplog_paths: &[impl AsRef<Path>]) -> Result<String, String> {
        // TODO: 讀取並反序列化所有的 oplog 檔案。
        // TODO: 交由 padnote-doc 進行 CRDT Squash（去除無用的墓碑、被刪除的文字節點）。
        // TODO: 將 Squash 後的結果寫入為一個 `<lamport>-<device>.snapshot` 或整合型 .oplog。
        // TODO: 回報可以安全刪除的舊 Oplog 列表供上層執行清理。
        
        Ok(format!("compacted_{}.snapshot", notebook_id))
    }
}
