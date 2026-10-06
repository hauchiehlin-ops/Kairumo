//! 圖學的立體輔助：草圖拉伸、三視圖與等角、隱藏線、剖面。
//!
//! 純幾何，不碰 UI、不碰檔案。兩個平台從 `padnote-core` 的 FFI 呼叫它，
//! 同一個立體在 Apple 與 Android 上畫出完全相同的線。

pub mod export3d;
pub mod geom;
pub mod glass;
pub mod glyph;
pub mod section;
pub mod sheet;
pub mod solid;
pub mod view;
