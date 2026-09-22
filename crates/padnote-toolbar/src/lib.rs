//! 工具列設定（工作項 S-49／S-261，需求 4）。
//!
//! 工具**全部模組化**，使用者自選顯示哪些。設計依據來自市調：
//! Goodnotes 的工具列是頂部固定且不可自訂，左撇子與橫向書寫時會擋手；
//! 而工具太多全部攤開又會佔掉書寫空間。
//!
//! ## 兩個原則
//! 1. **預設就是他現在看到的那一排** —— 不多也不少。精簡的工具列是好事，
//!    但那要由使用者自己按出來；新設定上線不能讓沒動過設定的人少掉幾支筆
//!    （見 [`tools::Tool::shown_by_default`]）。
//! 2. **設定可還原** —— 使用者改壞了要回得去（[`ToolbarConfig::reset`]）。
//!
//! ## 清單以出貨的工具列為準
//!
//! [`tools`] 的清單與核心畫面規格的 `editor.inktools` 一一對應。
//! 對不上的話，「自訂工具列」就會長成一個有一半開關控制不到東西的設定畫面
//! —— 詳見 [`tools`] 的模組說明。

pub mod config;
pub mod tools;

pub use config::{Placement, ToolbarConfig};
pub use tools::{Tool, ToolGroup, all_groups};
