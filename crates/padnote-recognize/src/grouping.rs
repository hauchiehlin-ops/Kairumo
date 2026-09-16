//! 依書寫停頓把筆畫分組（WP7）。
//!
//! # 為什麼要分組
//!
//! 逐筆送去辨識的話中文會整個垮掉 —— 一個字往往是好幾筆。整頁一次送則會把
//! 相隔很遠的兩段內容硬湊成一句。用**停頓**切是最接近人怎麼寫字的切法。
//!
//! # 為什麼在核心
//!
//! 這一段原本只有 Kotlin 版（`Handwriting.group`），Apple 端根本沒有手寫辨識。
//! 要補 Apple 就得再寫一份，而兩份「怎麼算停頓」遲早會不一樣 ——
//! 症狀是同一頁筆記在 iPad 上辨識成「週會記錄」、在 Android 上成了
//! 「週會」「記錄」兩組，搜尋結果因此不同。辨識引擎各平台不同是沒辦法的事
//! （ML Kit / Vision），但**切法**沒有理由不同。

/// 書寫停頓多久算換一組。
///
/// 700ms 是**起點值**，不是量出來的。需要用真實書寫節奏在實機上調整
/// （`docs/TODO.md` A-10）。訂太短會把一個詞切成兩組，訂太長會把兩句話黏起來。
pub const DEFAULT_GAP_MS: u64 = 700;

/// 一組要一起送去辨識的筆畫。
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct StrokeGroup {
    /// 這一組包含哪幾筆（核心的筆畫 id），順序即書寫順序。
    pub stroke_ids: Vec<String>,
}

/// 分組用的一筆畫：id、落筆時刻、書寫時長。
///
/// 只帶時間，不帶座標 —— 分組只看時間。把整份取樣點搬進來只會讓
/// 跨 FFI 的成本變高，而那些點在這裡一個也用不到。
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct StrokeTiming {
    pub id: String,
    /// 落筆時刻（毫秒）。
    pub started_at_ms: u64,
    /// 這一筆寫了多久（毫秒）。
    pub duration_ms: u64,
}

/// 依停頓分組。輸入須依書寫順序。
///
/// 停頓算的是「**上一筆結束**到這一筆開始」，不是兩個落筆時刻的差 ——
/// 後者會把「寫得久的一長筆」誤判成停頓，一個「一」字寫慢一點就被切開。
pub fn group_by_pause(strokes: &[StrokeTiming], gap_ms: u64) -> Vec<StrokeGroup> {
    let mut out: Vec<StrokeGroup> = Vec::new();
    let mut current: Vec<String> = Vec::new();

    for (i, stroke) in strokes.iter().enumerate() {
        if i > 0 {
            let previous = &strokes[i - 1];
            let previous_end = previous.started_at_ms.saturating_add(previous.duration_ms);
            // 用 saturating_sub：時間戳偶爾會倒退（時鐘調整、不同來源的
            // 事件交錯）。相減溢位會變成一個天文數字，於是每一筆都自成一組。
            if stroke.started_at_ms.saturating_sub(previous_end) > gap_ms && !current.is_empty() {
                out.push(StrokeGroup {
                    stroke_ids: std::mem::take(&mut current),
                });
            }
        }
        current.push(stroke.id.clone());
    }
    if !current.is_empty() {
        out.push(StrokeGroup {
            stroke_ids: current,
        });
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    fn s(id: &str, start: u64, duration: u64) -> StrokeTiming {
        StrokeTiming {
            id: id.into(),
            started_at_ms: start,
            duration_ms: duration,
        }
    }

    #[test]
    fn strokes_written_together_stay_together() {
        // 一個中文字是好幾筆，中間幾乎沒有停頓。
        let groups = group_by_pause(
            &[s("a", 0, 100), s("b", 120, 90), s("c", 250, 80)],
            DEFAULT_GAP_MS,
        );
        assert_eq!(groups.len(), 1);
        assert_eq!(groups[0].stroke_ids, ["a", "b", "c"]);
    }

    #[test]
    fn a_long_pause_starts_a_new_group() {
        let groups = group_by_pause(&[s("a", 0, 100), s("b", 2000, 100)], DEFAULT_GAP_MS);
        assert_eq!(groups.len(), 2);
        assert_eq!(groups[0].stroke_ids, ["a"]);
        assert_eq!(groups[1].stroke_ids, ["b"]);
    }

    #[test]
    fn the_gap_is_measured_from_the_end_of_the_previous_stroke() {
        // 這是整個演算法唯一容易寫錯的地方：用兩個「落筆時刻」相減的話，
        // 一筆寫得久（例如慢慢寫一個「一」）就會被當成停頓而切開。
        //
        // 這一筆從 0 寫到 1000，下一筆 1200 開始 —— 中間只停了 200ms。
        let groups = group_by_pause(&[s("long", 0, 1000), s("next", 1200, 50)], DEFAULT_GAP_MS);
        assert_eq!(groups.len(), 1, "寫得久不等於停頓");
    }

    #[test]
    fn exactly_at_the_threshold_is_still_the_same_group() {
        // 門檻用「大於」而不是「大於等於」：剛好等於門檻時不切，
        // 兩邊實作若一個用 > 一個用 >=，同一份筆記會分出不同的組。
        let groups = group_by_pause(&[s("a", 0, 0), s("b", DEFAULT_GAP_MS, 0)], DEFAULT_GAP_MS);
        assert_eq!(groups.len(), 1);
    }

    #[test]
    fn an_empty_page_produces_no_groups() {
        assert!(group_by_pause(&[], DEFAULT_GAP_MS).is_empty());
    }

    #[test]
    fn a_single_stroke_is_one_group() {
        let groups = group_by_pause(&[s("only", 42, 10)], DEFAULT_GAP_MS);
        assert_eq!(groups.len(), 1);
        assert_eq!(groups[0].stroke_ids, ["only"]);
    }

    #[test]
    fn time_going_backwards_does_not_explode_into_one_group_per_stroke() {
        // 時間戳偶爾會倒退（時鐘調整、不同來源的事件交錯）。
        // 直接相減會溢位成天文數字，於是每一筆都自成一組 ——
        // 中文就會變成逐筆辨識，完全認不出來。
        let groups = group_by_pause(&[s("a", 1000, 50), s("b", 200, 50)], DEFAULT_GAP_MS);
        assert_eq!(groups.len(), 1);
    }

    #[test]
    fn a_zero_gap_puts_every_stroke_in_its_own_group() {
        // 門檻可調，極端值也要有明確行為。
        let groups = group_by_pause(&[s("a", 0, 0), s("b", 1, 0), s("c", 2, 0)], 0);
        assert_eq!(groups.len(), 3);
    }

    #[test]
    fn grouping_preserves_writing_order() {
        // 順序錯掉的話，辨識出來的字序也會錯。
        let groups = group_by_pause(
            &[
                s("1", 0, 10),
                s("2", 20, 10),
                s("3", 5000, 10),
                s("4", 5020, 10),
            ],
            DEFAULT_GAP_MS,
        );
        assert_eq!(groups.len(), 2);
        assert_eq!(groups[0].stroke_ids, ["1", "2"]);
        assert_eq!(groups[1].stroke_ids, ["3", "4"]);
    }
}
