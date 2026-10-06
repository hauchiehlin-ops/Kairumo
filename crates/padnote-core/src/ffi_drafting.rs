//! 圖學的二維製圖工具（`padnote-drafting`）給平台用的介面：尺寸標註、符號、圖框與標題欄。
//!
//! 輸出一律是**製圖筆畫**（`FfiSheetStroke`：角色已經換成圖層、線型、筆寬與顏色）加上要放文字方塊的
//! 標籤（`FfiExampleText`，語系鍵）。平台用現有的「插入圖紙」流程落地 —— 放在視野中央、自動套索選住、
//! 一次復原。幾何與數字都在核心算，兩個平台畫出來完全相同。

use padnote_drafting::align;
use padnote_drafting::check::{self, Issue, LineKind, Seg, Tolerance};
use padnote_drafting::dim::{self, DimStyle, LinearAxis};
use padnote_drafting::edit;
use padnote_drafting::export2d::{self, ExportStroke};
use padnote_drafting::frame::{self, FrameOptions};
use padnote_drafting::instruments::{self, InstrumentKind};
use padnote_drafting::problems::{self, ErrorKind};
use padnote_drafting::symbols::{self, SymbolParams};
use padnote_drafting::{Drawing, UNITS_PER_MM};

use crate::ffi_draft::draft_pens;
use crate::ffi_draft_example::FfiExampleText;
use crate::ffi_shapes::FfiPoint;
use crate::ffi_solid::{FfiSheetStroke, pen_for};

/// 製圖成品：折線（已換成製圖筆）＋文字標籤。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiDraftKit {
    pub strokes: Vec<FfiSheetStroke>,
    pub texts: Vec<FfiExampleText>,
}

/// 一個標註：筆畫、標在圖上的文字、實物的數值（長度是毫米、角度是度）。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiDimension {
    pub strokes: Vec<FfiSheetStroke>,
    pub text: String,
    pub value: f32,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, uniffi::Enum)]
pub enum FfiDimAxis {
    /// 依尺寸線擺的位置決定水平或垂直。
    Auto,
    Horizontal,
    Vertical,
    /// 與兩點連線平行。
    Aligned,
}

/// 比例尺選項：`ratio` = 實物 / 圖上（1:2 → 2，2:1 → 0.5）。
#[derive(Clone, Debug, PartialEq, uniffi::Record)]
pub struct FfiDraftScale {
    pub label: String,
    pub ratio: f32,
}

/// 符號的參數。用到哪些欄位依符號而定；其餘忽略。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiSymbolParams {
    pub size_mm: f32,
    pub text: String,
    pub rotation_deg: f32,
    pub other_side: bool,
    pub all_around: bool,
    pub field: bool,
    pub diameter: bool,
    /// 幾何公差的基準字母，例如 `"AB"`。
    pub datums: String,
    pub length_mm: f32,
}

/// 符號清單的一項。
#[derive(Clone, Debug, PartialEq, uniffi::Record)]
pub struct FfiDraftSymbolInfo {
    pub id: String,
    /// 分組：surface／weld／thread／gdt／mark／fastener。
    pub group: String,
    /// 語系鍵 `draft_sym_<id>`。
    pub name_key: String,
}

fn kit_strokes(d: &Drawing) -> Vec<FfiSheetStroke> {
    let pens = draft_pens();
    d.strokes
        .iter()
        .filter_map(|s| {
            let pen = pens.iter().find(|p| p.id == pen_for(s.role))?;
            Some(FfiSheetStroke {
                points: s
                    .points
                    .iter()
                    .map(|p| FfiPoint { x: p.0, y: p.1 })
                    .collect(),
                layer: pen.layer,
                line_type: pen.line_type,
                width: pen.width,
                color_hex: pen.color_hex.clone(),
            })
        })
        .collect()
}

fn kit_from(d: &Drawing) -> FfiDraftKit {
    FfiDraftKit {
        strokes: kit_strokes(d),
        texts: d
            .labels
            .iter()
            .map(|l| FfiExampleText {
                key: l.key.clone(),
                x: l.x,
                y: l.y,
                width: l.width,
                font_size: l.size,
                bold: l.bold,
                color_hex: "#111827".into(),
            })
            .collect(),
    }
}

fn dimension_from(d: dim::Dimension) -> Option<FfiDimension> {
    if d.strokes.is_empty() {
        return None;
    }
    let strokes = kit_strokes(&Drawing {
        strokes: d.strokes,
        labels: Vec::new(),
    });
    Some(FfiDimension {
        strokes,
        text: d.text,
        value: d.value,
    })
}

fn p(a: FfiPoint) -> (f32, f32) {
    (a.x, a.y)
}

/// 頁面單位／毫米（A4 寬 210 mm = 800 單位；所有紙張規格同一個比例）。
#[uniffi::export]
pub fn draft_units_per_mm() -> f32 {
    UNITS_PER_MM
}

/// 常用的比例尺（工程製圖課常用：縮小、原尺寸、放大）。
#[uniffi::export]
pub fn draft_scales() -> Vec<FfiDraftScale> {
    [
        ("1:1", 1.0),
        ("1:2", 2.0),
        ("1:5", 5.0),
        ("1:10", 10.0),
        ("1:20", 20.0),
        ("1:50", 50.0),
        ("2:1", 0.5),
        ("5:1", 0.2),
        ("10:1", 0.1),
    ]
    .into_iter()
    .map(|(label, ratio)| FfiDraftScale {
        label: label.into(),
        ratio,
    })
    .collect()
}

/// 線性標註：`p1`、`p2` 是被標註的兩點，`through` 是尺寸線要經過的位置。兩點重合回 `None`。
#[uniffi::export]
pub fn draft_dim_linear(
    p1: FfiPoint,
    p2: FfiPoint,
    through: FfiPoint,
    axis: FfiDimAxis,
    ratio: f32,
) -> Option<FfiDimension> {
    let axis = match axis {
        FfiDimAxis::Auto => LinearAxis::Auto,
        FfiDimAxis::Horizontal => LinearAxis::Horizontal,
        FfiDimAxis::Vertical => LinearAxis::Vertical,
        FfiDimAxis::Aligned => LinearAxis::Aligned,
    };
    dimension_from(dim::linear(
        p(p1),
        p(p2),
        p(through),
        axis,
        ratio.max(1e-3),
        &DimStyle::iso(),
    ))
}

/// 直徑標註：圓心、半徑，引線從圓上 `dir` 方向那一點出去。
#[uniffi::export]
pub fn draft_dim_diameter(
    center: FfiPoint,
    radius: f32,
    dir: FfiPoint,
    ratio: f32,
) -> Option<FfiDimension> {
    dimension_from(dim::diameter(
        p(center),
        radius,
        p(dir),
        ratio.max(1e-3),
        &DimStyle::iso(),
    ))
}

/// 半徑標註。
#[uniffi::export]
pub fn draft_dim_radius(
    center: FfiPoint,
    radius: f32,
    dir: FfiPoint,
    ratio: f32,
) -> Option<FfiDimension> {
    dimension_from(dim::radius(
        p(center),
        radius,
        p(dir),
        ratio.max(1e-3),
        &DimStyle::iso(),
    ))
}

/// 角度標註：頂點、兩邊各朝 `a`、`b`，尺寸弧半徑 `arc_radius`。
#[uniffi::export]
pub fn draft_dim_angle(
    vertex: FfiPoint,
    a: FfiPoint,
    b: FfiPoint,
    arc_radius: f32,
) -> Option<FfiDimension> {
    dimension_from(dim::angle(
        p(vertex),
        p(a),
        p(b),
        arc_radius,
        &DimStyle::iso(),
    ))
}

/// 符號清單。
#[uniffi::export]
pub fn draft_symbol_catalog() -> Vec<FfiDraftSymbolInfo> {
    symbols::CATALOG
        .iter()
        .map(|(id, group)| FfiDraftSymbolInfo {
            id: (*id).into(),
            group: (*group).into(),
            name_key: format!("draft_sym_{id}"),
        })
        .collect()
}

/// 一個符號：定位點放在 `anchor`。認不得的識別字回 `None`。
#[uniffi::export]
pub fn draft_symbol(id: String, anchor: FfiPoint, params: FfiSymbolParams) -> Option<FfiDraftKit> {
    let params = SymbolParams {
        size_mm: params.size_mm,
        text: params.text,
        rotation_deg: params.rotation_deg,
        other_side: params.other_side,
        all_around: params.all_around,
        field: params.field,
        diameter: params.diameter,
        datums: params.datums.chars().collect(),
        length_mm: params.length_mm,
    };
    symbols::make(&id, p(anchor), &params).map(|d| kit_from(&d))
}

/// 圖框與標題欄。`paper_id` 是 `page_formats` 的識別字（a4、a3、a3_landscape、a2…）；
/// 認不得的紙張（含自訂尺寸）回 `None`。座標以紙的左上角為原點。
#[uniffi::export]
pub fn draft_sheet_frame(
    paper_id: String,
    scale_text: String,
    third_angle: bool,
    title_block: bool,
) -> Option<FfiDraftKit> {
    let (width_mm, height_mm) = frame::paper_mm(&paper_id)?;
    let d = frame::sheet(&FrameOptions {
        width_mm,
        height_mm,
        margin_mm: 10.0,
        binding_mm: 25.0,
        title_block,
        scale_text,
        third_angle,
    });
    (!d.strokes.is_empty()).then(|| kit_from(&d))
}

// MARK: - 投影對齊

#[derive(Clone, Copy, Debug, PartialEq, Eq, uniffi::Enum)]
pub enum FfiAlignGuideKind {
    /// 長對正（垂直線）。
    Vertical,
    /// 高平齊（水平線）。
    Horizontal,
    /// 寬相等：經 45° 轉折線傳遞。
    Transfer,
}

#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiAlignGuide {
    pub kind: FfiAlignGuideKind,
    pub points: Vec<FfiPoint>,
}

#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiAlignResult {
    /// 吸附之後的位置（沒吸到就是原來的游標）。
    pub point: FfiPoint,
    pub guides: Vec<FfiAlignGuide>,
}

/// 投影對齊：游標附近有沒有哪個既有點讓 x 或 y 對齊（含經 45° 轉折點傳遞）。
/// 找到就回吸附位置與要畫的對齊線。
#[uniffi::export]
pub fn draft_align(
    cursor: FfiPoint,
    anchors: Vec<FfiPoint>,
    pivot: Option<FfiPoint>,
    third_angle: bool,
    tolerance: f32,
) -> FfiAlignResult {
    let pts: Vec<(f32, f32)> = anchors.iter().map(|a| (a.x, a.y)).collect();
    let r = align::align(
        p(cursor),
        &pts,
        pivot.map(p),
        third_angle,
        tolerance.max(0.0),
    );
    FfiAlignResult {
        point: FfiPoint {
            x: r.point.0,
            y: r.point.1,
        },
        guides: r
            .guides
            .into_iter()
            .map(|g| FfiAlignGuide {
                kind: match g.kind {
                    align::GuideKind::Vertical => FfiAlignGuideKind::Vertical,
                    align::GuideKind::Horizontal => FfiAlignGuideKind::Horizontal,
                    align::GuideKind::Transfer => FfiAlignGuideKind::Transfer,
                },
                points: g
                    .points
                    .into_iter()
                    .map(|q| FfiPoint { x: q.0, y: q.1 })
                    .collect(),
            })
            .collect(),
    }
}

// MARK: - 虛擬尺規

#[derive(Clone, Copy, Debug, uniffi::Record)]
pub struct FfiSegment {
    pub a: FfiPoint,
    pub b: FfiPoint,
}

#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiTick {
    pub a: FfiPoint,
    pub b: FfiPoint,
    /// 0 = 一般、1 = 中、2 = 長（附數字）。
    pub weight: u8,
    pub label: Option<String>,
    pub label_at: FfiPoint,
}

#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiInstrumentGeometry {
    pub outline: Vec<Vec<FfiPoint>>,
    pub ticks: Vec<FfiTick>,
    /// 靠著畫線的邊。
    pub edges: Vec<FfiSegment>,
    /// 只能沿垂直方向移動（丁字尺）。
    pub vertical_only: bool,
    pub width: f32,
    pub height: f32,
    /// 讀數的圓心（量角器；尺自己的座標）。其他尺是 `None`。
    pub reading_center: Option<FfiPoint>,
}

#[derive(Clone, Copy, Debug, uniffi::Record)]
pub struct FfiEdgeSnap {
    pub edge_index: u32,
    pub point: FfiPoint,
}

fn fp(q: (f32, f32)) -> FfiPoint {
    FfiPoint { x: q.0, y: q.1 }
}

/// 尺規的識別字（直尺、丁字尺、兩種三角板、量角器）。語系鍵是 `draft_inst_<id>`。
#[uniffi::export]
pub fn draft_instrument_kinds() -> Vec<String> {
    instruments::KINDS
        .iter()
        .map(|k| k.id().to_string())
        .collect()
}

/// 尺規的幾何（真實毫米換成頁面單位）。`page_width` 給丁字尺貼滿頁寬用。認不得回 `None`。
#[uniffi::export]
pub fn draft_instrument_geometry(
    kind: String,
    size_mm: f32,
    page_width: f32,
) -> Option<FfiInstrumentGeometry> {
    let g = instruments::geometry(InstrumentKind::from_id(&kind)?, size_mm, page_width);
    Some(FfiInstrumentGeometry {
        outline: g
            .outline
            .iter()
            .map(|ring| ring.iter().map(|q| fp(*q)).collect())
            .collect(),
        ticks: g
            .ticks
            .iter()
            .map(|t| FfiTick {
                a: fp(t.a),
                b: fp(t.b),
                weight: t.weight,
                label: t.label.clone(),
                label_at: fp(t.label_at),
            })
            .collect(),
        edges: g
            .edges
            .iter()
            .map(|(a, b)| FfiSegment {
                a: fp(*a),
                b: fp(*b),
            })
            .collect(),
        vertical_only: g.vertical_only,
        width: g.width,
        height: g.height,
        reading_center: g.reading_center.map(fp),
    })
}

/// 量角器的讀數：從圓心看 `point` 的角度（度；0° 在右端、逆時針到 180° 在左端）。
/// 兩個點都用尺自己的座標。在底邊以下讀不到回 `None`。
#[uniffi::export]
pub fn draft_protractor_angle(center: FfiPoint, point: FfiPoint) -> Option<f32> {
    instruments::protractor_angle(p(center), p(point))
}

/// 點離哪一條邊最近（`band` 之內）：回邊的索引與投影點。
#[uniffi::export]
pub fn draft_snap_to_edges(
    point: FfiPoint,
    edges: Vec<FfiSegment>,
    band: f32,
) -> Option<FfiEdgeSnap> {
    let segs: Vec<((f32, f32), (f32, f32))> = edges.iter().map(|e| (p(e.a), p(e.b))).collect();
    instruments::snap_to_edges(p(point), &segs, band).map(|(i, q)| FfiEdgeSnap {
        edge_index: i as u32,
        point: fp(q),
    })
}

/// 把點投影到線段上（夾在兩端之內）。
#[uniffi::export]
pub fn draft_project_to_segment(point: FfiPoint, segment: FfiSegment) -> FfiPoint {
    fp(instruments::project_to_segment(
        p(point),
        p(segment.a),
        p(segment.b),
    ))
}

/// 圓規的圓弧：圓心、半徑，從 `start` 弧度掃過 `sweep` 弧度（可為負）。
#[uniffi::export]
pub fn draft_arc(center: FfiPoint, radius: f32, start: f32, sweep: f32) -> Vec<FfiPoint> {
    instruments::arc_points(p(center), radius, start, sweep)
        .into_iter()
        .map(fp)
        .collect()
}

// MARK: - 編輯運算

fn poly(points: &[FfiPoint]) -> Vec<(f32, f32)> {
    points.iter().map(|q| (q.x, q.y)).collect()
}

fn ffi_poly(points: Vec<(f32, f32)>) -> Vec<FfiPoint> {
    points.into_iter().map(fp).collect()
}

/// 一條折線（FFI 的 `Vec<FfiPoint>` 不能直接套進 `Vec<Vec<..>>` 的 Record，所以包一層）。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiPolyline {
    pub points: Vec<FfiPoint>,
}

#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiFillet {
    /// 修短（或延伸）之後的第一條線。
    pub a: Vec<FfiPoint>,
    /// 修短（或延伸）之後的第二條線。
    pub b: Vec<FfiPoint>,
    /// 連接兩條線的圓弧。
    pub arc: Vec<FfiPoint>,
}

/// 修剪：`click` 附近那一段，從前後最近的交點之間剪掉。回剩下的線（0、1 或 2 段）；
/// 沒有交點可剪回 `None`。
#[uniffi::export]
pub fn draft_trim(
    target: Vec<FfiPoint>,
    cutters: Vec<FfiPolyline>,
    click: FfiPoint,
) -> Option<Vec<FfiPolyline>> {
    let cutters: Vec<Vec<(f32, f32)>> = cutters.iter().map(|c| poly(&c.points)).collect();
    edit::trim(&poly(&target), &cutters, p(click)).map(|pieces| {
        pieces
            .into_iter()
            .map(|pts| FfiPolyline {
                points: ffi_poly(pts),
            })
            .collect()
    })
}

/// 延伸：把 `near` 附近的那一端延伸到最近的邊界。碰不到邊界回 `None`。
#[uniffi::export]
pub fn draft_extend(
    target: Vec<FfiPoint>,
    near: FfiPoint,
    boundaries: Vec<FfiPolyline>,
) -> Option<Vec<FfiPoint>> {
    let boundaries: Vec<Vec<(f32, f32)>> = boundaries.iter().map(|c| poly(&c.points)).collect();
    edit::extend(&poly(&target), p(near), &boundaries).map(ffi_poly)
}

/// 對稱軸 `a`→`b` 的鏡射。
#[uniffi::export]
pub fn draft_mirror(points: Vec<FfiPoint>, a: FfiPoint, b: FfiPoint) -> Vec<FfiPoint> {
    ffi_poly(edit::mirror(&poly(&points), p(a), p(b)))
}

/// 矩形陣列：`rows × cols` 份（列距 `dy`、欄距 `dx`），回傳除了原件以外的複本。
#[uniffi::export]
pub fn draft_array_rect(
    points: Vec<FfiPoint>,
    rows: u32,
    cols: u32,
    dx: f32,
    dy: f32,
) -> Vec<FfiPolyline> {
    edit::array_rect(&poly(&points), rows.min(50), cols.min(50), dx, dy)
        .into_iter()
        .map(|pts| FfiPolyline {
            points: ffi_poly(pts),
        })
        .collect()
}

/// 環形陣列：共 `count` 份、繞 `center` 均分 `total_deg`（360 = 一整圈），回傳除了原件以外的複本。
#[uniffi::export]
pub fn draft_array_polar(
    points: Vec<FfiPoint>,
    center: FfiPoint,
    count: u32,
    total_deg: f32,
) -> Vec<FfiPolyline> {
    edit::array_polar(&poly(&points), p(center), count.min(200), total_deg)
        .into_iter()
        .map(|pts| FfiPolyline {
            points: ffi_poly(pts),
        })
        .collect()
}

/// 圓角：兩條直線在點擊的那一側用半徑 `radius` 的圓弧接起來。平行、不是直線、半徑太大回 `None`。
#[uniffi::export]
pub fn draft_fillet(
    first: Vec<FfiPoint>,
    second: Vec<FfiPoint>,
    radius: f32,
    click_first: FfiPoint,
    click_second: FfiPoint,
) -> Option<FfiFillet> {
    edit::fillet(
        &poly(&first),
        &poly(&second),
        radius,
        p(click_first),
        p(click_second),
    )
    .map(|f| FfiFillet {
        a: ffi_poly(f.a),
        b: ffi_poly(f.b),
        arc: ffi_poly(f.arc),
    })
}

/// 偏移：折線往 `side` 那一側平移 `distance` 頁面單位。
#[uniffi::export]
pub fn draft_offset(points: Vec<FfiPoint>, distance: f32, side: FfiPoint) -> Option<Vec<FfiPoint>> {
    edit::offset(&poly(&points), distance, p(side)).map(ffi_poly)
}

// MARK: - 題庫與批改

/// 題目或答案裡的一條線（頁面座標）。`line_type`：0 實線、1 隱藏線、2 中心線；`thin` = 細實線（剖面線）。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiProblemLine {
    pub a: FfiPoint,
    pub b: FfiPoint,
    pub line_type: u8,
    pub thin: bool,
}

#[derive(Clone, Copy, Debug, uniffi::Record)]
pub struct FfiProblemRect {
    pub x: f32,
    pub y: f32,
    pub w: f32,
    pub h: f32,
}

#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiProblem {
    /// 題型編號（`draft_problem_kinds` 給的）。
    pub kind: String,
    pub seed: u64,
    pub third_angle: bool,
    /// 題目給的線，畫在底層。
    pub given: Vec<FfiProblemLine>,
    /// 標準答案（畫題才有）。
    pub answer: Vec<FfiProblemLine>,
    /// 學生作答的範圍（畫題才有）；只批改這裡面的線。
    pub answer_area: Option<FfiProblemRect>,
    /// 選擇題的選項（語系鍵）。
    pub choices: Vec<String>,
    pub correct: Option<u32>,
    /// 挑錯題：錯的位置。
    pub error_at: Option<FfiPoint>,
    pub width_mm: f32,
    pub height_mm: f32,
    pub depth_mm: f32,
    /// 輪廓種類（語系鍵 `solid_profile_<name>` 的名稱部分）。
    pub profile: String,
}

fn to_ffi_line(s: &Seg) -> FfiProblemLine {
    FfiProblemLine {
        a: fp(s.a),
        b: fp(s.b),
        line_type: match s.kind {
            LineKind::Hidden => 1,
            LineKind::Center => 2,
            _ => 0,
        },
        thin: s.kind == LineKind::Thin,
    }
}

/// 題型編號，依顯示順序。語系鍵是 `draft_prob_kind_<id>`。
#[uniffi::export]
pub fn draft_problem_kinds() -> Vec<String> {
    problems::KINDS.iter().map(|k| k.id().to_string()).collect()
}

/// 這個題型是要在頁面上畫（會批改），還是選答案。
#[uniffi::export]
pub fn draft_problem_is_drawing(kind: String) -> bool {
    problems::Kind::from_id(&kind).is_some_and(|k| k.is_drawing())
}

/// 以種子產生一題。`page_width`、`page_height` 是頁面大小（頁面單位）。認不得題型回 `None`。
#[uniffi::export]
pub fn draft_problem(
    kind: String,
    seed: u64,
    page_width: f32,
    page_height: f32,
) -> Option<FfiProblem> {
    let kind = problems::Kind::from_id(&kind)?;
    let page = (page_width.max(400.0), page_height.max(300.0));
    let p = problems::generate(kind, seed, page);
    Some(FfiProblem {
        kind: kind.id().to_string(),
        seed,
        third_angle: p.convention == problems::Convention::ThirdAngle,
        given: p.given.iter().map(to_ffi_line).collect(),
        answer: p.answer.iter().map(to_ffi_line).collect(),
        answer_area: p.answer_area.map(|r| FfiProblemRect {
            x: r.x,
            y: r.y,
            w: r.w,
            h: r.h,
        }),
        choices: p.choices.iter().map(|c| c.to_string()).collect(),
        correct: p.correct.map(|c| c as u32),
        error_at: p.error.map(|(_, at)| fp(at)),
        width_mm: p.dims_mm.0,
        height_mm: p.dims_mm.1,
        depth_mm: p.dims_mm.2,
        profile: p.profile.to_string(),
    })
}

/// 選擇題的批改。
#[uniffi::export]
pub fn draft_check_choice(
    kind: String,
    seed: u64,
    page_width: f32,
    page_height: f32,
    picked: u32,
) -> bool {
    problems::Kind::from_id(&kind)
        .map(|k| problems::generate(k, seed, (page_width.max(400.0), page_height.max(300.0))))
        .is_some_and(|p| problems::check_choice(&p, picked as usize))
}

/// 挑錯題的批改：選的種類要對，指的位置離錯的地方不超過 `radius`。
#[uniffi::export]
pub fn draft_check_error(
    seed: u64,
    page_width: f32,
    page_height: f32,
    picked: u32,
    at: Option<FfiPoint>,
    radius: f32,
) -> bool {
    let p = problems::generate(
        problems::Kind::SpotError,
        seed,
        (page_width.max(400.0), page_height.max(300.0)),
    );
    problems::check_error_answer(&p, picked as usize, at.map(p_), radius.max(1.0))
}

fn p_(q: FfiPoint) -> (f32, f32) {
    (q.x, q.y)
}

/// 學生畫的一筆（由平台的筆畫換成：圖層、線型、筆寬、點）。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiDrawnStroke {
    pub layer: u8,
    pub line_type: u8,
    pub width: f32,
    pub points: Vec<FfiPoint>,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, uniffi::Enum)]
pub enum FfiIssueKind {
    Missing,
    Extra,
    WrongType,
    Misaligned,
    HatchMissing,
    HatchAngle,
}

/// 批改出來的一個問題：種類與要標在畫面上的線（標準答案的那條，或學生多畫的那條）。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiIssue {
    pub kind: FfiIssueKind,
    /// 要標出來的線（剖面線的問題沒有）。
    pub line: Option<FfiProblemLine>,
    /// 沒對齊：學生的線相對標準的偏移。
    pub dx: f32,
    pub dy: f32,
    /// 線型錯：該是什麼（0 實線、1 隱藏線、2 中心線）。
    pub expected_line_type: u8,
    /// 剖面線角度（度）。
    pub expected_deg: f32,
    pub drawn_deg: f32,
}

#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiGrade {
    pub issues: Vec<FfiIssue>,
    pub matched: u32,
    pub expected: u32,
    pub score: u32,
}

fn kind_to_type(k: LineKind) -> u8 {
    match k {
        LineKind::Hidden => 1,
        LineKind::Center => 2,
        _ => 0,
    }
}

/// 批改畫題：只收落在作答範圍裡的頂層筆畫。
#[uniffi::export]
pub fn draft_grade(
    kind: String,
    seed: u64,
    page_width: f32,
    page_height: f32,
    strokes: Vec<FfiDrawnStroke>,
) -> Option<FfiGrade> {
    let kind = problems::Kind::from_id(&kind)?;
    let problem = problems::generate(kind, seed, (page_width.max(400.0), page_height.max(300.0)));
    let area = problem.answer_area?;
    let mut drawn: Vec<Seg> = Vec::new();
    for s in &strokes {
        let Some(lk) = check::classify(s.layer, s.line_type, s.width) else {
            continue;
        };
        let pts: Vec<(f32, f32)> = s.points.iter().map(|q| (q.x, q.y)).collect();
        // 只算作答範圍裡的線段（整段在範圍內才算）。
        for seg in check::segments(&pts, lk) {
            if area.contains(seg.a) && area.contains(seg.b) {
                drawn.push(seg);
            }
        }
    }
    let report = check::grade(&problem.answer, &drawn, Tolerance::default());
    let blank = FfiIssue {
        kind: FfiIssueKind::Missing,
        line: None,
        dx: 0.0,
        dy: 0.0,
        expected_line_type: 0,
        expected_deg: 0.0,
        drawn_deg: 0.0,
    };
    let issues = report
        .issues
        .iter()
        .map(|i| match i {
            Issue::Missing(s) => FfiIssue {
                kind: FfiIssueKind::Missing,
                line: Some(to_ffi_line(s)),
                expected_line_type: kind_to_type(s.kind),
                ..blank.clone()
            },
            Issue::Extra(s) => FfiIssue {
                kind: FfiIssueKind::Extra,
                line: Some(to_ffi_line(s)),
                ..blank.clone()
            },
            Issue::WrongType { drawn, expected } => FfiIssue {
                kind: FfiIssueKind::WrongType,
                line: Some(to_ffi_line(drawn)),
                expected_line_type: kind_to_type(*expected),
                ..blank.clone()
            },
            Issue::Misaligned { expected, dx, dy } => FfiIssue {
                kind: FfiIssueKind::Misaligned,
                line: Some(to_ffi_line(expected)),
                dx: *dx,
                dy: *dy,
                ..blank.clone()
            },
            Issue::HatchMissing => FfiIssue {
                kind: FfiIssueKind::HatchMissing,
                ..blank.clone()
            },
            Issue::HatchAngle {
                expected_deg,
                drawn_deg,
            } => FfiIssue {
                kind: FfiIssueKind::HatchAngle,
                expected_deg: *expected_deg,
                drawn_deg: *drawn_deg,
                ..blank.clone()
            },
        })
        .collect();
    Some(FfiGrade {
        issues,
        matched: report.matched as u32,
        expected: report.expected as u32,
        score: report.score(),
    })
}

/// 挑錯題的錯誤種類選項（語系鍵），與 `draft_problem` 給的 `choices` 一致。
#[uniffi::export]
pub fn draft_error_kinds() -> Vec<String> {
    [
        ErrorKind::Missing,
        ErrorKind::Extra,
        ErrorKind::WrongType,
        ErrorKind::Misaligned,
    ]
    .iter()
    .map(|e| e.choice_key().to_string())
    .collect()
}

// MARK: - 2D 匯出（SVG、DXF）

/// 要匯出的一筆。`color_hex` 是 `#RRGGBB`。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiExportStroke {
    pub points: Vec<FfiPoint>,
    pub layer: u8,
    pub line_type: u8,
    pub width: f32,
    pub color_hex: String,
}

fn export_strokes(strokes: &[FfiExportStroke]) -> Vec<ExportStroke> {
    let hex = |s: &str| -> (u8, u8, u8) {
        let h = s.trim_start_matches('#');
        let v = u32::from_str_radix(h.get(..6).unwrap_or("111827"), 16).unwrap_or(0x11_18_27);
        ((v >> 16) as u8, (v >> 8) as u8, v as u8)
    };
    strokes
        .iter()
        .map(|s| ExportStroke {
            points: poly(&s.points),
            layer: s.layer,
            line_type: s.line_type,
            width: s.width,
            color: hex(&s.color_hex),
        })
        .collect()
}

/// 頁面筆畫 → SVG（毫米；每個圖層一個群組；線型換成虛線圖樣）。
#[uniffi::export]
pub fn draft_export_svg(
    strokes: Vec<FfiExportStroke>,
    page_width: f32,
    page_height: f32,
) -> String {
    export2d::to_svg(
        &export_strokes(&strokes),
        page_width.max(1.0),
        page_height.max(1.0),
    )
}

/// 頁面筆畫 → DXF（R12、毫米、y 向上；圖層與線型都定義好）。
#[uniffi::export]
pub fn draft_export_dxf(
    strokes: Vec<FfiExportStroke>,
    page_width: f32,
    page_height: f32,
) -> String {
    export2d::to_dxf(
        &export_strokes(&strokes),
        page_width.max(1.0),
        page_height.max(1.0),
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    fn pt(x: f32, y: f32) -> FfiPoint {
        FfiPoint { x, y }
    }

    fn params() -> FfiSymbolParams {
        FfiSymbolParams {
            size_mm: 3.5,
            text: "Ra 1.6".into(),
            rotation_deg: 0.0,
            other_side: false,
            all_around: false,
            field: false,
            diameter: false,
            datums: String::new(),
            length_mm: 20.0,
        }
    }

    #[test]
    fn a_dimension_comes_back_as_drafting_strokes_with_the_value() {
        let m = draft_units_per_mm();
        let d = draft_dim_linear(
            pt(10.0, 100.0),
            pt(10.0 + 40.0 * m, 100.0),
            pt(0.0, 130.0),
            FfiDimAxis::Auto,
            1.0,
        )
        .unwrap();
        assert_eq!(d.text, "40");
        assert!((d.value - 40.0).abs() < 1e-3);
        // 尺寸線與數字都用細線、在頂層。
        assert!(d.strokes.iter().all(|s| s.layer == 3 && s.line_type == 0));
        assert!(
            d.strokes
                .iter()
                .all(|s| s.points.len() >= 2 && s.width > 0.0)
        );
        // 兩點重合就沒有標註。
        assert!(
            draft_dim_linear(
                pt(5.0, 5.0),
                pt(5.0, 5.0),
                pt(5.0, 30.0),
                FfiDimAxis::Auto,
                1.0
            )
            .is_none()
        );
    }

    #[test]
    fn the_scale_ratio_changes_the_number_and_a_bad_ratio_is_clamped() {
        let m = draft_units_per_mm();
        let at = |ratio: f32| {
            draft_dim_linear(
                pt(0.0, 0.0),
                pt(25.0 * m, 0.0),
                pt(10.0, 20.0),
                FfiDimAxis::Horizontal,
                ratio,
            )
            .unwrap()
            .text
        };
        assert_eq!(at(1.0), "25");
        assert_eq!(at(2.0), "50");
        assert_eq!(at(0.5), "12.5");
        // 0 或負的比例尺不會算出 0 或 NaN。
        assert!(!at(0.0).is_empty() && !at(-3.0).is_empty());
    }

    #[test]
    fn diameter_radius_and_angle_dimensions_have_their_prefixes() {
        let m = draft_units_per_mm();
        let dia = draft_dim_diameter(pt(100.0, 100.0), 10.0 * m, pt(1.0, -1.0), 1.0).unwrap();
        assert_eq!(dia.text, "⌀20");
        let rad = draft_dim_radius(pt(100.0, 100.0), 10.0 * m, pt(-1.0, 0.0), 1.0).unwrap();
        assert_eq!(rad.text, "R10");
        let ang = draft_dim_angle(pt(0.0, 0.0), pt(100.0, 0.0), pt(0.0, 100.0), 50.0).unwrap();
        assert_eq!(ang.text, "90°");
        assert!(draft_dim_diameter(pt(0.0, 0.0), 0.0, pt(1.0, 0.0), 1.0).is_none());
    }

    #[test]
    fn every_catalogue_symbol_can_be_made_through_the_ffi() {
        let cat = draft_symbol_catalog();
        assert!(cat.len() >= 30);
        for info in &cat {
            let kit = draft_symbol(info.id.clone(), pt(200.0, 200.0), params())
                .unwrap_or_else(|| panic!("{}", info.id));
            assert!(!kit.strokes.is_empty(), "{}", info.id);
            assert_eq!(info.name_key, format!("draft_sym_{}", info.id));
        }
        assert!(draft_symbol("nope".into(), pt(0.0, 0.0), params()).is_none());
    }

    #[test]
    fn a_gdt_frame_through_the_ffi_carries_tolerance_and_datums() {
        let mut prm = params();
        prm.text = "0.05".into();
        prm.diameter = true;
        prm.datums = "AB".into();
        let with = draft_symbol("gdt_position".into(), pt(0.0, 0.0), prm.clone()).unwrap();
        prm.datums.clear();
        let without = draft_symbol("gdt_position".into(), pt(0.0, 0.0), prm).unwrap();
        assert!(with.strokes.len() > without.strokes.len());
    }

    #[test]
    fn the_sheet_frame_has_a_title_block_with_language_keys() {
        let kit = draft_sheet_frame("a3_landscape".into(), "1:2".into(), true, true).unwrap();
        assert!(!kit.strokes.is_empty());
        assert!(kit.texts.iter().any(|t| t.key == "draft_tb_title"));
        assert!(kit.texts.iter().all(|t| t.font_size > 0.0 && t.width > 0.0));
        // 框線用粗實線（頂層）、格線用細線。
        assert!(kit.strokes.iter().any(|s| s.width > 2.0));
        assert!(kit.strokes.iter().any(|s| s.width < 1.5));
        // 沒有標題欄就沒有標籤。
        let plain = draft_sheet_frame("a4".into(), String::new(), true, false).unwrap();
        assert!(plain.texts.is_empty());
        // 認不得的紙張（含自訂尺寸）沒有圖框。
        assert!(draft_sheet_frame("custom_900x700".into(), String::new(), true, true).is_none());
    }

    #[test]
    fn the_scale_presets_cover_reduction_full_size_and_enlargement() {
        let s = draft_scales();
        assert!(s.iter().any(|x| x.label == "1:1" && x.ratio == 1.0));
        assert!(s.iter().any(|x| x.ratio > 1.0));
        assert!(s.iter().any(|x| x.ratio < 1.0));
        assert!(s.iter().all(|x| x.ratio > 0.0));
    }

    #[test]
    fn alignment_comes_back_through_the_ffi() {
        let r = draft_align(pt(203.0, 400.0), vec![pt(200.0, 100.0)], None, true, 8.0);
        assert_eq!((r.point.x, r.point.y), (200.0, 400.0));
        assert_eq!(r.guides.len(), 1);
        assert_eq!(r.guides[0].kind, FfiAlignGuideKind::Vertical);
        // 傳遞：轉折點 (400,500)，來源在上方 120 → x = 520。
        let t = draft_align(
            pt(518.0, 700.0),
            vec![pt(300.0, 380.0)],
            Some(pt(400.0, 500.0)),
            true,
            8.0,
        );
        assert_eq!(t.point.x, 520.0);
        assert!(
            t.guides
                .iter()
                .any(|g| g.kind == FfiAlignGuideKind::Transfer)
        );
    }

    #[test]
    fn every_instrument_has_geometry_and_edges_to_draw_against() {
        for id in draft_instrument_kinds() {
            let g = draft_instrument_geometry(id.clone(), 150.0, 800.0)
                .unwrap_or_else(|| panic!("{id}"));
            assert!(!g.outline.is_empty() && !g.edges.is_empty(), "{id}");
            assert!(g.width > 0.0 && g.height > 0.0, "{id}");
        }
        assert!(draft_instrument_geometry("nope".into(), 100.0, 800.0).is_none());
        let t = draft_instrument_geometry("t_square".into(), 100.0, 800.0).unwrap();
        assert!(t.vertical_only);
        // 直尺的刻度有數字。
        let r = draft_instrument_geometry("ruler".into(), 100.0, 800.0).unwrap();
        assert!(r.ticks.iter().any(|t| t.label.as_deref() == Some("10")));
        // 量角器有讀數圓心，直尺沒有。
        let pr = draft_instrument_geometry("protractor".into(), 70.0, 800.0).unwrap();
        let c = pr.reading_center.expect("量角器的圓心");
        assert_eq!(draft_protractor_angle(c, pt(c.x + 50.0, c.y)), Some(0.0));
        let up = draft_protractor_angle(c, pt(c.x, c.y - 50.0)).unwrap();
        assert!((up - 90.0).abs() < 1e-3);
        assert!(r.reading_center.is_none());
    }

    #[test]
    fn edge_snapping_and_the_compass_arc_work_through_the_ffi() {
        let seg = FfiSegment {
            a: pt(0.0, 100.0),
            b: pt(200.0, 100.0),
        };
        let hit = draft_snap_to_edges(pt(80.0, 104.0), vec![seg], 10.0).unwrap();
        assert_eq!(hit.edge_index, 0);
        assert_eq!((hit.point.x, hit.point.y), (80.0, 100.0));
        assert!(draft_snap_to_edges(pt(80.0, 140.0), vec![seg], 10.0).is_none());
        let q = draft_project_to_segment(pt(260.0, 90.0), seg);
        assert_eq!((q.x, q.y), (200.0, 100.0));
        let arc = draft_arc(pt(300.0, 300.0), 50.0, 0.0, std::f32::consts::PI);
        assert!(arc.len() > 80);
        assert!(draft_arc(pt(0.0, 0.0), 0.0, 0.0, 1.0).is_empty());
    }

    #[test]
    fn edit_operations_work_through_the_ffi() {
        let line = vec![pt(0.0, 0.0), pt(100.0, 0.0)];
        let cutter = FfiPolyline {
            points: vec![pt(40.0, -10.0), pt(40.0, 10.0)],
        };
        let pieces = draft_trim(line.clone(), vec![cutter.clone()], pt(80.0, 0.0)).unwrap();
        assert_eq!(pieces.len(), 1);
        assert_eq!(pieces[0].points.last().unwrap().x, 40.0);
        assert!(draft_trim(line.clone(), vec![], pt(80.0, 0.0)).is_none());

        let ext = draft_extend(
            vec![pt(0.0, 0.0), pt(30.0, 0.0)],
            pt(29.0, 0.0),
            vec![FfiPolyline {
                points: vec![pt(70.0, -5.0), pt(70.0, 5.0)],
            }],
        )
        .unwrap();
        assert_eq!(ext.last().unwrap().x, 70.0);

        let m = draft_mirror(vec![pt(1.0, 2.0)], pt(10.0, 0.0), pt(10.0, 9.0));
        assert_eq!((m[0].x, m[0].y), (19.0, 2.0));
        assert_eq!(draft_array_rect(line.clone(), 2, 2, 10.0, 10.0).len(), 3);
        assert_eq!(
            draft_array_polar(vec![pt(5.0, 0.0)], pt(0.0, 0.0), 4, 360.0).len(),
            3
        );
        // 巨大的份數被夾住，不會要記憶體。
        assert!(draft_array_rect(line.clone(), 100_000, 100_000, 1.0, 1.0).len() <= 50 * 50);

        let f = draft_fillet(
            vec![pt(0.0, 100.0), pt(100.0, 100.0)],
            vec![pt(100.0, 100.0), pt(100.0, 0.0)],
            20.0,
            pt(30.0, 100.0),
            pt(100.0, 30.0),
        )
        .unwrap();
        assert!(f.arc.len() > 4);
        let o = draft_offset(line, 10.0, pt(50.0, 20.0)).unwrap();
        assert_eq!(o[0].y, 10.0);
    }

    #[test]
    fn problems_and_grading_work_through_the_ffi() {
        let kinds = draft_problem_kinds();
        assert_eq!(kinds.len(), 5);
        for k in &kinds {
            let p = draft_problem(k.clone(), 11, 1600.0, 1132.0).unwrap();
            assert!(!p.given.is_empty(), "{k}");
            if draft_problem_is_drawing(k.clone()) {
                // 把標準答案當成學生畫的（頂層、粗實線／隱藏線／細線）→ 滿分。
                let strokes: Vec<FfiDrawnStroke> = p
                    .answer
                    .iter()
                    .map(|l| FfiDrawnStroke {
                        layer: 3,
                        line_type: l.line_type,
                        width: if l.thin { 1.2 } else { 2.6 },
                        points: vec![l.a, l.b],
                    })
                    .collect();
                let g = draft_grade(k.clone(), 11, 1600.0, 1132.0, strokes).unwrap();
                assert!(g.issues.is_empty(), "{k}: {:?}", g.issues.len());
                assert_eq!(g.score, 100);
                // 什麼都沒畫 → 一堆缺線。
                let blank = draft_grade(k.clone(), 11, 1600.0, 1132.0, vec![]).unwrap();
                assert!(!blank.issues.is_empty() && blank.score < 100);
            } else {
                assert!(p.correct.is_some());
            }
        }
        // 判斷題：選對／選錯。
        let p = draft_problem("angle_judgement".into(), 5, 1600.0, 1132.0).unwrap();
        let right = p.correct.unwrap();
        assert!(draft_check_choice(
            "angle_judgement".into(),
            5,
            1600.0,
            1132.0,
            right
        ));
        assert!(!draft_check_choice(
            "angle_judgement".into(),
            5,
            1600.0,
            1132.0,
            1 - right
        ));
        // 挑錯題。
        let e = draft_problem("spot_error".into(), 9, 1600.0, 1132.0).unwrap();
        let at = e.error_at.unwrap();
        assert!(draft_check_error(
            9,
            1600.0,
            1132.0,
            e.correct.unwrap(),
            Some(at),
            30.0
        ));
        assert!(!draft_check_error(
            9,
            1600.0,
            1132.0,
            e.correct.unwrap(),
            None,
            30.0
        ));
        assert!(draft_problem("nope".into(), 1, 1600.0, 1132.0).is_none());
        assert_eq!(draft_error_kinds().len(), 4);
        // 作答範圍之外的線不算：把答案平移到頁面另一邊，批改看不到。
        let far: Vec<FfiDrawnStroke> = draft_problem("complete_view".into(), 11, 1600.0, 1132.0)
            .unwrap()
            .answer
            .iter()
            .map(|l| FfiDrawnStroke {
                layer: 3,
                line_type: l.line_type,
                width: 2.6,
                points: vec![pt(l.a.x - 900.0, l.a.y), pt(l.b.x - 900.0, l.b.y)],
            })
            .collect();
        assert!(
            draft_grade("complete_view".into(), 11, 1600.0, 1132.0, far)
                .unwrap()
                .score
                < 100
        );
    }

    #[test]
    fn two_d_export_works_through_the_ffi() {
        let strokes = vec![
            FfiExportStroke {
                points: vec![pt(0.0, 0.0), pt(381.0, 0.0)],
                layer: 3,
                line_type: 1,
                width: 1.4,
                color_hex: "#111827".into(),
            },
            FfiExportStroke {
                points: vec![pt(10.0, 10.0), pt(10.0, 100.0)],
                layer: 2,
                line_type: 0,
                width: 1.0,
                color_hex: "#3B82F6".into(),
            },
        ];
        let svg = draft_export_svg(strokes.clone(), 800.0, 1132.0);
        assert_eq!(svg.matches("<polyline").count(), 2);
        assert!(svg.contains("stroke=\"#3B82F6\"") && svg.contains("stroke-dasharray"));
        let dxf = draft_export_dxf(strokes, 800.0, 1132.0);
        assert_eq!(dxf.matches("0\nPOLYLINE\n").count(), 2);
        assert!(dxf.ends_with("0\nEOF\n"));
        // 壞的顏色不會讓匯出失敗。
        let bad = draft_export_svg(
            vec![FfiExportStroke {
                points: vec![pt(0.0, 0.0), pt(5.0, 5.0)],
                layer: 3,
                line_type: 0,
                width: 1.0,
                color_hex: "zzz".into(),
            }],
            800.0,
            600.0,
        );
        assert!(bad.contains("<polyline"));
    }
}
