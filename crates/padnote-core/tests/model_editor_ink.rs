//! 編輯器筆跡模型檢查（架構審視 P0，Layer 1）。
//!
//! # 為什麼需要它
//!
//! 2026-10 iPad 回報一連串「內容消失」：切手繪／打字、點縮圖、換頁之後整頁變白，
//! 按「一鍵恢復」又回來。每一次都是單點修補，修好一條路徑、另一條又壞。
//! 根因是**同一頁的筆跡有好幾份副本**，彼此靠時間差同步。
//!
//! 架構方向定為「核心是筆跡唯一的真相，平台畫面只是投影」（見
//! `docs/plans/editor-single-source-of-truth.md`）。要讓平台放心把真相交給核心，
//! 核心本身必須先被證明：在任意編輯序列之後，**每一頁的筆跡都跟著頁面身分走，
//! 而且唯讀操作、重開、版面切換都不會改變它**。
//!
//! # 檢查方式
//!
//! 與 `model_multi_device.rs` 同一套做法：用種子化亂數產生動作序列，每一步之後
//! 檢查性質；失敗時自動縮小到最短的重現序列。
//!
//! 這裡的影子模型（`Shadow`）只記「頁面順序」與「每頁的筆畫 id 集合」——
//! 這兩件事簡單到不可能寫錯，所以可以拿來當預言機。
//!
//! - **I1 頁序**：核心的頁面順序 == 影子模型的頁面順序。
//! - **I2 筆跡跟著頁面身分走**：每一頁（以 pageId 識別）看得到的筆畫集合 ==
//!   影子模型。插頁、刪頁、搬頁之後，筆跡不准跑到別頁，也不准消失。
//! - **I3 唯讀零寫入**：只讀的操作（列頁、讀筆跡、讀繪製順序 —— 也就是平台
//!   「點縮圖、換頁、切模式、切版面」時會做的事）之前與之後，狀態完全相同。
//! - **I4 重開冪等**：關掉再開，狀態完全相同。
//! - **I5 套索搬移保數量**：套索整頁搬移之後筆畫數不變。
//! - **I6 里程碑還原**：還原到里程碑之後，筆跡 == 建立里程碑當下的筆跡。

use padnote_core::ffi::{PadnoteSession, PageStyle, StrokePoint, ToolKind};
use std::collections::{BTreeMap, BTreeSet};
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

/// 頁碼與筆畫序號都用「抽到的數字」表示，執行時再對目前頁數取餘數 ——
/// 這樣縮小時刪掉前面的步驟，後面的步驟仍然合法。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum Action {
    /// 在某頁寫一筆。
    Draw(usize),
    /// 擦掉某頁的某一筆。
    Erase(usize, usize),
    /// 新增一頁（加在最後）。
    AddPage,
    /// 刪掉一頁（只剩一頁時跳過 —— 筆記不能被刪空）。
    RemovePage(usize),
    /// 把一頁搬到另一個位置。
    MovePage(usize, usize),
    /// 複製一頁（新頁放在來源頁正後方）。
    DuplicatePage(usize),
    /// 套索選取整頁並平移。
    LassoMoveAll(usize),
    /// 平台的唯讀操作：點縮圖、換頁、切模式、切版面時會做的讀取。
    ReadOnlyBurst,
    /// 關掉再開。
    Reopen,
    /// 建立里程碑（「一鍵恢復」的基準點）。
    Milestone,
    /// 還原到最近一個里程碑。
    Restore,
}

fn generate(seed: u64, steps: usize) -> Vec<Action> {
    let mut rng = Rng(seed | 1);
    (0..steps)
        .map(|_| match rng.below(20) {
            0..=6 => Action::Draw(rng.below(64)),
            7 | 8 => Action::Erase(rng.below(64), rng.below(64)),
            9 => Action::AddPage,
            10 => Action::RemovePage(rng.below(64)),
            11 => Action::MovePage(rng.below(64), rng.below(64)),
            12 => Action::DuplicatePage(rng.below(64)),
            13 => Action::LassoMoveAll(rng.below(64)),
            14 | 15 => Action::ReadOnlyBurst,
            16 => Action::Reopen,
            17 => Action::Milestone,
            18 => Action::Restore,
            _ => Action::Draw(rng.below(64)),
        })
        .collect()
}

// ────────────────────────────── 觀察 ──────────────────────────────

/// 核心目前的可見狀態：頁面順序 + 每頁的筆畫 id 集合。
#[derive(Clone, Debug, PartialEq, Eq)]
struct Snapshot {
    pages: Vec<String>,
    strokes: BTreeMap<String, BTreeSet<String>>,
}

fn observe(s: &PadnoteSession) -> Snapshot {
    let n = s.page_count();
    let pages: Vec<String> = (0..n).filter_map(|i| s.page_id_at(i)).collect();
    let strokes = pages
        .iter()
        .map(|p| {
            let ids = s
                .visible_strokes(p.clone())
                .expect("visible_strokes")
                .into_iter()
                .map(|st| st.id.to_lowercase())
                .collect();
            (p.clone(), ids)
        })
        .collect();
    Snapshot { pages, strokes }
}

fn points(seq: u32) -> Vec<StrokePoint> {
    // 每一筆都在頁面中央附近、互不重疊；套索用整頁多邊形選取，一定圈得到。
    let base = 40.0 + (seq % 50) as f32 * 9.5;
    (0..6)
        .map(|k| StrokePoint {
            x: base + k as f32 * 3.25,
            y: 120.0 + (seq % 37) as f32 * 7.75 + k as f32 * 1.5,
            pressure: 0.5,
            tilt: 0.0,
            azimuth: 0.0,
            dt_us: if k == 0 { 0 } else { 8_000 },
            roll: 0.0,
        })
        .collect()
}

/// 足以涵蓋整頁的套索多邊形。
const WHOLE_PAGE: [f32; 8] = [
    -10_000.0, -10_000.0, 10_000.0, -10_000.0, 10_000.0, 10_000.0, -10_000.0, 10_000.0,
];

// ────────────────────────────── 執行 ──────────────────────────────

const DEVICE: u32 = 0x0A11_CE01;

fn run(actions: &[Action], dir: PathBuf) -> Result<(), String> {
    run_inner(actions, dir, false)
}

fn run_inner(actions: &[Action], dir: PathBuf, verbose: bool) -> Result<(), String> {
    let _ = std::fs::remove_dir_all(&dir);
    std::fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
    let path = dir.join("nb.padnote").to_string_lossy().into_owned();

    let mut session = Some(
        PadnoteSession::create(path.clone(), "model".into(), 1_700_000_000_000, DEVICE)
            .map_err(|e| format!("create: {e:?}"))?,
    );
    let mut clock_us: u64 = 1;
    let mut wall_ms: u64 = 1_700_000_000_000;
    let mut seq: u32 = 0;
    let mut shadow = observe(session.as_ref().unwrap());
    // (里程碑 id, 建立當下的影子)
    let mut milestone: Option<(String, Snapshot)> = None;

    for (step, action) in actions.iter().enumerate() {
        let s = session.as_ref().unwrap();
        clock_us += 10_000;
        wall_ms += 10;
        s.advance_time(clock_us);
        let n = shadow.pages.len();
        let fail = |what: String| format!("第 {step} 步 {action:?}：{what}");

        match *action {
            Action::Draw(p) => {
                let page = shadow.pages[p % n].clone();
                seq += 1;
                let id = s
                    .add_stroke(
                        page.clone(),
                        ToolKind::BallPoint,
                        vec![20, 20, 20, 255],
                        2.0,
                        points(seq),
                    )
                    .map_err(|e| fail(format!("add_stroke: {e:?}")))?;
                shadow
                    .strokes
                    .get_mut(&page)
                    .unwrap()
                    .insert(id.to_lowercase());
            }
            Action::Erase(p, k) => {
                let page = shadow.pages[p % n].clone();
                let ids: Vec<String> = shadow.strokes[&page].iter().cloned().collect();
                if ids.is_empty() {
                    continue;
                }
                let id = ids[k % ids.len()].clone();
                s.erase_stroke(page.clone(), id.clone())
                    .map_err(|e| fail(format!("erase_stroke: {e:?}")))?;
                shadow.strokes.get_mut(&page).unwrap().remove(&id);
            }
            Action::AddPage => {
                let id = s
                    .add_page(PageStyle::Blank)
                    .map_err(|e| fail(format!("add_page: {e:?}")))?;
                shadow.pages.push(id.clone());
                shadow.strokes.insert(id, BTreeSet::new());
            }
            Action::RemovePage(p) => {
                if n <= 1 {
                    continue;
                }
                let page = shadow.pages.remove(p % n);
                s.remove_page(page.clone())
                    .map_err(|e| fail(format!("remove_page: {e:?}")))?;
                shadow.strokes.remove(&page);
            }
            Action::MovePage(from, to) => {
                let page = shadow.pages.remove(from % n);
                let to = to % n;
                s.move_page(page.clone(), to as u32)
                    .map_err(|e| fail(format!("move_page: {e:?}")))?;
                shadow.pages.insert(to, page);
            }
            Action::DuplicatePage(p) => {
                let idx = p % n;
                let src = shadow.pages[idx].clone();
                let dup = s
                    .duplicate_page(src.clone())
                    .map_err(|e| fail(format!("duplicate_page: {e:?}")))?;
                // 新頁的筆畫：數量與來源頁一致、身分全新（核心刻意換 id，`id_map` 只列物件，不列筆畫）。
                let copied: BTreeSet<String> = s
                    .visible_strokes(dup.page_id.clone())
                    .map_err(|e| fail(format!("visible_strokes: {e:?}")))?
                    .into_iter()
                    .map(|st| st.id.to_lowercase())
                    .collect();
                let src_ids = &shadow.strokes[&src];
                if copied.len() != src_ids.len() {
                    return Err(fail(format!(
                        "複製頁筆數 {} != 來源頁 {}",
                        copied.len(),
                        src_ids.len()
                    )));
                }
                if !copied.is_disjoint(src_ids) {
                    return Err(fail("複製頁沿用了來源頁的筆畫 id（擦除會認錯頁）".into()));
                }
                let mapped = copied;
                shadow.pages.insert(idx + 1, dup.page_id.clone());
                shadow.strokes.insert(dup.page_id, mapped);
            }
            Action::LassoMoveAll(p) => {
                let page = shadow.pages[p % n].clone();
                let selected = s
                    .lasso_select(page.clone(), WHOLE_PAGE.to_vec())
                    .map_err(|e| fail(format!("lasso_select: {e:?}")))?;
                let before = shadow.strokes[&page].len();
                if selected.len() != before {
                    return Err(fail(format!(
                        "I5 套索整頁只圈到 {} / {before} 筆",
                        selected.len()
                    )));
                }
                if selected.is_empty() {
                    continue;
                }
                let new_ids = s
                    .lasso_translate(page.clone(), selected, 4.0, 4.0)
                    .map_err(|e| fail(format!("lasso_translate: {e:?}")))?;
                if new_ids.len() != before {
                    return Err(fail(format!(
                        "I5 套索搬移後筆數 {} != {before}",
                        new_ids.len()
                    )));
                }
                shadow.strokes.insert(
                    page,
                    new_ids.into_iter().map(|i| i.to_lowercase()).collect(),
                );
            }
            Action::ReadOnlyBurst => {
                let before = observe(s);
                // 平台切模式／換頁／點縮圖時會打的讀取，全部打一輪。
                for p in &before.pages {
                    let _ = s.visible_stroke_details(p.clone());
                    let _ = s.draw_order(p.clone());
                    let _ = s.page_size(p.clone());
                    let _ = s.page_style(p.clone());
                    let _ = s.text_block_ids(p.clone());
                    let _ = s.image_block_ids(p.clone());
                }
                let _ = s.milestones();
                let after = observe(s);
                if before != after {
                    return Err(fail(format!(
                        "I3 唯讀操作改變了狀態\n前：{before:?}\n後：{after:?}"
                    )));
                }
            }
            Action::Reopen => {
                let before = observe(s);
                drop(session.take()); // 先關，再開 —— 與平台層的生命週期一致
                let reopened = PadnoteSession::open_existing(path.clone(), DEVICE)
                    .map_err(|e| fail(format!("open_existing: {e:?}")))?;
                reopened.advance_time(clock_us);
                let after = observe(&reopened);
                session = Some(reopened);
                if before != after {
                    return Err(fail(format!(
                        "I4 重開之後狀態不同\n前：{before:?}\n後：{after:?}"
                    )));
                }
            }
            Action::Milestone => {
                let m = s
                    .create_milestone("m".into(), "model".into(), wall_ms)
                    .map_err(|e| fail(format!("create_milestone: {e:?}")))?;
                milestone = Some((m.id, shadow.clone()));
            }
            Action::Restore => {
                let Some((id, snap)) = milestone.clone() else {
                    continue;
                };
                s.restore_milestone(id, wall_ms, "safety".into())
                    .map_err(|e| fail(format!("restore_milestone: {e:?}")))?;
                shadow = snap;
            }
        }

        let actual = observe(session.as_ref().unwrap());
        if actual.pages != shadow.pages {
            return Err(fail(format!(
                "I1 頁序不符\n預期：{:?}\n實際：{:?}",
                shadow.pages, actual.pages
            )));
        }
        if actual.strokes != shadow.strokes {
            let mut diff = String::new();
            for p in &shadow.pages {
                let (want, got) = (
                    &shadow.strokes[p],
                    actual.strokes.get(p).cloned().unwrap_or_default(),
                );
                if *want != got {
                    diff += &format!(
                        "\n  頁 {p}: 少了 {:?} / 多了 {:?}",
                        want.difference(&got).collect::<Vec<_>>(),
                        got.difference(want).collect::<Vec<_>>()
                    );
                }
            }
            return Err(fail(format!("I2 筆跡沒有跟著頁面身分走{diff}")));
        }
        if verbose {
            eprintln!("  ✓ {step:>3} {action:?}");
        }
    }
    Ok(())
}

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
                best = candidate;
            } else {
                i += chunk;
            }
            if round > 400 {
                return best;
            }
        }
        chunk /= 2;
    }
    best
}

fn check_seed(seed: u64, steps: usize) {
    let dir = tmp(&format!("seed{seed}"));
    let actions = generate(seed, steps);
    if let Err(first) = run(&actions, dir.join("run")) {
        let min = shrink(&actions, &dir);
        let detail = run_inner(&min, dir.join("min"), true)
            .err()
            .unwrap_or_default();
        panic!(
            "種子 {seed} 失敗：{first}\n\n縮小後 {} 步：{min:?}\n{detail}\n\n修好之後把種子加進 REGRESSION_SEEDS。",
            min.len()
        );
    }
    let _ = std::fs::remove_dir_all(&dir);
}

// ────────────────────────────── 測試 ──────────────────────────────

fn tmp(name: &str) -> PathBuf {
    std::env::temp_dir().join(format!(
        "padnote-editor-model-{name}-{}",
        std::process::id()
    ))
}

/// 曾經找到過失敗的種子。**永遠重跑。**
const REGRESSION_SEEDS: &[u64] = &[];

#[test]
fn regression_seeds_still_pass() {
    for &seed in REGRESSION_SEEDS {
        check_seed(seed, 120);
    }
}

/// 每一個平台使用者回報過的情境，寫成固定序列 —— 讀起來就是重現步驟。
#[test]
fn reported_scenarios_keep_ink() {
    use Action::*;
    let scenarios: &[(&str, &[Action])] = &[
        // iPad：開筆記 → 切打字 → 切回手繪，第一頁內容消失。
        (
            "切換模式不改筆跡",
            &[
                Draw(0),
                Draw(0),
                ReadOnlyBurst,
                ReadOnlyBurst,
                Reopen,
                ReadOnlyBurst,
            ],
        ),
        // iPad：點任一縮圖，該頁內容消失。
        (
            "點縮圖不改筆跡",
            &[
                Draw(0),
                AddPage,
                Draw(1),
                Draw(1),
                ReadOnlyBurst,
                ReadOnlyBurst,
            ],
        ),
        // 插頁、搬頁之後，筆跡要跟著頁面身分走（Apple 端曾以頁序號為 key）。
        (
            "搬頁筆跡跟著走",
            &[
                Draw(0),
                AddPage,
                Draw(1),
                AddPage,
                Draw(2),
                MovePage(2, 0),
                MovePage(0, 2),
                Reopen,
            ],
        ),
        (
            "刪頁不波及他頁",
            &[
                Draw(0),
                AddPage,
                Draw(1),
                AddPage,
                Draw(2),
                RemovePage(1),
                Reopen,
            ],
        ),
        (
            "複製頁獨立",
            &[Draw(0), Draw(0), DuplicatePage(0), Erase(1, 0), Reopen],
        ),
        // 一鍵恢復初始狀態。
        (
            "一鍵恢復",
            &[Draw(0), Milestone, Draw(0), Draw(0), Restore, Reopen],
        ),
        // 套索。
        (
            "套索搬移",
            &[Draw(0), Draw(0), Draw(0), LassoMoveAll(0), Reopen],
        ),
    ];
    for (name, seq) in scenarios {
        let dir = tmp(&format!("scenario-{}", name.len()));
        if let Err(e) = run_inner(seq, dir.clone(), false) {
            panic!("情境「{name}」失敗：{e}");
        }
        let _ = std::fs::remove_dir_all(dir);
    }
}

#[test]
fn random_editing_histories_keep_ink_with_its_page() {
    for seed in 1..=24u64 {
        check_seed(seed.wrapping_mul(0x9E37_79B9_7F4A_7C15), 80);
    }
}

#[test]
#[ignore = "長時間浸泡測試：cargo test -p padnote-core --test model_editor_ink -- --ignored"]
fn a_long_soak() {
    for seed in 1..=400u64 {
        check_seed(seed.wrapping_mul(0xD1B5_4A32_D192_ED03), 300);
    }
}
