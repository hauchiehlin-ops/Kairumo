//! 筆畫互通的往返保真度（工作包 WP4）。
//!
//! 驗收條件寫的是「iOS 建立的筆記在 Android 開啟後，筆畫數、座標、顏色與原稿
//! 一致」。那句話要能被檢查，核心就必須提供**完整**的筆畫讀回路徑 ——
//! 只有外框與筆畫數是驗不出座標錯位或壓感遺失的。
//!
//! 這份測試刻意走平台層會走的那條路（`PadnoteSession` 的 `#[uniffi::export]`
//! 方法），而不是 core 內部 API：能力沒開到 FFI，平台層就碰不到。

use padnote_core::ffi::{PadnoteSession, StrokePoint, ToolKind};

fn tmp(name: &str) -> String {
    let d = std::env::temp_dir().join(format!("padnote-s47-{name}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&d);
    d.to_string_lossy().into_owned()
}

/// 刻意用不規則的數值：整數或 0 很容易讓「欄位接錯位置」的 bug 蒙混過關。
fn sample_points() -> Vec<StrokePoint> {
    vec![
        StrokePoint {
            x: 12.5,
            y: 300.25,
            pressure: 0.125,
            tilt: 0.75,
            azimuth: 1.5,
            dt_us: 0,
        },
        StrokePoint {
            x: 13.75,
            y: 301.5,
            pressure: 0.5,
            tilt: 0.8,
            azimuth: 1.75,
            dt_us: 8_333,
        },
        StrokePoint {
            x: 60.0,
            y: 280.125,
            pressure: 0.875,
            tilt: 0.2,
            azimuth: 4.5,
            dt_us: 8_334,
        },
    ]
}

/// 格式規格 §5.4 明訂 `pressure` / `tilt` / `azimuth` 各用一個 u16 定點數
/// 儲存（整點 16 bytes）。所以「往返後完全相同」只對 x / y / dt 成立；
/// 這三個欄位的正確期望是**誤差不超過一個量化格**。
///
/// 第一版測試把這三個也寫成位元組相等，結果測試紅了 —— 紅的是測試而不是程式。
/// 把期望改成規格實際允許的範圍，這條測試才擋得住真正的錯誤（欄位接錯、
/// 角度用錯最大值），而不是每次都在抱怨格式本來就這樣設計。
const PRESSURE_STEP: f32 = 1.0 / 65_535.0;
const TILT_STEP: f32 = std::f32::consts::FRAC_PI_2 / 65_535.0;
const AZIMUTH_STEP: f32 = std::f32::consts::TAU / 65_535.0;

fn assert_points_identical(expected: &[StrokePoint], actual: &[StrokePoint]) {
    assert_eq!(expected.len(), actual.len(), "取樣點數不同");
    for (i, (e, a)) in expected.iter().zip(actual).enumerate() {
        // 座標必須位元組相同：存的是原始取樣點，不做任何再取樣或平滑。
        assert_eq!(e.x.to_bits(), a.x.to_bits(), "第 {i} 點 x 不同");
        assert_eq!(e.y.to_bits(), a.y.to_bits(), "第 {i} 點 y 不同");
        assert_eq!(e.dt_us, a.dt_us, "第 {i} 點時間差不同");

        let checks = [
            ("壓感", e.pressure, a.pressure, PRESSURE_STEP),
            ("傾斜", e.tilt, a.tilt, TILT_STEP),
            ("方位", e.azimuth, a.azimuth, AZIMUTH_STEP),
        ];
        for (name, want, got, step) in checks {
            assert!(
                (want - got).abs() <= step,
                "第 {i} 點{name}超出一個量化格：期望 {want}、實得 {got}、格寬 {step}"
            );
        }
    }
}

#[test]
fn a_stroke_survives_write_then_read_without_losing_anything() {
    let s = PadnoteSession::create(tmp("rt"), "往返".into(), 1_757_635_200_000, 0xA1).unwrap();
    let page = s.first_page_id().unwrap();
    let points = sample_points();

    let id = s
        .add_stroke(
            page.clone(),
            ToolKind::Highlighter,
            vec![10, 200, 30, 128],
            4.25,
            points.clone(),
        )
        .unwrap();

    let got = s
        .stroke_detail(page, id.clone())
        .unwrap()
        .expect("應該找得到剛寫入的筆畫");
    assert_eq!(got.id, id);
    assert!(matches!(got.tool, ToolKind::Highlighter));
    assert_eq!(got.color_rgba, vec![10, 200, 30, 128]);
    assert_eq!(got.base_width.to_bits(), 4.25f32.to_bits());
    assert_points_identical(&points, &got.points);
}

#[test]
fn reopening_the_package_gives_back_the_same_bytes() {
    // 這一條才是「Android 打開 iOS 寫的檔案」真正走的路徑：關掉、重播 op-log、再讀。
    let path = tmp("reopen");
    let points = sample_points();
    let (page, id) = {
        let s =
            PadnoteSession::create(path.clone(), "重開".into(), 1_757_635_200_000, 0xA2).unwrap();
        let page = s.first_page_id().unwrap();
        let id = s
            .add_stroke(
                page.clone(),
                ToolKind::FountainPen,
                vec![0, 0, 0, 255],
                2.0,
                points.clone(),
            )
            .unwrap();
        (page, id)
    };

    // 換一個 device_id 開啟：模擬「另一台裝置」，而不是同一台重啟。
    let reopened = PadnoteSession::open_existing(path, 0xB9).unwrap();
    let details = reopened.visible_stroke_details(page).unwrap();
    assert_eq!(details.len(), 1, "重開後筆畫數必須一致");
    assert_eq!(details[0].id, id);
    assert!(matches!(details[0].tool, ToolKind::FountainPen));
    assert_points_identical(&points, &details[0].points);
}

#[test]
fn every_tool_round_trips_to_itself() {
    // 筆刷對應表寫反了也不會 panic，只會讓螢光筆變原子筆 —— 必須逐一釘住。
    let s = PadnoteSession::create(tmp("tools"), "筆刷".into(), 1_757_635_200_000, 0xA3).unwrap();
    let page = s.first_page_id().unwrap();
    let tools = [
        (ToolKind::FountainPen, "FountainPen"),
        (ToolKind::BallPoint, "BallPoint"),
        (ToolKind::Highlighter, "Highlighter"),
        (ToolKind::Pencil, "Pencil"),
    ];
    for (tool, name) in tools {
        let id = s
            .add_stroke(page.clone(), tool, vec![1, 2, 3, 4], 1.0, sample_points())
            .unwrap();
        let got = s.stroke_detail(page.clone(), id).unwrap().unwrap();
        assert_eq!(format!("{:?}", got.tool), name, "筆刷 {name} 沒有原樣回來");
    }
}

#[test]
fn erased_strokes_do_not_come_back() {
    let s = PadnoteSession::create(tmp("erase"), "擦除".into(), 1_757_635_200_000, 0xA4).unwrap();
    let page = s.first_page_id().unwrap();
    let id = s
        .add_stroke(
            page.clone(),
            ToolKind::Pencil,
            vec![9, 9, 9, 255],
            1.5,
            sample_points(),
        )
        .unwrap();

    s.erase_stroke(page.clone(), id.clone()).unwrap();

    assert!(s.visible_stroke_details(page.clone()).unwrap().is_empty());
    assert!(
        s.stroke_detail(page, id).unwrap().is_none(),
        "擦掉的筆畫不該被互通路徑撈回來"
    );
}

#[test]
fn many_points_survive_the_ffi_boundary() {
    // 真實一筆畫（120Hz 寫兩秒）大約就是這個量級。少一個點在畫面上看不出來，
    // 所以必須數，不能用眼睛看。
    let s = PadnoteSession::create(tmp("many"), "長筆畫".into(), 1_757_635_200_000, 0xA5).unwrap();
    let page = s.first_page_id().unwrap();
    let points: Vec<StrokePoint> = (0..2_400)
        .map(|i| StrokePoint {
            x: i as f32 * 0.25,
            y: (i as f32 * 0.125).sin() * 100.0,
            pressure: (i % 100) as f32 / 100.0,
            tilt: 0.3,
            azimuth: 2.0,
            dt_us: 8_333,
        })
        .collect();

    let id = s
        .add_stroke(
            page.clone(),
            ToolKind::BallPoint,
            vec![255, 0, 0, 255],
            3.0,
            points.clone(),
        )
        .unwrap();
    let got = s.stroke_detail(page, id).unwrap().unwrap();
    assert_points_identical(&points, &got.points);
}

// ---- 頁面尺寸與區塊座標（WP4 的另外兩項驗收條件）----

#[test]
fn page_height_survives_reopening() {
    // 「頁面高度與原稿一致」是驗收條件之一。Kairumo 的畫布可以向下延長，
    // 沒有落盤的話另一個平台會變回預設高度，看起來像內容被截掉。
    let path = tmp("pagesize");
    let page = {
        let s =
            PadnoteSession::create(path.clone(), "長畫布".into(), 1_757_635_200_000, 0xC1).unwrap();
        let page = s.first_page_id().unwrap();
        s.set_page_size(page.clone(), 595.0, 3_200.0).unwrap();
        assert_eq!(
            s.page_size(page.clone()).unwrap(),
            Some(vec![595.0, 3_200.0])
        );
        page
    };

    let reopened = PadnoteSession::open_existing(path, 0xC2).unwrap();
    assert_eq!(
        reopened.page_size(page).unwrap(),
        Some(vec![595.0, 3_200.0]),
        "延長過的頁面高度必須跟著檔案走"
    );
}

#[test]
fn block_position_survives_reopening() {
    // 文字方塊與圖片是絕對定位的。位置沒進 op-log 的話，跨平台打開會擠在一起。
    let path = tmp("blockpos");
    let block = {
        let s =
            PadnoteSession::create(path.clone(), "定位".into(), 1_757_635_200_000, 0xC3).unwrap();
        let page = s.first_page_id().unwrap();
        let block = s
            .add_text(page, "會議重點".into(), padnote_core::ffi::BlockStyle::Body)
            .unwrap();
        assert_eq!(
            s.block_position(block.clone()).unwrap(),
            None,
            "尚未定位前應為 None"
        );
        s.set_block_position(block.clone(), 120.5, 480.25).unwrap();
        block
    };

    let reopened = PadnoteSession::open_existing(path, 0xC4).unwrap();
    assert_eq!(
        reopened.block_position(block).unwrap(),
        Some(vec![120.5, 480.25])
    );
}

#[test]
fn positioning_a_missing_block_is_an_error_not_a_silent_noop() {
    // 靜默忽略的話，平台層會以為位置寫進去了，直到使用者發現物件跑掉。
    let s = PadnoteSession::create(tmp("misspos"), "錯誤".into(), 1_757_635_200_000, 0xC5).unwrap();
    let ghost = "00000000-0000-7000-8000-0000000000ff".to_string();
    assert!(s.set_block_position(ghost, 1.0, 2.0).is_err());
}

#[test]
fn every_page_can_be_reached_by_index() {
    // 多頁筆記若只拿得到第一頁，「多頁筆記在 Android 開起來一致」就無從談起。
    let s = PadnoteSession::create(tmp("pages"), "多頁".into(), 1_757_635_200_000, 0xC6).unwrap();
    let first = s.first_page_id().unwrap();
    let second = s.add_page(padnote_core::ffi::PageStyle::Grid).unwrap();
    let third = s.add_page(padnote_core::ffi::PageStyle::Lined).unwrap();

    assert_eq!(s.page_count(), 3);
    assert_eq!(s.page_id_at(0), Some(first));
    assert_eq!(s.page_id_at(1), Some(second));
    assert_eq!(s.page_id_at(2), Some(third));
    assert_eq!(
        s.page_id_at(3),
        None,
        "超出範圍要回 None，不是 panic 也不是最後一頁"
    );
}

// ---- 文字方塊的外觀（跨平台）----

#[test]
fn block_appearance_survives_reopening() {
    // 使用者在 iPad 上把文字方塊設成透明底、加了行距，換到 Android 打開卻
    // 變回白底無行距 —— 那不是「還沒支援」，是資料遺失。
    let path = tmp("appearance");
    let style = r#"{"backgroundColorHex":"clear","lineSpacing":8,"hasBorder":false}"#;
    let block = {
        let s =
            PadnoteSession::create(path.clone(), "外觀".into(), 1_757_635_200_000, 0xD1).unwrap();
        let page = s.first_page_id().unwrap();
        let block = s
            .add_text(page, "會議重點".into(), padnote_core::ffi::BlockStyle::Body)
            .unwrap();
        assert_eq!(
            s.block_appearance(block.clone()).unwrap(),
            None,
            "尚未設定前應為 None"
        );
        s.set_block_appearance(block.clone(), style.into()).unwrap();
        block
    };

    let reopened = PadnoteSession::open_existing(path, 0xD2).unwrap();
    assert_eq!(
        reopened.block_appearance(block).unwrap().as_deref(),
        Some(style)
    );
}

#[test]
fn the_core_does_not_interpret_the_appearance_json() {
    // 核心不該對內容有任何假設 —— 平台之後新增欄位時不必動核心。
    let s =
        PadnoteSession::create(tmp("opaque"), "不解讀".into(), 1_757_635_200_000, 0xD3).unwrap();
    let page = s.first_page_id().unwrap();
    let block = s
        .add_text(page, "x".into(), padnote_core::ffi::BlockStyle::Body)
        .unwrap();

    let odd = r#"{"somethingWeHaveNotInventedYet":[1,2,3],"nested":{"a":"b"}}"#;
    s.set_block_appearance(block.clone(), odd.into()).unwrap();
    assert_eq!(s.block_appearance(block).unwrap().as_deref(), Some(odd));
}

#[test]
fn appearance_on_a_missing_block_is_an_error_not_a_silent_noop() {
    // 靜默忽略的話，平台層會以為樣式存進去了，直到使用者發現它沒有跨過去。
    let s =
        PadnoteSession::create(tmp("missappear"), "錯誤".into(), 1_757_635_200_000, 0xD4).unwrap();
    let ghost = "00000000-0000-7000-8000-0000000000ee".to_string();
    assert!(s.set_block_appearance(ghost, "{}".into()).is_err());
}

#[test]
fn text_blocks_on_a_page_can_be_enumerated() {
    // 拿得到某個區塊的內容與外觀，卻列不出有哪些區塊的話，
    // 平台層就打不開別的裝置寫進來的文字方塊。
    let s = PadnoteSession::create(tmp("enum"), "列舉".into(), 1_757_635_200_000, 0xD5).unwrap();
    let page = s.first_page_id().unwrap();

    let a = s
        .add_text(
            page.clone(),
            "第一段".into(),
            padnote_core::ffi::BlockStyle::Body,
        )
        .unwrap();
    let b = s
        .add_text(
            page.clone(),
            "第二段".into(),
            padnote_core::ffi::BlockStyle::Body,
        )
        .unwrap();
    // 圖片不是文字區塊，不該被列進來
    let blob = s.put_blob(vec![1, 2, 3]).unwrap();
    s.add_image(page.clone(), blob, 10.0, 10.0).unwrap();

    assert_eq!(s.text_block_ids(page).unwrap(), vec![a, b]);
}

#[test]
fn enumerating_an_unknown_page_is_empty_not_an_error() {
    let s = PadnoteSession::create(tmp("enum2"), "列舉".into(), 1_757_635_200_000, 0xD6).unwrap();
    let ghost = "00000000-0000-7000-8000-0000000000dd".to_string();
    assert!(s.text_block_ids(ghost).unwrap().is_empty());
}
