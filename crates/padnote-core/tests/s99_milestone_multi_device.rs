//! 里程碑快照的跨裝置時序（工作項 H-MILESTONE）。
//!
//! # 為什麼這三項要在核心測，而不是「等兩台真機」
//!
//! `TODO.md` 原本把這三條列成「需要兩台真機 + 同一個雲端帳號」。那句話
//! 只對了一半：**真正需要真機的只有「Google Drive 會不會把檔案傳過去」**，
//! 而那件事 `sync_conformance.rs` 已經測過了。這三條問的其實是
//! 「檔案傳過去之後，兩邊算出來的東西一不一樣」—— 那是純核心的問題，
//! 而且在真機上反而**極難重現**：要精準控制兩台裝置的同步時序。
//!
//! 所以這裡直接建兩個套件目錄，用 [`sync`] 模擬資料夾同步的規則
//! （append-only、比長度、每台裝置只寫自己的檔），把時序寫死。
//!
//! # 同步規則刻意照抄 `ffi_folder_sync`
//!
//! - `doc/ops/` 與 `ink/` 是純追加：目的地沒有就拉，比較短就覆蓋。
//! - `manifest.json` **不同步**（「兩邊都有就各留各的」）—— 它裝著本機的
//!   金鑰包裝參數與壓實界線，覆蓋過去就是把這台裝置的解密資訊換成另一台的。
//!
//! 少了第二條，測試會是假的：里程碑的界線本來就該由各自的
//! `absorb_milestone_barriers` 從 oplog 重算，而不是靠同步帶過去。

use padnote_core::app::NotebookSession;
use padnote_core::doc::NotebookTime;
use padnote_core::doc::{TextStyle, Uuid};
use padnote_core::ink::{InkPoint, Stroke, Tool};
use std::path::{Path, PathBuf};

fn tmp(name: &str) -> PathBuf {
    let d = std::env::temp_dir().join(format!("padnote-s99-{name}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&d);
    d
}

const DEVICE_A: u32 = 0x0000_00A1;
const DEVICE_B: u32 = 0x0000_00B2;

/// 一個共用資料夾（模擬雲端）。
///
/// 刻意做成獨立的一份，而不是「把 A 的檔案直接複製到 B」——
/// 因為**壓實會刪雲端上被吃掉的碎檔**，而那個刪除正是這一組測試的重點。
/// 少了雲端這一層，刪除就沒有地方發生，測試會在不知不覺中變成假的。
struct Cloud(PathBuf);

impl Cloud {
    fn new(name: &str) -> Self {
        let d = tmp(name);
        std::fs::create_dir_all(&d).unwrap();
        Self(d)
    }

    /// 把 `device` 目錄裡「雲端沒有、或雲端比較短」的檔案推上去。
    ///
    /// 這條規則抄自 `plan_folder_sync`：append-only 的檔案比長度，
    /// **而本機有、雲端沒有的一律上傳**。最後那半句在時序 3 裡很關鍵 ——
    /// 它代表被別台裝置刪掉的碎檔，會被還留著它的裝置再傳回去。
    fn upload(&self, device: &Path) -> usize {
        let mut moved = 0;
        for sub in ["doc/ops", "ink"] {
            let Ok(entries) = std::fs::read_dir(device.join(sub)) else {
                continue;
            };
            for e in entries
                .filter_map(Result::ok)
                .filter(|e| e.path().is_file())
            {
                let dst = self.0.join(sub).join(e.file_name());
                if longer(&e.path(), &dst) {
                    std::fs::create_dir_all(dst.parent().unwrap()).unwrap();
                    std::fs::copy(e.path(), &dst).unwrap();
                    moved += 1;
                }
            }
        }
        moved
    }

    /// 把雲端上「本機沒有、或本機比較短」的檔案拉下來。
    fn download(&self, device: &Path) -> usize {
        let mut moved = 0;
        for sub in ["doc/ops", "ink"] {
            let Ok(entries) = std::fs::read_dir(self.0.join(sub)) else {
                continue;
            };
            for e in entries
                .filter_map(Result::ok)
                .filter(|e| e.path().is_file())
            {
                let dst = device.join(sub).join(e.file_name());
                if longer(&e.path(), &dst) {
                    std::fs::create_dir_all(dst.parent().unwrap()).unwrap();
                    std::fs::copy(e.path(), &dst).unwrap();
                    moved += 1;
                }
            }
        }
        moved
    }

    /// 壓實之後刪掉被吃掉的碎檔（`ffi_gdrive` 會照 `absorbed` 名單做這件事）。
    fn delete_ops(&self, names: &[String]) {
        for n in names {
            let _ = std::fs::remove_file(self.0.join("doc/ops").join(n));
        }
    }

    fn op_files(&self) -> Vec<String> {
        let mut v: Vec<String> = std::fs::read_dir(self.0.join("doc/ops"))
            .map(|it| {
                it.filter_map(Result::ok)
                    .map(|e| e.file_name().to_string_lossy().into_owned())
                    .collect()
            })
            .unwrap_or_default();
        v.sort();
        v
    }

    /// 一台新裝置第一次同步：整包拉下來。
    fn clone_into(&self, device: &Path, manifest_from: &Path) {
        std::fs::create_dir_all(device).unwrap();
        std::fs::copy(
            manifest_from.join("manifest.json"),
            device.join("manifest.json"),
        )
        .unwrap();
        self.download(device);
    }
}

fn longer(src: &Path, dst: &Path) -> bool {
    let s = src.metadata().map(|m| m.len()).unwrap_or(0);
    let d = dst.metadata().map(|m| m.len()).unwrap_or(0);
    s > d
}

/// 一趟完整的同步：先上傳再下載，兩台都做一次。
fn sync_all(cloud: &Cloud, devices: &[&Path]) {
    for d in devices {
        cloud.upload(d);
    }
    for d in devices {
        cloud.download(d);
    }
}

fn stroke() -> Stroke {
    Stroke {
        id: Uuid::now_v7(),
        started_at: NotebookTime::ZERO,
        tool: Tool::FountainPen,
        color_rgba8: [0, 0, 0, 255],
        base_width: 2.0,
        points: vec![
            InkPoint::new(0.0, 0.0, 0.5, 0),
            InkPoint::new(10.0, 10.0, 0.8, 8_000),
        ],
    }
}

/// 這一頁上看得見的文字區塊內容，排序過 —— 兩台裝置要比對的就是它。
fn texts(s: &NotebookSession, page: Uuid) -> Vec<String> {
    let mut out: Vec<String> = s
        .notebook()
        .page(page)
        .map(|p| {
            p.blocks()
                .iter()
                .filter_map(|b| b.searchable_text().map(str::to_string))
                .collect()
        })
        .unwrap_or_default();
    out.sort();
    out
}

fn milestone_titles(s: &NotebookSession) -> Vec<String> {
    let mut v: Vec<String> = s
        .milestones()
        .unwrap()
        .into_iter()
        .map(|m| m.title)
        .collect();
    v.sort();
    v
}

// ────────────────────────────────────────────────────────────────
// 時序 1：一台建里程碑並還原，另一台同步之後要看到一樣的東西
// ────────────────────────────────────────────────────────────────

#[test]
fn a_milestone_made_on_one_device_is_visible_and_identical_on_the_other() {
    let (pa, pb) = (tmp("cross-a"), tmp("cross-b"));
    let cloud = Cloud::new("cross-cloud");

    // A 建一本，寫一段，做里程碑，再寫一段。
    let page;
    let milestone_id;
    {
        let mut a = NotebookSession::create(&pa, "共用", 1_757_635_200_000, DEVICE_A).unwrap();
        page = a.first_page().unwrap();
        a.add_text_block(page, "快照當時", TextStyle::Body).unwrap();
        a.add_stroke(page, stroke()).unwrap();
        milestone_id = a
            .create_milestone("交稿前", "阿寬", 1_757_635_210_000, false)
            .unwrap()
            .id;
        a.add_text_block(page, "快照之後", TextStyle::Body).unwrap();
        a.add_stroke(page, stroke()).unwrap();
    }

    // B 從零開始，把 A 的套件複製過去（第一次同步 = 整包下載）。
    cloud.upload(&pa);
    cloud.clone_into(&pb, &pa);

    {
        let b = NotebookSession::open(&pb, DEVICE_B).unwrap();
        assert_eq!(
            milestone_titles(&b),
            ["交稿前"],
            "里程碑是 oplog 裡的一筆，同步過去就該看得到"
        );
        assert_eq!(texts(&b, page).len(), 2);
    }

    // A 還原，再同步給 B。
    {
        let mut a = NotebookSession::open(&pa, DEVICE_A).unwrap();
        a.restore_milestone(milestone_id, 1_757_635_220_000, "還原前")
            .unwrap();
        assert_eq!(texts(&a, page), ["快照當時"]);
        assert_eq!(a.visible_strokes(page).unwrap().len(), 1);
    }
    sync_all(&cloud, &[&pa, &pb]);

    let b = NotebookSession::open(&pb, DEVICE_B).unwrap();
    assert_eq!(
        texts(&b, page),
        ["快照當時"],
        "還原是 oplog 裡的一筆，兩台裝置必須算出同一個結果"
    );
    assert_eq!(
        b.visible_strokes(page).unwrap().len(),
        1,
        "筆畫的遮蔽也要跨裝置成立 —— 它走的是另一套儲存"
    );
    // 自動安全快照也要一起過去，否則 B 上的使用者沒有退路。
    assert!(
        milestone_titles(&b).contains(&"還原前".to_string()),
        "「還原之前」那一刀在 B 上也要看得到，實得 {:?}",
        milestone_titles(&b)
    );
}

// ────────────────────────────────────────────────────────────────
// 時序 2：一邊還原，另一邊同時在寫
// ────────────────────────────────────────────────────────────────

/// **B 在還原期間寫的東西不可以被吃掉。**
///
/// 這正是舊的 Apple 實作（整份覆蓋）會出錯的地方：A 把自己那份狀態寫回去，
/// B 同時寫的內容就這樣消失，而且沒有任何衝突訊號。
#[test]
fn work_written_concurrently_on_the_other_device_survives_a_restore() {
    let (pa, pb) = (tmp("concurrent-a"), tmp("concurrent-b"));
    let cloud = Cloud::new("concurrent-cloud");

    let page;
    let milestone_id;
    {
        let mut a = NotebookSession::create(&pa, "共用", 1_757_635_200_000, DEVICE_A).unwrap();
        page = a.first_page().unwrap();
        a.add_text_block(page, "共同起點", TextStyle::Body).unwrap();
        milestone_id = a
            .create_milestone("起點", "阿寬", 1_757_635_210_000, false)
            .unwrap()
            .id;
    }
    cloud.upload(&pa);
    cloud.clone_into(&pb, &pa);

    // 兩台各自離線編輯。
    {
        let mut a = NotebookSession::open(&pa, DEVICE_A).unwrap();
        a.add_text_block(page, "A 之後寫的", TextStyle::Body)
            .unwrap();
    }
    {
        let mut b = NotebookSession::open(&pb, DEVICE_B).unwrap();
        b.add_text_block(page, "B 同時寫的", TextStyle::Body)
            .unwrap();
        b.add_stroke(page, stroke()).unwrap();
    }

    // A 在**還沒收到 B 那一筆**的情況下還原 —— 這是最容易出錯的時序。
    {
        let mut a = NotebookSession::open(&pa, DEVICE_A).unwrap();
        a.restore_milestone(milestone_id, 1_757_635_220_000, "還原前")
            .unwrap();
        assert_eq!(texts(&a, page), ["共同起點"]);
    }

    sync_all(&cloud, &[&pa, &pb]);

    for (label, root, device) in [("A", &pa, DEVICE_A), ("B", &pb, DEVICE_B)] {
        let s = NotebookSession::open(root, device).unwrap();
        assert_eq!(
            texts(&s, page),
            ["B 同時寫的", "共同起點"],
            "{label}：A 的還原只該收掉 A 自己的歷史，B 同時寫的必須留著"
        );
        assert_eq!(
            s.visible_strokes(page).unwrap().len(),
            1,
            "{label}：B 同時畫的筆畫也要留著"
        );
    }
}

// ────────────────────────────────────────────────────────────────
// 時序 3：B 在還沒收到里程碑之前就壓實了自己的碎檔
// ────────────────────────────────────────────────────────────────

/// **這一條是 `TODO.md` 裡標著「我不確定會不會壞」的那個。**
///
/// 壓實會把 `0001..0005` 併成一個叫 `0005` 的檔，於是本來 lamport 為 2 的
/// 操作對外宣稱自己是 5。本機有 `milestone_barriers` 擋著，但那些界線是
/// **從自己看得到的 oplog 算出來的** —— B 還沒同步到 A 建的里程碑時，
/// B 根本不知道有這條界線要守。
#[test]
fn a_device_that_compacts_before_learning_about_a_milestone_still_agrees() {
    let (pa, pb) = (tmp("compact-a"), tmp("compact-b"));
    let cloud = Cloud::new("compact-cloud");

    let page;
    {
        let a = NotebookSession::create(&pa, "共用", 1_757_635_200_000, DEVICE_A).unwrap();
        page = a.first_page().unwrap();
    }
    cloud.upload(&pa);
    cloud.clone_into(&pb, &pa);

    // B 寫三筆，同步給 A。
    {
        let mut b = NotebookSession::open(&pb, DEVICE_B).unwrap();
        for t in ["B1", "B2", "B3"] {
            b.add_text_block(page, t, TextStyle::Body).unwrap();
        }
    }
    sync_all(&cloud, &[&pa, &pb]);

    // A 在「看得到 B1..B3」的這一刻建里程碑 —— 它的 cut 記著 B 寫到哪。
    let milestone_id = {
        let mut a = NotebookSession::open(&pa, DEVICE_A).unwrap();
        a.create_milestone("看得到 B3", "阿寬", 1_757_635_210_000, false)
            .unwrap()
            .id
    };

    // B **還沒收到那筆里程碑**，又寫了兩筆，然後壓實自己的全部碎檔。
    {
        let mut b = NotebookSession::open(&pb, DEVICE_B).unwrap();
        for t in ["B4", "B5"] {
            b.add_text_block(page, t, TextStyle::Body).unwrap();
        }
    }
    let absorbed: Vec<String> = {
        let b = NotebookSession::open(&pb, DEVICE_B).unwrap();
        let outcomes = b.package().compact_own_doc_ops(2, DEVICE_B).unwrap();
        let absorbed: Vec<String> = outcomes.iter().flat_map(|o| o.absorbed.clone()).collect();
        assert!(
            !absorbed.is_empty(),
            "這個情境的前提就是 B 真的壓實了，否則測試是空的"
        );
        absorbed
    };
    // **壓實之後要刪掉雲端上被吃掉的碎檔** —— `ffi_gdrive` 就是這樣做的。
    // 少了這一步，碎檔會一直留在雲端，測試就會在不知不覺中變成假的：
    // 它會靠那些碎檔算出正確答案，而真實世界裡它們已經被刪了。
    cloud.upload(&pb);
    cloud.delete_ops(&absorbed);
    assert!(
        !cloud.op_files().iter().any(|f| absorbed.contains(f)),
        "前提：被吃掉的碎檔真的從雲端消失了"
    );

    // 現在兩邊同步：B 拿到里程碑，A 拿到 B4/B5（以及 B 壓實後的那個檔）。
    sync_all(&cloud, &[&pa, &pb]);

    // **這一行解釋了為什麼下面會對。**
    //
    // A 手上還留著那些碎檔，而 `plan_folder_sync` 對「本機有、雲端沒有」的
    // 檔案一律上傳 —— 所以被 B 刪掉的碎檔又被 A 傳了回去。
    // 碎檔還在 ⇒ 每一筆操作仍然報得出自己真正的 lamport ⇒ 里程碑的那一刀
    // 落在對的地方。
    //
    // 換句話說，這個時序之所以安全，**靠的是「還有別台裝置留著碎檔」**，
    // 而不是壓實本身是安全的。下面那一項測的就是這個前提不成立的時候。
    // A 手上還留著「它在建里程碑時看得到的」那些碎檔，而 `plan_folder_sync`
    // 對「本機有、雲端沒有」的檔案一律上傳 —— 所以那幾個被 B 刪掉的碎檔
    // 又被 A 傳了回去。**A 沒看過的那些（B 離線寫的 B4、B5）沒有回來**，
    // 它們現在只活在 B 壓實後的那個檔裡。
    let back: Vec<&String> = absorbed
        .iter()
        .filter(|f| cloud.op_files().contains(f))
        .collect();
    assert!(
        !back.is_empty() && back.len() < absorbed.len(),
        "前提：A 看過的碎檔回來了、沒看過的沒有。absorbed={absorbed:?} 回來的={back:?}"
    );

    // A 還原到那個里程碑。
    {
        let mut a = NotebookSession::open(&pa, DEVICE_A).unwrap();
        a.restore_milestone(milestone_id, 1_757_635_220_000, "還原前")
            .unwrap();
    }
    sync_all(&cloud, &[&pa, &pb]);

    let on_a = {
        let a = NotebookSession::open(&pa, DEVICE_A).unwrap();
        texts(&a, page)
    };
    let on_b = {
        let b = NotebookSession::open(&pb, DEVICE_B).unwrap();
        texts(&b, page)
    };

    assert_eq!(
        on_a, on_b,
        "兩台裝置對同一份 oplog 必須算出同一個結果。\
         A 看到 {on_a:?}，B 看到 {on_b:?}"
    );
    assert_eq!(
        on_a,
        ["B1", "B2", "B3"],
        "里程碑的那一刀是「B 寫到 B3」—— B4、B5 該被收起來，B1..B3 必須留著"
    );
}

/// 時序 3 的嚴苛版：**沒有任何一台裝置留著被壓實吃掉的碎檔**。
///
/// 上一項之所以安全，靠的是「A 還留著碎檔，而同步會把本機有、雲端沒有的
/// 檔案傳回去」。那是一個**前提**，不是保證 —— 這一項把前提拿掉：
/// A 建完里程碑之後就不在了（重灌、換機、解除安裝），
/// 由一台從雲端整包下載的新裝置 C 來執行還原。
///
/// C 手上 B 的操作只剩壓實後的那一個檔，裡面每一筆都宣稱自己的 lamport
/// 是檔名上的那個最大值。於是「回到 B 寫到 B3 的那一刻」這條線落在錯的
/// 地方，B1..B3 一起被收走。
#[test]
fn a_restore_is_still_correct_when_nobody_kept_the_absorbed_fragments() {
    let (pa, pb, pc) = (tmp("lost-a"), tmp("lost-b"), tmp("lost-c"));
    let cloud = Cloud::new("lost-cloud");

    let page;
    {
        let a = NotebookSession::create(&pa, "共用", 1_757_635_200_000, DEVICE_A).unwrap();
        page = a.first_page().unwrap();
    }
    cloud.upload(&pa);
    cloud.clone_into(&pb, &pa);

    {
        let mut b = NotebookSession::open(&pb, DEVICE_B).unwrap();
        for t in ["B1", "B2", "B3"] {
            b.add_text_block(page, t, TextStyle::Body).unwrap();
        }
    }
    sync_all(&cloud, &[&pa, &pb]);

    // A 建里程碑並上傳，然後**這台裝置就不在了**。
    let milestone_id = {
        let mut a = NotebookSession::open(&pa, DEVICE_A).unwrap();
        a.create_milestone("看得到 B3", "阿寬", 1_757_635_210_000, false)
            .unwrap()
            .id
    };
    cloud.upload(&pa);

    // B 還沒收到里程碑，又寫了兩筆，壓實，刪掉雲端上被吃掉的碎檔。
    {
        let mut b = NotebookSession::open(&pb, DEVICE_B).unwrap();
        for t in ["B4", "B5"] {
            b.add_text_block(page, t, TextStyle::Body).unwrap();
        }
    }
    let absorbed: Vec<String> = {
        let b = NotebookSession::open(&pb, DEVICE_B).unwrap();
        let outcomes = b.package().compact_own_doc_ops(2, DEVICE_B).unwrap();
        outcomes.iter().flat_map(|o| o.absorbed.clone()).collect()
    };
    assert!(!absorbed.is_empty(), "前提：B 真的壓實了");
    cloud.upload(&pb);
    cloud.delete_ops(&absorbed);

    // 新裝置 C 從雲端整包下載 —— 它從來沒有看過那些碎檔。
    cloud.clone_into(&pc, &pb);

    // C 執行還原。
    {
        let mut c = NotebookSession::open(&pc, 0x0000_00C3).unwrap();
        c.restore_milestone(milestone_id, 1_757_635_220_000, "還原前")
            .unwrap();
    }

    let c = NotebookSession::open(&pc, 0x0000_00C3).unwrap();
    assert_eq!(
        texts(&c, page),
        ["B1", "B2", "B3"],
        "里程碑的那一刀是「B 寫到 B3」—— 就算碎檔已經被壓實吃掉、\
         而且沒有任何裝置留著它們，B1..B3 仍然必須留下來"
    );
}
