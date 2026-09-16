//! 無伺服器同步引擎（`docs/architecture.md` §4、`format-spec.md` §7）。
//!
//! 收斂靠三條不變式，而非靠伺服器仲裁：
//! 1. 每台裝置只寫自己 `device_id` 的檔案 ⇒ 無跨裝置寫入競爭
//! 2. 檔案 append-only ⇒ 雲端硬碟不會判定為修改衝突
//! 3. CRDT 合併可交換且冪等 ⇒ 套用順序無關，最終一致
//!
//! ⇒ **檔案層級衝突在數學上不可能發生**（Dropbox/iCloud 的 "conflicted copy"）。

pub mod engine;
pub mod gdrive;
pub mod library;
pub mod local;
pub mod oplog;
pub mod provider;
pub mod settings;

pub use engine::{PulledBatch, SyncCursors, SyncEngine};
pub use gdrive::{DriveHttp, GDriveProvider, ReqwestDriveHttp};
pub use library::{INDEX_PATH, ItemKind, LibraryIndex, LibraryItem};
pub use local::LocalFolderProvider;
pub use oplog::{DeviceId, OplogName};
pub use provider::{CloudProvider, RemoteEntry, SyncError};
pub use settings::{DefaultPen, DeviceSettings, Identity, SETTINGS_PATH, Stamped, SyncedSettings};
