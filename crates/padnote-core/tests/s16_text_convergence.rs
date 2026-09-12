//! **S-16：文字同步端到端驗證**
//!
//! S3 證明了筆畫能在無伺服器架構下收斂；這份測試對**文字**做同樣的事，
//! 而且是走完整路徑：CRDT → 二進位編碼 → 加密 → SyncEngine → 本機資料夾
//! → 拉取 → 解密 → 解碼 → 套用。
//!
//! 文字比筆畫難：筆畫只有「新增」與「墓碑」，位置是絕對座標；
//! 文字有「在某處插入」，併發編輯下位置會互相位移。

use padnote_core::crypto::Dek;
use padnote_core::doc::text::codec;
use padnote_core::doc::{TextCrdt, TextEditor, TextOp};
use padnote_core::sync::{DeviceId, LocalFolderProvider, SyncEngine};

/// 確定性 PRNG，讓失敗可重現。
struct Rng(u64);

impl Rng {
    fn next(&mut self) -> u64 {
        self.0 ^= self.0 >> 12;
        self.0 ^= self.0 << 25;
        self.0 ^= self.0 >> 27;
        self.0.wrapping_mul(0x2545_F491_4F6C_DD1D)
    }
    fn below(&mut self, n: usize) -> usize {
        if n == 0 {
            0
        } else {
            (self.next() % n as u64) as usize
        }
    }
}

/// 一台離線裝置：本地 CRDT + 尚未推送的操作。
struct Site {
    crdt: TextCrdt,
    editor: TextEditor,
    engine: SyncEngine<LocalFolderProvider>,
    unpushed: Vec<TextOp>,
}

impl Site {
    fn new(root: &std::path::Path, id: u32, dek: Dek) -> Self {
        Self {
            crdt: TextCrdt::new(),
            editor: TextEditor::new(id),
            engine: SyncEngine::new(LocalFolderProvider::new(root), DeviceId(id), Some(dek)),
            unpushed: Vec::new(),
        }
    }

    fn edit(&mut self, ops: Vec<TextOp>) {
        self.crdt.apply_all(ops.clone());
        self.unpushed.extend(ops);
    }

    fn push(&mut self) {
        if self.unpushed.is_empty() {
            return;
        }
        let bytes = codec::encode(&self.unpushed);
        self.engine.push(&bytes).expect("推送必須成功");
        self.unpushed.clear();
    }

    fn pull(&mut self) {
        for batch in self.engine.pull().expect("拉取必須成功") {
            let ops = codec::decode(&batch.payload).expect("解碼必須成功");
            // 讓本地時鐘追上遠端，避免產生撞號的 OpId
            for op in &ops {
                self.editor.observe(op.id());
            }
            self.crdt.apply_all(ops);
        }
    }
}

fn tmp(name: &str) -> std::path::PathBuf {
    let d = std::env::temp_dir().join(format!("padnote-s16-{name}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&d);
    std::fs::create_dir_all(&d).unwrap();
    d
}

const WORDS: [&str; 8] = [
    "線性",
    "代數",
    "特徵值",
    "矩陣",
    "rust",
    "CRDT",
    "。",
    "筆記",
];

#[test]
fn s16_three_sites_converge_after_300_concurrent_text_edits() {
    let root = tmp("converge");
    let dek = Dek::generate().unwrap();
    let mut rng = Rng(0xC0FF_EE00_1234_5678);

    let mut sites = [
        Site::new(&root, 0xA1, dek.clone()),
        Site::new(&root, 0xB2, dek.clone()),
        Site::new(&root, 0xC3, dek),
    ];

    let mut inserts = 0usize;
    let mut deletes = 0usize;

    for _ in 0..300 {
        let s = rng.below(3);

        match rng.below(10) {
            // 50% 插入
            0..=4 => {
                let len = sites[s].crdt.len();
                let at = rng.below(len + 1);
                let word = WORDS[rng.below(WORDS.len())];
                let ops = sites[s].editor.insert(&sites[s].crdt, at, word);
                inserts += ops.len();
                sites[s].edit(ops);
            }
            // 20% 刪除
            5..=6 => {
                let len = sites[s].crdt.len();
                if len > 0 {
                    let at = rng.below(len);
                    let count = 1 + rng.below(3.min(len - at));
                    let ops = sites[s].editor.delete(&sites[s].crdt, at, count);
                    deletes += ops.len();
                    sites[s].edit(ops);
                }
            }
            // 15% 推送
            7..=8 => sites[s].push(),
            // 15% 拉取
            _ => sites[s].pull(),
        }
    }

    // 收網：全部推送，然後反覆拉取直到穩定
    for s in &mut sites {
        s.push();
    }
    for _ in 0..3 {
        for s in &mut sites {
            s.pull();
        }
    }

    let a = sites[0].crdt.text();
    let b = sites[1].crdt.text();
    let c = sites[2].crdt.text();

    assert_eq!(a, b, "裝置 A 與 B 的文字未收斂");
    assert_eq!(b, c, "裝置 B 與 C 的文字未收斂");

    for (i, s) in sites.iter().enumerate() {
        assert_eq!(
            s.crdt.pending_count(),
            0,
            "裝置 {i} 仍有 {} 個操作卡在緩衝區 —— 代表有 op 遺失",
            s.crdt.pending_count()
        );
    }

    assert!(!a.is_empty(), "測試本身無效：沒有產生任何文字");
    eprintln!(
        "S-16 結果：300 次編輯 / 插入 {inserts} 字、刪除 {deletes} 字 / \
         最終長度 {} 字 / 三台文字完全一致 ✓",
        a.chars().count()
    );
}

#[test]
fn s16_offline_site_catches_up_with_all_text() {
    let root = tmp("offline");
    let dek = Dek::generate().unwrap();

    let mut online = Site::new(&root, 0xA1, dek.clone());
    let mut offline = Site::new(&root, 0xB2, dek);

    for word in ["第一段", "第二段", "第三段"] {
        let at = online.crdt.len();
        let ops = online.editor.insert(&online.crdt, at, word);
        online.edit(ops);
        online.push();
    }

    assert!(offline.crdt.is_empty(), "離線期間不該看到任何內容");
    offline.pull();

    assert_eq!(offline.crdt.text(), online.crdt.text());
    assert_eq!(offline.crdt.text(), "第一段第二段第三段");
}

#[test]
fn s16_concurrent_edit_at_the_same_spot_keeps_both() {
    // 兩人同時在同一位置打字，任何一方的輸入都不該消失。
    let root = tmp("samespot");
    let dek = Dek::generate().unwrap();

    let mut a = Site::new(&root, 0xA1, dek.clone());
    let mut b = Site::new(&root, 0xB2, dek);

    let base = a.editor.insert(&a.crdt, 0, "開始結束");
    a.edit(base);
    a.push();
    b.pull();
    assert_eq!(b.crdt.text(), "開始結束");

    // 兩邊同時在中間插入不同內容（互相看不見）
    let from_a = a.editor.insert(&a.crdt, 2, "AAA");
    a.edit(from_a);
    let from_b = b.editor.insert(&b.crdt, 2, "BBB");
    b.edit(from_b);

    a.push();
    b.push();
    a.pull();
    b.pull();

    assert_eq!(a.crdt.text(), b.crdt.text(), "必須收斂");
    assert!(a.crdt.text().contains("AAA"), "A 的輸入不得遺失");
    assert!(a.crdt.text().contains("BBB"), "B 的輸入不得遺失");
    assert!(a.crdt.text().starts_with("開始"));
    assert!(a.crdt.text().ends_with("結束"));
}

#[test]
fn s16_delete_and_insert_at_the_same_place_converge() {
    // 最容易不收斂的情境：A 刪掉一段，B 同時在那段中間插字。
    let root = tmp("delins");
    let dek = Dek::generate().unwrap();

    let mut a = Site::new(&root, 0xA1, dek.clone());
    let mut b = Site::new(&root, 0xB2, dek);

    let base = a.editor.insert(&a.crdt, 0, "abcdef");
    a.edit(base);
    a.push();
    b.pull();

    let del = a.editor.delete(&a.crdt, 1, 3); // A 刪掉 bcd
    a.edit(del);
    let ins = b.editor.insert(&b.crdt, 3, "XY"); // B 在 c 後面插入
    b.edit(ins);

    a.push();
    b.push();
    a.pull();
    b.pull();

    assert_eq!(a.crdt.text(), b.crdt.text(), "刪除與插入交錯必須收斂");
    assert_eq!(a.crdt.text(), "aXYef", "被刪的字消失，插入的字保留");
}

#[test]
fn s16_text_is_encrypted_on_disk() {
    let root = tmp("encrypted");
    let dek = Dek::generate().unwrap();
    let mut a = Site::new(&root, 0xA1, dek);

    let ops = a.editor.insert(&a.crdt, 0, "機密會議紀錄");
    a.edit(ops);
    a.push();

    let raw = std::fs::read(root.join("sync/000000a1/log-0.bin")).unwrap();
    let secret = "機密".as_bytes();
    assert!(
        !raw.windows(secret.len()).any(|w| w == secret),
        "明文不得出現在同步到雲端的檔案中"
    );
}
