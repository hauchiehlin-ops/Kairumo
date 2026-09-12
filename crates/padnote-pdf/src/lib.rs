//! PDF 匯入、標註與渲染（功能 E1–E3）。
//!
//! **效能是這裡的功能需求，不是最佳化。** 市調顯示「大 PDF 卡頓閃退」是
//! Goodnotes 評論區最高頻的負評。效能預算（J2）：500 頁開啟 ≤1.5s、捲動 60fps。
//!
//! 引擎用 **PDFium (BSD-3)**。❌ 絕不使用 MuPDF —— AGPL 會污染整個 App
//! （決策 D6，已在 `deny.toml` 封鎖）。
//!
//! 本 crate 只定義介面與快取策略；PDFium 綁定屬原生相依，見 `docs/TODO.md` S-10。

pub mod cache;
pub mod document;

pub use cache::{PageCache, RenderKey};
pub use document::{PdfDocument, PdfError, PdfPage, TextSpan};
