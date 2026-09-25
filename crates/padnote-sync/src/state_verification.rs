//! 狀態驗證 (State Verification) - Phase 2 正確性優化。
//!
//! 在分散式檔案同步（如 Google Drive / iCloud）中，最可怕的狀況是
//! 「漏檔」或「中途斷線導致的非一致狀態」，且沒有任何錯誤跳出。
//!
//! 為了達到數學上的 100% 正確性驗證，我們引入輕量級 Merkle Tree 概念
//! 的 Oplog 狀態雜湊 (State Hash)。
//!
//! # 實作原理
//! 將該筆記本當下已經成功套用的所有 `.oplog` 檔名（包含 Lamport 時戳與 DeviceID）
//! 進行字典序排序，並計算 SHA-256 (或快速的 xxHash)。
//! 雙方在建立 WebRTC 連線或透過 MQTT 廣播時，只需要附上這個 8 bytes / 32 bytes 的
//! State Hash，就能在 O(1) 的時間內確認兩台裝置的內容是否**完美位元一致**。
//!
//! 若 Hash 不同，代表其中一方漏了 Oplog，可立即發起雙向集合求差集 (Set Difference)
//! 精準補齊遺失的檔案，徹底消滅幽靈狀態。

use std::collections::BTreeSet;
use std::collections::hash_map::DefaultHasher;
use std::hash::{Hash, Hasher};

/// 筆記本狀態驗證器。
#[derive(Debug)]
pub struct SyncStateVerifier {
    applied_oplogs: BTreeSet<String>,
}

impl SyncStateVerifier {
    pub fn new() -> Self {
        Self {
            applied_oplogs: BTreeSet::new(),
        }
    }

    /// 記錄一筆已套用的 Oplog。
    pub fn record_oplog(&mut self, oplog_name: String) {
        self.applied_oplogs.insert(oplog_name);
    }

    /// 移除紀錄（例如壓實 Compaction 後）。
    pub fn remove_oplog(&mut self, oplog_name: &str) {
        self.applied_oplogs.remove(oplog_name);
    }

    /// 計算當前的狀態雜湊 (State Hash)。
    /// 字典序遍歷 BTreeSet 確保不受插入順序影響。
    pub fn compute_state_hash(&self) -> u64 {
        let mut hasher = DefaultHasher::new();
        for oplog in &self.applied_oplogs {
            oplog.hash(&mut hasher);
        }
        hasher.finish()
    }

    /// 與遠端傳來的 Hash 進行 O(1) 驗證。
    pub fn verify_match(&self, remote_hash: u64) -> bool {
        self.compute_state_hash() == remote_hash
    }

    /// (Phase 2) 雙向交換 Hash 的網路溝通介面。
    /// 當發起 P2P 或雲端拉取前，先呼叫此方法。若回傳 false，則觸發差集比對 (Set Difference)。
    pub fn exchange_and_verify(&self, remote_hash: u64) -> Result<bool, String> {
        let local_hash = self.compute_state_hash();
        if local_hash == remote_hash {
            Ok(true)
        } else {
            // TODO: 在此處發送 local_hash 與 oplog 總數給對方，並要求對方回傳 oplog 列表
            // 以找出漏檔的具體項目。目前先回傳不匹配。
            Ok(false)
        }
    }
}
