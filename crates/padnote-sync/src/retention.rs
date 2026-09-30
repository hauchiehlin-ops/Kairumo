//! 回收桶與保留期限 —— **什麼時候可以安全地永久刪掉？**
//!
//! 設計全文見 `docs/plans/expiry-purge.md`。這個檔案是其中「純計算」的部分：
//! 一次 HTTP 都不打、不讀時鐘（`now` 由呼叫端傳進來），所以可以窮舉時序來測。
//!
//! # 為什麼不能「期滿就刪」
//!
//! 刪除在這個系統裡是一個**會收斂的事件**（墓碑），不是一個動作。期限到了，
//! 本機可以放心刪 —— 那是自己的副本。但雲端的檔案是所有裝置共用的：
//! 某台裝置離線兩週，它手上可能有還沒上傳的操作、也可能根本還不知道這本
//! 筆記本被刪了。期滿就刪雲端，等於替它決定了「你那些沒傳的東西不要了」。
//!
//! 所以雲端要**再等一條**：每一台必要裝置都確認過這個墓碑
//! （見 [`DeviceAck`]）。而為了不讓一台被遺忘的裝置永遠卡住清除，
//! 失聯太久的裝置不再是必要的（[`STALE_DEVICE_DAYS`]）。

use std::collections::{BTreeMap, BTreeSet};

use serde::{Deserialize, Serialize};

use crate::library::{ItemKind, LibraryIndex, LibraryItem};

/// 預設保留天數。
pub const DEFAULT_RETENTION_DAYS: u32 = 30;

/// 裝置超過這麼多天沒有確認，就不再是「必要裝置」。
pub const STALE_DEVICE_DAYS: u64 = 90;

const DAY: u64 = 86_400;

/// 保留期限。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum RetentionPolicy {
    /// 刪除後保留這麼多天。
    Days(u32),
    /// 永不自動清除（回收桶仍可手動清空）。
    Forever,
}

impl Default for RetentionPolicy {
    fn default() -> Self {
        RetentionPolicy::Days(DEFAULT_RETENTION_DAYS)
    }
}

impl RetentionPolicy {
    /// 給平台用的整數表示：`0` 就是「永不」。
    pub fn from_days(days: u32) -> Self {
        if days == 0 {
            RetentionPolicy::Forever
        } else {
            RetentionPolicy::Days(days)
        }
    }

    fn seconds(self) -> Option<u64> {
        match self {
            RetentionPolicy::Days(d) => Some(u64::from(d) * DAY),
            RetentionPolicy::Forever => None,
        }
    }
}

/// 回收桶裡的一項。
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct TrashEntry {
    pub id: String,
    pub title: String,
    /// 刪除時間（Unix 秒）。`None` = 舊版墓碑，還沒有起算點。
    pub deleted_at: Option<u64>,
    /// 期滿時間（Unix 秒）。`None` = 永不，或還沒有起算點。
    pub expires_at: Option<u64>,
    /// 還剩幾天（無條件進位）。已期滿是 `0`。`None` = 永不，或還沒有起算點。
    pub days_left: Option<u32>,
}

/// 回收桶清單：所有已刪除的**筆記本**，最近刪的在前。
pub fn trash(index: &LibraryIndex, now: u64, policy: RetentionPolicy) -> Vec<TrashEntry> {
    let mut out: Vec<TrashEntry> = index
        .items
        .values()
        .filter(|i| i.deleted && i.kind == ItemKind::Notebook)
        .map(|i| {
            let expires_at = expiry(i, policy);
            let days_left = expires_at.map(|e| {
                if now >= e {
                    0
                } else {
                    (e - now).div_ceil(DAY) as u32
                }
            });
            TrashEntry {
                id: i.id.clone(),
                title: i.title.clone(),
                deleted_at: i.deleted_at,
                expires_at,
                days_left,
            }
        })
        .collect();
    out.sort_by(|a, b| b.deleted_at.cmp(&a.deleted_at).then(a.id.cmp(&b.id)));
    out
}

/// 給舊墓碑（沒有 `deleted_at`）補蓋章：保留期從「現在」起算。
///
/// 這是**一次普通的帶時戳寫入**（用 `lamport` 重寫同一個墓碑），所以與任何
/// 時序都會收斂；多台裝置同時蓋章，由 lamport 與裝置 id 決出同一個結果。
/// 效果是升級後**不會**一夜之間清掉所有歷史刪除，而是給它們一段完整的寬限期。
///
/// `lamport` 必須大於索引裡已見過的任何時戳（呼叫端的邏輯時鐘），否則蓋章寫不贏
/// 原本的墓碑。回傳蓋了幾個。
pub fn stamp_legacy(index: &mut LibraryIndex, now: u64, lamport: u64, device: &str) -> usize {
    let legacy: Vec<LibraryItem> = index
        .items
        .values()
        // 已經要求立即永久刪除的不必蓋章：它已經期滿，而且蓋章會把那個要求蓋掉。
        .filter(|i| i.deleted && i.deleted_at.is_none() && i.purge_at.is_none())
        .cloned()
        .collect();
    let stamped = legacy.len();
    for base in legacy {
        // 只改時戳、裝置與刪除時間，其餘欄位（標題、上層、…）原封不動。
        index.upsert(LibraryItem {
            lamport,
            device: device.to_string(),
            deleted_at: Some(now),
            ..base
        });
    }
    stamped
}

/// 索引裡看過的最大 lamport —— 「我這台已經合併到哪裡」。
pub fn max_lamport(index: &LibraryIndex) -> u64 {
    index.items.values().map(|i| i.lamport).max().unwrap_or(0)
}

/// 某個墓碑什麼時候期滿（Unix 秒）。`None` = 不會期滿。
///
/// 兩個來源取**較早**的：
/// - 保留期：`deleted_at + 保留天數`。沒有 `deleted_at`（舊墓碑）或政策是「永不」就沒有。
/// - 使用者要求立即永久刪除：`purge_at`。**不管保留期怎麼設**（甚至是「永不」）都算數 ——
///   那是使用者明確說「現在就刪」，見 [`LibraryItem::purge_at`]。
fn expiry(item: &LibraryItem, policy: RetentionPolicy) -> Option<u64> {
    let by_policy = item
        .deleted_at
        .zip(policy.seconds())
        .map(|(at, span)| at.saturating_add(span));
    match (item.purge_at, by_policy) {
        (Some(p), Some(e)) => Some(p.min(e)),
        (Some(p), None) => Some(p),
        (None, e) => e,
    }
}

// ─── 裝置確認 ────────────────────────────────────────────────────────────────

/// 一台裝置對「我已經合併到哪裡」的聲明。
///
/// 存在 `sync/<device_id>/ack.json`。**單調暫存器、單一寫入者**：兩個欄位
/// 都只增不減，而且只有這台裝置自己寫 —— 不違反「同步檔案層級不可能衝突」
/// 的不變式（沒有第二個寫入者）。
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DeviceAck {
    /// 這台裝置已經合併過的最大 lamport。
    pub seen_lamport: u64,
    /// 寫入時間（Unix 秒）。用來判斷裝置是否失聯。
    pub at: u64,
}

impl DeviceAck {
    /// 前進到新的狀態。**只增不減**：拿舊快照來寫不會把它倒退。
    pub fn advance(&mut self, seen_lamport: u64, at: u64) {
        self.seen_lamport = self.seen_lamport.max(seen_lamport);
        self.at = self.at.max(at);
    }

    pub fn to_json(&self) -> String {
        serde_json::to_string(self).unwrap_or_default()
    }

    /// 壞掉或空的內容當成「沒有確認」（`seen_lamport = 0`），不要 panic ——
    /// 那是網路輸入。
    pub fn from_json(text: &str) -> Self {
        serde_json::from_str(text).unwrap_or_default()
    }
}

/// 某台裝置的確認檔在雲端上的路徑。
pub fn ack_path(device: &str) -> String {
    format!("sync/{device}/ack.json")
}

/// 從雲端路徑反解出「是誰的確認檔」。
pub fn device_of_ack_path(path: &str) -> Option<&str> {
    let rest = path.strip_prefix("sync/")?;
    let (device, tail) = rest.split_once('/')?;
    (tail == "ack.json" && !device.is_empty()).then_some(device)
}

/// 雲端上所有已知的裝置：`sync/<device>/…` 底下有任何檔案的都算。
pub fn known_devices<'a>(paths: impl IntoIterator<Item = &'a str>) -> BTreeSet<String> {
    paths
        .into_iter()
        .filter_map(|p| {
            let rest = p.strip_prefix("sync/")?;
            let (device, tail) = rest.split_once('/')?;
            (!device.is_empty() && !tail.is_empty()).then(|| device.to_string())
        })
        .collect()
}

// ─── 清除計畫 ────────────────────────────────────────────────────────────────

/// 一台裝置要怎樣才算「確認過了」。
#[derive(Clone, Copy, Debug)]
enum Confirmation {
    /// 已經合併到這個 lamport（墓碑）。
    SeenLamport(u64),
    /// 在這個時間**之後**同步過（孤兒檔案：它寫進雲端時，那台裝置的索引若有這本筆記本，
    /// 之後任何一輪同步都會合併進來）。
    SyncedSince(u64),
}

/// 還在等哪些必要裝置。墓碑與孤兒檔案共用這一份 —— 兩邊各寫一份的話，
/// 「失聯多久不再等」這種規則遲早會分歧。
///
/// - 有確認檔且已確認 → 不等。
/// - 有確認檔但還沒確認：失聯超過 [`STALE_DEVICE_DAYS`] 就不再等，否則等。
/// - 沒有確認檔（舊版裝置）：`grace_anchor` 之後再過 [`STALE_DEVICE_DAYS`] 才不再等。
fn missing_devices(
    everyone: &BTreeSet<&str>,
    acks: &BTreeMap<String, DeviceAck>,
    now: u64,
    grace_anchor: u64,
    need: Confirmation,
) -> Vec<String> {
    everyone
        .iter()
        .filter(|device| match acks.get(**device) {
            Some(ack) => {
                let confirmed = match need {
                    Confirmation::SeenLamport(l) => ack.seen_lamport >= l,
                    Confirmation::SyncedSince(t) => ack.at >= t,
                };
                !confirmed && now.saturating_sub(ack.at) < STALE_DEVICE_DAYS * DAY
            }
            None => now < grace_anchor.saturating_add(STALE_DEVICE_DAYS * DAY),
        })
        .map(|d| (*d).to_string())
        .collect()
}

/// 孤兒檔案的清除計畫：雲端上 `notebooks/<id>/…` 但**索引裡從來沒有這個 id** 的檔案。
///
/// `files` 是 `(雲端路徑, 修改時間 Unix 秒)`。回傳可以永久刪除的路徑。
///
/// 一個孤兒**同時**要滿足才刪：
///
/// 1. **夠老**：修改時間已知（`0` = 不知道，當成年輕），而且超過保留天數。
///    年輕的 `Unknown` 多半是另一台裝置剛建立、索引還沒拉到 —— 刪掉等於吃掉別台剛寫的東西
///    （`audit.rs` 的安全底線）。
/// 2. **每台必要裝置在它寫進雲端之後都同步過**。它們的索引若有這本筆記本，那些同步
///    早就把它合併進來了；到現在索引裡還是沒有，才能說它真的是孤兒。
///
/// 保留期是「永不」時不清。只處理 `Unknown`：活著的、有墓碑的、不符合任何已知形狀的
/// 檔案一律不碰。
pub fn plan_orphans(
    files: &[(String, u64)],
    index: &LibraryIndex,
    now: u64,
    policy: RetentionPolicy,
    known: &BTreeSet<String>,
    acks: &BTreeMap<String, DeviceAck>,
    me: &str,
) -> Vec<String> {
    let Some(span) = policy.seconds() else {
        return Vec::new();
    };
    let mut everyone: BTreeSet<&str> = known.iter().map(String::as_str).collect();
    everyone.extend(acks.keys().map(String::as_str));
    everyone.remove(me);

    files
        .iter()
        .filter(|(path, _)| crate::audit::classify(path, index) == crate::audit::FileClass::Unknown)
        .filter(|(_, modified)| *modified != 0 && now >= modified.saturating_add(span))
        .filter(|(_, modified)| {
            missing_devices(
                &everyone,
                acks,
                now,
                modified.saturating_add(span),
                Confirmation::SyncedSince(*modified),
            )
            .is_empty()
        })
        .map(|(path, _)| path.clone())
        .collect()
}

/// 一個期滿、但還不能刪雲端的筆記本，以及它在等誰。
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Waiting {
    pub id: String,
    /// 還沒確認過這個墓碑的必要裝置。
    pub missing_devices: Vec<String>,
}

/// 這一輪的清除計畫。
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct PurgePlan {
    /// 已期滿、可以**永久刪除本機套件**的筆記本 id。本機不必等別的裝置。
    pub local: Vec<String>,
    /// 已期滿、而且所有必要裝置都確認過的筆記本 id —— 可以刪雲端檔案。
    pub cloud: Vec<String>,
    /// 已期滿、但還在等某些裝置確認的筆記本。
    pub waiting: Vec<Waiting>,
}

/// 算這一輪能清掉什麼。
///
/// - `known`：雲端上已知的裝置（[`known_devices`]）。
/// - `acks`：各裝置的確認檔內容。
/// - `me`：呼叫端自己的 device id —— **自己不必等自己**（自己的索引就是呼叫端手上這份）。
pub fn plan_purge(
    index: &LibraryIndex,
    now: u64,
    policy: RetentionPolicy,
    known: &BTreeSet<String>,
    acks: &BTreeMap<String, DeviceAck>,
    me: &str,
) -> PurgePlan {
    let mut plan = PurgePlan::default();
    let mut everyone: BTreeSet<&str> = known.iter().map(String::as_str).collect();
    everyone.extend(acks.keys().map(String::as_str));
    everyone.remove(me);

    for item in index.items.values() {
        if !(item.deleted && item.kind == ItemKind::Notebook) {
            continue;
        }
        let Some(expires_at) = expiry(item, policy) else {
            continue;
        };
        if now < expires_at {
            continue;
        }
        plan.local.push(item.id.clone());

        let missing = missing_devices(
            &everyone,
            acks,
            now,
            expires_at,
            Confirmation::SeenLamport(item.lamport),
        );

        if missing.is_empty() {
            plan.cloud.push(item.id.clone());
        } else {
            plan.waiting.push(Waiting {
                id: item.id.clone(),
                missing_devices: missing,
            });
        }
    }
    plan
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::library::LibraryItem;

    const T0: u64 = 1_800_000_000;

    fn live(id: &str, lamport: u64) -> LibraryItem {
        LibraryItem {
            id: id.into(),
            kind: ItemKind::Notebook,
            title: format!("title-{id}"),
            parent_id: None,
            lamport,
            device: "dev-a".into(),
            deleted: false,
            deleted_at: None,
            purge_at: None,
        }
    }

    /// 一本在 `T0` 被 lamport 10 刪掉的筆記本。
    fn index_with_trashed(id: &str) -> LibraryIndex {
        let mut index = LibraryIndex::default();
        index.upsert(live(id, 1));
        index.tombstone_at(id, 10, "dev-a", T0);
        index
    }

    fn devices(names: &[&str]) -> BTreeSet<String> {
        names.iter().map(|s| s.to_string()).collect()
    }

    fn ack(seen: u64, at: u64) -> DeviceAck {
        DeviceAck {
            seen_lamport: seen,
            at,
        }
    }

    fn days(n: u64) -> u64 {
        n * DAY
    }

    // ─── 政策與回收桶 ───

    #[test]
    fn zero_days_means_forever() {
        assert_eq!(RetentionPolicy::from_days(0), RetentionPolicy::Forever);
        assert_eq!(RetentionPolicy::from_days(7), RetentionPolicy::Days(7));
        assert_eq!(RetentionPolicy::default(), RetentionPolicy::Days(30));
    }

    #[test]
    fn trash_lists_only_deleted_notebooks_newest_first() {
        let mut index = LibraryIndex::default();
        index.upsert(live("kept", 1));
        index.upsert(live("old", 1));
        index.upsert(live("new", 1));
        index.tombstone_at("old", 5, "dev-a", T0);
        index.tombstone_at("new", 6, "dev-a", T0 + 100);

        let ids: Vec<_> = trash(&index, T0 + 200, RetentionPolicy::default())
            .into_iter()
            .map(|e| e.id)
            .collect();
        assert_eq!(ids, ["new", "old"]);
    }

    #[test]
    fn days_left_rounds_up_and_bottoms_out_at_zero() {
        let index = index_with_trashed("nb");
        let policy = RetentionPolicy::Days(30);

        let e = &trash(&index, T0, policy)[0];
        assert_eq!(e.days_left, Some(30));
        assert_eq!(e.expires_at, Some(T0 + days(30)));

        // 還剩 29 天又 1 秒 → 進位成 30；剩不到一天 → 1。
        assert_eq!(trash(&index, T0 + 1, policy)[0].days_left, Some(30));
        assert_eq!(
            trash(&index, T0 + days(30) - 5, policy)[0].days_left,
            Some(1)
        );
        assert_eq!(trash(&index, T0 + days(30), policy)[0].days_left, Some(0));
        assert_eq!(trash(&index, T0 + days(99), policy)[0].days_left, Some(0));
    }

    #[test]
    fn forever_and_legacy_tombstones_have_no_countdown() {
        let index = index_with_trashed("nb");
        let e = &trash(&index, T0, RetentionPolicy::Forever)[0];
        assert_eq!((e.expires_at, e.days_left), (None, None));

        // 舊版墓碑：沒有起算點。
        let mut legacy = LibraryIndex::default();
        legacy.upsert(live("nb", 1));
        legacy.tombstone("nb", 2, "dev-a");
        let e = &trash(&legacy, T0, RetentionPolicy::default())[0];
        assert_eq!(
            (e.deleted_at, e.expires_at, e.days_left),
            (None, None, None)
        );
    }

    // ─── 補蓋章與還原 ───

    #[test]
    fn stamping_starts_the_clock_for_legacy_tombstones_only() {
        let mut index = LibraryIndex::default();
        index.upsert(live("legacy", 1));
        index.upsert(live("stamped", 1));
        index.tombstone("legacy", 2, "dev-a");
        index.tombstone_at("stamped", 2, "dev-a", T0);

        let n = stamp_legacy(&mut index, T0 + 500, 20, "dev-b");
        assert_eq!(n, 1);
        assert_eq!(index.items["legacy"].deleted_at, Some(T0 + 500));
        assert_eq!(index.items["legacy"].lamport, 20);
        assert!(index.items["legacy"].deleted, "蓋章不能把墓碑弄不見");
        // 已經有時間的不動。
        assert_eq!(index.items["stamped"].deleted_at, Some(T0));
        // 再蓋一次沒有東西可蓋。
        assert_eq!(stamp_legacy(&mut index, T0 + 900, 30, "dev-b"), 0);
    }

    #[test]
    fn a_legacy_tombstone_is_not_expired_until_it_has_been_stamped() {
        let mut index = LibraryIndex::default();
        index.upsert(live("nb", 1));
        index.tombstone("nb", 2, "dev-a");
        let plan = plan_purge(
            &index,
            T0 + days(365),
            RetentionPolicy::default(),
            &devices(&[]),
            &BTreeMap::new(),
            "me",
        );
        assert_eq!(plan, PurgePlan::default(), "沒有起算點就不能算期滿");
    }

    #[test]
    fn restoring_brings_the_notebook_back_with_a_higher_lamport() {
        let mut index = index_with_trashed("nb");
        assert!(index.restore("nb", 11, "dev-b"));
        let item = &index.items["nb"];
        assert!(!item.deleted);
        assert_eq!(item.deleted_at, None);
        assert_eq!(item.title, "title-nb", "還原要保留標題");
        // 不在回收桶裡的、或本來就沒被刪的，還原不動。
        assert!(!index.restore("nb", 12, "dev-b"));
        assert!(!index.restore("nope", 12, "dev-b"));
    }

    #[test]
    fn a_restore_and_a_delete_converge_regardless_of_order() {
        let mut a = index_with_trashed("nb");
        let mut b = a.clone();
        // a 先還原再收到 b 的（同一個舊）墓碑；b 反過來。
        a.restore("nb", 11, "dev-b");
        b.merge(&a);
        a.merge(&b);
        assert_eq!(a, b);
        assert!(!a.items["nb"].deleted, "較大的 lamport 那個還原要贏");
    }

    // ─── 清除計畫：期限 ───

    #[test]
    fn nothing_is_purged_before_the_deadline() {
        let index = index_with_trashed("nb");
        let plan = plan_purge(
            &index,
            T0 + days(30) - 1,
            RetentionPolicy::Days(30),
            &devices(&[]),
            &BTreeMap::new(),
            "me",
        );
        assert_eq!(plan, PurgePlan::default());
    }

    #[test]
    fn a_lone_device_purges_local_and_cloud_at_the_deadline() {
        let index = index_with_trashed("nb");
        let plan = plan_purge(
            &index,
            T0 + days(30),
            RetentionPolicy::Days(30),
            &devices(&["me"]),
            &BTreeMap::new(),
            "me",
        );
        assert_eq!(plan.local, ["nb"]);
        assert_eq!(plan.cloud, ["nb"]);
        assert!(plan.waiting.is_empty());
    }

    #[test]
    fn forever_never_purges() {
        let index = index_with_trashed("nb");
        let plan = plan_purge(
            &index,
            T0 + days(10_000),
            RetentionPolicy::Forever,
            &devices(&[]),
            &BTreeMap::new(),
            "me",
        );
        assert_eq!(plan, PurgePlan::default());
    }

    #[test]
    fn a_shorter_policy_expires_things_sooner() {
        let index = index_with_trashed("nb");
        let plan = |d| {
            plan_purge(
                &index,
                T0 + days(8),
                RetentionPolicy::Days(d),
                &devices(&[]),
                &BTreeMap::new(),
                "me",
            )
        };
        assert_eq!(plan(7).local, ["nb"]);
        assert!(plan(30).local.is_empty());
    }

    // ─── 清除計畫：多裝置 ───

    #[test]
    fn local_purge_never_waits_for_other_devices() {
        let index = index_with_trashed("nb");
        let plan = plan_purge(
            &index,
            T0 + days(30),
            RetentionPolicy::Days(30),
            &devices(&["me", "phone"]),
            &BTreeMap::new(),
            "me",
        );
        assert_eq!(plan.local, ["nb"], "本機是自己的副本，不必等別台");
        assert!(plan.cloud.is_empty());
    }

    #[test]
    fn cloud_waits_for_every_required_device_to_confirm() {
        let index = index_with_trashed("nb");
        let now = T0 + days(30);
        let known = devices(&["me", "phone", "ipad"]);

        // phone 確認過（seen 10 ≥ 墓碑的 lamport 10），ipad 只看到 9。
        let acks = BTreeMap::from([
            ("phone".to_string(), ack(10, now - 10)),
            ("ipad".to_string(), ack(9, now - 10)),
        ]);
        let plan = plan_purge(&index, now, RetentionPolicy::Days(30), &known, &acks, "me");
        assert!(plan.cloud.is_empty());
        assert_eq!(
            plan.waiting,
            [Waiting {
                id: "nb".into(),
                missing_devices: vec!["ipad".into()]
            }]
        );

        // ipad 也確認之後放行。
        let acks = BTreeMap::from([
            ("phone".to_string(), ack(10, now - 10)),
            ("ipad".to_string(), ack(12, now - 5)),
        ]);
        let plan = plan_purge(&index, now, RetentionPolicy::Days(30), &known, &acks, "me");
        assert_eq!(plan.cloud, ["nb"]);
        assert!(plan.waiting.is_empty());
    }

    #[test]
    fn a_device_that_has_been_silent_for_90_days_stops_blocking() {
        let index = index_with_trashed("nb");
        let now = T0 + days(200);
        let known = devices(&["me", "drawer"]);
        // 抽屜裡那台最後一次出現是 100 天前，而且沒確認過這個墓碑。
        let acks = BTreeMap::from([("drawer".to_string(), ack(3, now - days(100)))]);
        let plan = plan_purge(&index, now, RetentionPolicy::Days(30), &known, &acks, "me");
        assert_eq!(plan.cloud, ["nb"]);

        // 80 天前還在線的，仍然要等。
        let acks = BTreeMap::from([("drawer".to_string(), ack(3, now - days(80)))]);
        let plan = plan_purge(&index, now, RetentionPolicy::Days(30), &known, &acks, "me");
        assert!(plan.cloud.is_empty());
    }

    #[test]
    fn an_old_app_without_an_ack_file_gets_an_extra_grace_period() {
        let index = index_with_trashed("nb");
        let known = devices(&["me", "old-app"]);
        let expires = T0 + days(30);

        // 期滿當天：舊版裝置沒有確認檔，沒辦法知道它會不會回來 → 等。
        let plan = plan_purge(
            &index,
            expires,
            RetentionPolicy::Days(30),
            &known,
            &BTreeMap::new(),
            "me",
        );
        assert!(plan.cloud.is_empty());
        assert_eq!(plan.waiting[0].missing_devices, ["old-app"]);

        // 再過 90 天才不再等它。
        let plan = plan_purge(
            &index,
            expires + days(90),
            RetentionPolicy::Days(30),
            &known,
            &BTreeMap::new(),
            "me",
        );
        assert_eq!(plan.cloud, ["nb"]);
    }

    #[test]
    fn a_device_known_only_by_its_ack_still_counts() {
        // 它的 sync/<device>/ 底下已經沒有檔案，但有確認檔。
        let index = index_with_trashed("nb");
        let now = T0 + days(30);
        let acks = BTreeMap::from([("ghost".to_string(), ack(2, now - 60))]);
        let plan = plan_purge(
            &index,
            now,
            RetentionPolicy::Days(30),
            &devices(&["me"]),
            &acks,
            "me",
        );
        assert!(plan.cloud.is_empty());
        assert_eq!(plan.waiting[0].missing_devices, ["ghost"]);
    }

    #[test]
    fn a_restored_notebook_is_never_in_the_plan() {
        let mut index = index_with_trashed("nb");
        index.restore("nb", 11, "dev-b");
        let plan = plan_purge(
            &index,
            T0 + days(365),
            RetentionPolicy::Days(30),
            &devices(&["me"]),
            &BTreeMap::new(),
            "me",
        );
        assert_eq!(plan, PurgePlan::default());
    }

    #[test]
    fn folders_are_not_purged_as_notebooks() {
        let mut index = LibraryIndex::default();
        index.upsert(LibraryItem {
            kind: ItemKind::Folder,
            ..live("f", 1)
        });
        index.tombstone_at("f", 5, "dev-a", T0);
        let plan = plan_purge(
            &index,
            T0 + days(365),
            RetentionPolicy::Days(30),
            &devices(&[]),
            &BTreeMap::new(),
            "me",
        );
        assert_eq!(plan, PurgePlan::default());
    }

    // ─── 確認檔 ───

    #[test]
    fn an_ack_only_moves_forward() {
        let mut a = DeviceAck::default();
        a.advance(10, 1000);
        a.advance(7, 900); // 拿舊快照來寫
        assert_eq!(a, ack(10, 1000));
        a.advance(12, 1500);
        assert_eq!(a, ack(12, 1500));
    }

    #[test]
    fn an_ack_round_trips_and_survives_garbage() {
        let a = ack(42, 1234);
        assert_eq!(DeviceAck::from_json(&a.to_json()), a);
        assert!(a.to_json().contains("seenLamport"));
        assert_eq!(DeviceAck::from_json("not json"), DeviceAck::default());
        assert_eq!(DeviceAck::from_json(""), DeviceAck::default());
    }

    #[test]
    fn ack_paths_and_device_discovery() {
        assert_eq!(ack_path("dev-a"), "sync/dev-a/ack.json");
        assert_eq!(device_of_ack_path("sync/dev-a/ack.json"), Some("dev-a"));
        assert_eq!(device_of_ack_path("sync/dev-a/log-1.bin"), None);
        assert_eq!(device_of_ack_path("notebooks/index.json"), None);

        let paths = [
            "sync/dev-a/log-1.bin",
            "sync/dev-a/ack.json",
            "sync/dev-b/log-1.bin",
            "sync/",
            "sync/dev-c",
            "notebooks/index.json",
        ];
        assert_eq!(known_devices(paths), devices(&["dev-a", "dev-b"]));
    }

    #[test]
    fn max_lamport_is_the_highest_seen() {
        let mut index = LibraryIndex::default();
        assert_eq!(max_lamport(&index), 0);
        index.upsert(live("a", 3));
        index.upsert(live("b", 9));
        assert_eq!(max_lamport(&index), 9);
    }

    // ─── 孤兒檔案 ───

    const ORPHAN: &str = "notebooks/ghost/doc/ops/dev-x.bin";

    fn orphans(
        files: &[(&str, u64)],
        index: &LibraryIndex,
        now: u64,
        policy: RetentionPolicy,
        known: &BTreeSet<String>,
        acks: &BTreeMap<String, DeviceAck>,
    ) -> Vec<String> {
        let files: Vec<(String, u64)> = files.iter().map(|(p, m)| (p.to_string(), *m)).collect();
        plan_orphans(&files, index, now, policy, known, acks, "me")
    }

    #[test]
    fn a_young_orphan_is_never_collected() {
        // 別台剛建好的筆記本、索引還沒拉到 —— 那是 `Unknown`，但不能刪。
        let index = LibraryIndex::default();
        let got = orphans(
            &[(ORPHAN, T0)],
            &index,
            T0 + days(29),
            RetentionPolicy::Days(30),
            &devices(&[]),
            &BTreeMap::new(),
        );
        assert!(got.is_empty());
    }

    #[test]
    fn an_old_orphan_is_collected_when_no_other_device_exists() {
        let index = LibraryIndex::default();
        let got = orphans(
            &[(ORPHAN, T0)],
            &index,
            T0 + days(30),
            RetentionPolicy::Days(30),
            &devices(&["me"]),
            &BTreeMap::new(),
        );
        assert_eq!(got, [ORPHAN]);
    }

    #[test]
    fn an_orphan_with_an_unknown_age_is_treated_as_young() {
        let index = LibraryIndex::default();
        let got = orphans(
            &[(ORPHAN, 0)],
            &index,
            T0 + days(3650),
            RetentionPolicy::Days(30),
            &devices(&[]),
            &BTreeMap::new(),
        );
        assert!(got.is_empty(), "不知道多老 → 當成年輕，永遠不刪");
    }

    #[test]
    fn an_orphan_waits_until_every_device_has_synced_since_it_was_written() {
        let index = LibraryIndex::default();
        let now = T0 + days(31);
        let known = devices(&["me", "phone"]);

        // phone 最後一次同步在檔案寫進雲端**之前** —— 它的索引可能還沒有這本。
        let acks = BTreeMap::from([("phone".to_string(), ack(5, T0 - 10))]);
        assert!(
            orphans(
                &[(ORPHAN, T0)],
                &index,
                now,
                RetentionPolicy::Days(30),
                &known,
                &acks
            )
            .is_empty()
        );

        // 它在那之後同步過了、索引裡仍然沒有 → 才是真的孤兒。
        let acks = BTreeMap::from([("phone".to_string(), ack(5, T0 + days(5)))]);
        assert_eq!(
            orphans(
                &[(ORPHAN, T0)],
                &index,
                now,
                RetentionPolicy::Days(30),
                &known,
                &acks
            ),
            [ORPHAN]
        );
    }

    #[test]
    fn a_silent_device_stops_blocking_orphans_too() {
        let index = LibraryIndex::default();
        let now = T0 + days(400);
        let known = devices(&["me", "drawer"]);
        let acks = BTreeMap::from([("drawer".to_string(), ack(1, T0 - days(1)))]);
        assert_eq!(
            orphans(
                &[(ORPHAN, T0)],
                &index,
                now,
                RetentionPolicy::Days(30),
                &known,
                &acks
            ),
            [ORPHAN]
        );
    }

    #[test]
    fn an_old_app_without_an_ack_file_gets_the_same_extra_grace_for_orphans() {
        let index = LibraryIndex::default();
        let known = devices(&["me", "old-app"]);
        let expires = T0 + days(30);
        assert!(
            orphans(
                &[(ORPHAN, T0)],
                &index,
                expires,
                RetentionPolicy::Days(30),
                &known,
                &BTreeMap::new()
            )
            .is_empty()
        );
        assert_eq!(
            orphans(
                &[(ORPHAN, T0)],
                &index,
                expires + days(90),
                RetentionPolicy::Days(30),
                &known,
                &BTreeMap::new()
            ),
            [ORPHAN]
        );
    }

    #[test]
    fn forever_never_collects_orphans() {
        let index = LibraryIndex::default();
        let got = orphans(
            &[(ORPHAN, T0)],
            &index,
            T0 + days(10_000),
            RetentionPolicy::Forever,
            &devices(&[]),
            &BTreeMap::new(),
        );
        assert!(got.is_empty());
    }

    #[test]
    fn only_unknown_notebooks_are_ever_orphans() {
        // 活著的、有墓碑的、不是筆記本的路徑：一個都不能被當成孤兒。
        let mut index = LibraryIndex::default();
        index.upsert(live("alive", 1));
        index.upsert(live("trashed", 1));
        index.tombstone_at("trashed", 5, "dev-a", T0);
        let got = orphans(
            &[
                ("notebooks/alive/doc/ops/a.bin", T0),
                ("notebooks/trashed/doc/ops/a.bin", T0),
                ("notebooks/index.json", T0),
                ("sync/dev-b/log-1.bin", T0),
                ("profile/account.json", T0),
                ("notebooks/ghost/doc/ops/a.bin", T0),
            ],
            &index,
            T0 + days(365),
            RetentionPolicy::Days(30),
            &devices(&["me"]),
            &BTreeMap::new(),
        );
        assert_eq!(got, ["notebooks/ghost/doc/ops/a.bin"]);
    }

    // ─── 使用者要求立即永久刪除（purge_at）───

    /// 一本在 `T0` 被刪、並在 `T0 + 1 天` 被使用者要求立即永久刪除的筆記本。
    fn index_with_purge_requested(id: &str) -> LibraryIndex {
        let mut index = index_with_trashed(id);
        assert!(index.request_purge(id, 11, "dev-a", T0 + days(1)));
        index
    }

    #[test]
    fn a_purge_request_expires_the_tombstone_at_once() {
        let index = index_with_purge_requested("nb");
        // 保留期 30 天，才過 1 天 —— 但使用者已經說「現在就刪」。
        let plan = plan_purge(
            &index,
            T0 + days(1),
            RetentionPolicy::Days(30),
            &devices(&["me"]),
            &BTreeMap::new(),
            "me",
        );
        assert_eq!(plan.local, ["nb"]);
        assert_eq!(plan.cloud, ["nb"]);
    }

    #[test]
    fn a_purge_request_beats_a_retention_of_forever() {
        let index = index_with_purge_requested("nb");
        let plan = plan_purge(
            &index,
            T0 + days(2),
            RetentionPolicy::Forever,
            &devices(&["me"]),
            &BTreeMap::new(),
            "me",
        );
        assert_eq!(
            plan.cloud,
            ["nb"],
            "「永不自動清除」管的是自動，不是使用者明說的立即刪除"
        );
    }

    #[test]
    fn a_purge_request_still_waits_for_every_required_device() {
        let index = index_with_purge_requested("nb");
        let now = T0 + days(2);
        let known = devices(&["me", "phone"]);

        // phone 只看到 lamport 10（刪除），還沒看到 11（要求立即刪除）—— 不能算確認。
        let acks = BTreeMap::from([("phone".to_string(), ack(10, now - 5))]);
        let plan = plan_purge(&index, now, RetentionPolicy::Days(30), &known, &acks, "me");
        assert!(plan.cloud.is_empty());
        assert_eq!(plan.waiting[0].missing_devices, ["phone"]);

        // 確認到 11 之後放行。
        let acks = BTreeMap::from([("phone".to_string(), ack(11, now - 5))]);
        let plan = plan_purge(&index, now, RetentionPolicy::Days(30), &known, &acks, "me");
        assert_eq!(plan.cloud, ["nb"]);
    }

    #[test]
    fn an_old_app_gets_its_grace_counted_from_the_purge_request() {
        let index = index_with_purge_requested("nb");
        let known = devices(&["me", "old-app"]);
        let requested = T0 + days(1);
        let none = BTreeMap::new();

        // 要求當天：沒有確認檔的舊版裝置，多等 90 天。
        let plan = plan_purge(
            &index,
            requested,
            RetentionPolicy::Days(30),
            &known,
            &none,
            "me",
        );
        assert!(plan.cloud.is_empty());
        let plan = plan_purge(
            &index,
            requested + days(90),
            RetentionPolicy::Days(30),
            &known,
            &none,
            "me",
        );
        assert_eq!(plan.cloud, ["nb"]);
    }

    #[test]
    fn the_trash_listing_shows_a_purged_item_as_expired() {
        let index = index_with_purge_requested("nb");
        let entry = &trash(&index, T0 + days(2), RetentionPolicy::Days(30))[0];
        assert_eq!(entry.days_left, Some(0));
        assert_eq!(entry.expires_at, Some(T0 + days(1)));
        // 保留期是「永不」時也一樣：要求立即刪除的有倒數，而且是 0。
        let entry = &trash(&index, T0 + days(2), RetentionPolicy::Forever)[0];
        assert_eq!(entry.days_left, Some(0));
    }

    #[test]
    fn restoring_clears_a_purge_request() {
        let mut index = index_with_purge_requested("nb");
        assert!(index.restore("nb", 12, "dev-b"));
        let item = &index.items["nb"];
        assert!(!item.deleted);
        assert_eq!((item.deleted_at, item.purge_at), (None, None));
    }

    #[test]
    fn a_fresh_delete_does_not_inherit_an_old_purge_request() {
        let mut index = index_with_purge_requested("nb");
        index.restore("nb", 12, "dev-b");
        index.tombstone_at("nb", 13, "dev-b", T0 + days(5));
        let item = &index.items["nb"];
        assert!(item.deleted);
        assert_eq!(
            item.purge_at, None,
            "再刪一次要重新進回收桶，不是馬上被清掉"
        );
        let plan = plan_purge(
            &index,
            T0 + days(6),
            RetentionPolicy::Days(30),
            &devices(&["me"]),
            &BTreeMap::new(),
            "me",
        );
        assert_eq!(plan, PurgePlan::default());
    }

    #[test]
    fn a_purge_request_only_applies_to_something_in_the_trash() {
        let mut index = LibraryIndex::default();
        index.upsert(live("alive", 1));
        assert!(
            !index.request_purge("alive", 5, "dev-a", T0),
            "還活著的不能被要求永久刪除"
        );
        assert!(
            !index.request_purge("ghost", 5, "dev-a", T0),
            "索引裡沒有的也不行"
        );
        assert!(!index.items["alive"].deleted);
    }

    #[test]
    fn a_purge_request_fills_in_a_missing_deletion_time() {
        let mut index = LibraryIndex::default();
        index.upsert(live("nb", 1));
        index.tombstone("nb", 2, "dev-a"); // 舊墓碑：沒有刪除時間
        assert!(index.request_purge("nb", 3, "dev-a", T0));
        assert_eq!(index.items["nb"].deleted_at, Some(T0));
    }

    #[test]
    fn stamping_never_overwrites_a_purge_request() {
        let mut index = LibraryIndex::default();
        index.upsert(live("nb", 1));
        index.tombstone("nb", 2, "dev-a");
        index.request_purge("nb", 3, "dev-a", T0);
        // 補蓋章不該再碰它（它已經有刪除時間，也已經期滿）。
        assert_eq!(stamp_legacy(&mut index, T0 + 999, 20, "dev-b"), 0);
        assert_eq!(index.items["nb"].purge_at, Some(T0));
    }

    #[test]
    fn stamping_keeps_every_other_field() {
        let mut index = LibraryIndex::default();
        index.upsert(LibraryItem {
            parent_id: Some("folder".into()),
            ..live("nb", 1)
        });
        index.tombstone("nb", 2, "dev-a");
        stamp_legacy(&mut index, T0, 20, "dev-b");
        let item = &index.items["nb"];
        assert_eq!(item.title, "title-nb");
        assert_eq!(
            item.parent_id.as_deref(),
            Some("folder"),
            "補蓋章不能把它搬回最上層"
        );
    }

    #[test]
    fn a_purge_request_and_a_restore_converge_regardless_of_order() {
        let base = index_with_trashed("nb");
        let mut purged = base.clone();
        purged.request_purge("nb", 11, "dev-a", T0 + days(1));
        let mut restored = base.clone();
        restored.restore("nb", 12, "dev-b");

        let (mut a, mut b) = (purged.clone(), restored.clone());
        a.merge(&restored);
        b.merge(&purged);
        assert_eq!(a, b);
        assert!(!a.items["nb"].deleted, "較大的 lamport（還原）要贏");
    }
}
