//! 雲端檔案的歸屬稽核 —— **這個檔案是誰的？**
//!
//! # 為什麼需要它
//!
//! 索引那一層（[`crate::library`]）已經收斂得很好：每個項目帶 Lamport
//! 時戳與裝置 id，刪除是明確的墓碑事件，平手時墓碑優先。筆記本的
//! 新增／改名／刪除在任何時序下都會收斂到同一個結果。
//!
//! **但檔案那一層沒有人管。** 雲端上是一堆扁平的名字
//! （`notebooks/<id>/doc/ops/<device>.bin`、`.../media/blobs/<hash>`），
//! 而沒有任何東西在問「這個檔案屬於誰、還需不需要」。後果：
//!
//! * 刪掉一本筆記，索引收斂了，**它的檔案永遠留在雲端**。
//! * 某台裝置傳到一半就再也沒開過，殘骸留在那裡。
//! * 使用者看到的是「追蹤 11823 個檔案」，而其中有多少是活的，
//!   **沒有人答得出來**。
//!
//! # 分類與各自該怎麼處理
//!
//! 關鍵是分清楚「已知該刪」與「我還不知道」—— 這兩件事在雲端上長得
//! 一模一樣（索引裡都沒有這個 id），但處理方式相反：
//!
//! | 類別 | 意思 | 動作 |
//! |------|------|------|
//! | [`FileClass::Live`] | 屬於一本活著的筆記本 | 留著 |
//! | [`FileClass::Deleted`] | 屬於一本**有墓碑**的筆記本 | 可以回收 |
//! | [`FileClass::Unknown`] | 路徑長得對，但索引裡沒有這個 id | **只回報，絕不刪** |
//! | [`FileClass::Foreign`] | 不符合任何已知形狀 | 只回報 |
//! | [`FileClass::Index`] | 索引本身 | 留著 |
//!
//! `Unknown` 那一條是整件事的安全底線。另一台裝置剛建好一本筆記、檔案
//! 已經上傳、而索引的更新這台還沒拉到 —— 那時候它的檔案就是 `Unknown`。
//! **把 `Unknown` 當垃圾刪掉，等於把別台裝置剛寫的東西吃掉**，而且症狀
//! 會是「新建的筆記本過一會兒就不見了」，幾乎不可能查。
//!
//! 所以只有**明確的墓碑**才授權刪除。這和 [`crate::library`] 拒絕從
//! 「檔案不見了」推論刪除是同一條原則，只是方向相反。

use std::collections::{BTreeMap, BTreeSet};

use crate::library::{INDEX_PATH, LibraryIndex};

/// 一個雲端檔案的歸屬。
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub enum FileClass {
    /// 索引本身。
    Index,
    /// 屬於一本活著的筆記本。
    Live,
    /// 屬於一本已經有墓碑的筆記本 —— 可以回收。
    Deleted,
    /// 路徑形狀對，但索引裡沒有這個 id。**可能只是還沒同步到**。
    Unknown,
    /// 不符合任何已知形狀。別人放進來的，或是舊版留下的。
    Foreign,
}

/// 稽核結果。
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct CloudAudit {
    /// 每一類各有幾個檔案。
    pub counts: BTreeMap<String, u32>,
    /// 可以回收的檔案路徑（[`FileClass::Deleted`]）。
    pub collectable: Vec<String>,
    /// 索引裡沒有、但雲端上有檔案的筆記本 id。
    ///
    /// **這不是「垃圾」** —— 多半是另一台裝置剛建立、索引還沒拉到。
    /// 值得讓使用者看見，不該自動刪。
    pub unknown_notebooks: BTreeSet<String>,
    /// 不符合任何已知形狀的路徑。
    pub foreign: Vec<String>,
}

impl CloudAudit {
    pub fn count(&self, class: FileClass) -> u32 {
        self.counts.get(class_name(class)).copied().unwrap_or(0)
    }
}

fn class_name(class: FileClass) -> &'static str {
    match class {
        FileClass::Index => "index",
        FileClass::Live => "live",
        FileClass::Deleted => "deleted",
        FileClass::Unknown => "unknown",
        FileClass::Foreign => "foreign",
    }
}

/// 從雲端路徑反解出筆記本 id。
///
/// 路徑的形狀是 `notebooks/<id>/…`。只有 `notebooks/` 底下**而且**還有
/// 下一層的才算 —— `notebooks/index.json` 是索引，不是某本筆記的檔案。
fn notebook_id_of(path: &str) -> Option<&str> {
    let rest = path.strip_prefix("notebooks/")?;
    let (id, tail) = rest.split_once('/')?;
    if id.is_empty() || tail.is_empty() {
        return None;
    }
    Some(id)
}

/// 判斷單一路徑的歸屬。
pub fn classify(path: &str, index: &LibraryIndex) -> FileClass {
    if path == INDEX_PATH {
        return FileClass::Index;
    }
    let Some(id) = notebook_id_of(path) else {
        return FileClass::Foreign;
    };
    // 索引裡的 id 可能含大寫（舊資料），雲端路徑一律是正規化後的 ——
    // 兩邊都過一次 `canonical_id` 才比得對。不這樣做的話，一本大寫 id
    // 的筆記本會被判成 Unknown，而它明明活得好好的。
    match lookup(index, id) {
        Some(true) => FileClass::Live,
        Some(false) => FileClass::Deleted,
        None => FileClass::Unknown,
    }
}

/// `Some(true)` = 活著，`Some(false)` = 有墓碑，`None` = 索引裡沒有。
fn lookup(index: &LibraryIndex, canonical: &str) -> Option<bool> {
    for item in index.items.values() {
        if crate::paths::canonical_id(&item.id) == canonical {
            return Some(!item.deleted);
        }
    }
    None
}

/// 稽核整個雲端檔案清單。
///
/// `paths` 是雲端上所有物件的路徑（[`crate::remote_index::RemoteIndex`]
/// 的鍵）。這是**純計算，一次 HTTP 都不打**。
pub fn audit<'a>(paths: impl IntoIterator<Item = &'a str>, index: &LibraryIndex) -> CloudAudit {
    let mut out = CloudAudit::default();
    for path in paths {
        let class = classify(path, index);
        *out.counts.entry(class_name(class).to_string()).or_insert(0) += 1;
        match class {
            FileClass::Deleted => out.collectable.push(path.to_string()),
            FileClass::Unknown => {
                if let Some(id) = notebook_id_of(path) {
                    out.unknown_notebooks.insert(id.to_string());
                }
            }
            FileClass::Foreign => out.foreign.push(path.to_string()),
            FileClass::Index | FileClass::Live => {}
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::library::{ItemKind, LibraryItem};

    fn item(id: &str, deleted: bool) -> LibraryItem {
        LibraryItem {
            id: id.to_string(),
            kind: ItemKind::Notebook,
            title: id.to_string(),
            parent_id: None,
            lamport: 1,
            device: "dev-a".to_string(),
            deleted,
        }
    }

    fn index_with(items: &[LibraryItem]) -> LibraryIndex {
        let mut index = LibraryIndex::default();
        for it in items {
            index.upsert(it.clone());
        }
        index
    }

    #[test]
    fn files_of_a_live_notebook_are_live() {
        let index = index_with(&[item("nb1", false)]);
        assert_eq!(
            classify("notebooks/nb1/doc/ops/dev-a.bin", &index),
            FileClass::Live
        );
        assert_eq!(
            classify("notebooks/nb1/media/blobs/abc123", &index),
            FileClass::Live
        );
    }

    #[test]
    fn the_index_itself_is_not_a_notebook_file() {
        let index = index_with(&[]);
        assert_eq!(classify(INDEX_PATH, &index), FileClass::Index);
    }

    #[test]
    fn files_of_a_tombstoned_notebook_are_collectable() {
        let index = index_with(&[item("nb1", true)]);
        let result = audit(
            [
                "notebooks/nb1/doc/ops/dev-a.bin",
                "notebooks/nb1/media/blobs/x",
            ],
            &index,
        );
        assert_eq!(result.count(FileClass::Deleted), 2);
        assert_eq!(result.collectable.len(), 2);
    }

    /// **整件事的安全底線。**
    ///
    /// 另一台裝置剛建好一本筆記、檔案已經上傳，而索引的更新這台還沒拉到。
    /// 那時候它的檔案在這台眼裡就是 Unknown —— 當垃圾刪掉的話，等於把
    /// 別台剛寫的東西吃掉，症狀是「新建的筆記本過一會兒就不見了」。
    #[test]
    fn a_notebook_this_device_has_not_seen_yet_is_never_collectable() {
        let index = index_with(&[item("nb1", false)]);
        let result = audit(["notebooks/nb-from-other-device/doc/ops/dev-b.bin"], &index);

        assert_eq!(result.count(FileClass::Unknown), 1);
        assert!(
            result.collectable.is_empty(),
            "沒見過的筆記本不可以出現在回收清單裡：{:?}",
            result.collectable
        );
        assert!(result.unknown_notebooks.contains("nb-from-other-device"));
    }

    /// 舊資料的 id 可能含大寫，而雲端路徑一律正規化過。
    /// 不兩邊都正規化的話，一本活著的筆記本會被判成 Unknown。
    #[test]
    fn an_uppercase_id_still_matches_its_canonical_path() {
        let index = index_with(&[item("696F43C5", false)]);
        assert_eq!(
            classify("notebooks/696f43c5/doc/ops/dev-a.bin", &index),
            FileClass::Live
        );
    }

    #[test]
    fn anything_that_is_not_a_notebook_path_is_foreign() {
        let index = index_with(&[]);
        let result = audit(
            ["some-other-app.dat", "notebooks/", "notebooks/nb1"],
            &index,
        );
        assert_eq!(result.count(FileClass::Foreign), 3);
        assert_eq!(result.foreign.len(), 3);
    }

    #[test]
    fn counts_cover_every_file() {
        let index = index_with(&[item("live", false), item("gone", true)]);
        let paths = [
            INDEX_PATH,
            "notebooks/live/doc/ops/a.bin",
            "notebooks/gone/doc/ops/a.bin",
            "notebooks/mystery/doc/ops/a.bin",
            "junk",
        ];
        let result = audit(paths, &index);
        let total: u32 = result.counts.values().sum();
        assert_eq!(total, paths.len() as u32, "每個檔案都要被分到某一類");
        assert_eq!(result.count(FileClass::Live), 1);
        assert_eq!(result.count(FileClass::Deleted), 1);
        assert_eq!(result.count(FileClass::Unknown), 1);
        assert_eq!(result.count(FileClass::Foreign), 1);
        assert_eq!(result.count(FileClass::Index), 1);
    }
}
