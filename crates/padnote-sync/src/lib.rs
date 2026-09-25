//! 無伺服器同步引擎（`docs/architecture.md` §4、`format-spec.md` §7）。
//!
//! 收斂靠三條不變式，而非靠伺服器仲裁：
//! 1. 每台裝置只寫自己 `device_id` 的檔案 ⇒ 無跨裝置寫入競爭
//! 2. 檔案 append-only ⇒ 雲端硬碟不會判定為修改衝突
//! 3. CRDT 合併可交換且冪等 ⇒ 套用順序無關，最終一致
//!
//! ⇒ **檔案層級衝突在數學上不可能發生**（Dropbox/iCloud 的 "conflicted copy"）。

pub mod audit;
pub mod engine;
pub mod gate;
pub mod gdrive;
pub mod library;
pub mod local;
pub mod media_tombstone;
pub mod oplog;
pub mod order;
pub mod paths;
pub mod provider;
pub mod remote_index;
pub mod scheduler;
pub mod settings;

pub use audit::{CloudAudit, FileClass, audit, classify};
pub use engine::{PulledBatch, SyncCursors, SyncEngine};
pub use gate::{GateDecision, STALE_TAKEOVER_MS, SyncGate};
pub use gdrive::{DriveHttp, GDriveProvider, ReqwestDriveHttp};
pub use library::{INDEX_PATH, ItemKind, LibraryIndex, LibraryItem};
pub use local::LocalFolderProvider;
pub use media_tombstone::{MediaTombstone, MediaTombstones};
pub use oplog::{DeviceId, OplogName};
pub use order::active_first;
pub use paths::{
    canonical_id, canonical_name, canonical_path, is_canonical, notebook_audio_file,
    notebook_audio_prefix, notebook_blob_file, notebook_blobs_prefix, notebook_op_file,
    notebook_ops_prefix, notebook_root,
};
pub use provider::{CloudProvider, RemoteEntry, SyncError};
pub use remote_index::{RemoteFile, RemoteIndex};
pub use scheduler::{SyncOutcome, SyncScheduler, SyncTrigger};
pub use settings::{DefaultPen, DeviceSettings, Identity, SETTINGS_PATH, Stamped, SyncedSettings};
pub mod webrtc;
