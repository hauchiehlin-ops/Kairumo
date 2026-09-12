//! 文件模型與**統一時間軸**。
//!
//! 時間軸是 `docs/format-spec.md` §4 的核心約定：筆畫、文字編輯、錄音、
//! 轉錄詞全部以同一個 `NotebookTime` 座標系定位。C1（筆跡↔錄音跳轉）、
//! C4（詞級時間戳）、A10（筆跡重播）、B6（版本回溯）都建立在這之上。

pub mod document;
pub mod text;
pub mod timeline;
pub mod uuid;

pub use document::{Block, BlockKind, LayoutMode, Notebook, Page, PageTemplate, TextStyle};
pub use text::{OpId, TextCrdt, TextEditor, TextOp};
pub use timeline::{AudioSession, NotebookTime, Timeline, TranscriptWord};
pub use uuid::Uuid;
