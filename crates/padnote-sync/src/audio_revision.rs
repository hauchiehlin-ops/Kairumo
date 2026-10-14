//! Immutable, content-addressed audio revisions shared by every client.
use sha2::{Digest, Sha256};

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct AudioRevision {
    pub recording: String,
    pub lamport: u64,
    pub device: u32,
    pub hash: String,
    pub duration_us: u64,
}

pub fn content_hash(bytes: &[u8]) -> String {
    format!("{:x}", Sha256::digest(bytes))
}

impl AudioRevision {
    pub fn marker_name(&self) -> String {
        format!(
            "{}-{:016x}-{:08x}-{}-{:016x}.rev",
            self.recording, self.lamport, self.device, self.hash, self.duration_us
        )
    }

    pub fn parse(name: &str) -> Option<Self> {
        let stem = name.strip_suffix(".rev")?;
        let (prefix, duration) = stem.rsplit_once('-')?;
        let (prefix, hash) = prefix.rsplit_once('-')?;
        let (prefix, device) = prefix.rsplit_once('-')?;
        let (recording, lamport) = prefix.rsplit_once('-')?;
        if !recording.ends_with(".opus")
            || hash.len() != 64
            || !hash.bytes().all(|b| b.is_ascii_hexdigit())
        {
            return None;
        }
        Some(Self {
            recording: recording.to_string(),
            lamport: u64::from_str_radix(lamport, 16).ok()?,
            device: u32::from_str_radix(device, 16).ok()?,
            hash: hash.to_ascii_lowercase(),
            duration_us: u64::from_str_radix(duration, 16).ok()?,
        })
    }
}
