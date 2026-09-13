//! 圖表的資料模型與版面計算。
//!
//! # 為什麼在核心
//!
//! 圖表是「資料 + 樣式 → 幾何」，那是純邏輯。各平台自己畫一份的話，同一組
//! 數字在 iPad 與 Android 上會長得不一樣 —— 軸的刻度不同、長條的寬度不同、
//! 圓餅的起始角不同。使用者看到的是「我的圖變了」。
//!
//! 所以這裡算出**所有幾何**（長條的矩形、折線的頂點、扇形的角度、刻度位置、
//! 圖例與資料標籤的落點），平台層只負責把這些形狀畫出來。
//!
//! # 為什麼可以重新編修
//!
//! 圖表以 [`ChartSpec`] 的形式保存，而不是保存一張算繪好的圖。使用者再打開
//! 時拿到的是原始資料與樣式，改完重畫即可 —— 保存圖片的話，那張圖就是
//! 最終產物，資料再也回不來。

mod layout;
mod spec;

pub use layout::{
    ChartLayout, GridLine, LayoutError, LegendEntry, PieSlice, PlotBar, PlotPoint, PlotPolyline,
    TextAlign, TextLabel, TickMark, estimate_text_width, layout,
};
pub use spec::{
    AxisSpec, ChartKind, ChartSpec, DEFAULT_PALETTE, LabelPosition, LegendPosition, Series,
    SpecError, palette_color,
};
