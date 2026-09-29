//! 雲端內容的本機快照（P1：用 change token 取代全量列舉）。
//!
//! # 為什麼需要它
//!
//! 舊的流程是「每同步一本筆記本就打一次 `files.list`」。50 本筆記 =
//! 50 次往返，**而且不管有沒有變動都要付這個代價**。使用者要求的
//! 「沒變動的就不要花時間去動它」在那個結構下做不到：要知道有沒有變動，
//! 就得先去問，而問本身就是主要成本。
//!
//! Drive 早就備好了正確的工具：`changes.list` + `startPageToken`。
//! 一次請求回「自上次游標之後的所有變動」，沒有變動就回空清單。
//! Joplin、rclone 的 Drive 後端、Obsidian Sync 全部走這條路 ——
//! 沒有人每次去列整棵樹。
//!
//! 於是流程變成：
//!
//! 1. 一次 `changes.list` → 更新這份本機快照
//! 2. **同步計畫完全在本機算**（零 HTTP）
//! 3. 只碰真的有差異的檔案
//!
//! # 名稱的正規化與相容性
//!
//! 索引的鍵是 [`crate::paths::canonical_name`] 之後的路徑（全小寫 ASCII），
//! 但 `name` 欄位保留**雲端上的原始名字**。舊版可能上傳過含大寫的檔名，
//! 存取時要用原始名字，比對時則用正規化後的鍵 —— 兩者分開，才不會為了
//! 統一大小寫而把整個雲端重傳一次。
//!
//! # 這份快照可以壞，但壞了不會錯
//!
//! 游標失效（Drive 回 410）或索引損毀時，退回一次全量列舉重建即可。
//! 那是唯一的慢路徑，而且是自我修復的。

use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

/// 雲端上的一個檔案。
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RemoteFile {
    /// Drive 的 file id。**帶著它，上傳就不必再查一次**
    /// —— 舊流程每次 `put` 之前都要 `files.list` 找 id，那是一次白白的往返。
    pub id: String,
    /// 雲端上的原始名字（可能含大寫，見模組說明）。
    pub name: String,
    pub size: u64,
    /// Drive 的 `modifiedTime`（Unix 秒）。`0` = 不知道。
    ///
    /// 只給「孤兒檔案要放多久才算過期」用（`docs/plans/expiry-purge.md`）。
    /// **不參與 [`RemoteIndex::apply`] 的「有沒有改變」判斷** —— 自己剛上傳的檔案，
    /// 回音事件帶著修改時間、`note_upload` 當初卻不知道，若把它算進相等比較，
    /// 焦點通道會把每一次自己的推送都誤判成「對方動了」。
    #[serde(default)]
    pub modified: u64,
}

/// 雲端內容的本機快照。
#[derive(Clone, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RemoteIndex {
    /// Drive 的變更游標。空字串表示「還沒建立基準」，需要一次全量列舉。
    #[serde(default)]
    pub page_token: String,
    /// 正規化路徑 → 檔案。
    #[serde(default)]
    pub files: BTreeMap<String, RemoteFile>,
}

impl RemoteIndex {
    pub fn from_json(json: &str) -> Self {
        serde_json::from_str(json).unwrap_or_default()
    }

    pub fn to_json(&self) -> String {
        serde_json::to_string(self).unwrap_or_else(|_| "{}".to_string())
    }

    /// 還沒有基準 ⇒ 需要一次全量列舉。
    pub fn needs_rebuild(&self) -> bool {
        self.page_token.is_empty()
    }

    /// 套用一筆變更。`gone` 為 true 表示被刪除或丟進垃圾桶。
    ///
    /// 垃圾桶要當成刪除：Drive 預設查得到垃圾桶裡的檔案，不濾掉的話
    /// 已經刪掉的內容會被當成還在，然後重新拉回來。
    ///
    /// 回傳**快照有沒有真的改變**。自己剛上傳的檔案，`changes.list` 之後也會
    /// 回報它 —— 但 `note_upload` 早就把同樣的 id 與大小記進去了，套用之後
    /// 什麼都沒變。焦點通道靠這個區分「對方動了」與「只是我自己的回音」，
    /// 否則每次推送之後的下一次輪詢都會被誤判成雲端有新東西。
    pub fn apply(
        &mut self,
        id: &str,
        name: Option<&str>,
        size: u64,
        modified: u64,
        gone: bool,
    ) -> bool {
        match (name, gone) {
            (_, true) => {
                // 刪除只給得到 fileId，名字要從既有快照反查。
                let key = name
                    .map(crate::paths::canonical_path)
                    .or_else(|| self.key_of_id(id));
                key.is_some_and(|key| self.files.remove(&key).is_some())
            }
            (Some(name), false) => {
                let key = crate::paths::canonical_path(name);
                let file = RemoteFile {
                    id: id.to_string(),
                    name: name.to_string(),
                    size,
                    modified,
                };
                // 「有沒有改變」只看 id、名字、大小；修改時間照樣更新，但不算改變。
                let changed = self.files.get(&key).is_none_or(|old| {
                    old.id != file.id || old.name != file.name || old.size != file.size
                });
                self.files.insert(key, file);
                changed
            }
            // 沒有名字又沒說被刪：這筆變更沒有可用的資訊。
            (None, false) => false,
        }
    }

    fn key_of_id(&self, id: &str) -> Option<String> {
        self.files
            .iter()
            .find(|(_, f)| f.id == id)
            .map(|(k, _)| k.clone())
    }

    /// 全量重建時用：整份換掉，但保留游標。
    pub fn replace_files(&mut self, files: Vec<RemoteFile>) {
        self.files = files
            .into_iter()
            .map(|f| (crate::paths::canonical_path(&f.name), f))
            .collect();
    }

    /// 某個路徑的檔案。傳進來的路徑會先正規化。
    pub fn get(&self, path: &str) -> Option<&RemoteFile> {
        self.files.get(&crate::paths::canonical_path(path))
    }

    /// 某個前綴底下的檔案：`(檔名, 檔案)`，檔名是**最後一段**。
    ///
    /// 回傳的是正規化後的短檔名，因為同步比對的單位是套件裡的檔名。
    pub fn entries_under(&self, prefix: &str) -> BTreeMap<String, RemoteFile> {
        let prefix = crate::paths::canonical_path(prefix);
        let with_slash = format!("{prefix}/");
        self.files
            .iter()
            .filter(|(key, _)| key.starts_with(&with_slash))
            .filter_map(|(key, file)| {
                let rest = &key[with_slash.len()..];
                // 只要直接子項。前綴底下再開一層目錄不是這個佈局會出現的情況，
                // 但真的出現時不該把它混進來比對。
                if rest.contains('/') {
                    return None;
                }
                Some((rest.to_string(), file.clone()))
            })
            .collect()
    }

    /// 本機剛寫上去的檔案，直接記進快照。
    ///
    /// 不記的話，同一輪裡後續的判斷會以為雲端還沒有這個檔，於是重傳一次。
    pub fn note_upload(&mut self, path: &str, id: &str, size: u64) {
        let key = crate::paths::canonical_path(path);
        let name = self
            .files
            .get(&key)
            .map(|f| f.name.clone())
            .unwrap_or_else(|| key.clone());
        self.files.insert(
            key,
            RemoteFile {
                id: id.to_string(),
                name,
                size,
                // 剛自己傳上去的：不知道 Drive 記的時間，等下一次變更回音再補。
                modified: 0,
            },
        );
    }

    pub fn note_delete(&mut self, path: &str) {
        self.files.remove(&crate::paths::canonical_path(path));
    }

    pub fn len(&self) -> usize {
        self.files.len()
    }

    pub fn is_empty(&self) -> bool {
        self.files.is_empty()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn f(id: &str, name: &str, size: u64) -> RemoteFile {
        RemoteFile {
            id: id.into(),
            name: name.into(),
            size,
            modified: 0,
        }
    }

    #[test]
    fn a_fresh_index_asks_for_a_rebuild() {
        assert!(RemoteIndex::default().needs_rebuild());
    }

    #[test]
    fn entries_under_returns_only_direct_children() {
        let mut idx = RemoteIndex::default();
        idx.replace_files(vec![
            f("1", "notebooks/nb1/doc/ops/a.oplog", 10),
            f("2", "notebooks/nb1/doc/ops/b.oplog", 20),
            f("3", "notebooks/nb2/doc/ops/c.oplog", 30),
            f("4", "notebooks/nb1/media/audio/x.opus", 40),
        ]);
        let under = idx.entries_under("notebooks/nb1/doc/ops");
        assert_eq!(under.len(), 2);
        assert_eq!(under["a.oplog"].size, 10);
        assert!(under.contains_key("b.oplog"));
    }

    #[test]
    fn a_name_that_differs_only_in_case_is_the_same_entry() {
        // 這是真的爆過的 bug。索引層要把它收斂掉，否則上層永遠看到兩份。
        let mut idx = RemoteIndex::default();
        idx.apply("1", Some("notebooks/NB1/media/audio/A1.opus"), 10, 0, false);
        idx.apply("2", Some("notebooks/nb1/media/audio/a1.opus"), 20, 0, false);
        assert_eq!(idx.len(), 1, "大小寫不同不該變成兩個項目");
        assert_eq!(
            idx.get("notebooks/nb1/media/audio/a1.opus").unwrap().size,
            20
        );
    }

    #[test]
    fn the_original_cloud_name_is_preserved_for_access() {
        // 比對用正規化後的鍵，存取要用雲端上的原始名字 ——
        // 不然為了統一大小寫就得把整個雲端重傳一次。
        let mut idx = RemoteIndex::default();
        idx.apply("1", Some("notebooks/NB1/doc/ops/AA.oplog"), 10, 0, false);
        assert_eq!(
            idx.get("notebooks/nb1/doc/ops/aa.oplog").unwrap().name,
            "notebooks/NB1/doc/ops/AA.oplog"
        );
    }

    #[test]
    fn a_removal_without_a_name_still_finds_the_entry_by_id() {
        // Drive 的刪除變更只給 fileId，沒有名字。反查不到就會留下幽靈項目，
        // 而幽靈項目會讓同步以為雲端還有那個檔。
        let mut idx = RemoteIndex::default();
        idx.apply("id-7", Some("notebooks/nb1/doc/ops/a.oplog"), 10, 0, false);
        idx.apply("id-7", None, 0, 0, true);
        assert!(idx.is_empty(), "刪除沒有生效");
    }

    #[test]
    fn trashed_counts_as_gone() {
        let mut idx = RemoteIndex::default();
        idx.apply("id-7", Some("notebooks/nb1/doc/ops/a.oplog"), 10, 0, false);
        idx.apply("id-7", Some("notebooks/nb1/doc/ops/a.oplog"), 10, 0, true);
        assert!(idx.is_empty());
    }

    #[test]
    fn survives_a_json_round_trip() {
        let mut idx = RemoteIndex {
            page_token: "tok-1".into(),
            ..Default::default()
        };
        idx.apply("1", Some("notebooks/nb1/doc/ops/a.oplog"), 10, 0, false);
        let back = RemoteIndex::from_json(&idx.to_json());
        assert_eq!(back, idx);
    }

    #[test]
    fn broken_json_falls_back_to_a_rebuild_instead_of_failing() {
        // 壞掉的快照不該讓使用者整個同步不了 —— 重建一次就好。
        let idx = RemoteIndex::from_json("{{{ not json");
        assert!(idx.needs_rebuild());
    }

    #[test]
    fn noting_an_upload_makes_the_same_round_skip_it() {
        let mut idx = RemoteIndex::default();
        idx.note_upload("notebooks/nb1/doc/ops/a.oplog", "id-1", 99);
        assert_eq!(idx.get("notebooks/nb1/doc/ops/a.oplog").unwrap().size, 99);
    }

    #[test]
    fn applying_the_echo_of_our_own_upload_changes_nothing() {
        let mut idx = RemoteIndex::default();
        idx.note_upload("notebooks/nb1/doc/ops/a.oplog", "id-1", 10);
        // Drive 之後把同一個檔案當成變動回報。
        assert!(!idx.apply("id-1", Some("notebooks/nb1/doc/ops/a.oplog"), 10, 0, false));
        // 對方把它變長了：這才是真的變動。
        assert!(idx.apply("id-1", Some("notebooks/nb1/doc/ops/a.oplog"), 25, 0, false));
        // 刪除一個不存在的東西不算變動。
        assert!(!idx.apply("id-9", None, 0, 0, true));
        assert!(idx.apply("id-1", None, 0, 0, true));
    }

    #[test]
    fn the_modified_time_is_recorded_but_is_not_a_change() {
        // 自己剛上傳的檔案，回音事件帶著修改時間；`note_upload` 當初不知道。
        // 那不能被算成「對方動了」，否則焦點通道每次自己的推送都會誤判。
        let mut idx = RemoteIndex::default();
        idx.note_upload("notebooks/nb1/doc/ops/a.oplog", "id-1", 10);
        let changed = idx.apply(
            "id-1",
            Some("notebooks/nb1/doc/ops/a.oplog"),
            10,
            1_800_000_000,
            false,
        );
        assert!(!changed, "只多了修改時間，不是對方的變動");
        assert_eq!(
            idx.get("notebooks/nb1/doc/ops/a.oplog").unwrap().modified,
            1_800_000_000,
            "修改時間仍然要記下來"
        );
        // 大小變了才是真的改變。
        assert!(idx.apply(
            "id-1",
            Some("notebooks/nb1/doc/ops/a.oplog"),
            11,
            1_800_000_100,
            false
        ));
    }

    #[test]
    fn an_old_snapshot_without_modified_times_still_loads() {
        let json = r#"{"pageToken":"1","files":{"a":{"id":"1","name":"a","size":3}}}"#;
        let idx = RemoteIndex::from_json(json);
        assert_eq!(idx.get("a").unwrap().modified, 0);
    }
}
