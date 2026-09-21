//! `.padnote` 套件的讀寫（`docs/format-spec.md` §2、§3）。
//!
//! 目錄式套件而非單一二進位檔，理由是**資料主權**：使用者可以直接用檔案總管
//! 進去看、用腳本解析、用任何同步工具搬運。這是 H4 承諾的技術實現。

pub mod atomic;
pub mod blob;
pub mod manifest;
pub mod package;

pub use atomic::write_atomic;
pub use blob::{BlobId, BlobStore};
pub use manifest::{Encryption, Manifest};
pub use package::{
    CompactOutcome, CompactResult, NotebookPackage, StorageError, archive_package, extract_package,
};
