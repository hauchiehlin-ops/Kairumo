//! 筆記本與資料夾樹的跨裝置收斂（G-05，ADR-0011）。
//!
//! # 為什麼不能靠「比對檔案清單」
//!
//! 最直覺的做法是兩邊各列一次 `notebooks/`，有的補、沒的刪。那會壞在刪除上：
//! A 刪掉一本筆記、B 還沒同步過來，B 看到「雲端沒有、我有」就會**把它傳回去**
//! —— 刪除永遠刪不掉，而且每同步一次就復活一次。
//!
//! 所以刪除必須是**明確的事件**（tombstone），不能從「檔案不見了」推論。
//! 改名與搬移同理：從清單差異看，「改名」與「刪掉舊的＋新增一個」長得一樣。
//!
//! # 收斂規則
//!
//! 每個項目帶一個 Lamport 時戳與寫入裝置 id，合併時逐項取較新的；
//! 平手比裝置 id，讓結果是全序、與套用順序無關。
//! **墓碑在同一個時戳上優先於存在**：兩台裝置同時「一邊改名、一邊刪除」時，
//! 收斂到刪除 —— 反過來的話，使用者刪掉的東西會因為另一台的無關修改而復活。

use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

/// 雲端上放索引的路徑（`format-spec.md` §7.0）。
pub const INDEX_PATH: &str = "notebooks/index.json";

/// 一個項目是筆記本還是資料夾。
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum ItemKind {
    Notebook,
    Folder,
}

/// 樹上的一個項目。
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct LibraryItem {
    pub id: String,
    pub kind: ItemKind,
    pub title: String,
    /// 上層資料夾 id。`None` 表示在根目錄。
    pub parent_id: Option<String>,
    /// 這一筆的邏輯時戳。
    pub lamport: u64,
    /// 寫入者，供時戳平手時決勝。
    pub device: String,
    /// 已刪除。**刪除是一個欄位，不是「不在清單裡」**，見模組說明。
    #[serde(default)]
    pub deleted: bool,
}

impl LibraryItem {
    fn wins_over(&self, other: &LibraryItem) -> bool {
        match self.lamport.cmp(&other.lamport) {
            std::cmp::Ordering::Greater => true,
            std::cmp::Ordering::Less => false,
            // 同一個時戳：先看刪除。使用者刪掉的東西不該因為另一台裝置的
            // 無關修改而復活。
            std::cmp::Ordering::Equal => match (self.deleted, other.deleted) {
                (true, false) => true,
                (false, true) => false,
                _ => self.device > other.device,
            },
        }
    }
}

/// 筆記本與資料夾的索引。
#[derive(Clone, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct LibraryIndex {
    /// id → 項目。用 `BTreeMap` 讓序列化結果有穩定順序 ——
    /// 順序不穩的話，同一份內容每次上傳的位元組都不同，
    /// 看起來像「一直有東西在改」。
    pub items: BTreeMap<String, LibraryItem>,
}

impl LibraryIndex {
    pub fn upsert(&mut self, mut item: LibraryItem) {
        item.id = item.id.to_lowercase();
        if let Some(ref mut parent) = item.parent_id {
            *parent = parent.to_lowercase();
        }
        match self.items.get(&item.id) {
            Some(existing) if existing.wins_over(&item) => {}
            _ => {
                self.items.insert(item.id.clone(), item);
            }
        }
    }

    /// 標記刪除。**留下墓碑而不是移除**，理由見模組說明。
    pub fn tombstone(&mut self, id: &str, lamport: u64, device: &str) {
        let norm_id = id.to_lowercase();
        let base = self.items.get(&norm_id).cloned();
        let item = LibraryItem {
            id: norm_id,
            kind: base.as_ref().map_or(ItemKind::Notebook, |i| i.kind),
            title: base.as_ref().map_or(String::new(), |i| i.title.clone()),
            parent_id: base.and_then(|i| i.parent_id),
            lamport,
            device: device.to_string(),
            deleted: true,
        };
        self.upsert(item);
    }

    /// 合併另一台裝置的索引。可交換、冪等。
    pub fn merge(&mut self, other: &LibraryIndex) {
        for item in other.items.values() {
            self.upsert(item.clone());
        }
    }

    /// 還活著的項目。
    pub fn live(&self) -> Vec<&LibraryItem> {
        self.items.values().filter(|i| !i.deleted).collect()
    }

    /// 所有還看得見的**筆記本**，不分層級。
    ///
    /// 同步要用的是這個而不是 [`live`]：判斷「雲端有、本機還沒有」時需要一份
    /// 攤平的清單，而 `children_of` 一次只給一層。
    ///
    /// 已刪除資料夾底下的筆記本**不算**——它們在畫面上已經消失了，
    /// 再把內容抓下來只是白佔空間，而且使用者永遠看不到那份下載。
    pub fn live_notebooks(&self) -> Vec<&LibraryItem> {
        let mut out: Vec<&LibraryItem> = self
            .items
            .values()
            .filter(|i| !i.deleted && i.kind == ItemKind::Notebook)
            .filter(|i| !self.has_deleted_ancestor(i))
            .collect();
        out.sort_by(|a, b| a.id.cmp(&b.id));
        out
    }

    /// 某個資料夾底下還活著的項目。
    ///
    /// 排序是**碼位順序**，不是語系排序規則。這裡要的是「同一份資料在任何
    /// 裝置上都得到同一個順序」，那是同步的正確性問題；中文該照筆畫還是
    /// 注音排，是顯示問題，由平台層自己用系統的排序規則處理。
    /// 在核心做語系排序反而會讓兩台語系不同的裝置算出不同的位元組。
    ///
    /// **父項已刪除的孤兒不會出現在任何地方。** 所以這裡額外檢查祖先鏈：
    /// 資料夾被刪掉之後，裡面的筆記本要一起消失，否則它們會變成
    /// 「存在但打不開、也刪不掉」的幽靈。
    pub fn children_of(&self, parent: Option<&str>) -> Vec<&LibraryItem> {
        let norm_parent = parent.map(str::to_lowercase);
        let mut out: Vec<&LibraryItem> = self
            .items
            .values()
            .filter(|i| !i.deleted)
            .filter(|i| i.parent_id.as_deref() == norm_parent.as_deref())
            .filter(|i| !self.has_deleted_ancestor(i))
            .collect();
        out.sort_by(|a, b| a.title.cmp(&b.title).then(a.id.cmp(&b.id)));
        out
    }

    /// 這個項目該不該因為刪除而**從畫面上消失**。
    ///
    /// # 與 [`children_of`] 的規則不一樣，而且必須不一樣
    ///
    /// `children_of` 是在畫一棵樹，所以「父項沒看過」要當成不可見 ——
    /// 否則會掛出一個沒有上層的孤兒。
    ///
    /// 這裡問的是另一件事：**本機有一個檔案，該不該把它藏起來。**
    /// 「索引裡沒看過」不是「被刪了」：剛從另一台同步過來、或是索引還沒
    /// 收斂完的項目都會落在這個狀態。把它當成刪除的話，使用者會看到
    /// 自己的筆記本莫名其妙消失 —— 那比多顯示一個幽靈嚴重得多。
    ///
    /// 所以只有**明確的墓碑**才算：自己被刪，或祖先鏈上任何一層被刪。
    pub fn is_hidden_by_deletion(&self, id: &str) -> bool {
        let norm_id = id.to_lowercase();
        let Some(item) = self.items.get(&norm_id) else {
            // 沒看過。那是「還不知道」，不是「被刪了」。
            return false;
        };
        if item.deleted {
            return true;
        }
        let mut seen = vec![norm_id.clone()];
        let mut cursor = item.parent_id.clone();
        while let Some(parent_id) = cursor {
            // 迴圈保護：兩台裝置各自把 A 搬進 B、把 B 搬進 A 就會接成環，
            // 沒有這道保護的話這裡會無限迴圈 —— App 直接凍住。
            if seen.contains(&parent_id) {
                return false;
            }
            seen.push(parent_id.clone());
            match self.items.get(&parent_id) {
                Some(parent) if parent.deleted => return true,
                Some(parent) => cursor = parent.parent_id.clone(),
                // 父項沒看過：同上，不當成刪除。
                None => return false,
            }
        }
        false
    }

    /// 祖先鏈上有沒有已刪除（或根本不存在）的資料夾。
    fn has_deleted_ancestor(&self, item: &LibraryItem) -> bool {
        let mut seen = Vec::new();
        let mut cursor = item.parent_id.clone();
        while let Some(id) = cursor {
            // 迴圈保護：兩台裝置各自把 A 搬進 B、把 B 搬進 A，就會接成一個環。
            // 沒有這道保護的話，這裡會無限迴圈 —— App 直接凍住。
            if seen.contains(&id) {
                return true;
            }
            seen.push(id.clone());
            match self.items.get(&id) {
                Some(parent) if parent.deleted => return true,
                Some(parent) => cursor = parent.parent_id.clone(),
                // 父項在這台裝置上根本沒看過：當成不可見，
                // 免得在樹上掛出一個沒有上層的項目。
                None => return true,
            }
        }
        false
    }

    /// 搬移之後會不會形成環。
    ///
    /// UI 要在**動手之前**問這個：把一個資料夾搬進自己的子孫裡，
    /// 那棵子樹就會從樹上整個斷開，而且刪不掉也救不回來。
    pub fn would_create_cycle(&self, item_id: &str, new_parent: Option<&str>) -> bool {
        let norm_item = item_id.to_lowercase();
        let mut cursor = new_parent.map(|p| p.to_lowercase());
        let mut seen = Vec::new();
        while let Some(id) = cursor {
            if id == norm_item {
                return true;
            }
            if seen.contains(&id) {
                return true;
            }
            seen.push(id.clone());
            cursor = self.items.get(&id).and_then(|i| i.parent_id.clone());
        }
        false
    }

    pub fn to_json(&self) -> String {
        serde_json::to_string_pretty(self).unwrap_or_else(|_| "{}".into())
    }

    /// 將索引中的所有項目以小寫 ID 正規化，並自動合併因平台大小寫差異產生的重複條目
    pub fn canonicalize(&mut self) {
        let old = std::mem::take(&mut self.items);
        for (_, item) in old {
            self.upsert(item);
        }
    }

    /// 壞掉的 JSON 回空索引而不是錯誤 —— 雲端上一份壞檔案不該讓使用者
    /// 整個筆記庫打不開；本機還有自己的那一份。
    pub fn from_json(text: &str) -> Self {
        let mut idx: Self = serde_json::from_str(text).unwrap_or_default();
        idx.canonicalize();
        idx
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn item(
        id: &str,
        title: &str,
        parent: Option<&str>,
        lamport: u64,
        device: &str,
    ) -> LibraryItem {
        LibraryItem {
            id: id.into(),
            kind: ItemKind::Notebook,
            title: title.into(),
            parent_id: parent.map(str::to_string),
            lamport,
            device: device.into(),
            deleted: false,
        }
    }

    fn folder(
        id: &str,
        title: &str,
        parent: Option<&str>,
        lamport: u64,
        device: &str,
    ) -> LibraryItem {
        LibraryItem {
            kind: ItemKind::Folder,
            ..item(id, title, parent, lamport, device)
        }
    }

    #[test]
    fn an_incoming_deletion_hides_the_local_file() {
        // 這是「在 A 刪掉、B 上還在」那個 bug 的回歸測試。
        let mut index = LibraryIndex::default();
        index.upsert(item("n1", "會議", None, 1, "dev-a"));
        assert!(!index.is_hidden_by_deletion("n1"));

        index.tombstone("n1", 2, "dev-b");
        assert!(index.is_hidden_by_deletion("n1"));
    }

    #[test]
    fn deleting_a_folder_hides_the_notebooks_inside_it() {
        let mut index = LibraryIndex::default();
        index.upsert(folder("f1", "工作", None, 1, "dev-a"));
        index.upsert(item("n1", "會議", Some("f1"), 2, "dev-a"));
        index.tombstone("f1", 3, "dev-b");

        assert!(
            index.is_hidden_by_deletion("n1"),
            "刪掉資料夾，裡面的要一起消失"
        );
    }

    #[test]
    fn something_the_index_has_never_seen_is_not_hidden() {
        // **這一條比上面兩條更重要。** 「沒看過」不是「被刪了」——
        // 混在一起的話，剛建好還沒同步、或索引還沒收斂完的筆記本
        // 會在使用者眼前消失，那比多顯示一個幽靈嚴重得多。
        let mut index = LibraryIndex::default();
        index.upsert(item("n1", "會議", None, 1, "dev-a"));

        assert!(!index.is_hidden_by_deletion("完全沒看過的 id"));

        // 父項沒看過也一樣不藏。
        index.upsert(item("n2", "孤兒", Some("不存在的資料夾"), 2, "dev-a"));
        assert!(!index.is_hidden_by_deletion("n2"));
    }

    #[test]
    fn a_parent_cycle_does_not_hang_the_visibility_check() {
        // 兩台裝置各自把 A 搬進 B、把 B 搬進 A 就會接成環。
        let mut index = LibraryIndex::default();
        index.upsert(folder("f1", "A", Some("f2"), 1, "dev-a"));
        index.upsert(folder("f2", "B", Some("f1"), 1, "dev-b"));
        index.upsert(item("n1", "裡面的", Some("f1"), 2, "dev-a"));

        assert!(!index.is_hidden_by_deletion("n1"));
    }

    #[test]
    fn live_notebooks_is_flat_and_skips_folders() {
        // 同步靠這份清單決定「要抓哪幾本下來」。漏掉巢狀的那幾本，
        // 症狀是「有些筆記本同步得過來、有些永遠不來」。
        let mut index = LibraryIndex::default();
        index.upsert(folder("f1", "工作", None, 1, "dev-a"));
        index.upsert(item("n1", "根目錄的", None, 2, "dev-a"));
        index.upsert(item("n2", "資料夾裡的", Some("f1"), 3, "dev-a"));

        let ids: Vec<&str> = index
            .live_notebooks()
            .iter()
            .map(|i| i.id.as_str())
            .collect();
        assert_eq!(ids, vec!["n1", "n2"], "資料夾不算，巢狀的不能漏");
    }

    #[test]
    fn a_notebook_in_a_deleted_folder_is_not_worth_downloading() {
        // 它在畫面上已經看不到了。還把內容抓下來只是白佔空間，
        // 而且使用者永遠看不到那份下載。
        let mut index = LibraryIndex::default();
        index.upsert(folder("f1", "工作", None, 1, "dev-a"));
        index.upsert(item("n1", "會議", Some("f1"), 2, "dev-a"));
        index.tombstone("f1", 3, "dev-b");

        assert!(index.live_notebooks().is_empty());
    }

    #[test]
    fn a_new_device_pulls_everything() {
        let mut cloud = LibraryIndex::default();
        cloud.upsert(folder("f1", "工作", None, 1, "dev-a"));
        cloud.upsert(item("n1", "會議", Some("f1"), 2, "dev-a"));

        let mut fresh = LibraryIndex::default();
        fresh.merge(&cloud);
        assert_eq!(fresh.live().len(), 2);
        assert_eq!(fresh.children_of(Some("f1")).len(), 1);
    }

    #[test]
    fn a_deleted_notebook_does_not_come_back() {
        // 這是整個模組存在的理由。靠「比對清單」的話，還沒同步到刪除的
        // 那一台會把筆記本傳回去 —— 刪除永遠刪不掉，每同步一次復活一次。
        let mut a = LibraryIndex::default();
        a.upsert(item("n1", "會議", None, 1, "dev-a"));
        let mut b = a.clone();

        a.tombstone("n1", 5, "dev-a");
        // B 還不知道，手上仍是活的那一份。
        b.merge(&a);
        assert!(b.live().is_empty(), "刪除被 B 復活了");

        // 再把 B 的合併回 A 也不會復活。
        a.merge(&b);
        assert!(a.live().is_empty());
    }

    #[test]
    fn rename_and_move_both_converge() {
        // 從清單差異看，「改名」與「刪掉舊的＋新增一個」長得一樣。
        let mut a = LibraryIndex::default();
        a.upsert(folder("f1", "工作", None, 1, "dev-a"));
        a.upsert(item("n1", "會議", None, 1, "dev-a"));
        let mut b = a.clone();

        // A 改名
        a.upsert(item("n1", "週會", None, 4, "dev-a"));
        // B 搬進資料夾（比較晚）
        b.upsert(item("n1", "會議", Some("f1"), 6, "dev-b"));

        let mut ab = a.clone();
        ab.merge(&b);
        let mut ba = b.clone();
        ba.merge(&a);
        assert_eq!(ab, ba, "兩邊要收斂到同一個結果");
        // 較新的那一筆整筆勝出（逐筆而非逐欄位）。
        assert_eq!(ab.items["n1"].parent_id.as_deref(), Some("f1"));
    }

    #[test]
    fn merge_is_commutative_and_idempotent() {
        let mut a = LibraryIndex::default();
        a.upsert(item("n1", "A 的", None, 3, "dev-a"));
        a.upsert(item("n2", "只有 A", None, 1, "dev-a"));
        let mut b = LibraryIndex::default();
        b.upsert(item("n1", "B 的", None, 4, "dev-b"));
        b.tombstone("n3", 2, "dev-b");

        let mut ab = a.clone();
        ab.merge(&b);
        let mut ba = b.clone();
        ba.merge(&a);
        assert_eq!(ab, ba);

        let mut twice = ab.clone();
        twice.merge(&a);
        twice.merge(&b);
        assert_eq!(ab, twice);
    }

    #[test]
    fn delete_beats_edit_on_a_tie() {
        // 同一個時戳上「一邊改名、一邊刪除」要收斂到刪除 ——
        // 反過來的話，使用者刪掉的東西會因為另一台的無關修改而復活。
        let mut a = LibraryIndex::default();
        a.upsert(item("n1", "原本", None, 1, "dev-a"));
        let mut b = a.clone();

        a.upsert(item("n1", "改過的", None, 7, "dev-a"));
        b.tombstone("n1", 7, "dev-b");

        let mut ab = a.clone();
        ab.merge(&b);
        let mut ba = b.clone();
        ba.merge(&a);
        assert!(ab.items["n1"].deleted);
        assert_eq!(ab, ba);
    }

    #[test]
    fn deleting_a_folder_hides_what_is_inside_it() {
        // 不處理的話，資料夾裡的筆記本會變成「存在但打不開、也刪不掉」的幽靈。
        let mut idx = LibraryIndex::default();
        idx.upsert(folder("f1", "工作", None, 1, "dev-a"));
        idx.upsert(item("n1", "會議", Some("f1"), 1, "dev-a"));
        idx.tombstone("f1", 5, "dev-a");
        assert!(idx.children_of(Some("f1")).is_empty());
        assert!(idx.children_of(None).is_empty());
    }

    #[test]
    fn an_item_under_an_unknown_parent_is_not_shown_at_the_root() {
        // 父項還沒同步過來時，不要把它掛在根目錄 —— 使用者會看到一個
        // 突然出現在外面的筆記本，然後同步完又跳回資料夾裡。
        let mut idx = LibraryIndex::default();
        idx.upsert(item("n1", "會議", Some("f-unknown"), 1, "dev-a"));
        assert!(idx.children_of(None).is_empty());
    }

    #[test]
    fn a_parent_cycle_does_not_hang() {
        // 兩台裝置各自把 A 搬進 B、把 B 搬進 A，合併之後就接成一個環。
        // 沒有迴圈保護的話這裡會無限迴圈 —— App 直接凍住。
        let mut idx = LibraryIndex::default();
        idx.upsert(folder("f1", "一", Some("f2"), 3, "dev-a"));
        idx.upsert(folder("f2", "二", Some("f1"), 4, "dev-b"));
        assert!(idx.children_of(None).is_empty());
        assert!(idx.children_of(Some("f1")).is_empty());
    }

    #[test]
    fn moving_a_folder_into_its_own_subtree_is_rejected_up_front() {
        let mut idx = LibraryIndex::default();
        idx.upsert(folder("f1", "上", None, 1, "dev-a"));
        idx.upsert(folder("f2", "下", Some("f1"), 1, "dev-a"));
        assert!(idx.would_create_cycle("f1", Some("f2")));
        assert!(idx.would_create_cycle("f1", Some("f1")));
        assert!(!idx.would_create_cycle("f2", None));
    }

    #[test]
    fn listing_order_is_stable() {
        // 順序不穩的話，同一份內容每次上傳的位元組都不同，
        // 看起來像「一直有東西在改」。
        let mut idx = LibraryIndex::default();
        idx.upsert(item("n2", "乙", None, 1, "dev-a"));
        idx.upsert(item("n1", "甲", None, 1, "dev-a"));
        let first = idx.to_json();
        let second = LibraryIndex::from_json(&first).to_json();
        assert_eq!(first, second);
        // 碼位順序（乙 U+4E59 在 甲 U+7532 之前），不是中文的排序習慣 ——
        // 這裡要的是「任何裝置都得到同一個順序」，顯示順序由平台層決定。
        let titles: Vec<_> = idx
            .children_of(None)
            .iter()
            .map(|i| i.title.clone())
            .collect();
        assert_eq!(titles, vec!["乙", "甲"]);
        // 同一份資料算兩次要完全一樣。
        let again: Vec<_> = idx
            .children_of(None)
            .iter()
            .map(|i| i.title.clone())
            .collect();
        assert_eq!(titles, again);
    }

    #[test]
    fn broken_json_falls_back_to_an_empty_index() {
        assert_eq!(LibraryIndex::from_json("{{{"), LibraryIndex::default());
    }

    #[test]
    fn offline_edits_on_two_devices_converge() {
        // G-05 的判定條件：離線兩台各自新增／改名／移動／刪除，
        // 重新上線後要收斂，而且不復活刪除項。
        let mut base = LibraryIndex::default();
        base.upsert(folder("f1", "工作", None, 1, "seed"));
        base.upsert(item("n1", "會議", Some("f1"), 1, "seed"));
        base.upsert(item("n2", "雜記", None, 1, "seed"));

        let mut a = base.clone();
        a.upsert(item("n3", "A 新增", None, 10, "dev-a")); // 新增
        a.upsert(item("n1", "週會", Some("f1"), 11, "dev-a")); // 改名
        a.tombstone("n2", 12, "dev-a"); // 刪除

        let mut b = base.clone();
        b.upsert(folder("f2", "私人", None, 10, "dev-b")); // 新增資料夾
        b.upsert(item("n1", "會議", Some("f2"), 9, "dev-b")); // 搬移（比 A 的改名早）

        let mut ab = a.clone();
        ab.merge(&b);
        let mut ba = b.clone();
        ba.merge(&a);
        assert_eq!(ab, ba);

        assert!(ab.items["n2"].deleted, "刪掉的不可以復活");
        assert_eq!(ab.items["n1"].title, "週會", "較新的改名要留下");
        assert_eq!(ab.items["n1"].parent_id.as_deref(), Some("f1"));
        assert_eq!(ab.live().len(), 4); // f1, f2, n1, n3
    }

    #[test]
    fn cross_platform_uuid_case_insensitivity_converges() {
        // Apple 端產生大寫 UUID，Android 產生小寫 UUID。兩端同步時不得重複，且墓碑必須正確套用
        let mut idx = LibraryIndex::default();
        let upper_id = "B62B0B1F-ADF4-4FF7-AE54-6B9C0513DB36";
        let lower_id = "b62b0b1f-adf4-4ff7-ae54-6b9c0513db36";

        idx.upsert(item(upper_id, "Apple 筆記", None, 1, "apple-dev"));
        assert_eq!(idx.live_notebooks().len(), 1);
        assert_eq!(idx.items[lower_id].title, "Apple 筆記");

        // Android 以較新時戳改名，使用小寫 ID
        idx.upsert(item(lower_id, "Android 更新", None, 2, "android-dev"));
        assert_eq!(idx.live_notebooks().len(), 1, "不得產生重複筆記本");
        assert_eq!(idx.items[lower_id].title, "Android 更新");

        // Apple 端以大寫 ID 標記墓碑刪除
        idx.tombstone(upper_id, 3, "apple-dev");
        assert_eq!(idx.live_notebooks().len(), 0, "墓碑必須生效");
        assert!(idx.items[lower_id].deleted);
        assert!(idx.is_hidden_by_deletion(upper_id));
        assert!(idx.is_hidden_by_deletion(lower_id));
    }
}
