//! 匯出（功能 H1–H4）。
//!
//! 這是「**資料被綁架**」這個全行業痛點的正面回應。競品幾乎都是黑箱格式、
//! 匯出受限（MyScript 甚至只能存自家雲）。Padnote 的立場是：
//! 使用者隨時可以把資料完整帶走。

pub mod markdown;
pub mod svg;

pub use markdown::{MarkdownOptions, to_markdown};
pub use svg::stroke_to_svg_path;
