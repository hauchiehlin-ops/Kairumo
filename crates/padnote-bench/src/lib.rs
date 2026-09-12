//! 準確度與效能迴歸基準。
//!
//! - **ASR**：對自建中文測試集計算 CER，作為 CI 門檻（M0/S2）
//! - **墨跡**：motion-to-photon 延遲基準，不得回退（J1）
//!
//! 測試集是本專案最有價值、競品也抄不走的資產之一：Goodnotes 可以抄 UI，
//! 抄不走你手上的台灣口音教室錄音與標註。

pub mod cer;
pub mod report;

pub use cer::{cer, edit_distance};
pub use report::{Scenario, ScoreReport, Utterance, parse_tsv};
