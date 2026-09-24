//! 一輪同步裡「先做哪一本」——**使用者正在看的那一本要先到**。
//!
//! # 為什麼這件事值得一個模組
//!
//! 同步一輪要跑完所有有差異的筆記本。順序若是隨意的，使用者正在編輯的
//! 那一本可能排在第二十本 —— 他在另一台裝置上寫的那一行，要等前面十九本
//! 都傳完才會出現。**「即時」是使用者對當下這一本的體感**，不是整輪的總時間。
//!
//! 資料夾同步那邊早就有這個概念（「前台極速軌」），Drive 這邊沒有：
//! Android 有排序但**只有編輯器裡的手動同步會傳作用中的 id**，自動同步
//! 那條完全沒傳；Apple 連這個概念都沒有。於是最該即時的那條路徑
//! （自動同步 + 正在編輯）反而沒有享受到它。
//!
//! 規則放在核心，兩端才會是同一套。各寫一份的話，使用者感覺到的不是
//! 「策略不同」，是「Android 比較慢」。

/// 把作用中的筆記本排到最前面，其餘維持原本的相對順序。
///
/// **穩定排序**：其餘的順序不變。不穩定的話，每一輪的順序都不一樣，
/// 「為什麼這一本每次都最後才到」這種問題就變得無法重現。
///
/// `active` 是 `None`（沒有開著任何一本）時原樣回傳。
pub fn active_first<T: AsRef<str> + Clone>(ids: &[T], active: Option<&str>) -> Vec<T> {
    let Some(active) = active else {
        return ids.to_vec();
    };
    let mut out: Vec<T> = Vec::with_capacity(ids.len());
    // 比對前兩邊都正規化 —— 雲端路徑一律是小寫 ASCII，而本機的 id 可能
    // 含大寫（舊資料）。不正規化的話，一本大寫 id 的筆記本永遠插不了隊，
    // 而症狀只是「有時候比較慢」，沒有人會去查。
    let want = crate::paths::canonical_id(active);
    for id in ids {
        if crate::paths::canonical_id(id.as_ref()) == want {
            out.push(id.clone());
        }
    }
    for id in ids {
        if crate::paths::canonical_id(id.as_ref()) != want {
            out.push(id.clone());
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_active_notebook_goes_first() {
        let ids = ["a", "b", "c"];
        assert_eq!(active_first(&ids, Some("c")), ["c", "a", "b"]);
    }

    #[test]
    fn everything_else_keeps_its_order() {
        let ids = ["a", "b", "c", "d"];
        assert_eq!(active_first(&ids, Some("b")), ["b", "a", "c", "d"]);
    }

    #[test]
    fn no_active_notebook_changes_nothing() {
        let ids = ["a", "b", "c"];
        assert_eq!(active_first(&ids, None), ["a", "b", "c"]);
    }

    #[test]
    fn an_active_id_that_is_not_in_the_list_changes_nothing() {
        let ids = ["a", "b"];
        assert_eq!(active_first(&ids, Some("zzz")), ["a", "b"]);
    }

    /// 舊資料的 id 可能含大寫。不正規化的話它永遠插不了隊，
    /// 而症狀只是「有時候比較慢」—— 沒有人會去查。
    #[test]
    fn an_uppercase_active_id_still_jumps_the_queue() {
        let ids = ["aaa", "696f43c5", "bbb"];
        assert_eq!(
            active_first(&ids, Some("696F43C5")),
            ["696f43c5", "aaa", "bbb"]
        );
    }

    #[test]
    fn nothing_is_lost_or_duplicated() {
        let ids = ["a", "b", "c", "d", "e"];
        let out = active_first(&ids, Some("d"));
        assert_eq!(out.len(), ids.len());
        let mut sorted = out.clone();
        sorted.sort_unstable();
        assert_eq!(sorted, ["a", "b", "c", "d", "e"]);
    }
}
