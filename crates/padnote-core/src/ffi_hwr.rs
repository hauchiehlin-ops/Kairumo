//! 手寫辨識的分組（WP7 / S-22）。
//!
//! 分組規則在 [`padnote_recognize::grouping`]，兩個平台共用。
//! **辨識引擎本身留在平台層**（Apple Vision / ML Kit Digital Ink）——
//! 那是作業系統提供的能力，核心搬不進來；但「怎麼把筆畫切成一組一組」
//! 沒有理由兩邊不同，切法不同會讓同一頁筆記在兩台裝置上搜到不一樣的東西。

use padnote_recognize::grouping::{DEFAULT_GAP_MS, StrokeTiming, group_by_pause};

/// 分組用的一筆畫。只帶時間 —— 分組不看座標，把取樣點搬過 FFI 是白費。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiStrokeTiming {
    pub id: String,
    pub started_at_ms: u64,
    pub duration_ms: u64,
}

/// 一組要一起送去辨識的筆畫。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiStrokeGroup {
    pub stroke_ids: Vec<String>,
}

/// 預設的停頓門檻（毫秒）。
///
/// 700 是起點值，不是量出來的；實機調整見 `docs/TODO.md` A-10。
#[uniffi::export]
pub fn hwr_default_gap_ms() -> u64 {
    DEFAULT_GAP_MS
}

/// 依書寫停頓分組。輸入須依書寫順序。
#[uniffi::export]
pub fn hwr_group_strokes(strokes: Vec<FfiStrokeTiming>, gap_ms: u64) -> Vec<FfiStrokeGroup> {
    let input: Vec<StrokeTiming> = strokes
        .into_iter()
        .map(|s| StrokeTiming {
            id: s.id,
            started_at_ms: s.started_at_ms,
            duration_ms: s.duration_ms,
        })
        .collect();
    group_by_pause(&input, gap_ms)
        .into_iter()
        .map(|g| FfiStrokeGroup {
            stroke_ids: g.stroke_ids,
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn s(id: &str, start: u64, duration: u64) -> FfiStrokeTiming {
        FfiStrokeTiming {
            id: id.into(),
            started_at_ms: start,
            duration_ms: duration,
        }
    }

    #[test]
    fn the_split_survives_the_ffi() {
        // 換型別時把時長當成結束時刻（或反過來），停頓就全算錯 ——
        // 而那在核心的單元測試裡看不到。
        let groups = hwr_group_strokes(
            vec![s("a", 0, 1000), s("b", 1200, 50), s("c", 5000, 50)],
            hwr_default_gap_ms(),
        );
        assert_eq!(groups.len(), 2);
        assert_eq!(groups[0].stroke_ids, ["a", "b"]);
        assert_eq!(groups[1].stroke_ids, ["c"]);
    }

    #[test]
    fn an_empty_page_is_empty_not_a_crash() {
        assert!(hwr_group_strokes(Vec::new(), hwr_default_gap_ms()).is_empty());
    }

    #[test]
    fn the_default_gap_matches_the_core() {
        // 平台層若自己寫死 700，核心調整門檻時就會不同步。
        assert_eq!(hwr_default_gap_ms(), 700);
    }
}
