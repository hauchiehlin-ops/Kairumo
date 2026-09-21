//! 資料夾同步的**策略**（決策 D3 選項 A：用使用者自己的雲端硬碟）。
//!
//! # 為什麼只有策略在核心、I/O 在平台層
//!
//! Android 的雲端資料夾是 SAF 的 tree URI，根本沒有 POSIX 路徑，Rust 碰不到；
//! Apple 端則是可以直接讀寫的檔案系統路徑。兩邊的 I/O 天差地遠，但**要複製
//! 哪些檔案、往哪個方向複製**這件事必須完全一樣 —— 否則兩個平台會對「同步」
//! 有不同的理解，而不同的理解在使用者眼中就是資料遺失。
//!
//! # 為什麼聯集就夠了（不需要合併伺服器）
//!
//! 架構不變式 1：每台裝置只寫自己 `device_id` 的檔案，而且是 append-only。
//! 所以同一個檔名只會有一台裝置在寫，兩邊都有的話，較長的那份必然是較新的
//! **超集**。同步因此退化成「把對方沒有的檔案送過去、把自己沒有的拉回來」。
//!
//! 這也是為什麼筆畫檔的命名一定要帶 device（見 `padnote-storage`）——
//! 沒有那一步，這裡的推論全部不成立。

/// 雲端或本機資料夾裡的一個檔案。
#[derive(Clone, Debug, uniffi::Record)]
pub struct SyncFileEntry {
    /// 相對於套件根目錄的路徑，例如 `doc/ops/0000…-000000f1.oplog`。
    pub path: String,
    pub size: u64,
}

/// 同步計畫。平台層照著做 I/O。
#[derive(Clone, Debug, uniffi::Record)]
pub struct SyncPlan {
    /// 要從本機送上雲端的檔案。
    pub upload: Vec<String>,
    /// 要從雲端拉回本機的檔案。
    pub download: Vec<String>,
    /// 兩邊都有、但**內容長度相同以外**無法判斷的檔案。
    ///
    /// 目前只有 `manifest.json` 會落在這裡 —— 它是整份覆寫的，不是 append-only，
    /// 所以不能用「較長的是超集」來推論。平台層應該保留雲端那份，
    /// 並把這件事告訴使用者，而不是默默挑一個。
    pub needs_attention: Vec<String>,
}

/// 整份覆寫、不適用 append-only 推論的檔案。
const NOT_APPEND_ONLY: &[&str] = &["manifest.json"];

// # 為什麼這裡不再「推論某個遠端碎檔已經被壓實涵蓋」
//
// 舊版會跳過「lamport 比本機同裝置最大值小」的遠端碎檔，理由是
// 「它一定已經在本機的壓實檔裡」。那個推論會錯：本機可能根本沒下載過
// 中間那個碎檔（只拿到 0005 與 0010，0007 還在路上），於是跳過的是
// 一份**本機從來沒有過**的操作，而且不會有任何錯誤訊息。
//
// 現在的規則是：只有寫那個檔的裝置會刪自己的碎檔（壓實後、上傳成功後，
// 依明確名單刪），所以雲端不會無限累積，而這裡也不需要猜。
// 多下載一個已經涵蓋過的碎檔只是浪費幾 KB —— 套用是冪等的。

/// 算出同步計畫。
#[uniffi::export]
pub fn plan_folder_sync(local: Vec<SyncFileEntry>, remote: Vec<SyncFileEntry>) -> SyncPlan {
    use std::collections::HashMap;

    let local_map: HashMap<&str, u64> = local.iter().map(|e| (e.path.as_str(), e.size)).collect();
    let remote_map: HashMap<&str, u64> = remote.iter().map(|e| (e.path.as_str(), e.size)).collect();

    let mut plan = SyncPlan {
        upload: Vec::new(),
        download: Vec::new(),
        needs_attention: Vec::new(),
    };

    for entry in &local {
        match remote_map.get(entry.path.as_str()) {
            None => plan.upload.push(entry.path.clone()),
            Some(&remote_size) if remote_size == entry.size => {}
            Some(&remote_size) => {
                if NOT_APPEND_ONLY.contains(&entry.path.as_str()) {
                    plan.needs_attention.push(entry.path.clone());
                } else if entry.size > remote_size {
                    // 本機較長 ⇒ 本機是超集（append-only）
                    plan.upload.push(entry.path.clone());
                } else {
                    plan.download.push(entry.path.clone());
                }
            }
        }
    }

    for entry in &remote {
        if !local_map.contains_key(entry.path.as_str()) {
            plan.download.push(entry.path.clone());
        }
    }

    // 固定順序：同一組輸入在兩個平台上要得到同一份計畫，才比對得出差異。
    plan.upload.sort();
    plan.download.sort();
    plan.needs_attention.sort();
    plan
}

/// 這份計畫是否什麼都不用做。
#[uniffi::export]
pub fn sync_plan_is_empty(plan: SyncPlan) -> bool {
    plan.upload.is_empty() && plan.download.is_empty()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn e(path: &str, size: u64) -> SyncFileEntry {
        SyncFileEntry {
            path: path.into(),
            size,
        }
    }

    #[test]
    fn files_only_on_one_side_move_to_the_other() {
        let plan = plan_folder_sync(vec![e("a.oplog", 10)], vec![e("b.oplog", 20)]);
        assert_eq!(plan.upload, vec!["a.oplog"]);
        assert_eq!(plan.download, vec!["b.oplog"]);
    }

    #[test]
    fn identical_files_are_left_alone() {
        let plan = plan_folder_sync(vec![e("a.oplog", 10)], vec![e("a.oplog", 10)]);
        assert!(sync_plan_is_empty(plan));
    }

    #[test]
    fn the_longer_side_wins_because_append_only_means_superset() {
        // 這條推論是整個方案的地基。它成立的前提是「同一個檔名只有一台裝置在寫」。
        let plan = plan_folder_sync(
            vec![e("ink/p-aaaa.strokes", 500)],
            vec![e("ink/p-aaaa.strokes", 300)],
        );
        assert_eq!(plan.upload, vec!["ink/p-aaaa.strokes"]);
        assert!(plan.download.is_empty());

        let other = plan_folder_sync(
            vec![e("ink/p-aaaa.strokes", 300)],
            vec![e("ink/p-aaaa.strokes", 500)],
        );
        assert_eq!(other.download, vec!["ink/p-aaaa.strokes"]);
    }

    #[test]
    fn the_manifest_is_never_silently_overwritten() {
        // manifest.json 是整份覆寫的，不是 append-only —— 「比較長的是超集」
        // 對它不成立。默默挑一個的後果是另一台裝置改的標題無聲消失。
        let plan = plan_folder_sync(vec![e("manifest.json", 300)], vec![e("manifest.json", 200)]);
        assert!(plan.upload.is_empty());
        assert!(plan.download.is_empty());
        assert_eq!(plan.needs_attention, vec!["manifest.json"]);
    }

    #[test]
    fn a_manifest_that_only_exists_locally_is_uploaded() {
        let plan = plan_folder_sync(vec![e("manifest.json", 300)], vec![]);
        assert_eq!(plan.upload, vec!["manifest.json"]);
        assert!(plan.needs_attention.is_empty());
    }

    #[test]
    fn two_devices_ink_files_both_survive() {
        // 真正的多裝置情境：各自的筆畫檔在對方那裡都不存在，兩份都要過去。
        let plan = plan_folder_sync(
            vec![e("ink/p-11111111.strokes", 100)],
            vec![e("ink/p-22222222.strokes", 120)],
        );
        assert_eq!(plan.upload, vec!["ink/p-11111111.strokes"]);
        assert_eq!(plan.download, vec!["ink/p-22222222.strokes"]);
    }

    #[test]
    fn the_plan_is_deterministic() {
        // 兩個平台對同一組輸入必須得到同一份計畫，否則比對不出差異。
        let local = vec![e("z.oplog", 1), e("a.oplog", 1), e("m.oplog", 1)];
        let plan = plan_folder_sync(local, vec![]);
        assert_eq!(plan.upload, vec!["a.oplog", "m.oplog", "z.oplog"]);
    }

    #[test]
    fn an_empty_folder_pulls_everything() {
        // 第一次在新裝置上接上同步資料夾就是這個情況。
        let plan = plan_folder_sync(
            vec![],
            vec![e("manifest.json", 100), e("doc/ops/x.oplog", 50)],
        );
        assert_eq!(plan.download.len(), 2);
        assert!(plan.upload.is_empty());
    }

    #[test]
    fn a_remote_fragment_is_never_skipped_by_guessing() {
        // 舊版會跳過 0005（「它一定已經在本機的 0010 壓實檔裡」）。
        // 那個推論在本機沒下載過 0005 的時候是錯的，而錯的代價是
        // **永遠拿不到那幾筆操作**。寧可多下載幾 KB —— 套用是冪等的。
        let local = vec![e("doc/ops/0000000000000010-00000001.oplog", 1000)];
        let remote = vec![
            e("doc/ops/0000000000000005-00000001.oplog", 100),
            e("doc/ops/0000000000000010-00000001.oplog", 1000),
            e("doc/ops/0000000000000015-00000001.oplog", 1500),
        ];
        let plan = plan_folder_sync(local, remote);
        assert_eq!(
            plan.download,
            vec![
                "doc/ops/0000000000000005-00000001.oplog",
                "doc/ops/0000000000000015-00000001.oplog"
            ]
        );
    }
}
