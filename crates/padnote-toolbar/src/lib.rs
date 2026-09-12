//! 工具列設定（工作項 S-49，需求 4）。
//!
//! 工具**全部模組化**，使用者自選顯示哪些。設計依據來自市調：
//! Goodnotes 的工具列是頂部固定且不可自訂，左撇子與橫向書寫時會擋手；
//! 而工具太多全部攤開又會佔掉書寫空間。
//!
//! ## 兩個原則
//! 1. **預設精簡** —— 新使用者看到的是最常用的一組，不是全部。
//!    工具列塞滿反而找不到東西。
//! 2. **設定可還原** —— 使用者改壞了要回得去（[`ToolbarConfig::reset`]）。

pub mod config;
pub mod tools;

pub use config::{Placement, ToolbarConfig};
pub use tools::{Tool, ToolGroup, all_groups};
