//! 準確度與效能迴歸基準。
//!
//! - ASR：對自建中文測試集計算 CER，作為 CI 門檻（M0/S2）
//! - 墨跡：motion-to-photon 延遲基準，不得回退（J1）
//!
//! TODO(M0)：接上測試集後啟用 CI 閘門。

pub mod cer;
