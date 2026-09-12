//! 輸入仲裁與掌拒（工作項 S-36，ADR-0007）。
//!
//! 手寫 App 若沒有掌拒，使用者把手掌靠在螢幕上寫字會畫出大片塗鴉 ——
//! 這是產品的生死線，不是體驗優化。
//!
//! ## 為什麼仲裁邏輯在 Rust core 而不在平台層
//! 掌拒的判準是**靠真實使用調出來的經驗值**，會不斷修改。
//! 邏輯若散在 Swift 與 Kotlin，兩邊必然長歪，而且無法寫測試 ——
//! 而這種靠經驗值調的東西**最需要迴歸測試**。
//!
//! 平台層只做一件事：把原始指標事件轉成 [`PointerEvent`] 餵進來。
//! 分類與採納由 [`PointerArbiter`] 決定。
//!
//! ## 最難的情況：手掌先落、筆後落
//! 使用者的自然動作是**手掌先碰到螢幕，筆才落下**。此時手掌那一筆
//! 已經開始畫了。因此仲裁器必須能**事後撤銷**——
//! [`Decision::retract`] 會列出要收回的筆畫 id。
//!
//! 沒有這個機制，掌拒只能擋住「筆之後」的誤觸，擋不住最常見的那一種。

pub mod arbiter;
pub mod pressure;

pub use arbiter::{
    ArbiterConfig, Decision, InputMode, Phase, PointerArbiter, PointerEvent, PointerKind, Verdict,
};
pub use pressure::{PressureAction, PressureCurve};
