//! 畫布物件在平台層的可用性（需求 1–5）。
//!
//! 上一輪的教訓：能力建在 Rust core 裡卻沒開 FFI，平台層一個都碰不到 ——
//! 建了用不到等於沒建。因此這份測試刻意走**平台層會走的那條路**
//! （`PadnoteSession` 與 `#[uniffi::export]` 的自由函式），而非 core 的內部 API。

use padnote_core::ffi::PadnoteSession;
use padnote_core::ffi_shapes::{
    FfiShapeKind, all_shape_kinds, flowchart_shape_kinds, flowchart_templates, shape_semantic,
};
use padnote_core::ffi_ui::{FfiLocale, FfiTool, FfiToolbar, supported_locales};

fn tmp(name: &str) -> String {
    let d = std::env::temp_dir().join(format!("padnote-s46-{name}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&d);
    d.to_string_lossy().into_owned()
}

fn session(name: &str) -> (PadnoteSession, String) {
    let s = PadnoteSession::create(tmp(name), "測試".into(), 1_757_635_200_000, 0xB2).unwrap();
    let page = s.first_page_id().unwrap();
    (s, page)
}

fn stroke_object(s: &PadnoteSession, page: &str, n: u8) -> String {
    let stroke = padnote_core::doc::Uuid::from_bytes([n; 16]).to_string();
    s.create_stroke_object(page.to_string(), vec![stroke])
        .unwrap()
}

#[test]
fn objects_can_be_restacked_from_the_platform_layer() {
    let (s, page) = session("z");
    let a = stroke_object(&s, &page, 1);
    let b = stroke_object(&s, &page, 2);

    assert_eq!(s.z_index(page.clone(), a.clone()).unwrap(), Some(0));

    s.bring_to_front(page.clone(), a.clone()).unwrap();
    assert_eq!(
        s.z_index(page.clone(), a.clone()).unwrap(),
        Some(1),
        "移到最上層後應排在 b 之後"
    );
    assert_eq!(s.z_index(page.clone(), b).unwrap(), Some(0));

    s.send_backward(page.clone(), a.clone()).unwrap();
    assert_eq!(s.z_index(page.clone(), a).unwrap(), Some(0));

    let order = s.draw_order(page).unwrap();
    assert_eq!(order.len(), 2, "兩個物件都要在繪製清單裡");
    assert_eq!(order[0].transform.len(), 6, "變換必須是 6 個係數");
}

#[test]
fn z_order_survives_a_reopen() {
    // 排列順序若不落盤，使用者重開就會看到疊錯的畫面。
    let path = tmp("z-persist");
    let (page, a) = {
        let s =
            PadnoteSession::create(path.clone(), "測試".into(), 1_757_635_200_000, 0xB2).unwrap();
        let page = s.first_page_id().unwrap();
        let a = stroke_object(&s, &page, 1);
        stroke_object(&s, &page, 2);
        s.bring_to_front(page.clone(), a.clone()).unwrap();
        (page, a)
    };

    let back = PadnoteSession::open_existing(path, 0xB2).unwrap();
    assert_eq!(
        back.z_index(page, a).unwrap(),
        Some(1),
        "重開後堆疊順序必須一樣"
    );
}

#[test]
fn tables_round_trip_through_the_ffi() {
    let (s, page) = session("table");
    let id = s
        .insert_table(
            page,
            2,
            2,
            vec!["項目".into(), "數量".into(), "筆記本".into(), "3".into()],
            true,
        )
        .unwrap();

    s.set_table_cell(id.clone(), 1, 1, "9".into()).unwrap();
    assert!(
        s.set_table_cell(id, 5, 0, "x".into()).is_err(),
        "越界必須報錯，不能靜默吞掉"
    );
}

#[test]
fn every_shape_and_template_is_reachable() {
    assert_eq!(all_shape_kinds().len(), 20);
    assert_eq!(flowchart_shape_kinds().len(), 9, "ISO 5807 的九個符號");
    for k in flowchart_shape_kinds() {
        assert!(
            shape_semantic(k).is_some(),
            "{k:?} 是流程圖符號卻沒有語意說明"
        );
    }
    assert!(shape_semantic(FfiShapeKind::Star).is_none());
    assert!(!flowchart_templates().is_empty());
}

#[test]
fn the_toolbar_is_customisable_in_every_language() {
    for info in supported_locales() {
        let tb = FfiToolbar::new(info.locale);
        let groups = tb.all_groups();
        assert!(!groups.is_empty(), "{} 沒有任何分組", info.tag);
        for g in &groups {
            assert!(
                !g.label.is_empty(),
                "{} 的分組 {:?} 缺標籤",
                info.tag,
                g.group
            );
            for t in &g.tools {
                assert!(!t.label.is_empty(), "{} 的 {:?} 缺標籤", info.tag, t.tool);
            }
        }
    }

    let tb = FfiToolbar::new(FfiLocale::Thai);
    assert!(tb.is_visible(FfiTool::Eraser));
    tb.set_visible(FfiTool::Eraser, false);
    assert!(!tb.is_visible(FfiTool::Eraser));
    tb.reset();
    assert!(tb.is_visible(FfiTool::Eraser), "reset 必須回得去");
}
