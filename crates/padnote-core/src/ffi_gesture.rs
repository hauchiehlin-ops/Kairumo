//! 畫布的手勢規則：一指做什麼、兩指做什麼、可以縮放到多大。
//!
//! # 為什麼在核心
//!
//! 使用者的回報是「在手機上手指沒辦法捲動，也沒辦法縮放」。查下去發現
//! 兩邊的成因不同，而**兩邊都不是設定錯了，是根本沒做**：
//!
//! - Apple：`PKCanvasView` 的 `minimumZoomScale` / `maximumZoomScale`
//!   從頭到尾沒有設定過，預設兩者都是 1.0 —— 捏合手勢在任何裝置上
//!   都不會有反應。
//! - Android：整頁模式的畫布是一個固定的 `Box`，既不捲動也不縮放。
//!   連續模式因為外面包了 `LazyColumn` 才勉強捲得動。
//!
//! 各補各的話，兩邊會長出兩套「一指到底是畫還是平移」的規則，而那是
//! 使用者**每一秒都在用**的東西。所以規則寫在這裡。

/// 一根手指放上去會發生什麼事。
#[derive(Clone, Copy, PartialEq, Eq, Debug, uniffi::Enum)]
pub enum FfiFingerAction {
    /// 畫線。
    Draw,
    /// 平移畫布。
    Pan,
}

/// 目前誰能畫。與 `PalmRejection` / `penOnly` 開關對應。
#[derive(Clone, Copy, PartialEq, Eq, Debug, uniffi::Enum)]
pub enum FfiInkPolicy {
    /// 手指與筆都能畫。
    AnyInput,
    /// 只有觸控筆能畫。
    StylusOnly,
}

/// 編輯器模式。
#[derive(Clone, Copy, PartialEq, Eq, Debug, uniffi::Enum)]
pub enum FfiEditorMode {
    /// 手寫。
    Draw,
    /// 打字與物件編輯。
    Type,
}

/// 這個狀態下的手勢規則。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiCanvasGesture {
    /// 一根手指。
    pub one_finger: FfiFingerAction,
    /// 兩根手指永遠是平移 —— 這一條沒有例外，所以不用欄位表示。
    /// 這裡放的是「兩指能不能縮放」。
    pub pinch_zoom: bool,
    /// 縮放下限。比 1 小才看得到整頁。
    pub min_zoom: f32,
    /// 縮放上限。
    pub max_zoom: f32,
    /// 連按兩下要縮放到多少（再按一次回到 1.0）。
    pub double_tap_zoom: f32,
}

/// 縮放範圍。
///
/// 下限 0.5：A4 比例的頁面在手機上要看得到整頁，就得縮到一半以下。
/// 上限 4.0：再大就只是把筆跡的鋸齒放大，沒有實際用途，而且記憶體會爆。
const MIN_ZOOM: f32 = 0.5;
const MAX_ZOOM: f32 = 4.0;
const DOUBLE_TAP_ZOOM: f32 = 2.0;

/// 這個模式與輸入政策下，手勢該怎麼分工。
///
/// # 一指到底是畫還是平移
///
/// **看「手指現在能不能畫」**：
///
/// - 手指能畫（`AnyInput`）→ 一指畫線。要平移就用兩指。
///   這是沒有觸控筆的人唯一能寫字的方式。
/// - 只有筆能畫（`StylusOnly`，或剛用過筆的自動掌拒）→ **一指平移**。
///   這時手指不負責畫線，讓它去做捲動是它唯一有意義的用途 ——
///   而原本的行為是「一指什麼也不做」，使用者按下去畫面完全不動，
///   看起來就像畫布卡住了。
/// - 打字模式 → 一指平移。手指要用來捲動與選取物件。
#[uniffi::export]
pub fn canvas_gesture(mode: FfiEditorMode, ink: FfiInkPolicy) -> FfiCanvasGesture {
    let one_finger = match (mode, ink) {
        (FfiEditorMode::Draw, FfiInkPolicy::AnyInput) => FfiFingerAction::Draw,
        _ => FfiFingerAction::Pan,
    };
    FfiCanvasGesture {
        one_finger,
        // 縮放永遠開著。它與「誰能畫」無關 —— 兩指捏合不會被誤認成筆畫。
        pinch_zoom: true,
        min_zoom: MIN_ZOOM,
        max_zoom: MAX_ZOOM,
        double_tap_zoom: DOUBLE_TAP_ZOOM,
    }
}

/// 多根手指一次點下或滑動時要做什麼。
#[derive(Clone, Copy, PartialEq, Eq, Debug, uniffi::Enum)]
pub enum FfiMultiFingerAction {
    /// 沒有對應的動作 —— 什麼都不做。
    None,
    Undo,
    Redo,
    PrevPage,
    NextPage,
}

/// N 根手指點一下要做什麼。
///
/// # 為什麼這張表要在核心
///
/// 這四個動作原本**只有 Apple 有**，而且是直接寫在
/// `NotebookEditorView` 裡的四個 `@objc` 方法 —— Android 一個都沒有。
/// 使用者的回報是「手指操作畫布的設計無法落地」，而在 Android 上那句話
/// 是字面意義的真：雙指點了沒有復原，三指滑了不會翻頁。
///
/// 規則不在核心，兩端就不可能對齊 —— 這四個動作與「一指是畫還是平移」
/// 一樣是使用者的肌肉記憶，在兩台裝置上不一樣比兩台都沒有更糟。
///
/// 一根手指不在這裡：那是畫線或平移，由 [`canvas_gesture`] 決定。
#[uniffi::export]
pub fn finger_tap_action(fingers: u8) -> FfiMultiFingerAction {
    match fingers {
        2 => FfiMultiFingerAction::Undo,
        3 => FfiMultiFingerAction::Redo,
        _ => FfiMultiFingerAction::None,
    }
}

/// N 根手指往上／往下滑要做什麼。
///
/// 三指上滑是**下一頁**：內容跟著手指往上走，下一頁從底下進來 ——
/// 與捲動的方向感一致。四指以上不給動作，那通常是手掌放上去。
#[uniffi::export]
pub fn finger_swipe_action(fingers: u8, upwards: bool) -> FfiMultiFingerAction {
    match (fingers, upwards) {
        (3, true) => FfiMultiFingerAction::NextPage,
        (3, false) => FfiMultiFingerAction::PrevPage,
        _ => FfiMultiFingerAction::None,
    }
}

/// 把縮放值夾在允許範圍內。
///
/// 兩端各自 `coerceIn` 的話，其中一邊寫錯常數不會有人發現 ——
/// 症狀是「同一本筆記在另一台上縮不了那麼小」。
#[uniffi::export]
pub fn clamp_zoom(scale: f32) -> f32 {
    if scale.is_nan() {
        return 1.0;
    }
    scale.clamp(MIN_ZOOM, MAX_ZOOM)
}

/// 縮放後，平移量的允許範圍（單邊）。
///
/// 縮到比視窗小的時候不該還能拖走 —— 那會讓使用者把頁面拖出畫面外，
/// 然後找不回來。回傳 0 表示「置中、不給拖」。
#[uniffi::export]
pub fn max_pan_offset(content: f32, viewport: f32, scale: f32) -> f32 {
    let scaled = content * scale;
    if scaled <= viewport {
        0.0
    } else {
        (scaled - viewport) / 2.0
    }
}

#[cfg(test)]
mod tests {
    use super::{FfiMultiFingerAction, finger_swipe_action, finger_tap_action};

    #[test]
    fn two_and_three_finger_taps_are_undo_and_redo() {
        assert_eq!(finger_tap_action(2), FfiMultiFingerAction::Undo);
        assert_eq!(finger_tap_action(3), FfiMultiFingerAction::Redo);
    }

    #[test]
    fn one_finger_has_no_tap_action() {
        // 一指是畫線或平移，由 `canvas_gesture` 決定 —— 在這裡給它一個
        // 動作的話，每畫一筆都會順便復原一次。
        assert_eq!(finger_tap_action(1), FfiMultiFingerAction::None);
    }

    #[test]
    fn four_or_more_fingers_do_nothing() {
        // 四指以上通常是手掌放上去。給它動作的話，使用者把手靠在螢幕上
        // 就會莫名其妙翻頁。
        for n in 4..=10 {
            assert_eq!(finger_tap_action(n), FfiMultiFingerAction::None, "{n} 指");
            assert_eq!(
                finger_swipe_action(n, true),
                FfiMultiFingerAction::None,
                "{n} 指"
            );
        }
    }

    #[test]
    fn three_finger_swipe_turns_pages_in_the_scroll_direction() {
        // 上滑是下一頁：內容跟著手指往上走，下一頁從底下進來。
        assert_eq!(finger_swipe_action(3, true), FfiMultiFingerAction::NextPage);
        assert_eq!(
            finger_swipe_action(3, false),
            FfiMultiFingerAction::PrevPage
        );
    }

    #[test]
    fn two_finger_swipe_is_not_a_page_turn() {
        // 兩指是平移與縮放 —— 平移途中順手翻頁是最糟的誤觸。
        assert_eq!(finger_swipe_action(2, true), FfiMultiFingerAction::None);
        assert_eq!(finger_swipe_action(2, false), FfiMultiFingerAction::None);
    }

    use super::*;

    #[test]
    fn a_finger_draws_only_when_it_is_allowed_to() {
        assert_eq!(
            canvas_gesture(FfiEditorMode::Draw, FfiInkPolicy::AnyInput).one_finger,
            FfiFingerAction::Draw
        );
    }

    #[test]
    fn a_finger_that_cannot_draw_pans_instead_of_doing_nothing() {
        // 原本的行為是「一指什麼也不做」—— 使用者按下去畫面完全不動，
        // 看起來像畫布卡住了。這是這次回報的主要症狀。
        assert_eq!(
            canvas_gesture(FfiEditorMode::Draw, FfiInkPolicy::StylusOnly).one_finger,
            FfiFingerAction::Pan
        );
        assert_eq!(
            canvas_gesture(FfiEditorMode::Type, FfiInkPolicy::AnyInput).one_finger,
            FfiFingerAction::Pan
        );
        assert_eq!(
            canvas_gesture(FfiEditorMode::Type, FfiInkPolicy::StylusOnly).one_finger,
            FfiFingerAction::Pan
        );
    }

    #[test]
    fn pinch_zoom_is_always_available() {
        // 縮放與「誰能畫」無關：兩指捏合不會被誤認成筆畫。
        for mode in [FfiEditorMode::Draw, FfiEditorMode::Type] {
            for ink in [FfiInkPolicy::AnyInput, FfiInkPolicy::StylusOnly] {
                let g = canvas_gesture(mode, ink);
                assert!(g.pinch_zoom, "{mode:?}/{ink:?} 少了縮放");
                assert!(g.min_zoom < 1.0, "縮不到比一頁還小就看不到整頁");
                assert!(g.max_zoom > 1.0);
            }
        }
    }

    #[test]
    fn zoom_is_clamped_and_survives_garbage() {
        assert_eq!(clamp_zoom(0.1), MIN_ZOOM);
        assert_eq!(clamp_zoom(99.0), MAX_ZOOM);
        assert_eq!(clamp_zoom(1.5), 1.5);
        // 兩指手勢在某些裝置上會算出 NaN（兩指落在同一點）。
        // 不擋的話畫布會整個消失，而且再也回不來。
        assert_eq!(clamp_zoom(f32::NAN), 1.0);
    }

    #[test]
    fn you_cannot_drag_a_page_smaller_than_the_window_off_screen() {
        assert_eq!(max_pan_offset(800.0, 1000.0, 1.0), 0.0);
        assert_eq!(max_pan_offset(800.0, 1000.0, 0.5), 0.0);
        // 放大到 2 倍：1600 寬、視窗 1000 → 單邊可以拖 300。
        assert_eq!(max_pan_offset(800.0, 1000.0, 2.0), 300.0);
    }
}
