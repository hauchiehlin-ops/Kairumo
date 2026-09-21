//! 一致性向量的產生與驗證（一致性閘門 1）。
//!
//! # 為什麼需要它
//!
//! 兩端有大量成對的測試，測的是同一件事，但**期望值各寫一份**。
//! 2026-09-22 查證時抓到的例子：Android 的 `DocumentTemplateCatalogTest`
//! 檢查「區塊不可以掉到紙外面」，Apple 的 `DocumentTemplateTests`
//! **沒有這一條**；反過來 Apple 檢查「頁數要放得下所有區塊」，Android 用
//! 另一種寫法檢查。兩邊測的是同一件事的不同子集，
//! 而**沒有人知道哪一邊漏了什麼**。
//!
//! 那正是這個專案一路踩過來的形狀：同一個事實兩份表示，沒有東西強迫它們一致。
//!
//! # 做法
//!
//! 核心**產生**向量（輸入 → 期望輸出），兩端各有一支測試讀它、跑、比對。
//! 向量是產生的，不是手寫的 —— 手寫等於把問題原封不動搬到另一個檔案裡。
//!
//! - 重新產生：`UPDATE_CONFORMANCE=1 cargo test -p padnote-core --test conformance_vectors`
//! - 驗證（CI 走這條）：直接跑測試，內容有差就紅。
//!
//! # 這裡**不**比什麼
//!
//! 不比像素。兩端的算繪本來就不同（PencilKit vs 自繪），逐像素比對會是
//! 一個永遠在紅的閘門。這裡比的是**資料與版面數字**。

use padnote_core::ffi;
use serde_json::{Value, json};

fn vector_dir() -> std::path::PathBuf {
    std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("../../docs/conformance")
        .canonicalize()
        .expect("docs/conformance 要先存在")
}

// ────────────────────── 各組向量 ──────────────────────

/// 版面數字。曾經 1040 / 420 / 900 在三個地方各存一份。
fn layout() -> Value {
    let cases: Vec<Value> = [320.0f32, 375.0, 428.0, 600.0, 744.0, 840.0, 1024.0, 1366.0]
        .iter()
        .map(|&w| {
            let m = padnote_core::ffi_layout::layout_metrics(w);
            json!({
                "width": w,
                "size_class": format!("{:?}", m.size_class),
                "gutter": m.gutter,
                "content_max_width": m.content_max_width,
                "readable_max_width": m.readable_max_width,
                "sidebar_width": m.sidebar_width,
                "sidebar_is_inline": m.sidebar_is_inline,
                "note_columns": m.note_columns,
            })
        })
        .collect();
    json!({ "cases": cases })
}

/// 壓感曲線。曾經 Apple 端手抄 0.35 / 0.65 兩個常數。
fn ink_curve() -> Value {
    use ffi::ToolKind::*;
    let tools = [
        ("FountainPen", FountainPen),
        ("BallPoint", BallPoint),
        ("Highlighter", Highlighter),
        ("Pencil", Pencil),
        ("Brush", Brush),
        ("Marker", Marker),
        ("Watercolor", Watercolor),
    ];
    let cases: Vec<Value> = tools
        .iter()
        .map(|(name, tool)| {
            let scales: Vec<f32> = [0.0f32, 0.25, 0.5, 0.75, 1.0]
                .iter()
                .map(|&p| ffi::ink_width_scale(*tool, p))
                .collect();
            json!({
                "tool": name,
                "pressure_sensitive": ffi::ink_tool_is_pressure_sensitive(*tool),
                "pressures": [0.0, 0.25, 0.5, 0.75, 1.0],
                "width_scales": scales,
            })
        })
        .collect();
    json!({ "cases": cases })
}

/// 掌拒門檻的範圍與預設（工作項 S-101）。
fn palm() -> Value {
    let l = padnote_core::ffi_input::palm_threshold_limits();
    json!({
        "default_radius_dp": l.default_radius_dp,
        "finger_mode_radius_dp": l.finger_mode_radius_dp,
        "min_radius_dp": l.min_radius_dp,
        "max_radius_dp": l.max_radius_dp,
        "default_retract_ms": l.default_retract_ms,
        "min_retract_ms": l.min_retract_ms,
        "max_retract_ms": l.max_retract_ms,
        // 曾經有人把核心內部的微秒預設值當成毫秒傳進來（500 秒）。
        "clamped": [
            { "in": 500000, "out": padnote_core::ffi_input::palm_retract_ms_clamped(500_000) },
            { "in": 50,     "out": padnote_core::ffi_input::palm_retract_ms_clamped(50) },
        ],
    })
}

/// 墨跡延遲預算（一致性閘門 4）。
///
/// 這兩個數字原本只寫在 `docs/TODO.md` 裡 —— 寫在文件裡的數字擋不住任何人。
fn ink_latency_budget() -> Value {
    let b = padnote_core::ffi_input::ink_latency_budget();
    json!({
        "median_us": b.median_us,
        "p95_us": b.p95_us,
        "cases": [
            { "median_us": 9000, "p95_us": 12000, "ok": true },
            { "median_us": 9001, "p95_us": 12000, "ok": false },
            { "median_us": 9000, "p95_us": 12001, "ok": false },
        ],
    })
}

/// 符號面板。Apple 曾經把陣列寫死在工具列裡。
fn symbols() -> Value {
    let cases: Vec<Value> = padnote_core::ffi_symbols::symbol_categories()
        .into_iter()
        .map(|c| {
            json!({
                "category": format!("{c:?}"),
                "symbols": padnote_core::ffi_symbols::symbol_palette(c),
            })
        })
        .collect();
    json!({ "cases": cases })
}

/// 版面輔助線。匯出的 PDF 曾經完全沒有它們（畫布是康乃爾、匯出是空白紙）。
fn page_guides() -> Value {
    let cases: Vec<Value> = ["blank", "lined", "grid", "dotted", "cornell"]
        .iter()
        .map(|&id| {
            let guides = padnote_core::ffi_guides::page_guides(id.to_string(), 800.0, 1132.0);
            json!({
                "paper_id": id,
                "count": guides.len(),
                "guides": guides.iter().take(8).map(|g| json!({
                    "kind": format!("{:?}", g.kind),
                    "x": g.x, "y": g.y, "w": g.w, "h": g.h,
                })).collect::<Vec<_>>(),
            })
        })
        .collect();
    json!({ "cases": cases })
}

/// 頁面幾何。兩端的分頁位置與可列印範圍都靠它。
fn page_geometry() -> Value {
    let size = ffi::standard_page_size();
    let inset = 24.0f32;
    let r = padnote_core::ffi_geometry::printable_rect(size[0], size[1], inset);
    json!({
        "width": size[0],
        "height": size[1],
        "printable_inset": inset,
        "printable_rect": [r.min_x, r.min_y, r.max_x, r.max_y],
    })
}

fn all() -> Vec<(&'static str, Value)> {
    vec![
        ("layout.json", layout()),
        ("ink-curve.json", ink_curve()),
        ("palm.json", palm()),
        ("ink-latency.json", ink_latency_budget()),
        ("symbols.json", symbols()),
        ("page-guides.json", page_guides()),
        ("page-geometry.json", page_geometry()),
    ]
}

// ────────────────────── 產生／驗證 ──────────────────────

#[test]
fn conformance_vectors_are_up_to_date() {
    let dir = vector_dir();
    let updating = std::env::var("UPDATE_CONFORMANCE").is_ok();
    let mut stale = Vec::new();

    for (name, value) in all() {
        let text = format!("{}\n", serde_json::to_string_pretty(&value).unwrap());
        let path = dir.join(name);
        let current = std::fs::read_to_string(&path).unwrap_or_default();
        if current == text {
            continue;
        }
        if updating {
            std::fs::write(&path, &text).unwrap();
        } else {
            stale.push(name);
        }
    }

    assert!(
        stale.is_empty(),
        "這幾組向量與核心目前的行為不一致：{stale:?}\n\
         如果核心的改動是故意的，重新產生並**連同兩端的測試一起檢視**：\n\
             UPDATE_CONFORMANCE=1 cargo test -p padnote-core --test conformance_vectors\n\
         向量改了就代表兩個平台的行為都會跟著改 —— 那正是要被看見的那一刻。"
    );
}
