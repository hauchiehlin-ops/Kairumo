//! 頁碼重新對齊：插入、刪除、搬動之後，附著在頁面上的東西要落在哪一頁。
//!
//! # 為什麼在核心
//!
//! Apple 端有九種附件（圖片、文字、連結、3D、註解釘、錄音、表格、形狀、
//! 連接線），每一種原本各自寫一份「這一頁之後的往後移一格」。新增型別時
//! 沒有人記得回來補，於是插入一頁之後，那一頁後面的表格與形狀留在原本的
//! 頁碼上 —— 畫面上看起來是「我插了一頁，我的表格跑到別頁去了」。
//!
//! 而 Android 端要做同一件事時，會再手抄一份。所以**索引的算術只寫一次**，
//! 兩邊的平台層只負責把每一種型別餵進來。
//!
//! 索引一律由 0 起算。

/// 在 `at` 插入一頁之後，原本在 `index` 的東西落在哪一頁。
///
/// 插入點**之後**（含插入點本身）的往後移一格；之前的不動。
#[uniffi::export]
pub fn page_index_after_insert(index: u32, at: u32) -> u32 {
    if index >= at {
        index + 1
    } else {
        index
    }
}

/// 把第 `from` 頁搬到第 `to` 頁之後，原本在 `index` 的東西落在哪一頁。
///
/// # 為什麼不是「加一減一」就好
///
/// 往後搬與往前搬的區間不對稱。第 1 頁搬到第 3 頁，中間的 2、3 各往前移
/// 一格；第 3 頁搬到第 1 頁，中間的 1、2 各往後移一格。寫成同一條式子的
/// 人會在其中一個方向上差一格 —— 而差一格的症狀是「搬完之後有兩頁長得
/// 一樣、少了一頁」，很難一眼看出是哪一邊錯。
#[uniffi::export]
pub fn page_index_after_move(index: u32, from: u32, to: u32) -> u32 {
    if from == to {
        return index;
    }
    if index == from {
        return to;
    }
    if from < to {
        // 往後搬：被跨過的區間 (from, to] 整段往前遞補一格。
        if index > from && index <= to {
            index - 1
        } else {
            index
        }
    } else {
        // 往前搬：被跨過的區間 [to, from) 整段往後讓一格。
        if index >= to && index < from {
            index + 1
        } else {
            index
        }
    }
}

/// 這個搬動要不要做。
///
/// 超出範圍或原地不動都回 false —— 平台層拿到 false 就整個跳過，
/// 不必各自再判斷一次「搬到自己身上」這種邊界。
#[uniffi::export]
pub fn page_move_is_valid(count: u32, from: u32, to: u32) -> bool {
    count > 1 && from < count && to < count && from != to
}

/// 搬動時實際會被改到的頁碼範圍（含頭含尾）。
///
/// 平台層只要把這段區間內的筆跡檔案重寫一次就夠了 —— 整本重寫在幾十頁
/// 的筆記上是看得到的卡頓，而搬一頁只會動到兩個端點之間那一段。
#[uniffi::export]
pub fn page_move_touched_range(from: u32, to: u32) -> Vec<u32> {
    let lo = from.min(to);
    let hi = from.max(to);
    (lo..=hi).collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn inserting_pushes_everything_from_the_insert_point_onwards() {
        // 在第 1 頁插入：0 不動，1 之後全部往後一格。
        assert_eq!(page_index_after_insert(0, 1), 0);
        assert_eq!(page_index_after_insert(1, 1), 2);
        assert_eq!(page_index_after_insert(5, 1), 6);
        // 插在最後面，前面的全部不動。
        assert_eq!(page_index_after_insert(0, 9), 0);
    }

    #[test]
    fn moving_backwards_and_forwards_are_not_mirror_images() {
        // 第 1 頁搬到第 3 頁：1→3，2→1，3→2，其餘不動。
        assert_eq!(page_index_after_move(1, 1, 3), 3);
        assert_eq!(page_index_after_move(2, 1, 3), 1);
        assert_eq!(page_index_after_move(3, 1, 3), 2);
        assert_eq!(page_index_after_move(0, 1, 3), 0);
        assert_eq!(page_index_after_move(4, 1, 3), 4);

        // 第 3 頁搬到第 1 頁：3→1，1→2，2→3，其餘不動。
        assert_eq!(page_index_after_move(3, 3, 1), 1);
        assert_eq!(page_index_after_move(1, 3, 1), 2);
        assert_eq!(page_index_after_move(2, 3, 1), 3);
        assert_eq!(page_index_after_move(0, 3, 1), 0);
        assert_eq!(page_index_after_move(4, 3, 1), 4);
    }

    #[test]
    fn moving_a_page_is_a_permutation_never_a_duplicate() {
        // 每一種搬動都必須是重排：n 頁進去、n 個不重複的頁碼出來。
        // 少了這一條，差一格的錯誤會表現成「兩頁疊在同一個頁碼上」，
        // 而其中一頁的內容就這樣消失了。
        let n = 6u32;
        for from in 0..n {
            for to in 0..n {
                let mut seen: Vec<u32> = (0..n).map(|i| page_index_after_move(i, from, to)).collect();
                seen.sort_unstable();
                let expected: Vec<u32> = (0..n).collect();
                assert_eq!(seen, expected, "from={from} to={to} 不是重排");
            }
        }
    }

    #[test]
    fn moving_to_itself_changes_nothing() {
        for i in 0..5 {
            assert_eq!(page_index_after_move(i, 2, 2), i);
        }
        assert!(!page_move_is_valid(5, 2, 2));
    }

    #[test]
    fn a_one_page_notebook_cannot_reorder() {
        assert!(!page_move_is_valid(1, 0, 0));
        assert!(!page_move_is_valid(3, 3, 0));
        assert!(!page_move_is_valid(3, 0, 7));
        assert!(page_move_is_valid(3, 0, 2));
    }

    #[test]
    fn the_touched_range_covers_both_ends_in_either_direction() {
        assert_eq!(page_move_touched_range(1, 3), vec![1, 2, 3]);
        assert_eq!(page_move_touched_range(3, 1), vec![1, 2, 3]);
        assert_eq!(page_move_touched_range(2, 2), vec![2]);
    }
}
