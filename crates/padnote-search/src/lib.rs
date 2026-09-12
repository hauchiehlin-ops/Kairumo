//! 本機全文搜尋（功能 F3）。
//!
//! 索引來源涵蓋：打字文字、**錄音轉錄**、PDF 文字層、OCR 結果、**手寫辨識結果**。
//! 這是 Goodnotes「手寫搜尋」的對應能力，但多了轉錄內容 —— 競品沒有人做到。
//!
//! 索引位於 `index/`，屬**衍生資料，永不同步**（format-spec §2）。壞掉就重建，
//! 重建成本遠低於同步成本。
//!
//! ## 為什麼自己做而不直接上 Tantivy
//! 中文斷詞才是難點，不是倒排索引。這裡用 **bigram（二元組）**策略：
//! 不需要詞典、不需要模型、召回率高，且「特徵值」這種未登錄詞不會被切錯。
//! 代價是索引較大 —— 對本機單機搜尋完全可接受。
//! Tantivy 可在 P2 階段替換進來，介面（`SearchIndex`）不必改。

pub mod index;
pub mod tokenizer;

pub use index::{DocId, Hit, SearchIndex, Source};
pub use tokenizer::tokenize;
