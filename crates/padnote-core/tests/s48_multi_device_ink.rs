//! 兩台裝置在同一本筆記上書寫，筆畫不能互相覆蓋。
//!
//! # 為什麼要有這份測試
//!
//! 架構不變式 1 是「每台裝置只寫自己 `device_id` 的檔案」。`doc/ops/` 一直
//! 遵守它，但筆畫檔原本是 `ink/<page>.strokes` —— **每頁一個檔、與裝置無關**。
//! 單機用完全正常；一旦把套件放進共用的雲端資料夾，兩台裝置寫同一頁就會
//! 寫同一個檔名，後到的那份蓋掉先到的，手寫就這樣不見了，而且沒有任何錯誤。
//!
//! 這份測試模擬的就是那個情境：同一個套件目錄、兩個不同的 device id。

use padnote_core::ffi::{PadnoteSession, StrokePoint, ToolKind};

fn tmp(name: &str) -> String {
    let d = std::env::temp_dir().join(format!("padnote-s48-{name}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&d);
    d.to_string_lossy().into_owned()
}

fn points(x: f32) -> Vec<StrokePoint> {
    (0..6)
        .map(|i| StrokePoint {
            x: x + i as f32,
            y: 100.0,
            pressure: 0.5,
            tilt: 0.3,
            azimuth: 1.0,
            dt_us: if i == 0 { 0 } else { 8_333 },
        })
        .collect()
}

#[test]
fn two_devices_writing_the_same_page_keep_both_sets_of_strokes() {
    let path = tmp("share");

    let page = {
        let a = PadnoteSession::create(path.clone(), "共用".into(), 1_757_635_200_000, 0xAAAA_AAAA)
            .unwrap();
        let page = a.first_page_id().unwrap();
        a.add_stroke(page.clone(), ToolKind::FountainPen, vec![0, 0, 0, 255], 3.0, points(0.0))
            .unwrap();
        page
    };

    // 另一台裝置開同一個套件（同步資料夾裡就是這樣）並在同一頁上寫字
    {
        let b = PadnoteSession::open_existing(path.clone(), 0xBBBB_BBBB).unwrap();
        b.add_stroke(page.clone(), ToolKind::BallPoint, vec![255, 0, 0, 255], 2.0, points(500.0))
            .unwrap();
    }

    let reader = PadnoteSession::open_existing(path, 0xCCCC_CCCC).unwrap();
    let strokes = reader.visible_stroke_details(page).unwrap();
    assert_eq!(strokes.len(), 2, "兩台裝置的筆畫都要在，實得 {}", strokes.len());

    let xs: Vec<f32> = strokes.iter().map(|s| s.points[0].x).collect();
    assert!(xs.contains(&0.0), "A 裝置的筆畫不見了");
    assert!(xs.contains(&500.0), "B 裝置的筆畫不見了");
}

#[test]
fn each_device_writes_its_own_ink_file() {
    // 直接檢查檔名 —— 這是「檔案層級衝突不可能發生」的實體憑據。
    let path = tmp("files");
    let page = {
        let a = PadnoteSession::create(path.clone(), "檔名".into(), 1_757_635_200_000, 0x1111_1111)
            .unwrap();
        let page = a.first_page_id().unwrap();
        a.add_stroke(page.clone(), ToolKind::Pencil, vec![0, 0, 0, 255], 1.0, points(1.0))
            .unwrap();
        page
    };
    {
        let b = PadnoteSession::open_existing(path.clone(), 0x2222_2222).unwrap();
        b.add_stroke(page, ToolKind::Pencil, vec![0, 0, 0, 255], 1.0, points(2.0))
            .unwrap();
    }

    let names: Vec<String> = std::fs::read_dir(std::path::Path::new(&path).join("ink"))
        .unwrap()
        .map(|e| e.unwrap().file_name().to_string_lossy().into_owned())
        .collect();
    assert_eq!(names.len(), 2, "兩台裝置應該各有一個檔，實得 {names:?}");
    assert!(names.iter().any(|n| n.contains("11111111")));
    assert!(names.iter().any(|n| n.contains("22222222")));
}

#[test]
fn strokes_written_by_the_legacy_layout_are_still_readable() {
    // 使用者手上已經有 `ink/<page>.strokes` 這種檔案了。改了命名規則之後，
    // 那些筆畫不能就此消失 —— 那會是最嚴重的一種資料遺失。
    let path = tmp("legacy");
    let (page, legacy_bytes) = {
        let s = PadnoteSession::create(path.clone(), "舊版".into(), 1_757_635_200_000, 0x3333_3333)
            .unwrap();
        let page = s.first_page_id().unwrap();
        s.add_stroke(page.clone(), ToolKind::FountainPen, vec![0, 0, 0, 255], 3.0, points(7.0))
            .unwrap();
        let ink_dir = std::path::Path::new(&path).join("ink");
        let written = std::fs::read_dir(&ink_dir).unwrap().next().unwrap().unwrap().path();
        let bytes = std::fs::read(&written).unwrap();
        std::fs::remove_file(&written).unwrap();
        (page, bytes)
    };

    // 用舊版的命名把同一份位元組放回去
    let legacy = std::path::Path::new(&path)
        .join("ink")
        .join(format!("{page}.strokes"));
    std::fs::write(&legacy, &legacy_bytes).unwrap();

    let reopened = PadnoteSession::open_existing(path, 0x4444_4444).unwrap();
    let strokes = reopened.visible_stroke_details(page).unwrap();
    assert_eq!(strokes.len(), 1, "舊版命名的筆畫必須仍然讀得到");
    assert_eq!(strokes[0].points[0].x, 7.0);
}

#[test]
fn a_stroke_erased_on_one_device_stays_erased_on_the_other() {
    // 墓碑是寫在擦除那一台的檔案裡的。串接時若順序不對（刪除排在新增之前），
    // 被擦掉的筆畫會復活。`materialize` 先收齊墓碑再過濾，這條釘住那個性質。
    let path = tmp("erase");
    let (page, stroke_id) = {
        let a = PadnoteSession::create(path.clone(), "擦除".into(), 1_757_635_200_000, 0x5555_5555)
            .unwrap();
        let page = a.first_page_id().unwrap();
        let id = a
            .add_stroke(page.clone(), ToolKind::Pencil, vec![0, 0, 0, 255], 1.0, points(3.0))
            .unwrap();
        (page, id)
    };
    {
        let b = PadnoteSession::open_existing(path.clone(), 0x6666_6666).unwrap();
        b.erase_stroke(page.clone(), stroke_id).unwrap();
    }

    let reader = PadnoteSession::open_existing(path, 0x7777_7777).unwrap();
    assert!(
        reader.visible_stroke_details(page).unwrap().is_empty(),
        "在另一台裝置擦掉的筆畫不該復活"
    );
}
