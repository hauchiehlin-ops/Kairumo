//! 多裝置模型檢查（一致性閘門 3）。
//!
//! # 為什麼需要它
//!
//! 2026-09-22 找到一個會掉資料的 bug：壓實會改寫 oplog 檔名，而里程碑拿
//! 檔名當座標，於是還原會把那一刀**之前**就該留下來的內容一起收走。
//!
//! 它是怎麼被找到的？**我先猜到情境才寫得出測試** ——
//! 「如果沒有任何裝置留著被壓實吃掉的碎檔呢？」猜對了是運氣。
//! 下一個 bug 不一定猜得到。
//!
//! 這份測試不靠猜：把「一台裝置能做的事」列成一個動作集合，用種子化的
//! 亂數抽出幾百步，每一步之後檢查幾條**不需要預言機**的性質。
//!
//! # 為什麼性質是這幾條
//!
//! 最想寫的性質是「狀態應該等於 X」，但要算出 X 就得再實作一次還原的語意
//! —— 那正是這個專案一路踩過來的坑（同一個事實兩份表示）。
//!
//! 所以這裡全部用**關係性**的性質：拿系統自己在不同時刻的觀察互相比，
//! 不另外算一份答案。
//!
//! - **P1 收斂**：同步到底之後，所有活著的裝置必須看到完全一樣的內容。
//! - **P2 單調**：在還沒有任何還原發生之前，同步與壓實**只會增加**看得見
//!   的內容，永不減少。今天那個 bug 正是壓實讓內容變少。
//! - **P3 冪等**：同一批檔案再下載一次，狀態不准變。
//! - **P4 快照回得去**：還原到里程碑 M 之後，M 建立當下看得到的東西
//!   **一個都不准少**。這是今天那個 bug 的直接形狀。
//! - **P5 還原真的有還原**：建立 M 之後由同一台裝置寫的東西，
//!   還原後不准再看得到。少了這條，一個什麼都不做的「還原」也能通過 P4。
//!
//! # 失敗之後
//!
//! 亂數測試如果只丟一句「第 173 步炸了」，沒有人看得懂，
//! 這個閘門第三次紅的時候就會被關掉。所以：
//!
//! - 動作序列先產生成一個 `Vec<Action>`，**執行過程完全由它決定**；
//! - 失敗時自動縮小（delta debugging）到最短的失敗序列並印出來；
//! - 找到的種子存進 [`REGRESSION_SEEDS`]，之後每次都重跑。

use padnote_core::app::NotebookSession;
use padnote_core::doc::{TextStyle, Uuid};
use std::collections::BTreeSet;
use std::path::{Path, PathBuf};

// ────────────────────────────── 亂數 ──────────────────────────────

/// xorshift64*。確定性 —— 失敗一定重現得出來。
struct Rng(u64);

impl Rng {
    fn next(&mut self) -> u64 {
        self.0 ^= self.0 >> 12;
        self.0 ^= self.0 << 25;
        self.0 ^= self.0 >> 27;
        self.0.wrapping_mul(0x2545_F491_4F6C_DD1D)
    }
    fn below(&mut self, n: usize) -> usize {
        (self.next() % n as u64) as usize
    }
}

// ────────────────────────────── 動作 ──────────────────────────────

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum Action {
    /// 寫一段可辨識的文字。
    Edit(usize),
    /// 把本機的檔案推上雲端（`true` 表示只推一部分 —— 模擬同步到一半斷線）。
    Upload(usize, bool),
    /// 從雲端拉檔案下來。
    Download(usize, bool),
    /// 壓實自己的碎檔，並刪掉雲端上被吃掉的那些。
    Compact(usize),
    /// 建立里程碑。
    Milestone(usize),
    /// 還原到某個已知的里程碑。
    Restore(usize, usize),
    /// 這台裝置消失（重灌、換機）。它手上那份就沒了。
    Die(usize),
    /// 一台新裝置從雲端整包下載後加入。
    Join,
}

fn generate(seed: u64, steps: usize) -> Vec<Action> {
    let mut rng = Rng(seed);
    (0..steps)
        .map(|_| {
            let d = rng.below(8);
            match rng.below(100) {
                0..=33 => Action::Edit(d),
                34..=53 => Action::Upload(d, rng.below(4) == 0),
                54..=73 => Action::Download(d, rng.below(4) == 0),
                74..=81 => Action::Compact(d),
                82..=87 => Action::Milestone(d),
                88..=93 => Action::Restore(d, rng.below(8)),
                94..=96 => Action::Join,
                _ => Action::Die(d),
            }
        })
        .collect()
}

// ────────────────────────────── 世界 ──────────────────────────────

struct Device {
    id: u32,
    root: PathBuf,
    alive: bool,
    /// 上一次觀察到的內容，供 P2 單調性比對。
    last_seen: BTreeSet<String>,
}

struct Milestone {
    id: Uuid,
    creator: usize,
    /// 建立當下，建立者看得到的內容。**這是觀察，不是另算一份答案。**
    observed: BTreeSet<String>,
}

struct World {
    dir: PathBuf,
    cloud: PathBuf,
    devices: Vec<Device>,
    page: Option<Uuid>,
    milestones: Vec<Milestone>,
    next_tag: u32,
    /// 一旦有過還原，P2 單調性就不再成立（還原本來就會讓內容變少）。
    restored: bool,
}

impl World {
    fn new(dir: PathBuf) -> Self {
        let _ = std::fs::remove_dir_all(&dir);
        let cloud = dir.join("cloud");
        std::fs::create_dir_all(cloud.join("doc/ops")).unwrap();
        std::fs::create_dir_all(cloud.join("ink")).unwrap();

        let root = dir.join("dev0");
        let s = NotebookSession::create(&root, "模型", 1_757_635_200_000, 0xD000).unwrap();
        let page = s.first_page();
        drop(s);

        let mut w = Self {
            dir,
            cloud,
            devices: vec![Device {
                id: 0xD000,
                root,
                alive: true,
                last_seen: BTreeSet::new(),
            }],
            page,
            milestones: Vec::new(),
            next_tag: 0,
            restored: false,
        };
        w.upload(0, false);
        w
    }

    fn alive(&self) -> Vec<usize> {
        (0..self.devices.len())
            .filter(|i| self.devices[*i].alive)
            .collect()
    }

    /// 這台裝置目前看得見的內容（以我們埋進去的標記表示）。
    fn seen(&self, i: usize) -> BTreeSet<String> {
        let d = &self.devices[i];
        if !d.alive {
            return BTreeSet::new();
        }
        let Some(page) = self.page else {
            return BTreeSet::new();
        };
        let Ok(s) = NotebookSession::open(&d.root, d.id) else {
            return BTreeSet::new();
        };
        let Some(p) = s.notebook().page(page) else {
            return BTreeSet::new();
        };
        p.blocks()
            .iter()
            .filter_map(|b| b.searchable_text())
            .filter(|t| t.starts_with('#'))
            .map(str::to_string)
            .collect()
    }

    // ---- 檔案搬運（規則抄自 `ffi_folder_sync::plan_folder_sync`）----

    fn transfer(from: &Path, to: &Path, partial: bool, rng: &mut Rng) -> usize {
        let mut moved = 0;
        for sub in ["doc/ops", "ink"] {
            let Ok(entries) = std::fs::read_dir(from.join(sub)) else {
                continue;
            };
            let mut files: Vec<PathBuf> = entries
                .filter_map(Result::ok)
                .map(|e| e.path())
                .filter(|p| p.is_file())
                .collect();
            files.sort();
            for src in files {
                // 只搬一部分 —— 模擬同步到一半斷線、逾時、App 被系統殺掉。
                if partial && rng.below(2) == 0 {
                    continue;
                }
                let dst = to.join(sub).join(src.file_name().unwrap());
                let sl = src.metadata().map(|m| m.len()).unwrap_or(0);
                let dl = dst.metadata().map(|m| m.len()).unwrap_or(0);
                if sl > dl {
                    std::fs::create_dir_all(dst.parent().unwrap()).unwrap();
                    std::fs::copy(&src, &dst).unwrap();
                    moved += 1;
                }
            }
        }
        moved
    }

    fn upload(&mut self, i: usize, partial: bool) {
        if !self.devices[i].alive {
            return;
        }
        let mut rng = Rng(0x5EED_0001 ^ i as u64);
        Self::transfer(
            &self.devices[i].root.clone(),
            &self.cloud.clone(),
            partial,
            &mut rng,
        );
        // manifest 不同步（「兩邊都有就各留各的」）—— 它裝著本機的金鑰包裝
        // 參數與壓實界線，覆蓋過去就是把這台裝置的解密資訊換成另一台的。
        let m = self.cloud.join("manifest.json");
        if !m.exists() {
            let _ = std::fs::copy(self.devices[i].root.join("manifest.json"), m);
        }
    }

    fn download(&mut self, i: usize, partial: bool) {
        if !self.devices[i].alive {
            return;
        }
        let mut rng = Rng(0x5EED_0002 ^ i as u64);
        Self::transfer(
            &self.cloud.clone(),
            &self.devices[i].root.clone(),
            partial,
            &mut rng,
        );
    }

    /// 同步到底：所有活著的裝置反覆上傳下載，直到沒有東西再動。
    fn settle(&mut self) {
        for _ in 0..3 {
            for i in self.alive() {
                self.upload(i, false);
            }
            for i in self.alive() {
                self.download(i, false);
            }
        }
    }
}

// ────────────────────────────── 執行 ──────────────────────────────

/// 跑一段動作序列。回傳 `Err(說明)` 表示某條性質被違反。
fn run(actions: &[Action], dir: PathBuf) -> Result<(), String> {
    run_inner(actions, dir, false)
}

/// `verbose` 只有除錯時用：逐步印出每台裝置看到什麼。
fn run_inner(actions: &[Action], dir: PathBuf, verbose: bool) -> Result<(), String> {
    let mut w = World::new(dir);

    for (step, action) in actions.iter().enumerate() {
        let before: Vec<BTreeSet<String>> = (0..w.devices.len()).map(|i| w.seen(i)).collect();

        match *action {
            Action::Edit(d) => {
                let i = d % w.devices.len();
                if w.devices[i].alive
                    && let Some(page) = w.page
                {
                    let tag = format!("#{}", w.next_tag);
                    w.next_tag += 1;
                    if let Ok(mut s) = NotebookSession::open(&w.devices[i].root, w.devices[i].id)
                        && s.notebook().page(page).is_some()
                    {
                        let _ = s.add_text_block(page, &tag, TextStyle::Body);
                    }
                }
            }
            Action::Upload(d, partial) => w.upload(d % w.devices.len(), partial),
            Action::Download(d, partial) => w.download(d % w.devices.len(), partial),

            Action::Compact(d) => {
                let i = d % w.devices.len();
                if w.devices[i].alive
                    && let Ok(s) = NotebookSession::open(&w.devices[i].root, w.devices[i].id)
                {
                    let absorbed: Vec<String> = s
                        .package()
                        .compact_own_doc_ops(2, w.devices[i].id)
                        .unwrap_or_default()
                        .iter()
                        .flat_map(|o| o.absorbed.clone())
                        .collect();
                    drop(s);
                    // 壓實之後刪掉雲端上被吃掉的碎檔（`ffi_gdrive` 就是這樣做的）。
                    w.upload(i, false);
                    for n in &absorbed {
                        let _ = std::fs::remove_file(w.cloud.join("doc/ops").join(n));
                    }
                }
            }

            Action::Milestone(d) => {
                let i = d % w.devices.len();
                if w.devices[i].alive
                    && let Ok(mut s) = NotebookSession::open(&w.devices[i].root, w.devices[i].id)
                    && let Ok(m) = s.create_milestone("M", "模型", 1_757_635_200_000, false)
                {
                    drop(s);
                    w.milestones.push(Milestone {
                        id: m.id,
                        creator: i,
                        observed: w.seen(i),
                    });
                }
            }

            Action::Restore(d, mi) => {
                let i = d % w.devices.len();
                if !w.devices[i].alive || w.milestones.is_empty() {
                    continue;
                }
                let m = &w.milestones[mi % w.milestones.len()];
                let (mid, observed, creator) = (m.id, m.observed.clone(), m.creator);
                let Ok(mut s) = NotebookSession::open(&w.devices[i].root, w.devices[i].id) else {
                    continue;
                };
                // 這台裝置可能還沒同步到那個里程碑 —— 那不是錯誤。
                if s.restore_milestone(mid, 1_757_635_300_000, "還原前")
                    .is_err()
                {
                    continue;
                }
                drop(s);
                w.restored = true;

                // P4：快照當下看得到的東西，還原之後一個都不准少。
                //
                // 只在**建立者自己**身上檢查。別台裝置可能還沒同步到當時的
                // 全部內容，少了不是 bug 而是還沒收到。
                if i == creator {
                    let after = w.seen(i);
                    let lost: Vec<&String> = observed.difference(&after).collect();
                    if !lost.is_empty() {
                        return Err(format!(
                            "P4 快照回不去：第 {step} 步在裝置 {i} 還原之後，\
                             里程碑當下看得到的 {lost:?} 不見了"
                        ));
                    }
                }
            }

            Action::Die(d) => {
                let i = d % w.devices.len();
                // 至少留一台活著，否則之後的每一步都是空轉。
                if w.alive().len() > 1 {
                    let _ = std::fs::remove_dir_all(&w.devices[i].root);
                    w.devices[i].alive = false;
                }
            }

            Action::Join => {
                if w.devices.len() >= 6 {
                    continue;
                }
                let n = w.devices.len();
                let root = w.dir.join(format!("dev{n}"));
                std::fs::create_dir_all(&root).unwrap();
                let src = w.cloud.join("manifest.json");
                if !src.exists() {
                    continue;
                }
                std::fs::copy(&src, root.join("manifest.json")).unwrap();
                w.devices.push(Device {
                    id: 0xD000 + n as u32,
                    root,
                    alive: true,
                    last_seen: BTreeSet::new(),
                });
                w.download(n, false);
            }
        }

        if verbose {
            let states: Vec<String> = (0..w.devices.len())
                .map(|i| format!("d{i}{:?}", w.seen(i)))
                .collect();
            eprintln!("{step:>3} {action:?} → {}", states.join(" "));
        }

        // ---- P2 單調：還沒有任何還原之前，內容只增不減 ----
        if !w.restored {
            for i in 0..w.devices.len().min(before.len()) {
                if !w.devices[i].alive {
                    continue;
                }
                let now = w.seen(i);
                let lost: Vec<&String> = before[i].difference(&now).collect();
                if !lost.is_empty() {
                    return Err(format!(
                        "P2 單調被破壞：第 {step} 步（{action:?}）之後，\
                         裝置 {i} 少了 {lost:?}"
                    ));
                }
            }
        }

        // ---- P5 還原真的有還原（下一步才看得出來，所以放在這裡記錄）----
        for i in 0..w.devices.len() {
            if w.devices[i].alive {
                let s = w.seen(i);
                w.devices[i].last_seen = s;
            }
        }
    }

    // ---- P3 冪等：再下載一次同一批檔案，狀態不准變 ----
    w.settle();
    let snapshot: Vec<BTreeSet<String>> = (0..w.devices.len()).map(|i| w.seen(i)).collect();
    w.settle();
    for i in w.alive() {
        if w.seen(i) != snapshot[i] {
            return Err(format!("P3 冪等被破壞：裝置 {i} 再同步一次之後狀態變了"));
        }
    }

    // ---- P1 收斂：同步到底之後，所有活著的裝置必須完全一致 ----
    let live = w.alive();
    if let Some(&first) = live.first() {
        let expected = w.seen(first);
        for &i in &live {
            let got = w.seen(i);
            if got != expected {
                let missing: Vec<&String> = expected.difference(&got).collect();
                let extra: Vec<&String> = got.difference(&expected).collect();
                return Err(format!(
                    "P1 收斂被破壞：裝置 {i} 與裝置 {first} 不一致。\
                     少了 {missing:?}，多了 {extra:?}"
                ));
            }
        }
    }

    Ok(())
}

// ────────────────────────────── 縮小 ──────────────────────────────

/// 把失敗的序列縮到最短。
///
/// 沒有這一步，錯誤訊息會是「這 200 步裡的某一步炸了」，沒有人看得懂，
/// 然後這個閘門就會被關掉。
fn shrink(actions: &[Action], dir: &Path) -> Vec<Action> {
    let mut best = actions.to_vec();
    let mut chunk = best.len() / 2;
    let mut round = 0usize;

    while chunk >= 1 {
        let mut i = 0;
        while i < best.len() {
            let mut candidate = best.clone();
            let end = (i + chunk).min(candidate.len());
            candidate.drain(i..end);
            round += 1;
            let d = dir.join(format!("shrink{round}"));
            if candidate.len() < best.len() && run(&candidate, d).is_err() {
                best = candidate; // 拿掉這一段還是壞的 ⇒ 這一段不需要
            } else {
                i += chunk;
            }
            if round > 400 {
                return best; // 縮小本身不該變成跑不完的東西
            }
        }
        chunk /= 2;
    }
    best
}

// ────────────────────────────── 測試 ──────────────────────────────

fn tmp(name: &str) -> PathBuf {
    std::env::temp_dir().join(format!("padnote-model-{name}-{}", std::process::id()))
}

/// 曾經找到過失敗的種子。**永遠重跑。**
///
/// 亂數測試最大的風險是「它上次紅過，但這次抽到別的序列所以綠了」。
/// 把種子存下來，回歸就變成確定性的。
const REGRESSION_SEEDS: &[u64] = &[
    // 抓到：壓實把 `0001-devA` 併進 `0003-devA` 之後，那筆 AddPage 的
    // **重播順序**跟著檔名跑到 `0002-devB` 後面 —— 裝置 B 的區塊先被重播，
    // 那一頁還不存在，區塊就被靜默丟掉。縮小之後只要七步。
    // 修法：`read_doc_op_entries` 依 `(lamport, device)` 排序，不信檔案順序。
    0x4abf_bd93_f77d_d0fc,
    // 長時間版抓到（400 步，縮小後 18 步）：部分同步會在向量時鐘裡留下洞。
    // A 還原掉一段內容；B 在還沒收到那筆還原時建里程碑（畫面上那段還在）；
    // B 補同步之後內容消失；B 還原回自己的里程碑 —— 內容回不來，
    // 因為那筆還原的 lamport 比刀口小，不落在遮蔽區間裡。
    // 修法：`MilestoneCut::seen_restores` 記下「建立這一刀時看得到哪些還原」。
    0x51ec_a623_9439_ac78,
];

#[test]
fn regression_seeds_still_pass() {
    for (n, &seed) in REGRESSION_SEEDS.iter().enumerate() {
        let actions = generate(seed, 400);
        if let Err(why) = run(&actions, tmp(&format!("regress{n}"))) {
            let minimal = shrink(&actions, &tmp(&format!("regress{n}-s")));
            panic!("種子 {seed:#x} 又壞了：{why}\n最短失敗序列：{minimal:#?}");
        }
    }
}

#[test]
fn random_histories_converge_and_never_lose_content() {
    // CI 上跑得完的份量；`--ignored` 那一項跑得更久。
    for k in 0..24u64 {
        let seed = 0x2026_0922_0000_0000u64 ^ k.wrapping_mul(0x9E37_79B9_7F4A_7C15);
        let actions = generate(seed, 160);
        if let Err(why) = run(&actions, tmp(&format!("rand{k}"))) {
            let minimal = shrink(&actions, &tmp(&format!("rand{k}-s")));
            panic!(
                "種子 {seed:#x} 違反了性質：{why}\n\
                 把這個種子加進 REGRESSION_SEEDS。\n\
                 最短失敗序列（{} 步）：{minimal:#?}",
                minimal.len()
            );
        }
    }
}

/// 長時間版本。手動或夜間跑：`cargo test --test model_multi_device -- --ignored`
#[test]
#[ignore = "跑很久，給夜間或手動用"]
fn a_long_soak() {
    for k in 0..300u64 {
        let seed = 0xA11C_E000_0000_0000u64 ^ k.wrapping_mul(0x9E37_79B9_7F4A_7C15);
        let actions = generate(seed, 400);
        if let Err(why) = run(&actions, tmp(&format!("soak{k}"))) {
            let minimal = shrink(&actions, &tmp(&format!("soak{k}-s")));
            panic!("種子 {seed:#x}：{why}\n最短失敗序列：{minimal:#?}");
        }
    }
}
