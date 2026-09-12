//! oplog 檔名規則（`format-spec.md` §6.1）。
//!
//! ```text
//! <lamport:016x>-<device_id>.oplog
//! 例：0000000000001a2f-7c4e9b12.oplog
//! ```
//! Lamport 時戳前置且固定寬度 ⇒ **檔名字典序即因果序**，掃描目錄即得套用順序，
//! 不需要額外索引檔（少一個可能損毀的單點）。

use std::fmt;

/// 裝置識別碼，序列化為 8 個小寫 hex 字元。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash, Debug)]
pub struct DeviceId(pub u32);

impl fmt::Display for DeviceId {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{:08x}", self.0)
    }
}

/// 解析／產生 oplog 檔名。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub struct OplogName {
    pub lamport: u64,
    pub device: DeviceId,
}

impl OplogName {
    pub fn new(lamport: u64, device: DeviceId) -> Self {
        Self { lamport, device }
    }

    pub fn parse(name: &str) -> Option<Self> {
        let stem = name.strip_suffix(".oplog")?;
        let (l, d) = stem.split_once('-')?;
        if l.len() != 16 || d.len() != 8 {
            return None;
        }
        Some(Self {
            lamport: u64::from_str_radix(l, 16).ok()?,
            device: DeviceId(u32::from_str_radix(d, 16).ok()?),
        })
    }
}

impl fmt::Display for OplogName {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{:016x}-{}.oplog", self.lamport, self.device)
    }
}

/// Lamport 時鐘：在沒有共用時間來源的情況下建立因果序。
#[derive(Clone, Copy, Debug, Default)]
pub struct LamportClock(u64);

impl LamportClock {
    pub fn new(start: u64) -> Self {
        Self(start)
    }

    /// 本地事件：遞增。
    pub fn tick(&mut self) -> u64 {
        self.0 += 1;
        self.0
    }

    /// 收到遠端事件：取 max 後遞增，保證因果順序不被顛倒。
    pub fn observe(&mut self, remote: u64) -> u64 {
        self.0 = self.0.max(remote) + 1;
        self.0
    }

    pub fn value(self) -> u64 {
        self.0
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn name_roundtrips() {
        let n = OplogName::new(0x1a2f, DeviceId(0x7c4e9b12));
        assert_eq!(n.to_string(), "0000000000001a2f-7c4e9b12.oplog");
        assert_eq!(OplogName::parse(&n.to_string()), Some(n));
    }

    #[test]
    fn lexicographic_order_equals_causal_order() {
        // 固定寬度 hex 是這個性質的前提；少一位就會排錯。
        let mut names: Vec<String> = [3u64, 17, 2, 256, 1]
            .iter()
            .map(|&l| OplogName::new(l, DeviceId(1)).to_string())
            .collect();
        names.sort();

        let lamports: Vec<u64> = names
            .iter()
            .map(|n| OplogName::parse(n).unwrap().lamport)
            .collect();
        assert_eq!(
            lamports,
            [1, 2, 3, 17, 256],
            "檔名字典序必須等於 Lamport 序"
        );
    }

    #[test]
    fn rejects_malformed_names() {
        assert!(
            OplogName::parse("1a2f-7c4e9b12.oplog").is_none(),
            "寬度不足"
        );
        assert!(OplogName::parse("0000000000001a2f-7c4e9b12.bin").is_none());
        assert!(OplogName::parse("snapshot-3.automerge").is_none());
        assert!(OplogName::parse("zzzzzzzzzzzzzzzz-7c4e9b12.oplog").is_none());
    }

    #[test]
    fn observe_never_goes_backwards() {
        let mut c = LamportClock::new(5);
        assert_eq!(c.observe(3), 6, "遠端較舊時仍須前進");
        assert_eq!(c.observe(100), 101, "遠端較新時須追上並前進");
        assert_eq!(c.tick(), 102);
    }

    #[test]
    fn two_devices_never_collide_on_filename() {
        // 同一 Lamport 值、不同裝置 ⇒ 不同檔名 ⇒ 雲端不會產生 conflicted copy。
        let a = OplogName::new(42, DeviceId(0xAAAA_AAAA)).to_string();
        let b = OplogName::new(42, DeviceId(0xBBBB_BBBB)).to_string();
        assert_ne!(a, b);
    }
}
