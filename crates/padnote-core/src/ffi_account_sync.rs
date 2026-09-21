//! 帳號式同步的平台介面（G-04 / G-05，ADR-0011）。
//!
//! 合併規則在 [`padnote_sync::settings`] 與 [`padnote_sync::library`]，
//! 這裡只做型別轉換與一層「整包 JSON 進、整包 JSON 出」的門面。
//!
//! # 為什麼是 JSON 進出而不是逐欄位 API
//!
//! 這兩份資料**本來就是以 JSON 的形式存在雲端**（`settings/global.json`、
//! `notebooks/index.json`）。平台層拿到的是位元組，要做的事只有三件：
//! 合併、問結果、送回去。逐欄位開 API 會讓每新增一個設定就要動三個地方
//! （核心、Swift、Kotlin），而那正是設定同步最容易漏掉東西的地方。

use padnote_sync::library::{ItemKind, LibraryIndex, LibraryItem};
use padnote_sync::settings::{Stamped, SyncedSettings};

// 雲端上的固定路徑原本開在這裡（`sync_settings_path` / `sync_index_path`），
// 給平台層用來避免自己拼字串。但**從來沒有平台呼叫過** —— 兩份 JSON 的
// 讀寫一直都在核心裡（`gdrive` 那一側），平台只收合併後的字串。
//
// 留著一個沒人用的匯出，下一個人會以為平台需要自己組路徑，然後真的去組。
// 需要時從 `padnote_sync::settings::SETTINGS_PATH` 直接拿。

/// 下一個可用的 Lamport 時戳：這份文件裡看過的最大值加一。
///
/// # 為什麼不用牆上時間
///
/// 裝置時鐘不同步是常態。用牆上時間的話，「時鐘快五分鐘的那台」會永遠贏 ——
/// 使用者在慢的那台改的設定，一同步就被蓋掉，而且看起來毫無道理。
///
/// # 為什麼由核心算
///
/// 兩個平台各自維護一個計數器的話，遲早會有一邊忘了在合併之後往前跳，
/// 於是它寫出去的每一筆都比對方舊、永遠推不上去。從文件本身推導就沒有
/// 「忘了更新」這回事。
///
/// 傳設定 JSON 或索引 JSON 都可以；解析不出來時回 1。
#[uniffi::export]
pub fn sync_next_lamport(json: String) -> u64 {
    let from_index = LibraryIndex::from_json(&json)
        .items
        .values()
        .map(|i| i.lamport)
        .max()
        .unwrap_or(0);
    let settings = SyncedSettings::from_json(&json);
    let from_settings = [
        settings.locale.as_ref().map(|s| s.lamport),
        settings.toolbar_json.as_ref().map(|s| s.lamport),
        settings.default_pen.as_ref().map(|s| s.lamport),
        settings.identity.as_ref().map(|s| s.lamport),
    ]
    .into_iter()
    .flatten()
    .max()
    .unwrap_or(0);
    from_index.max(from_settings) + 1
}

// ── 全域設定（G-04）──────────────────────────────────────────────

/// 合併兩份設定 JSON，回傳合併後的 JSON。
///
/// 逐欄位取較新的：A 改語言、B 改工具列，兩邊的改動都會留下來。
/// 整包「最後寫入者勝」的話，後上傳的那個會把另一個蓋掉。
///
/// 任何一邊解析不出來就當成空的 —— 雲端上一份壞檔案不該讓使用者
/// 整個進不去設定。
#[uniffi::export]
pub fn sync_merge_settings(mine_json: String, theirs_json: String) -> String {
    let mut mine = SyncedSettings::from_json(&mine_json);
    mine.merge(&SyncedSettings::from_json(&theirs_json));
    mine.to_json()
}

/// 設定裡的一個欄位。平台層用它改單一設定，不必自己組時戳。
#[derive(Clone, Copy, PartialEq, Eq, Debug, uniffi::Enum)]
pub enum FfiSyncedField {
    /// 介面語言。
    Locale,
    /// 工具列配置（`ToolbarConfig::to_json` 的字串）。
    ToolbarJson,
}

/// 改一個字串設定並蓋上時戳。
///
/// `lamport` 要用同步引擎的邏輯時鐘，**不要用牆上時間** —— 裝置時鐘不同步
/// 是常態，用牆上時間會讓「時鐘快五分鐘的那台」永遠贏。
#[uniffi::export]
pub fn sync_set_setting(
    settings_json: String,
    field: FfiSyncedField,
    value: String,
    lamport: u64,
    device_id: String,
) -> String {
    let mut settings = SyncedSettings::from_json(&settings_json);
    let stamped = Stamped::new(value, lamport, device_id);
    match field {
        FfiSyncedField::Locale => settings.locale = Some(stamped),
        FfiSyncedField::ToolbarJson => settings.toolbar_json = Some(stamped),
    }
    settings.to_json()
}

/// 讀一個字串設定。沒有設過就回空字串。
#[uniffi::export]
pub fn sync_get_setting(settings_json: String, field: FfiSyncedField) -> String {
    let settings = SyncedSettings::from_json(&settings_json);
    let slot = match field {
        FfiSyncedField::Locale => &settings.locale,
        FfiSyncedField::ToolbarJson => &settings.toolbar_json,
    };
    slot.as_ref().map(|s| s.value.clone()).unwrap_or_default()
}

// ── 筆記本與資料夾（G-05）────────────────────────────────────────

/// 樹上的一個項目。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiLibraryItem {
    pub id: String,
    /// true 為資料夾。
    pub is_folder: bool,
    pub title: String,
    /// 空字串表示在根目錄（UniFFI 的 Option<String> 在兩邊都比較囉嗦）。
    pub parent_id: String,
    pub lamport: u64,
    pub device: String,
    pub deleted: bool,
}

impl From<&LibraryItem> for FfiLibraryItem {
    fn from(item: &LibraryItem) -> Self {
        Self {
            id: item.id.clone(),
            is_folder: item.kind == ItemKind::Folder,
            title: item.title.clone(),
            parent_id: item.parent_id.clone().unwrap_or_default(),
            lamport: item.lamport,
            device: item.device.clone(),
            deleted: item.deleted,
        }
    }
}

impl From<FfiLibraryItem> for LibraryItem {
    fn from(item: FfiLibraryItem) -> Self {
        Self {
            id: item.id,
            kind: if item.is_folder {
                ItemKind::Folder
            } else {
                ItemKind::Notebook
            },
            title: item.title,
            parent_id: Some(item.parent_id).filter(|p| !p.is_empty()),
            lamport: item.lamport,
            device: item.device,
            deleted: item.deleted,
        }
    }
}

/// 合併兩份索引 JSON。可交換、冪等 —— 同步引擎不保證誰先到、也不保證只送一次。
#[uniffi::export]
pub fn sync_merge_index(mine_json: String, theirs_json: String) -> String {
    let mut mine = LibraryIndex::from_json(&mine_json);
    mine.merge(&LibraryIndex::from_json(&theirs_json));
    mine.to_json()
}

/// 新增或更新一個項目。
#[uniffi::export]
pub fn sync_upsert_item(index_json: String, item: FfiLibraryItem) -> String {
    let mut index = LibraryIndex::from_json(&index_json);
    index.upsert(item.into());
    index.to_json()
}

/// 刪除。**留下墓碑而不是移除** —— 從「檔案不見了」推論刪除的話，
/// 還沒同步到的那台裝置會把它傳回去，刪除永遠刪不掉。
#[uniffi::export]
pub fn sync_delete_item(
    index_json: String,
    item_id: String,
    lamport: u64,
    device_id: String,
) -> String {
    let mut index = LibraryIndex::from_json(&index_json);
    index.tombstone(&item_id, lamport, &device_id);
    index.to_json()
}

/// 某個資料夾底下還活著的項目。`parent_id` 傳空字串表示根目錄。
///
/// 已刪除資料夾底下的東西**不會**出現在任何地方 —— 否則它們會變成
/// 「存在但打不開、也刪不掉」的幽靈。
#[uniffi::export]
pub fn sync_children_of(index_json: String, parent_id: String) -> Vec<FfiLibraryItem> {
    let index = LibraryIndex::from_json(&index_json);
    let parent = if parent_id.is_empty() {
        None
    } else {
        Some(parent_id.as_str())
    };
    index
        .children_of(parent)
        .into_iter()
        .map(Into::into)
        .collect()
}

/// 所有還看得見的**筆記本**，攤平成一份清單，不分層級。
///
/// 同步時要用這個來回答「雲端有、本機還沒有哪幾本」——`sync_children_of`
/// 一次只給一層，放在資料夾裡的筆記本會被漏掉，而使用者看到的症狀是
/// 「有些筆記本同步得過來、有些永遠不來」。
#[uniffi::export]
pub fn sync_live_notebooks(index_json: String) -> Vec<FfiLibraryItem> {
    LibraryIndex::from_json(&index_json)
        .live_notebooks()
        .into_iter()
        .map(Into::into)
        .collect()
}

/// 這個 id 是不是已經被刪除（索引裡有它的墓碑）。
///
/// 索引裡**沒有**這一筆時回 false —— 那是「沒看過」，不是「被刪了」。
/// 兩者混在一起的話，剛從另一台同步過來、本機索引還沒有的筆記本
/// 會被當成已刪除而收掉。
#[uniffi::export]
pub fn sync_is_deleted(index_json: String, item_id: String) -> bool {
    LibraryIndex::from_json(&index_json)
        .items
        .get(&item_id)
        .map(|i| i.deleted)
        .unwrap_or(false)
}

/// 索引裡的一筆。沒有就回 `None`。
///
/// 平台層用它問「這本筆記在哪個資料夾」與「這個資料夾叫什麼名字」——
/// 兩者都只有索引知道，本機檔案系統上看不出來。
#[uniffi::export]
pub fn sync_item(index_json: String, item_id: String) -> Option<FfiLibraryItem> {
    LibraryIndex::from_json(&index_json)
        .items
        .get(&item_id)
        .map(Into::into)
}

/// 這個項目該不該因為刪除而**從畫面上消失**。
///
/// 清單要用這個，不是 [`sync_is_deleted`]：後者只看自己那一筆，
/// 刪掉一個資料夾之後，裡面的筆記本仍然會被列出來 ——
/// 那就是「存在但打不開、也刪不掉」的幽靈。
///
/// 索引裡**沒看過**的一律回 false。「沒看過」不是「被刪了」——
/// 混在一起的話，剛建好還沒同步的筆記本會在使用者眼前消失，
/// 那比多顯示一個幽靈嚴重得多。
#[uniffi::export]
pub fn sync_is_hidden(index_json: String, item_id: String) -> bool {
    LibraryIndex::from_json(&index_json).is_hidden_by_deletion(&item_id)
}

/// 搬移之後會不會形成環。UI 要在**動手之前**問 ——
/// 把資料夾搬進自己的子孫裡，那棵子樹會從樹上整個斷開，救不回來。
#[uniffi::export]
pub fn sync_would_create_cycle(index_json: String, item_id: String, new_parent_id: String) -> bool {
    let index = LibraryIndex::from_json(&index_json);
    let parent = if new_parent_id.is_empty() {
        None
    } else {
        Some(new_parent_id.as_str())
    };
    index.would_create_cycle(&item_id, parent)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn item(id: &str, title: &str, lamport: u64, device: &str) -> FfiLibraryItem {
        FfiLibraryItem {
            id: id.into(),
            is_folder: false,
            title: title.into(),
            parent_id: String::new(),
            lamport,
            device: device.into(),
            deleted: false,
        }
    }

    #[test]
    fn settings_round_trip_across_the_ffi() {
        let a = sync_set_setting(
            String::new(),
            FfiSyncedField::Locale,
            "ja".into(),
            3,
            "dev-a".into(),
        );
        assert_eq!(sync_get_setting(a.clone(), FfiSyncedField::Locale), "ja");

        let b = sync_set_setting(
            String::new(),
            FfiSyncedField::ToolbarJson,
            "{\"x\":1}".into(),
            4,
            "dev-b".into(),
        );
        // 兩台各改一個欄位，合併之後兩個都要在。
        let merged = sync_merge_settings(a, b);
        assert_eq!(
            sync_get_setting(merged.clone(), FfiSyncedField::Locale),
            "ja"
        );
        assert_eq!(
            sync_get_setting(merged, FfiSyncedField::ToolbarJson),
            "{\"x\":1}"
        );
    }

    #[test]
    fn an_unset_setting_is_empty_not_a_crash() {
        assert_eq!(sync_get_setting(String::new(), FfiSyncedField::Locale), "");
        assert_eq!(
            sync_get_setting("garbage".into(), FfiSyncedField::Locale),
            ""
        );
    }

    #[test]
    fn the_index_survives_the_ffi_intact() {
        // 換型別時把 parent_id 的空字串與 None 搞混，整棵樹就會攤平到根目錄，
        // 而那在核心的單元測試裡看不到 —— 那些測的是 Option。
        let mut json = sync_upsert_item(
            String::new(),
            FfiLibraryItem {
                is_folder: true,
                ..item("f1", "工作", 1, "dev-a")
            },
        );
        json = sync_upsert_item(
            json,
            FfiLibraryItem {
                parent_id: "f1".into(),
                ..item("n1", "會議", 2, "dev-a")
            },
        );

        assert_eq!(sync_children_of(json.clone(), String::new()).len(), 1);
        let inside = sync_children_of(json.clone(), "f1".into());
        assert_eq!(inside.len(), 1);
        assert_eq!(inside[0].title, "會議");
        assert_eq!(inside[0].parent_id, "f1");
    }

    #[test]
    fn a_deleted_item_stays_deleted_after_a_merge() {
        let live = sync_upsert_item(String::new(), item("n1", "會議", 1, "dev-a"));
        let deleted = sync_delete_item(live.clone(), "n1".into(), 5, "dev-a".into());
        // 另一台手上還是活的那一份，合併之後不可以復活。
        let merged = sync_merge_index(live, deleted);
        assert!(sync_children_of(merged, String::new()).is_empty());
    }

    #[test]
    fn never_seen_is_not_the_same_as_deleted() {
        // 混在一起的話，剛從另一台同步過來、本機索引還沒有的筆記本
        // 會被當成已刪除而收掉。
        let live = sync_upsert_item(String::new(), item("n1", "會議", 1, "dev-a"));
        assert!(!sync_is_deleted(live.clone(), "n1".into()));
        assert!(!sync_is_deleted(live.clone(), "從沒看過".into()));

        let gone = sync_delete_item(live, "n1".into(), 2, "dev-a".into());
        assert!(sync_is_deleted(gone, "n1".into()));
    }

    #[test]
    fn cycles_are_reported_before_the_move_happens() {
        let mut json = sync_upsert_item(
            String::new(),
            FfiLibraryItem {
                is_folder: true,
                ..item("f1", "上", 1, "dev-a")
            },
        );
        json = sync_upsert_item(
            json,
            FfiLibraryItem {
                is_folder: true,
                parent_id: "f1".into(),
                ..item("f2", "下", 1, "dev-a")
            },
        );
        assert!(sync_would_create_cycle(
            json.clone(),
            "f1".into(),
            "f2".into()
        ));
        assert!(!sync_would_create_cycle(json, "f2".into(), String::new()));
    }

    #[test]
    fn the_next_lamport_moves_past_everything_already_seen() {
        // 忘了往前跳的話，這台裝置寫出去的每一筆都比對方舊，永遠推不上去。
        let settings = sync_set_setting(
            String::new(),
            FfiSyncedField::Locale,
            "ja".into(),
            41,
            "dev-a".into(),
        );
        assert_eq!(sync_next_lamport(settings), 42);

        let index = sync_upsert_item(String::new(), item("n1", "會議", 99, "dev-a"));
        assert_eq!(sync_next_lamport(index), 100);

        // 空的或壞的都從 1 開始，不要回 0 —— 0 會與「沒設過」混淆。
        assert_eq!(sync_next_lamport(String::new()), 1);
        assert_eq!(sync_next_lamport("garbage".into()), 1);
    }

    #[test]
    fn the_cloud_paths_are_the_ones_in_the_spec() {
        // 這兩個路徑寫在 `format-spec.md` §7.0，改了就是換一個雲端佈局 ——
        // 舊版的裝置會繼續讀寫舊路徑，而兩邊永遠同步不到，
        // 沒有任何錯誤訊息。
        assert_eq!(
            padnote_sync::settings::SETTINGS_PATH,
            "settings/global.json"
        );
        assert_eq!(padnote_sync::library::INDEX_PATH, "notebooks/index.json");
    }
}
