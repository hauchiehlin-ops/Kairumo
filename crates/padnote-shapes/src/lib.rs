//! 形狀、連接線與流程圖範本（工作項 S-47）。
//!
//! ## 為什麼連接線要「連」而不只是「畫」
//! 流程圖的價值在於線會跟著圖形走。把箭頭畫成獨立的線，移動方塊時線就斷了 ——
//! 那只是畫圖，不是流程圖。因此 [`Connection`] 存的是「從哪個圖形的哪個
//! 連接點到哪個」，路徑在渲染時才算。
//!
//! ## 為什麼用標準符號
//! 流程圖符號有標準語意（ISO 5807）：菱形＝判斷、平行四邊形＝輸入輸出。
//! 使用者看得懂才有意義，因此不自創圖形，並在 UI 顯示
//! [`ShapeKind::semantic`] 的說明。

pub mod connector;
pub mod shape;
pub mod template;

pub use connector::{Connection, EndCap, RouteStyle, arrow_head};
pub use shape::{Anchor, Shape, ShapeKind};
pub use template::{Template, TemplateNode, builtin_templates};
