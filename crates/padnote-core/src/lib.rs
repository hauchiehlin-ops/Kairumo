//! Padnote 核心門面。各平台外殼（Swift / Kotlin）透過此 crate 的 UniFFI
//! 介面存取所有業務邏輯。
//!
//! 架構：`docs/architecture.md`。UI 與墨跡渲染以外的一切都在這裡，
//! 因此「跨平台功能對等」是架構保證，而非靠紀律維持。

pub use padnote_asr as asr;
pub use padnote_doc as doc;
pub use padnote_ink as ink;
pub use padnote_recognize as recognize;
pub use padnote_sync as sync;

/// 本 build 所實作的 `.padnote` 格式版本（`format-spec.md` §3）。
pub const SPEC_VERSION: u32 = 1;

/// 可讀取的最低格式版本。低於此者必須拒絕開啟，絕不猜測解析。
pub const MIN_READER_VERSION: u32 = 1;

/// 讀取器是否能安全開啟這份筆記本（`format-spec.md` §8）。
pub fn can_open(spec_version: u32, min_reader_version: u32) -> bool {
    min_reader_version <= SPEC_VERSION && spec_version >= MIN_READER_VERSION
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn opens_current_version() {
        assert!(can_open(SPEC_VERSION, MIN_READER_VERSION));
    }

    #[test]
    fn forward_compatible_when_reader_version_allows() {
        // 未來版本但宣告舊讀取器仍可解析 ⇒ 允許，忽略未知欄位。
        assert!(can_open(99, 1));
    }

    #[test]
    fn refuses_when_file_demands_newer_reader() {
        // 靜默解析會造成資料損毀，寧可拒絕開啟。
        assert!(!can_open(99, 99));
    }
}
