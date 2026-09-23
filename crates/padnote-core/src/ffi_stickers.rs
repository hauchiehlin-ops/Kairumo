//! 內建貼紙庫。
//!
//! # 為什麼原本是空的
//!
//! 貼紙庫一直只存**使用者自己存下來的**筆跡 —— 沒有任何內建內容。
//! 第一次打開它的人看到的是一片空白加一句「還沒有貼紙」，而他根本不知道
//! 要怎麼生出第一張。一個要使用者先餵資料才有用的功能，等於沒有。
//!
//! # 為什麼是自己畫的向量
//!
//! 這個專案**完全開源、完全免費**。市面上的貼紙包幾乎都有授權限制，
//! 抄進來就是把授權問題埋進產品。畫成向量另外還有三個好處：兩端算繪
//! 同一份資料、縮放不糊、跟著主題配色走。
//!
//! 圖形本體在 `sticker_shapes.rs`，與素材線圖共用同一組 `Builder`。

// 與素材線圖共用同一組 `Builder` 與小工具 —— 複製一份的話，兩邊的
// 圓角、貝茲近似值會慢慢漂開，而那是使用者看得到的。
use crate::ffi_asset_art::{Builder, FfiDrawPath, FfiPathVerb, curve_seg, m, seg};

include!("sticker_shapes.rs");

/// 貼紙畫在多大的方格裡。
///
/// 100 而不是素材線圖的 400：貼紙小得多，用同一個尺度的話每個座標都要
/// 除以四，而除錯時心算除法是會出錯的。
#[uniffi::export]
pub fn sticker_canvas_size() -> f32 {
    100.0
}

/// 一個貼紙分類。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiStickerCategory {
    /// 穩定 id（`annotate`、`task`…）。
    pub id: String,
    /// 分類名稱的語系鍵。
    pub title_key: String,
    /// 這一類的貼紙代號，依顯示順序。
    pub codes: Vec<String>,
}

/// 全部分類。
///
/// **依「使用者想做什麼」分，不是依圖形長相分。** 依長相分的話
/// （圓形類、箭頭類）使用者得先知道自己要找什麼形狀，
/// 而他心裡想的是「我要標一個重點」。
#[uniffi::export]
pub fn sticker_categories() -> Vec<FfiStickerCategory> {
    CATALOGUE
        .iter()
        .map(|(id, codes)| FfiStickerCategory {
            id: (*id).to_string(),
            title_key: format!("sticker_cat_{id}"),
            codes: codes.iter().map(|c| (*c).to_string()).collect(),
        })
        .collect()
}

/// 全部貼紙代號（不分類）。搜尋與「最近使用」用得到。
#[uniffi::export]
pub fn sticker_codes() -> Vec<String> {
    CATALOGUE
        .iter()
        .flat_map(|(_, codes)| codes.iter().map(|c| (*c).to_string()))
        .collect()
}

/// 一張貼紙的路徑。認不得的代號回一個空心圓，**不是空清單**。
#[uniffi::export]
pub fn sticker_drawing(code: String) -> Vec<FfiDrawPath> {
    draw_sticker(&code)
}

/// 貼紙名稱的語系鍵。
#[uniffi::export]
pub fn sticker_label_key(code: String) -> String {
    format!("sticker_{code}")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn every_code_draws_something() {
        // 一格空白的貼紙，使用者分不出是沒畫好還是壞掉了。
        for code in sticker_codes() {
            assert!(
                !sticker_drawing(code.clone()).is_empty(),
                "{code} 畫不出任何東西"
            );
        }
    }

    #[test]
    fn codes_are_unique_across_categories() {
        // 代號同時是查圖與查名稱的鍵 —— 重複的話，兩個分類會畫出同一張。
        let mut all = sticker_codes();
        let before = all.len();
        all.sort();
        all.dedup();
        assert_eq!(before, all.len(), "有重複的貼紙代號");
    }

    #[test]
    fn an_unknown_code_is_a_placeholder_not_an_empty_grid() {
        assert!(!sticker_drawing("no_such_sticker".into()).is_empty());
    }

    #[test]
    fn every_sticker_fits_inside_the_canvas() {
        // 超出方格的座標會被裁掉一角，而那在小尺寸的格子裡看起來像畫錯了。
        let size = sticker_canvas_size();
        for code in sticker_codes() {
            for path in sticker_drawing(code.clone()) {
                for s in path.segs {
                    for (v, name) in [(s.x, "x"), (s.y, "y")] {
                        assert!(
                            (-2.0..=size + 2.0).contains(&v),
                            "{code} 的 {name}={v} 跑出 0..{size} 的方格"
                        );
                    }
                }
            }
        }
    }

    #[test]
    fn there_are_enough_stickers_to_be_useful() {
        // 「內建貼紙」只有五張的話，使用者第一次打開還是會覺得它是空的。
        assert!(
            sticker_codes().len() >= 30,
            "實得 {}",
            sticker_codes().len()
        );
        assert!(sticker_categories().len() >= 5);
    }

    #[test]
    fn categories_are_named_by_purpose() {
        // 分類 id 是給程式用的，但它也是語系鍵的一部分 ——
        // 改了就是改文案的鍵，所以釘住。
        let ids: Vec<String> = sticker_categories().into_iter().map(|c| c.id).collect();
        assert_eq!(ids, ["annotate", "task", "mood", "label", "study", "flow"]);
    }
}
