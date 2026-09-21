//! 音訊錄製與編碼（工作項 S-13，功能 C3/C6）。
//!
//! **音檔永遠先落地**（`architecture.md` §6.2 第一原則）。轉錄是衍生物，
//! 失敗可無限重試；音訊掉了就永遠回不來 —— 這是 Notability 最大差評的來源。
//!
//! 編碼用 **libopus（BSD-3）**。語音在 24–32 kbps 就有很好的品質：
//! 一小時錄音約 14 MB，而同樣長度的未壓縮 16kHz PCM 是 115 MB。

pub mod decoder;
pub mod encoder;
pub mod ogg;

pub use decoder::{OggOpusDecoder, decode_ogg_opus};
pub use encoder::{AudioError, OpusEncoder, VOICE_BITRATE};
pub use ogg::{OggOpusWriter, ogg_opus_duration_us};
