//! **M0 / Spike S3：無伺服器同步收斂驗證**
//!
//! Go 門檻（`docs/roadmap.md`）：
//! > 500 次隨機併發編輯後，三台裝置狀態完全一致、0 個 conflicted copy、0 資料遺失
//!
//! 這是風險登記簿上唯一標「影響極高」的項目 —— 若無法達成，整個「用使用者自己的
//! 雲端硬碟同步」的架構就不成立，必須退回單主裝置模式。
//!
//! 模擬的是最惡劣的情況：三台裝置離線各自編輯、以隨機順序 flush 與 pull、
//! 且會刪除「從別台裝置學到的」筆畫（製造 Remove 先於 Add 抵達第三台的因果亂序）。

use padnote_core::ink::{
    InkPoint, InkRecord, Stroke, StrokeReader, StrokeWriter, Tool, materialize,
};
use padnote_core::sync::{CloudProvider, DeviceId, LocalFolderProvider, OplogName};
use padnote_core::{doc::NotebookTime, doc::Uuid, sync::oplog::LamportClock};
use std::collections::{BTreeSet, HashSet};

/// 確定性 PRNG，讓失敗可重現。
struct Rng(u64);

impl Rng {
    fn next(&mut self) -> u64 {
        // xorshift64*
        self.0 ^= self.0 >> 12;
        self.0 ^= self.0 << 25;
        self.0 ^= self.0 >> 27;
        self.0.wrapping_mul(0x2545_F491_4F6C_DD1D)
    }

    fn below(&mut self, n: usize) -> usize {
        (self.next() % n as u64) as usize
    }
}

/// 一台離線裝置。只寫自己 `device_id` 的檔案，永不碰別人的。
struct Device {
    id: DeviceId,
    clock: LamportClock,
    /// 尚未 flush 到雲端的本地記錄。
    pending: Vec<InkRecord>,
    /// 已套用的全部記錄（本地 + 已拉取的遠端）。
    applied: Vec<InkRecord>,
    /// 每個遠端檔案已讀取的位元組數，用於增量拉取。
    read_cursor: std::collections::HashMap<String, u64>,
}

impl Device {
    fn new(id: u32) -> Self {
        Self {
            id: DeviceId(id),
            clock: LamportClock::default(),
            pending: Vec::new(),
            applied: Vec::new(),
            read_cursor: Default::default(),
        }
    }

    fn edit(&mut self, r: InkRecord) {
        self.clock.tick();
        self.pending.push(r.clone());
        self.applied.push(r);
    }

    /// 把待寫記錄寫成一個**新的**檔案。檔名含 device_id ⇒ 不可能與他人衝突。
    fn flush(&mut self, cloud: &LocalFolderProvider) {
        if self.pending.is_empty() {
            return;
        }
        let name = OplogName::new(self.clock.value(), self.id);
        let mut w = StrokeWriter::new(Uuid::from_bytes([0xAB; 16]));
        for r in &self.pending {
            w.push(r);
        }
        cloud
            .put(&format!("ops/{name}"), w.as_bytes())
            .expect("flush 必須成功");
        self.pending.clear();
    }

    /// 拉取所有裝置（含自己）的檔案增量並套用。
    fn pull(&mut self, cloud: &LocalFolderProvider) {
        for entry in cloud.list("ops").expect("list 必須成功") {
            let already = self.read_cursor.get(&entry.path).copied().unwrap_or(0);
            if already >= entry.size {
                continue; // 已讀完，增量拉取跳過
            }
            let bytes = cloud.get_range(&entry.path, 0..entry.size).unwrap();
            let records = StrokeReader::new(&bytes)
                .expect("格式必須可解析")
                .read_all()
                .expect("不得有截斷");

            // 只套用尚未見過的記錄；CRDT 語意下重複套用也是安全的（冪等）。
            if already == 0 {
                if let Some(n) = OplogName::parse(entry.path.rsplit('/').next().unwrap()) {
                    self.clock.observe(n.lamport);
                }
                self.applied.extend(records);
            }
            self.read_cursor.insert(entry.path, entry.size);
        }
    }

    /// 目前可見的筆畫 id 集合。
    fn visible(&self) -> BTreeSet<Uuid> {
        materialize(&self.applied)
            .into_iter()
            .map(|s| s.id)
            .collect()
    }
}

fn new_stroke(rng: &mut Rng) -> Stroke {
    Stroke {
        id: Uuid::v7_from_parts(rng.next() % 1_000_000, rng.next()),
        started_at: NotebookTime::from_micros(rng.next() % 10_000_000),
        tool: Tool::BallPoint,
        color_rgba8: [0, 0, 0, 255],
        base_width: 2.0,
        points: vec![
            InkPoint::new(rng.next() as u16 as f32, rng.next() as u16 as f32, 0.5, 0),
            InkPoint::new(
                rng.next() as u16 as f32,
                rng.next() as u16 as f32,
                0.7,
                8_000,
            ),
        ],
    }
}

fn tmp_dir(name: &str) -> std::path::PathBuf {
    let d = std::env::temp_dir().join(format!("padnote-s3-{name}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&d);
    std::fs::create_dir_all(&d).unwrap();
    d
}

#[test]
fn s3_three_devices_converge_after_500_concurrent_edits() {
    let root = tmp_dir("converge");
    let cloud = LocalFolderProvider::new(&root);
    let mut rng = Rng(0xDEAD_BEEF_CAFE_1234);

    let mut devices = [Device::new(0xA1), Device::new(0xB2), Device::new(0xC3)];

    // 記錄每個曾被新增/刪除的筆畫，作為「預期結果」的獨立事實來源。
    let mut all_added: Vec<Uuid> = Vec::new();
    let mut all_removed: HashSet<Uuid> = HashSet::new();

    for _ in 0..500 {
        let d = rng.below(3);

        match rng.below(10) {
            // 60% 新增筆畫
            0..=5 => {
                let s = new_stroke(&mut rng);
                all_added.push(s.id);
                devices[d].edit(InkRecord::Add(s));
            }
            // 20% 刪除一個「自己看得到」的筆畫 —— 包含從別台學來的，
            // 藉此製造 Remove 先於 Add 抵達第三台的因果亂序。
            6..=7 => {
                let visible: Vec<Uuid> = devices[d].visible().into_iter().collect();
                if !visible.is_empty() {
                    let id = visible[rng.below(visible.len())];
                    all_removed.insert(id);
                    devices[d].edit(InkRecord::Remove(id));
                }
            }
            // 10% flush（上傳）
            8 => devices[d].flush(&cloud),
            // 10% pull（下載）
            _ => devices[d].pull(&cloud),
        }
    }

    // 收網：全部 flush，然後反覆 pull 直到不再有新變化。
    for d in &mut devices {
        d.flush(&cloud);
    }
    for _ in 0..3 {
        for d in &mut devices {
            d.pull(&cloud);
        }
    }

    // --- 門檻 1：三台狀態完全一致 ---
    let a = devices[0].visible();
    let b = devices[1].visible();
    let c = devices[2].visible();
    assert_eq!(a, b, "裝置 A 與 B 未收斂");
    assert_eq!(b, c, "裝置 B 與 C 未收斂");

    // --- 門檻 2：0 資料遺失 ---
    // 每一個新增過且未被刪除的筆畫，都必須出現在所有裝置上。
    let expected: BTreeSet<Uuid> = all_added
        .iter()
        .copied()
        .filter(|id| !all_removed.contains(id))
        .collect();
    assert_eq!(a, expected, "資料遺失或出現幽靈筆畫（J7 零容忍）");
    assert!(!expected.is_empty(), "測試本身無效：沒有產生任何筆畫");

    // --- 門檻 3：0 個 conflicted copy ---
    // 每個檔案的擁有者必須是檔名宣告的那台裝置，且檔名全域唯一。
    let files = cloud.list("ops").unwrap();
    let mut seen = HashSet::new();
    for f in &files {
        let name = f.path.rsplit('/').next().unwrap();
        assert!(
            !name.contains("conflict"),
            "出現衝突副本 {name} —— append-only 不變式被破壞"
        );
        let parsed = OplogName::parse(name).unwrap_or_else(|| panic!("非法檔名 {name}"));
        assert!(seen.insert(name.to_string()), "檔名重複：{name}");
        assert!(
            [0xA1, 0xB2, 0xC3].contains(&parsed.device.0),
            "未知裝置寫入：{name}"
        );
    }
    assert!(files.len() >= 3, "測試本身無效：檔案太少");

    eprintln!(
        "S3 結果：{} 次編輯 / 新增 {} 筆、刪除 {} 筆 / 最終可見 {} 筆 / \
         雲端 {} 個 oplog 檔 / conflicted copy 0 個 / 三台裝置一致 ✓",
        500,
        all_added.len(),
        all_removed.len(),
        a.len(),
        files.len()
    );
}

#[test]
fn s3_remove_arriving_before_add_still_converges() {
    // 最容易讓同步失去收斂性的情境，單獨固定為迴歸測試。
    let s = {
        let mut rng = Rng(7);
        new_stroke(&mut rng)
    };
    let id = s.id;

    let forward = vec![InkRecord::Add(s.clone()), InkRecord::Remove(id)];
    let reversed = vec![InkRecord::Remove(id), InkRecord::Add(s)];

    assert!(materialize(&forward).is_empty());
    assert!(
        materialize(&reversed).is_empty(),
        "套用順序改變結果 ⇒ 合併不可交換 ⇒ 同步無法收斂"
    );
}

#[test]
fn s3_offline_device_catches_up_without_loss() {
    // 一台裝置長期離線後重新上線，必須拿到全部歷史。
    let root = tmp_dir("offline");
    let cloud = LocalFolderProvider::new(&root);
    let mut rng = Rng(0x1234_5678);

    let mut online = Device::new(0xA1);
    let mut offline = Device::new(0xB2);

    let mut ids = Vec::new();
    for _ in 0..50 {
        let s = new_stroke(&mut rng);
        ids.push(s.id);
        online.edit(InkRecord::Add(s));
        online.flush(&cloud);
    }

    assert!(offline.visible().is_empty(), "離線期間不應看到任何東西");
    offline.pull(&cloud);

    assert_eq!(
        offline.visible(),
        ids.iter().copied().collect::<BTreeSet<_>>(),
        "重新上線後必須拿到全部 50 筆，一筆不漏"
    );
}
