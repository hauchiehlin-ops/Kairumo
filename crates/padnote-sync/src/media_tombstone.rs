//! 媒體檔的刪除墓碑 —— **刪掉的錄音不可以復活**。
//!
//! # 為什麼需要它
//!
//! [`crate::library`] 開頭那段話對筆記本成立，對媒體檔卻一直沒做到：
//!
//! > 刪除必須是**明確的事件**，不能從「檔案不見了」推論。
//!
//! 錄音的下載條件原本是「遠端有、本機沒有（或比較短）就抓回來」。使用者
//! 刪掉一段錄音之後本機長度是 0，於是下一輪同步**把它抓了回來** ——
//! 刪除永遠刪不掉，每同步一次就復活一次。使用者回報的「一直無法處於
//! 真正同步狀態」，這是其中一個具體成因。
//!
//! # 為什麼不需要跟檔案比版本
//!
//! 錄音是 uuid 命名的，一個名字這輩子只對應一份內容 —— 刪掉之後不會有人
//! 用同一個 uuid 再錄一段。所以墓碑只要記住「這個名字已經死了」就夠，
//! 不必像文件操作那樣比 Lamport 誰新。
//!
//! Lamport 與裝置 id 還是要記：兩台同時對同一個名字做事時要有全序，
//! 而且日後要查「是誰、在哪一步刪的」時，沒記就永遠查不到。
//!
//! # 每台只寫自己那一份
//!
//! 檔案是 `media/tombstones/<device>.json`，沿用 oplog 的不變式 ——
//! 每台裝置只寫自己 `device_id` 的檔案 ⇒ 沒有跨裝置寫入競爭 ⇒ 雲端硬碟
//! 不會判定為修改衝突。合併就是聯集。

use std::collections::BTreeMap;

use serde::{Deserialize, Serialize};

/// 一筆刪除事件。
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MediaTombstone {
    /// 邏輯時戳。
    pub lamport: u64,
    /// 是誰刪的。
    pub device: String,
}

/// 一本筆記本裡被刪掉的媒體檔。
#[derive(Clone, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MediaTombstones {
    /// **正規化後的**檔名 → 刪除事件。
    ///
    /// 用正規化的名字當鍵：Apple 的 APFS 不分大小寫、Android 分，
    /// 不統一的話同一段錄音在兩台上的鍵不一樣，墓碑就漏接了。
    #[serde(default)]
    pub deleted: BTreeMap<String, MediaTombstone>,
}

impl MediaTombstones {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn from_json(text: &str) -> Self {
        serde_json::from_str(text).unwrap_or_default()
    }

    pub fn to_json(&self) -> String {
        serde_json::to_string(self).unwrap_or_else(|_| "{}".to_string())
    }

    /// 記下一筆刪除。
    pub fn mark(&mut self, name: &str, lamport: u64, device: &str) {
        let key = crate::paths::canonical_name(name);
        let entry = MediaTombstone {
            lamport,
            device: device.to_string(),
        };
        match self.deleted.get(&key) {
            // 已經有一筆了：留時戳較大的，平手比裝置 id。
            // 結果與套用順序無關 —— 兩台裝置合併出來的答案要一樣。
            Some(existing)
                if (existing.lamport, existing.device.as_str())
                    >= (entry.lamport, entry.device.as_str()) => {}
            _ => {
                self.deleted.insert(key, entry);
            }
        }
    }

    /// 這個檔名被刪掉了嗎。
    pub fn contains(&self, name: &str) -> bool {
        self.deleted
            .contains_key(&crate::paths::canonical_name(name))
    }

    /// 合併另一份墓碑（聯集）。
    pub fn merge(&mut self, other: &MediaTombstones) {
        for (name, entry) in &other.deleted {
            self.mark(name, entry.lamport, &entry.device);
        }
    }

    pub fn is_empty(&self) -> bool {
        self.deleted.is_empty()
    }

    pub fn len(&self) -> usize {
        self.deleted.len()
    }
}

/// 一本筆記本底下放墓碑的目錄前綴。
pub fn tombstones_prefix(notebook_id: &str) -> String {
    format!(
        "{}/media/tombstones",
        crate::paths::notebook_root(notebook_id)
    )
}

/// 某台裝置那一份墓碑的完整雲端路徑。
pub fn tombstone_file(notebook_id: &str, device: &str) -> String {
    format!(
        "{}/{}.json",
        tombstones_prefix(notebook_id),
        crate::paths::canonical_name(device)
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_marked_name_is_remembered() {
        let mut t = MediaTombstones::new();
        t.mark("abc.opus", 1, "dev-a");
        assert!(t.contains("abc.opus"));
        assert!(!t.contains("other.opus"));
    }

    /// Apple 不分大小寫、Android 分。不統一的話同一段錄音在兩台上的鍵
    /// 不一樣，墓碑就漏接了 —— 而症狀是「只有其中一台刪得掉」。
    #[test]
    fn names_are_matched_case_insensitively() {
        let mut t = MediaTombstones::new();
        t.mark("ABC-123.OPUS", 1, "dev-a");
        assert!(t.contains("abc-123.opus"));
    }

    #[test]
    fn merging_is_a_union() {
        let mut a = MediaTombstones::new();
        a.mark("one.opus", 1, "dev-a");
        let mut b = MediaTombstones::new();
        b.mark("two.opus", 2, "dev-b");

        a.merge(&b);
        assert!(a.contains("one.opus"));
        assert!(a.contains("two.opus"));
        assert_eq!(a.len(), 2);
    }

    /// 合併的結果不可以跟順序有關 —— 兩台裝置各自合併要得到同一份答案。
    #[test]
    fn merging_is_order_independent() {
        let mut a = MediaTombstones::new();
        a.mark("x.opus", 5, "dev-a");
        let mut b = MediaTombstones::new();
        b.mark("x.opus", 9, "dev-b");

        let mut ab = a.clone();
        ab.merge(&b);
        let mut ba = b.clone();
        ba.merge(&a);

        assert_eq!(ab, ba);
        assert_eq!(ab.deleted["x.opus"].lamport, 9);
    }

    #[test]
    fn a_later_deletion_wins() {
        let mut t = MediaTombstones::new();
        t.mark("x.opus", 1, "dev-a");
        t.mark("x.opus", 7, "dev-b");
        assert_eq!(t.deleted["x.opus"].lamport, 7);
        assert_eq!(t.deleted["x.opus"].device, "dev-b");
    }

    #[test]
    fn json_round_trips() {
        let mut t = MediaTombstones::new();
        t.mark("a.opus", 3, "dev-a");
        t.mark("b.opus", 4, "dev-b");
        assert_eq!(MediaTombstones::from_json(&t.to_json()), t);
    }

    #[test]
    fn broken_json_is_an_empty_set_not_a_panic() {
        assert!(MediaTombstones::from_json("這不是 JSON").is_empty());
    }

    /// 每台只寫自己那一份 —— 路徑要帶得出裝置 id，而且是正規化的。
    #[test]
    fn each_device_writes_its_own_file() {
        assert_eq!(
            tombstone_file("nb1", "Dev-A"),
            "notebooks/nb1/media/tombstones/dev-a.json"
        );
        assert!(tombstone_file("nb1", "dev-b").starts_with(&tombstones_prefix("nb1")));
    }
}
