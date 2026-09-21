//! Padnote 核心門面。
//!
//! 各平台外殼（Swift / Kotlin）**只透過這一層**存取業務邏輯。
//! UI 與墨跡渲染以外的一切都在 Rust core，因此「跨平台功能對等」是架構保證，
//! 而非靠紀律維持。
//!
//! TODO(S-11)：以 UniFFI 產生 Swift / Kotlin 綁定。

uniffi::setup_scaffolding!();

pub mod app;
pub mod ffi;
pub mod ffi_account_sync;
pub mod ffi_asr;
pub mod ffi_asset_art;
pub mod ffi_assets;
mod ffi_audio;
pub mod ffi_backup;
pub mod ffi_chart;
pub mod ffi_collab;
pub mod ffi_folder_sync;
pub mod ffi_gdrive;
pub mod ffi_geometry;
pub mod ffi_gesture;
pub mod ffi_guides;
pub mod ffi_hwr;
pub mod ffi_input;
pub mod ffi_interop;
pub mod ffi_layout;
pub mod ffi_link;
pub mod ffi_llm;
pub mod ffi_math;
pub mod ffi_model3d;
pub mod ffi_models;
pub mod ffi_oauth;
pub mod ffi_pages;
pub mod ffi_paper;
#[cfg(feature = "relay")]
pub mod ffi_relay;
pub mod ffi_scheduler;
pub mod ffi_screens;
pub mod ffi_shapes;
pub mod ffi_sketch;
pub mod ffi_symbols;
pub mod ffi_table;
pub mod ffi_texture;
pub mod ffi_theme_tools;
pub mod ffi_ui;
pub mod setup;
pub mod transcript;

pub use padnote_asr as asr;
pub use padnote_chart as chart;
pub use padnote_crypto as crypto;
pub use padnote_doc as doc;
pub use padnote_embed as embed;
pub use padnote_export as export;
pub use padnote_i18n as i18n;
pub use padnote_ink as ink;
pub use padnote_input as input;
pub use padnote_models as models;
pub use padnote_pdf as pdf;
#[cfg(feature = "asr-onnx")]
pub use padnote_punct_ct as punct_ct;
pub use padnote_recognize as recognize;
pub use padnote_recorder as recorder;
pub use padnote_search as search;
pub use padnote_shapes as shapes;
pub use padnote_storage as storage;
pub use padnote_sync as sync;
pub use padnote_table as table;
pub use padnote_text as text;
pub use padnote_toolbar as toolbar;
#[cfg(feature = "asr-onnx")]
pub use padnote_vad_silero as vad;

pub use app::{AppError, NotebookSession, RecordingState};
pub use setup::{Capability, Feature, FeatureReadiness, SetupAction, SetupCenter, Status};
pub use transcript::TranscriptPostProcessor;

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
        assert!(can_open(99, 1));
    }

    #[test]
    fn refuses_when_file_demands_newer_reader() {
        assert!(!can_open(99, 99));
    }
}
