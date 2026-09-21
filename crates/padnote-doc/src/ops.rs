//! 文件操作日誌（工作項 S-23，`format-spec.md` §6）。
//!
//! 在此之前只有**筆畫**會落盤，頁面、區塊、錄音 session 都只活在記憶體裡 ——
//! 關掉 App 就沒了。這個模組補上整條文件的持久化。
//!
//! 與筆畫一樣是 **append-only**：每個變更追加一筆 `DocOp`，重開時重播得到
//! 目前狀態。刪除用墓碑而非移除記錄，保持記錄可交換（同步收斂的前提）。

use crate::document::CellSpan;
use crate::milestone::{DocClock, InkClock, MilestoneCut};
use crate::object::{
    Anchor, ConnectionObject, EndCap, ObjectKind, ObjectRect, RouteStyle, ShapeKind, ShapeObject,
};
use crate::text::{OpId, TextOp};
use crate::{Affine2, NotebookTime, PageTemplate, TextStyle, Uuid};

/// 一個文件變更。
#[derive(Clone, Debug, PartialEq)]
pub enum DocOp {
    SetTitle {
        title: String,
    },
    AddPage {
        id: Uuid,
        template: PageTemplate,
        /// 插入位置。超出範圍時接在最後。
        index: u32,
    },
    RemovePage {
        id: Uuid,
    },
    /// 把某一頁搬到新的位置（S-87）。
    ///
    /// # 為什麼需要一個獨立的操作
    ///
    /// 「刪掉再加回去」看起來等價，實際上會丟掉那一頁的**內容**
    /// （區塊住在頁面底下），而且在協同時會與別人的編輯打架。
    /// 搬動只改順序，內容原封不動。
    ///
    /// 超出範圍的 `index` 一律夾到最後一頁 —— 兩台裝置對「最後」的
    /// 認知可能差一頁（其中一台剛好多加了一頁），夾住才不會失敗。
    MovePage {
        id: Uuid,
        index: u32,
    },
    /// 文字區塊。內容本身由後續的 `TextEdit` 操作構成（CRDT）。
    AddTextBlock {
        page: Uuid,
        id: Uuid,
        style: TextStyle,
        created_at: NotebookTime,
    },
    /// 轉錄區塊。文字來自 ASR，不可協同編輯，因此直接存字串。
    AddTranscriptBlock {
        page: Uuid,
        id: Uuid,
        session: Uuid,
        text: String,
        created_at: NotebookTime,
    },
    AddImageBlock {
        page: Uuid,
        id: Uuid,
        blob: String,
        width: f32,
        height: f32,
        created_at: NotebookTime,
    },
    /// 調整同層內的堆疊順序（需求 1：物件可自由排列）。
    ///
    /// 記錄**絕對索引**而非「上移一層」：相對操作在併發下會疊加，
    /// 兩個裝置各按一次「移到最上層」就會得出誰也沒預期的順序。
    SetZIndex {
        id: Uuid,
        index: u32,
    },
    /// 新增表格（需求 2）。
    AddTableBlock {
        page: Uuid,
        id: Uuid,
        rows: u32,
        cols: u32,
        cells: Vec<String>,
        header_row: bool,
        created_at: NotebookTime,
    },
    /// 修改單一儲存格。
    ///
    /// 逐格記錄而非整表覆寫 —— 兩人同時編輯不同格時才不會互相覆蓋。
    SetTableCell {
        id: Uuid,
        row: u32,
        col: u32,
        text: String,
    },
    InsertTableRow {
        id: Uuid,
        index: u32,
        cells: Vec<String>,
    },
    DeleteTableRow {
        id: Uuid,
        index: u32,
    },
    InsertTableColumn {
        id: Uuid,
        index: u32,
        cells: Vec<String>,
    },
    DeleteTableColumn {
        id: Uuid,
        index: u32,
    },
    MergeTableCells {
        id: Uuid,
        span: CellSpan,
    },
    UnmergeTableCell {
        id: Uuid,
        row: u32,
        col: u32,
    },
    /// 嵌入外部文件（ADR-0009）。
    AddEmbeddedBlock {
        page: Uuid,
        id: Uuid,
        blob: String,
        format: String,
        interaction: String,
        text: String,
        created_at: NotebookTime,
    },
    RemoveBlock {
        id: Uuid,
    },
    SetBlockStyle {
        id: Uuid,
        style: TextStyle,
    },
    /// 文字 CRDT 操作（ADR-0004）。
    TextEdit {
        block: Uuid,
        op: TextOp,
    },
    StartAudio {
        id: Uuid,
        started_at: NotebookTime,
        media_path: String,
    },
    EndAudio {
        id: Uuid,
        ended_at: NotebookTime,
    },
    /// 新增物件（ADR-0010）。
    AddObject {
        page: Uuid,
        id: Uuid,
        kind: ObjectKind,
        transform: Affine2,
    },
    AddShapeObject {
        page: Uuid,
        id: Uuid,
        shape: ShapeObject,
        transform: Affine2,
    },
    AddConnectionObject {
        page: Uuid,
        id: Uuid,
        connection: ConnectionObject,
        transform: Affine2,
    },
    RemoveObject {
        id: Uuid,
    },
    /// 變更物件的變換。**不改寫任何取樣點**（ADR-0010）。
    SetObjectTransform {
        id: Uuid,
        transform: Affine2,
    },
    /// 把多個物件收進新群組。群組只記錄成員 id，不搬動筆畫資料。
    Group {
        page: Uuid,
        group_id: Uuid,
        members: Vec<Uuid>,
    },
    Ungroup {
        id: Uuid,
    },
    /// 調整頁面尺寸（點）。
    ///
    /// 沒有這個操作的話，「可向下延長的長畫布」在檔案裡完全沒有記錄 ——
    /// iPad 上拉長到 3200pt 的那一頁，在另一個平台會變回預設高度，
    /// 上面的內容看起來就像被截掉了。
    SetPageSize {
        id: Uuid,
        width: f32,
        height: f32,
    },
    /// 設定區塊在頁面上的絕對座標。
    ///
    /// `Block.position` 這個欄位一直存在，卻沒有任何操作寫得進去 —— 於是文字
    /// 方塊與圖片的擺放位置無法落進 op-log。跨平台打開時所有物件會擠在一起，
    /// 而且在原本的平台上看不出來（位置是另外存的）。
    SetBlockPosition {
        id: Uuid,
        x: f32,
        y: f32,
    },
    /// 設定區塊的外觀（顏色、邊框、段落…），內容是平台自訂的 JSON。
    ///
    /// # 為什麼是一團不解讀的 JSON
    ///
    /// 核心不需要知道「淡黃色」或「圓角 12」是什麼意思 —— 那是平台的 UI 詞彙。
    /// 但那些值**必須跨得過平台**：使用者在 iPad 上把文字方塊設成透明底、
    /// 加了行距，換到 Android 打開卻變回白底無行距，那不是「還沒支援」，
    /// 是資料遺失。
    ///
    /// 兩個平台用同一組鍵名（見 `format-spec.md` §6.2），核心只負責原樣搬運。
    SetBlockAppearance {
        id: Uuid,
        json: String,
    },
    /// 筆記本層級的平台中繼資料（平台自訂的 JSON）。
    ///
    /// 與 [`DocOp::SetBlockAppearance`] 同一個契約：**核心不解讀內容**。
    ///
    /// 為什麼需要它：有些東西是「一本筆記」的屬性而不是某個區塊的 ——
    /// 版面樣板、所屬資料夾、討論圖釘、建立時間。核心的文件模型沒有這些概念，
    /// 但它們必須跨得過平台，否則同一本筆記在另一台裝置上會變回空白樣板、
    /// 掉出資料夾、圖釘整串消失。那不是「還沒支援」，是資料遺失。
    ///
    /// 語意是**整份取代**（後寫者贏），與 [`DocOp::SetTitle`] 相同 ——
    /// 合併不是核心的工作，因為核心看不懂內容。
    SetNotebookMeta {
        json: String,
    },
    /// 一個轉錄詞，時間戳在筆記本時間軸上（format-spec §4.1）。
    AddWord {
        text: String,
        start: NotebookTime,
        end: NotebookTime,
        confidence: f32,
    },
    /// 這一批操作的來源座標，寫在**批次的最前面**（工作項 H-MILESTONE）。
    ///
    /// # 為什麼座標不能只靠檔名
    ///
    /// oplog 檔名是 `<lamport>-<device>.oplog`，里程碑就拿它當座標。
    /// 但壓實會把 `0002..0006` 併成一個叫 `0006` 的檔 —— 併完之後，
    /// 本來 lamport 為 2 的操作對外宣稱自己是 6。
    ///
    /// 後果是**資料遺失，不只是設定失效**：一個「回到 lamport 3 那一刻」的
    /// 里程碑，會把整個併起來的檔一起收走，包含那一刀**之前**就該留下來的
    /// 內容。而且沒有任何錯誤訊息 —— 使用者按下還原，東西就少了。
    ///
    /// 把座標寫進資料流本身，壓實（純位元組串接）就保得住它。
    /// 沒有這一筆的舊檔案仍然退回用檔名，所以既有的套件照樣讀得動。
    BatchOrigin {
        lamport: u64,
        device: u32,
    },
    /// 建立一個具名的里程碑（工作項 S-99）。
    ///
    /// 它**不改變任何狀態** —— 只是把「歷史上的這一刀」連同名字記進 oplog，
    /// 這樣每一台裝置都看得到同一份清單，不需要另一個會走散的側邊檔案。
    MarkMilestone {
        id: Uuid,
        title: String,
        creator: String,
        created_unix_ms: u64,
        cut: MilestoneCut,
        automatic: bool,
    },
    /// 還原到某個里程碑：遮蔽 `(cut, upto]` 區間內的操作。
    ///
    /// `cut` 是要回到的那一刀，`upto` 是下手還原時的當下狀態。
    /// 兩個都要，理由見 `milestone` 模組說明。
    RestoreMilestone {
        milestone: Uuid,
        cut: MilestoneCut,
        upto: MilestoneCut,
    },
}

// ---- 編碼 ----

const OP_SET_TITLE: u8 = 1;
const OP_ADD_PAGE: u8 = 2;
const OP_REMOVE_PAGE: u8 = 3;
const OP_ADD_TEXT_BLOCK: u8 = 4;
const OP_ADD_TRANSCRIPT_BLOCK: u8 = 5;
const OP_ADD_IMAGE_BLOCK: u8 = 6;
const OP_REMOVE_BLOCK: u8 = 7;
const OP_SET_BLOCK_STYLE: u8 = 8;
const OP_TEXT_EDIT: u8 = 9;
const OP_START_AUDIO: u8 = 10;
const OP_END_AUDIO: u8 = 11;
const OP_ADD_WORD: u8 = 12;
const OP_ADD_OBJECT: u8 = 13;
const OP_REMOVE_OBJECT: u8 = 14;
const OP_SET_OBJECT_TRANSFORM: u8 = 15;
const OP_GROUP: u8 = 16;
const OP_UNGROUP: u8 = 17;
const OP_ADD_EMBEDDED_BLOCK: u8 = 18;
const OP_ADD_TABLE_BLOCK: u8 = 19;
const OP_SET_TABLE_CELL: u8 = 20;
const OP_SET_Z_INDEX: u8 = 21;
const OP_ADD_SHAPE_OBJECT: u8 = 22;
const OP_ADD_CONNECTION_OBJECT: u8 = 23;
const OP_INSERT_TABLE_ROW: u8 = 24;
const OP_DELETE_TABLE_ROW: u8 = 25;
const OP_INSERT_TABLE_COLUMN: u8 = 26;
const OP_DELETE_TABLE_COLUMN: u8 = 27;
const OP_MERGE_TABLE_CELLS: u8 = 28;
const OP_UNMERGE_TABLE_CELL: u8 = 29;
const OP_SET_PAGE_SIZE: u8 = 30;
const OP_SET_BLOCK_POSITION: u8 = 31;
const OP_SET_BLOCK_APPEARANCE: u8 = 32;
const OP_SET_NOTEBOOK_META: u8 = 33;
/// S-87。**新增 op 代表舊版讀到它會整份拒絕**（`UnknownOp`），
/// 與先前三十三個 op 的情況相同 —— 兩端要同版本發布。
const OP_MOVE_PAGE: u8 = 34;
const OP_MARK_MILESTONE: u8 = 35;
const OP_BATCH_ORIGIN: u8 = 37;
const OP_RESTORE_MILESTONE: u8 = 36;

#[derive(Debug, PartialEq, Eq)]
pub enum DocCodecError {
    Truncated,
    UnknownOp(u8),
    UnknownTemplate(u8),
    UnknownStyle(u8),
    UnknownObjectKind(u8),
    UnknownShapeKind(u8),
    UnknownAnchor(u8),
    UnknownRouteStyle(u8),
    UnknownEndCap(u8),
    InvalidUtf8,
    InvalidChar(u32),
}

impl std::fmt::Display for DocCodecError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Truncated => write!(f, "文件操作資料被截斷"),
            Self::UnknownOp(k) => write!(f, "未知的操作類型：{k}"),
            Self::UnknownTemplate(t) => write!(f, "未知的頁面模板：{t}"),
            Self::UnknownStyle(s) => write!(f, "未知的文字樣式：{s}"),
            Self::UnknownObjectKind(k) => write!(f, "未知的物件類型：{k}"),
            Self::UnknownShapeKind(k) => write!(f, "未知的形狀類型：{k}"),
            Self::UnknownAnchor(a) => write!(f, "未知的連接點：{a}"),
            Self::UnknownRouteStyle(r) => write!(f, "未知的連接線路由：{r}"),
            Self::UnknownEndCap(c) => write!(f, "未知的線端樣式：{c}"),
            Self::InvalidUtf8 => write!(f, "字串不是合法的 UTF-8"),
            Self::InvalidChar(c) => write!(f, "非法的 Unicode 碼位：{c}"),
        }
    }
}

impl std::error::Error for DocCodecError {}

struct Writer(Vec<u8>);

impl Writer {
    fn u8(&mut self, v: u8) -> &mut Self {
        self.0.push(v);
        self
    }
    fn u32(&mut self, v: u32) -> &mut Self {
        self.0.extend_from_slice(&v.to_le_bytes());
        self
    }
    fn u64(&mut self, v: u64) -> &mut Self {
        self.0.extend_from_slice(&v.to_le_bytes());
        self
    }
    fn f32(&mut self, v: f32) -> &mut Self {
        self.0.extend_from_slice(&v.to_le_bytes());
        self
    }
    fn uuid(&mut self, v: Uuid) -> &mut Self {
        self.0.extend_from_slice(v.as_bytes());
        self
    }
    fn time(&mut self, v: NotebookTime) -> &mut Self {
        self.u64(v.as_micros())
    }
    fn str(&mut self, s: &str) -> &mut Self {
        self.u32(s.len() as u32);
        self.0.extend_from_slice(s.as_bytes());
        self
    }
    fn op_id(&mut self, id: OpId) -> &mut Self {
        self.u64(id.seq).u32(id.site)
    }
    fn affine(&mut self, t: Affine2) -> &mut Self {
        self.f32(t.a).f32(t.b).f32(t.c).f32(t.d).f32(t.tx).f32(t.ty)
    }
    fn strings(&mut self, items: &[String]) -> &mut Self {
        self.u32(items.len() as u32);
        for s in items {
            self.str(s);
        }
        self
    }
    /// 里程碑的向量時鐘。兩張表都以 `u32` 筆數開頭，長度可為 0。
    fn cut(&mut self, c: &MilestoneCut) -> &mut Self {
        self.u32(c.doc.len() as u32);
        for (device, lamport) in &c.doc {
            self.u32(*device).u64(*lamport);
        }
        self.u32(c.ink.len() as u32);
        for ((page, device), count) in &c.ink {
            self.uuid(*page).u32(*device).u32(*count);
        }
        // 建立這一刀時已經看得到的還原（見 `MilestoneCut::seen_restores`）。
        self.u32(c.seen_restores.len() as u32);
        for (lamport, device) in &c.seen_restores {
            self.u64(*lamport).u32(*device);
        }
        self
    }
    fn uuids(&mut self, ids: &[Uuid]) -> &mut Self {
        self.u32(ids.len() as u32);
        for id in ids {
            self.uuid(*id);
        }
        self
    }
    fn object_kind(&mut self, k: &ObjectKind) -> &mut Self {
        match k {
            ObjectKind::Strokes(ids) => self.u8(0).uuids(ids),
            ObjectKind::Block(id) => self.u8(1).uuid(*id),
            ObjectKind::Group(ids) => self.u8(2).uuids(ids),
            ObjectKind::Shape(shape) => self.u8(3).shape(shape),
            ObjectKind::Connection(conn) => self.u8(4).connection(conn),
        }
    }
    fn rect(&mut self, r: ObjectRect) -> &mut Self {
        self.f32(r.min_x).f32(r.min_y).f32(r.max_x).f32(r.max_y)
    }
    fn shape_kind(&mut self, k: ShapeKind) -> &mut Self {
        self.u8(match k {
            ShapeKind::Rectangle => 0,
            ShapeKind::RoundedRectangle => 1,
            ShapeKind::Ellipse => 2,
            ShapeKind::Triangle => 3,
            ShapeKind::Diamond => 4,
            ShapeKind::Pentagon => 5,
            ShapeKind::Hexagon => 6,
            ShapeKind::Star => 7,
            ShapeKind::Process => 8,
            ShapeKind::Decision => 9,
            ShapeKind::Terminator => 10,
            ShapeKind::Data => 11,
            ShapeKind::Document => 12,
            ShapeKind::Database => 13,
            ShapeKind::Preparation => 14,
            ShapeKind::ManualInput => 15,
            ShapeKind::Connector => 16,
            ShapeKind::Line => 17,
            ShapeKind::Arrow => 18,
            ShapeKind::DoubleArrow => 19,
            // **20 以後才是新的。0–19 一個都不能動** —— 那些號碼已經寫進
            // 使用者的 .padnote 檔了，改一個就是把他既有的圖形換成別的形狀。
            ShapeKind::ManualOperation => 20,
            ShapeKind::Delay => 21,
            ShapeKind::StoredData => 22,
            ShapeKind::Merge => 23,
            ShapeKind::Extract => 24,
            ShapeKind::OffPageConnector => 25,
            ShapeKind::Display => 26,
            ShapeKind::PunchedTape => 27,
            ShapeKind::PunchedCard => 28,
            ShapeKind::Collate => 29,
            ShapeKind::RightTriangle => 30,
            ShapeKind::Parallelogram => 31,
            ShapeKind::Trapezoid => 32,
            ShapeKind::Heptagon => 33,
            ShapeKind::Octagon => 34,
            ShapeKind::Cross => 35,
            ShapeKind::Chevron => 36,
            ShapeKind::ArrowBlockRight => 37,
            ShapeKind::ArrowBlockLeft => 38,
            ShapeKind::ArrowBlockUp => 39,
            ShapeKind::ArrowBlockDown => 40,
            ShapeKind::Cloud => 41,
            ShapeKind::Heart => 42,
            ShapeKind::Bolt => 43,
            ShapeKind::Moon => 44,
            ShapeKind::Teardrop => 45,
            ShapeKind::LShape => 46,
            ShapeKind::Star4 => 47,
            ShapeKind::Star6 => 48,
            ShapeKind::Star8 => 49,
            ShapeKind::Sun => 50,
            ShapeKind::Banner => 51,
            ShapeKind::SpeechBubble => 52,
            ShapeKind::Plaque => 53,
            ShapeKind::Pie => 54,
        })
    }
    fn anchor(&mut self, a: Anchor) -> &mut Self {
        self.u8(match a {
            Anchor::Top => 0,
            Anchor::Right => 1,
            Anchor::Bottom => 2,
            Anchor::Left => 3,
            Anchor::Center => 4,
        })
    }
    fn route_style(&mut self, r: RouteStyle) -> &mut Self {
        self.u8(match r {
            RouteStyle::Straight => 0,
            RouteStyle::Orthogonal => 1,
        })
    }
    fn end_cap(&mut self, c: EndCap) -> &mut Self {
        self.u8(match c {
            EndCap::None => 0,
            EndCap::Arrow => 1,
            EndCap::HollowArrow => 2,
            EndCap::Circle => 3,
            EndCap::Diamond => 4,
        })
    }
    fn shape(&mut self, s: &ShapeObject) -> &mut Self {
        self.shape_kind(s.kind)
            .rect(s.bounds)
            .f32(s.corner_radius)
            .str(&s.text)
    }
    fn connection(&mut self, c: &ConnectionObject) -> &mut Self {
        self.uuid(c.from)
            .uuid(c.to)
            .anchor(c.from_anchor)
            .anchor(c.to_anchor)
            .route_style(c.route)
            .end_cap(c.start_cap)
            .end_cap(c.end_cap)
            .str(&c.label)
    }
    fn cell_span(&mut self, s: &CellSpan) -> &mut Self {
        self.u32(s.row).u32(s.col).u32(s.row_span).u32(s.col_span)
    }
    fn template(&mut self, t: &PageTemplate) -> &mut Self {
        match t {
            PageTemplate::Blank => self.u8(0),
            PageTemplate::Lined => self.u8(1),
            PageTemplate::Grid => self.u8(2),
            PageTemplate::Dotted => self.u8(3),
            PageTemplate::Cornell => self.u8(4),
            PageTemplate::MusicStaff => self.u8(5),
            PageTemplate::Pdf { blob, page_index } => self.u8(6).str(blob).u32(*page_index),
            PageTemplate::Custom { blob } => self.u8(7).str(blob),
        }
    }
    fn style(&mut self, s: TextStyle) -> &mut Self {
        match s {
            TextStyle::Body => self.u8(0),
            TextStyle::Heading1 => self.u8(1),
            TextStyle::Heading2 => self.u8(2),
            TextStyle::Heading3 => self.u8(3),
            TextStyle::Bullet => self.u8(4),
            TextStyle::Numbered => self.u8(5),
            TextStyle::Quote => self.u8(6),
            TextStyle::Code => self.u8(7),
            TextStyle::Todo { done } => self.u8(8).u8(u8::from(done)),
        }
    }
}

struct Reader<'a> {
    data: &'a [u8],
    pos: usize,
}

impl<'a> Reader<'a> {
    fn take(&mut self, n: usize) -> Result<&'a [u8], DocCodecError> {
        let end = self.pos.checked_add(n).ok_or(DocCodecError::Truncated)?;
        let s = self
            .data
            .get(self.pos..end)
            .ok_or(DocCodecError::Truncated)?;
        self.pos = end;
        Ok(s)
    }
    fn u8(&mut self) -> Result<u8, DocCodecError> {
        Ok(self.take(1)?[0])
    }
    fn u32(&mut self) -> Result<u32, DocCodecError> {
        Ok(u32::from_le_bytes(self.take(4)?.try_into().unwrap()))
    }
    fn u64(&mut self) -> Result<u64, DocCodecError> {
        Ok(u64::from_le_bytes(self.take(8)?.try_into().unwrap()))
    }
    fn f32(&mut self) -> Result<f32, DocCodecError> {
        Ok(f32::from_le_bytes(self.take(4)?.try_into().unwrap()))
    }
    fn uuid(&mut self) -> Result<Uuid, DocCodecError> {
        Ok(Uuid::from_bytes(self.take(16)?.try_into().unwrap()))
    }
    fn time(&mut self) -> Result<NotebookTime, DocCodecError> {
        Ok(NotebookTime::from_micros(self.u64()?))
    }
    fn str(&mut self) -> Result<String, DocCodecError> {
        let n = self.u32()? as usize;
        std::str::from_utf8(self.take(n)?)
            .map(str::to_string)
            .map_err(|_| DocCodecError::InvalidUtf8)
    }
    fn affine(&mut self) -> Result<Affine2, DocCodecError> {
        Ok(Affine2 {
            a: self.f32()?,
            b: self.f32()?,
            c: self.f32()?,
            d: self.f32()?,
            tx: self.f32()?,
            ty: self.f32()?,
        })
    }
    fn strings(&mut self) -> Result<Vec<String>, DocCodecError> {
        let n = self.u32()? as usize;
        (0..n).map(|_| self.str()).collect()
    }
    fn cut(&mut self) -> Result<MilestoneCut, DocCodecError> {
        let mut doc = DocClock::new();
        for _ in 0..self.u32()? {
            let device = self.u32()?;
            doc.insert(device, self.u64()?);
        }
        let mut ink = InkClock::new();
        for _ in 0..self.u32()? {
            let page = self.uuid()?;
            let device = self.u32()?;
            ink.insert((page, device), self.u32()?);
        }
        let mut seen_restores = std::collections::BTreeSet::new();
        for _ in 0..self.u32()? {
            let lamport = self.u64()?;
            seen_restores.insert((lamport, self.u32()?));
        }
        Ok(MilestoneCut {
            doc,
            ink,
            seen_restores,
        })
    }
    fn uuids(&mut self) -> Result<Vec<Uuid>, DocCodecError> {
        let n = self.u32()? as usize;
        (0..n).map(|_| self.uuid()).collect()
    }
    fn object_kind(&mut self) -> Result<ObjectKind, DocCodecError> {
        Ok(match self.u8()? {
            0 => ObjectKind::Strokes(self.uuids()?),
            1 => ObjectKind::Block(self.uuid()?),
            2 => ObjectKind::Group(self.uuids()?),
            3 => ObjectKind::Shape(self.shape()?),
            4 => ObjectKind::Connection(self.connection()?),
            k => return Err(DocCodecError::UnknownObjectKind(k)),
        })
    }
    fn rect(&mut self) -> Result<ObjectRect, DocCodecError> {
        Ok(ObjectRect {
            min_x: self.f32()?,
            min_y: self.f32()?,
            max_x: self.f32()?,
            max_y: self.f32()?,
        })
    }
    fn shape_kind(&mut self) -> Result<ShapeKind, DocCodecError> {
        Ok(match self.u8()? {
            0 => ShapeKind::Rectangle,
            1 => ShapeKind::RoundedRectangle,
            2 => ShapeKind::Ellipse,
            3 => ShapeKind::Triangle,
            4 => ShapeKind::Diamond,
            5 => ShapeKind::Pentagon,
            6 => ShapeKind::Hexagon,
            7 => ShapeKind::Star,
            8 => ShapeKind::Process,
            9 => ShapeKind::Decision,
            10 => ShapeKind::Terminator,
            11 => ShapeKind::Data,
            12 => ShapeKind::Document,
            13 => ShapeKind::Database,
            14 => ShapeKind::Preparation,
            15 => ShapeKind::ManualInput,
            16 => ShapeKind::Connector,
            17 => ShapeKind::Line,
            18 => ShapeKind::Arrow,
            19 => ShapeKind::DoubleArrow,
            20 => ShapeKind::ManualOperation,
            21 => ShapeKind::Delay,
            22 => ShapeKind::StoredData,
            23 => ShapeKind::Merge,
            24 => ShapeKind::Extract,
            25 => ShapeKind::OffPageConnector,
            26 => ShapeKind::Display,
            27 => ShapeKind::PunchedTape,
            28 => ShapeKind::PunchedCard,
            29 => ShapeKind::Collate,
            30 => ShapeKind::RightTriangle,
            31 => ShapeKind::Parallelogram,
            32 => ShapeKind::Trapezoid,
            33 => ShapeKind::Heptagon,
            34 => ShapeKind::Octagon,
            35 => ShapeKind::Cross,
            36 => ShapeKind::Chevron,
            37 => ShapeKind::ArrowBlockRight,
            38 => ShapeKind::ArrowBlockLeft,
            39 => ShapeKind::ArrowBlockUp,
            40 => ShapeKind::ArrowBlockDown,
            41 => ShapeKind::Cloud,
            42 => ShapeKind::Heart,
            43 => ShapeKind::Bolt,
            44 => ShapeKind::Moon,
            45 => ShapeKind::Teardrop,
            46 => ShapeKind::LShape,
            47 => ShapeKind::Star4,
            48 => ShapeKind::Star6,
            49 => ShapeKind::Star8,
            50 => ShapeKind::Sun,
            51 => ShapeKind::Banner,
            52 => ShapeKind::SpeechBubble,
            53 => ShapeKind::Plaque,
            54 => ShapeKind::Pie,
            k => return Err(DocCodecError::UnknownShapeKind(k)),
        })
    }
    fn anchor(&mut self) -> Result<Anchor, DocCodecError> {
        Ok(match self.u8()? {
            0 => Anchor::Top,
            1 => Anchor::Right,
            2 => Anchor::Bottom,
            3 => Anchor::Left,
            4 => Anchor::Center,
            a => return Err(DocCodecError::UnknownAnchor(a)),
        })
    }
    fn route_style(&mut self) -> Result<RouteStyle, DocCodecError> {
        Ok(match self.u8()? {
            0 => RouteStyle::Straight,
            1 => RouteStyle::Orthogonal,
            r => return Err(DocCodecError::UnknownRouteStyle(r)),
        })
    }
    fn end_cap(&mut self) -> Result<EndCap, DocCodecError> {
        Ok(match self.u8()? {
            0 => EndCap::None,
            1 => EndCap::Arrow,
            2 => EndCap::HollowArrow,
            3 => EndCap::Circle,
            4 => EndCap::Diamond,
            c => return Err(DocCodecError::UnknownEndCap(c)),
        })
    }
    fn shape(&mut self) -> Result<ShapeObject, DocCodecError> {
        Ok(ShapeObject {
            kind: self.shape_kind()?,
            bounds: self.rect()?,
            corner_radius: self.f32()?,
            text: self.str()?,
        })
    }
    fn connection(&mut self) -> Result<ConnectionObject, DocCodecError> {
        Ok(ConnectionObject {
            from: self.uuid()?,
            to: self.uuid()?,
            from_anchor: self.anchor()?,
            to_anchor: self.anchor()?,
            route: self.route_style()?,
            start_cap: self.end_cap()?,
            end_cap: self.end_cap()?,
            label: self.str()?,
        })
    }
    fn cell_span(&mut self) -> Result<CellSpan, DocCodecError> {
        Ok(CellSpan {
            row: self.u32()?,
            col: self.u32()?,
            row_span: self.u32()?,
            col_span: self.u32()?,
        })
    }
    fn op_id(&mut self) -> Result<OpId, DocCodecError> {
        Ok(OpId {
            seq: self.u64()?,
            site: self.u32()?,
        })
    }
    fn template(&mut self) -> Result<PageTemplate, DocCodecError> {
        Ok(match self.u8()? {
            0 => PageTemplate::Blank,
            1 => PageTemplate::Lined,
            2 => PageTemplate::Grid,
            3 => PageTemplate::Dotted,
            4 => PageTemplate::Cornell,
            5 => PageTemplate::MusicStaff,
            6 => PageTemplate::Pdf {
                blob: self.str()?,
                page_index: self.u32()?,
            },
            7 => PageTemplate::Custom { blob: self.str()? },
            t => return Err(DocCodecError::UnknownTemplate(t)),
        })
    }
    fn style(&mut self) -> Result<TextStyle, DocCodecError> {
        Ok(match self.u8()? {
            0 => TextStyle::Body,
            1 => TextStyle::Heading1,
            2 => TextStyle::Heading2,
            3 => TextStyle::Heading3,
            4 => TextStyle::Bullet,
            5 => TextStyle::Numbered,
            6 => TextStyle::Quote,
            7 => TextStyle::Code,
            8 => TextStyle::Todo {
                done: self.u8()? == 1,
            },
            s => return Err(DocCodecError::UnknownStyle(s)),
        })
    }
}

pub fn encode(ops: &[DocOp]) -> Vec<u8> {
    let mut w = Writer(Vec::with_capacity(ops.len() * 48));
    for op in ops {
        match op {
            DocOp::SetTitle { title } => {
                w.u8(OP_SET_TITLE).str(title);
            }
            DocOp::AddPage {
                id,
                template,
                index,
            } => {
                w.u8(OP_ADD_PAGE).uuid(*id).template(template).u32(*index);
            }
            DocOp::RemovePage { id } => {
                w.u8(OP_REMOVE_PAGE).uuid(*id);
            }
            DocOp::MovePage { id, index } => {
                w.u8(OP_MOVE_PAGE).uuid(*id).u32(*index);
            }
            DocOp::AddTextBlock {
                page,
                id,
                style,
                created_at,
            } => {
                w.u8(OP_ADD_TEXT_BLOCK)
                    .uuid(*page)
                    .uuid(*id)
                    .style(*style)
                    .time(*created_at);
            }
            DocOp::AddTranscriptBlock {
                page,
                id,
                session,
                text,
                created_at,
            } => {
                w.u8(OP_ADD_TRANSCRIPT_BLOCK)
                    .uuid(*page)
                    .uuid(*id)
                    .uuid(*session)
                    .str(text)
                    .time(*created_at);
            }
            DocOp::AddImageBlock {
                page,
                id,
                blob,
                width,
                height,
                created_at,
            } => {
                w.u8(OP_ADD_IMAGE_BLOCK)
                    .uuid(*page)
                    .uuid(*id)
                    .str(blob)
                    .f32(*width)
                    .f32(*height)
                    .time(*created_at);
            }
            DocOp::RemoveBlock { id } => {
                w.u8(OP_REMOVE_BLOCK).uuid(*id);
            }
            DocOp::SetBlockStyle { id, style } => {
                w.u8(OP_SET_BLOCK_STYLE).uuid(*id).style(*style);
            }
            DocOp::TextEdit { block, op } => {
                w.u8(OP_TEXT_EDIT).uuid(*block);
                match op {
                    TextOp::Insert { id, origin, ch } => {
                        w.u8(1).op_id(*id);
                        match origin {
                            Some(o) => {
                                w.u8(1).op_id(*o);
                            }
                            None => {
                                w.u8(0);
                            }
                        }
                        w.u32(*ch as u32);
                    }
                    TextOp::Delete { id } => {
                        w.u8(2).op_id(*id);
                    }
                }
            }
            DocOp::StartAudio {
                id,
                started_at,
                media_path,
            } => {
                w.u8(OP_START_AUDIO)
                    .uuid(*id)
                    .time(*started_at)
                    .str(media_path);
            }
            DocOp::EndAudio { id, ended_at } => {
                w.u8(OP_END_AUDIO).uuid(*id).time(*ended_at);
            }
            DocOp::AddWord {
                text,
                start,
                end,
                confidence,
            } => {
                w.u8(OP_ADD_WORD)
                    .str(text)
                    .time(*start)
                    .time(*end)
                    .f32(*confidence);
            }
            DocOp::AddObject {
                page,
                id,
                kind,
                transform,
            } => {
                w.u8(OP_ADD_OBJECT)
                    .uuid(*page)
                    .uuid(*id)
                    .object_kind(kind)
                    .affine(*transform);
            }
            DocOp::AddShapeObject {
                page,
                id,
                shape,
                transform,
            } => {
                w.u8(OP_ADD_SHAPE_OBJECT)
                    .uuid(*page)
                    .uuid(*id)
                    .shape(shape)
                    .affine(*transform);
            }
            DocOp::AddConnectionObject {
                page,
                id,
                connection,
                transform,
            } => {
                w.u8(OP_ADD_CONNECTION_OBJECT)
                    .uuid(*page)
                    .uuid(*id)
                    .connection(connection)
                    .affine(*transform);
            }
            DocOp::AddEmbeddedBlock {
                page,
                id,
                blob,
                format,
                interaction,
                text,
                created_at,
            } => {
                w.u8(OP_ADD_EMBEDDED_BLOCK)
                    .uuid(*page)
                    .uuid(*id)
                    .str(blob)
                    .str(format)
                    .str(interaction)
                    .str(text)
                    .time(*created_at);
            }
            DocOp::AddTableBlock {
                page,
                id,
                rows,
                cols,
                cells,
                header_row,
                created_at,
            } => {
                w.u8(OP_ADD_TABLE_BLOCK)
                    .uuid(*page)
                    .uuid(*id)
                    .u32(*rows)
                    .u32(*cols)
                    .strings(cells)
                    .u8(u8::from(*header_row))
                    .time(*created_at);
            }
            DocOp::SetTableCell { id, row, col, text } => {
                w.u8(OP_SET_TABLE_CELL)
                    .uuid(*id)
                    .u32(*row)
                    .u32(*col)
                    .str(text);
            }
            DocOp::InsertTableRow { id, index, cells } => {
                w.u8(OP_INSERT_TABLE_ROW)
                    .uuid(*id)
                    .u32(*index)
                    .strings(cells);
            }
            DocOp::DeleteTableRow { id, index } => {
                w.u8(OP_DELETE_TABLE_ROW).uuid(*id).u32(*index);
            }
            DocOp::InsertTableColumn { id, index, cells } => {
                w.u8(OP_INSERT_TABLE_COLUMN)
                    .uuid(*id)
                    .u32(*index)
                    .strings(cells);
            }
            DocOp::DeleteTableColumn { id, index } => {
                w.u8(OP_DELETE_TABLE_COLUMN).uuid(*id).u32(*index);
            }
            DocOp::MergeTableCells { id, span } => {
                w.u8(OP_MERGE_TABLE_CELLS).uuid(*id).cell_span(span);
            }
            DocOp::UnmergeTableCell { id, row, col } => {
                w.u8(OP_UNMERGE_TABLE_CELL).uuid(*id).u32(*row).u32(*col);
            }
            DocOp::SetZIndex { id, index } => {
                w.u8(OP_SET_Z_INDEX).uuid(*id).u32(*index);
            }
            DocOp::SetPageSize { id, width, height } => {
                w.u8(OP_SET_PAGE_SIZE).uuid(*id).f32(*width).f32(*height);
            }
            DocOp::SetBlockPosition { id, x, y } => {
                w.u8(OP_SET_BLOCK_POSITION).uuid(*id).f32(*x).f32(*y);
            }
            DocOp::SetBlockAppearance { id, json } => {
                w.u8(OP_SET_BLOCK_APPEARANCE).uuid(*id).str(json);
            }
            DocOp::SetNotebookMeta { json } => {
                w.u8(OP_SET_NOTEBOOK_META).str(json);
            }
            DocOp::RemoveObject { id } => {
                w.u8(OP_REMOVE_OBJECT).uuid(*id);
            }
            DocOp::SetObjectTransform { id, transform } => {
                w.u8(OP_SET_OBJECT_TRANSFORM).uuid(*id).affine(*transform);
            }
            DocOp::Group {
                page,
                group_id,
                members,
            } => {
                w.u8(OP_GROUP).uuid(*page).uuid(*group_id).uuids(members);
            }
            DocOp::Ungroup { id } => {
                w.u8(OP_UNGROUP).uuid(*id);
            }
            DocOp::MarkMilestone {
                id,
                title,
                creator,
                created_unix_ms,
                cut,
                automatic,
            } => {
                w.u8(OP_MARK_MILESTONE)
                    .uuid(*id)
                    .str(title)
                    .str(creator)
                    .u64(*created_unix_ms)
                    .cut(cut)
                    .u8(u8::from(*automatic));
            }
            DocOp::BatchOrigin { lamport, device } => {
                w.u8(OP_BATCH_ORIGIN).u64(*lamport).u32(*device);
            }
            DocOp::RestoreMilestone {
                milestone,
                cut,
                upto,
            } => {
                w.u8(OP_RESTORE_MILESTONE)
                    .uuid(*milestone)
                    .cut(cut)
                    .cut(upto);
            }
        }
    }
    w.0
}

pub fn decode(data: &[u8]) -> Result<Vec<DocOp>, DocCodecError> {
    let mut r = Reader { data, pos: 0 };
    let mut out = Vec::new();

    while r.pos < data.len() {
        let op = match r.u8()? {
            OP_SET_TITLE => DocOp::SetTitle { title: r.str()? },
            OP_ADD_PAGE => DocOp::AddPage {
                id: r.uuid()?,
                template: r.template()?,
                index: r.u32()?,
            },
            OP_REMOVE_PAGE => DocOp::RemovePage { id: r.uuid()? },
            OP_MOVE_PAGE => DocOp::MovePage {
                id: r.uuid()?,
                index: r.u32()?,
            },
            OP_ADD_TEXT_BLOCK => DocOp::AddTextBlock {
                page: r.uuid()?,
                id: r.uuid()?,
                style: r.style()?,
                created_at: r.time()?,
            },
            OP_ADD_TRANSCRIPT_BLOCK => DocOp::AddTranscriptBlock {
                page: r.uuid()?,
                id: r.uuid()?,
                session: r.uuid()?,
                text: r.str()?,
                created_at: r.time()?,
            },
            OP_ADD_IMAGE_BLOCK => DocOp::AddImageBlock {
                page: r.uuid()?,
                id: r.uuid()?,
                blob: r.str()?,
                width: r.f32()?,
                height: r.f32()?,
                created_at: r.time()?,
            },
            OP_REMOVE_BLOCK => DocOp::RemoveBlock { id: r.uuid()? },
            OP_SET_BLOCK_STYLE => DocOp::SetBlockStyle {
                id: r.uuid()?,
                style: r.style()?,
            },
            OP_TEXT_EDIT => {
                let block = r.uuid()?;
                let op = match r.u8()? {
                    1 => {
                        let id = r.op_id()?;
                        let origin = if r.u8()? == 1 { Some(r.op_id()?) } else { None };
                        let cp = r.u32()?;
                        TextOp::Insert {
                            id,
                            origin,
                            ch: char::from_u32(cp).ok_or(DocCodecError::InvalidChar(cp))?,
                        }
                    }
                    2 => TextOp::Delete { id: r.op_id()? },
                    k => return Err(DocCodecError::UnknownOp(k)),
                };
                DocOp::TextEdit { block, op }
            }
            OP_START_AUDIO => DocOp::StartAudio {
                id: r.uuid()?,
                started_at: r.time()?,
                media_path: r.str()?,
            },
            OP_END_AUDIO => DocOp::EndAudio {
                id: r.uuid()?,
                ended_at: r.time()?,
            },
            OP_ADD_WORD => DocOp::AddWord {
                text: r.str()?,
                start: r.time()?,
                end: r.time()?,
                confidence: r.f32()?,
            },
            OP_ADD_OBJECT => DocOp::AddObject {
                page: r.uuid()?,
                id: r.uuid()?,
                kind: r.object_kind()?,
                transform: r.affine()?,
            },
            OP_ADD_SHAPE_OBJECT => DocOp::AddShapeObject {
                page: r.uuid()?,
                id: r.uuid()?,
                shape: r.shape()?,
                transform: r.affine()?,
            },
            OP_ADD_CONNECTION_OBJECT => DocOp::AddConnectionObject {
                page: r.uuid()?,
                id: r.uuid()?,
                connection: r.connection()?,
                transform: r.affine()?,
            },
            OP_ADD_EMBEDDED_BLOCK => DocOp::AddEmbeddedBlock {
                page: r.uuid()?,
                id: r.uuid()?,
                blob: r.str()?,
                format: r.str()?,
                interaction: r.str()?,
                text: r.str()?,
                created_at: r.time()?,
            },
            OP_ADD_TABLE_BLOCK => DocOp::AddTableBlock {
                page: r.uuid()?,
                id: r.uuid()?,
                rows: r.u32()?,
                cols: r.u32()?,
                cells: r.strings()?,
                header_row: r.u8()? == 1,
                created_at: r.time()?,
            },
            OP_SET_TABLE_CELL => DocOp::SetTableCell {
                id: r.uuid()?,
                row: r.u32()?,
                col: r.u32()?,
                text: r.str()?,
            },
            OP_INSERT_TABLE_ROW => DocOp::InsertTableRow {
                id: r.uuid()?,
                index: r.u32()?,
                cells: r.strings()?,
            },
            OP_DELETE_TABLE_ROW => DocOp::DeleteTableRow {
                id: r.uuid()?,
                index: r.u32()?,
            },
            OP_INSERT_TABLE_COLUMN => DocOp::InsertTableColumn {
                id: r.uuid()?,
                index: r.u32()?,
                cells: r.strings()?,
            },
            OP_DELETE_TABLE_COLUMN => DocOp::DeleteTableColumn {
                id: r.uuid()?,
                index: r.u32()?,
            },
            OP_MERGE_TABLE_CELLS => DocOp::MergeTableCells {
                id: r.uuid()?,
                span: r.cell_span()?,
            },
            OP_UNMERGE_TABLE_CELL => DocOp::UnmergeTableCell {
                id: r.uuid()?,
                row: r.u32()?,
                col: r.u32()?,
            },
            OP_SET_Z_INDEX => DocOp::SetZIndex {
                id: r.uuid()?,
                index: r.u32()?,
            },
            OP_SET_PAGE_SIZE => DocOp::SetPageSize {
                id: r.uuid()?,
                width: r.f32()?,
                height: r.f32()?,
            },
            OP_SET_BLOCK_POSITION => DocOp::SetBlockPosition {
                id: r.uuid()?,
                x: r.f32()?,
                y: r.f32()?,
            },
            OP_SET_BLOCK_APPEARANCE => DocOp::SetBlockAppearance {
                id: r.uuid()?,
                json: r.str()?,
            },
            OP_SET_NOTEBOOK_META => DocOp::SetNotebookMeta { json: r.str()? },
            OP_REMOVE_OBJECT => DocOp::RemoveObject { id: r.uuid()? },
            OP_SET_OBJECT_TRANSFORM => DocOp::SetObjectTransform {
                id: r.uuid()?,
                transform: r.affine()?,
            },
            OP_GROUP => DocOp::Group {
                page: r.uuid()?,
                group_id: r.uuid()?,
                members: r.uuids()?,
            },
            OP_UNGROUP => DocOp::Ungroup { id: r.uuid()? },
            OP_MARK_MILESTONE => DocOp::MarkMilestone {
                id: r.uuid()?,
                title: r.str()?,
                creator: r.str()?,
                created_unix_ms: r.u64()?,
                cut: r.cut()?,
                automatic: r.u8()? != 0,
            },
            OP_BATCH_ORIGIN => DocOp::BatchOrigin {
                lamport: r.u64()?,
                device: r.u32()?,
            },
            OP_RESTORE_MILESTONE => DocOp::RestoreMilestone {
                milestone: r.uuid()?,
                cut: r.cut()?,
                upto: r.cut()?,
            },
            k => return Err(DocCodecError::UnknownOp(k)),
        };
        out.push(op);
    }
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn uid(b: u8) -> Uuid {
        Uuid::from_bytes([b; 16])
    }

    fn shape() -> ShapeObject {
        ShapeObject {
            kind: ShapeKind::Process,
            bounds: ObjectRect {
                min_x: 10.0,
                min_y: 20.0,
                max_x: 110.0,
                max_y: 80.0,
            },
            corner_radius: 8.0,
            text: "輸入".into(),
        }
    }

    fn connection() -> ConnectionObject {
        ConnectionObject {
            from: uid(70),
            to: uid(71),
            from_anchor: Anchor::Right,
            to_anchor: Anchor::Left,
            route: RouteStyle::Orthogonal,
            start_cap: EndCap::None,
            end_cap: EndCap::Arrow,
            label: "是".into(),
        }
    }

    fn all_op_kinds() -> Vec<DocOp> {
        vec![
            DocOp::SetTitle {
                title: "線性代數 第三週".into(),
            },
            DocOp::AddPage {
                id: uid(1),
                template: PageTemplate::Cornell,
                index: 0,
            },
            DocOp::AddPage {
                id: uid(2),
                template: PageTemplate::Pdf {
                    blob: "abc123".into(),
                    page_index: 7,
                },
                index: 1,
            },
            DocOp::RemovePage { id: uid(2) },
            // S-87：搬動頁面也要能編解碼往返。
            DocOp::MovePage {
                id: uid(3),
                index: 2,
            },
            DocOp::AddTextBlock {
                page: uid(1),
                id: uid(10),
                style: TextStyle::Heading2,
                created_at: NotebookTime::from_micros(1_000_000),
            },
            DocOp::SetBlockStyle {
                id: uid(10),
                style: TextStyle::Todo { done: true },
            },
            DocOp::AddTranscriptBlock {
                page: uid(1),
                id: uid(11),
                session: uid(20),
                text: "今天要講的是特徵值".into(),
                created_at: NotebookTime::from_micros(2_000_000),
            },
            DocOp::AddImageBlock {
                page: uid(1),
                id: uid(12),
                blob: "deadbeef".into(),
                width: 640.5,
                height: 480.25,
                created_at: NotebookTime::ZERO,
            },
            DocOp::RemoveBlock { id: uid(12) },
            DocOp::TextEdit {
                block: uid(10),
                op: TextOp::Insert {
                    id: OpId::new(3, 7),
                    origin: None,
                    ch: '線',
                },
            },
            DocOp::TextEdit {
                block: uid(10),
                op: TextOp::Insert {
                    id: OpId::new(3, 8),
                    origin: Some(OpId::new(3, 7)),
                    ch: '🖋',
                },
            },
            DocOp::TextEdit {
                block: uid(10),
                op: TextOp::Delete {
                    id: OpId::new(3, 7),
                },
            },
            DocOp::StartAudio {
                id: uid(20),
                started_at: NotebookTime::from_micros(500_000),
                media_path: "media/audio/x.opus".into(),
            },
            DocOp::EndAudio {
                id: uid(20),
                ended_at: NotebookTime::from_micros(9_000_000),
            },
            DocOp::AddWord {
                text: "特徵值".into(),
                start: NotebookTime::from_micros(3_000_000),
                end: NotebookTime::from_micros(3_800_000),
                confidence: 0.93,
            },
            DocOp::AddObject {
                page: uid(1),
                id: uid(30),
                kind: ObjectKind::Strokes(vec![uid(31), uid(32)]),
                transform: Affine2::translate(10.5, -3.25),
            },
            DocOp::RemoveObject { id: uid(30) },
            DocOp::SetObjectTransform {
                id: uid(30),
                transform: Affine2::scale(2.0, 0.5),
            },
            DocOp::Group {
                page: uid(1),
                group_id: uid(40),
                members: vec![uid(30), uid(33)],
            },
            DocOp::Ungroup { id: uid(40) },
            DocOp::AddEmbeddedBlock {
                page: uid(1),
                id: uid(50),
                blob: "deadbeef".into(),
                format: "xlsx".into(),
                interaction: "editable".into(),
                text: "項目 數量 單價".into(),
                created_at: NotebookTime::from_micros(7_000_000),
            },
            DocOp::AddTableBlock {
                page: uid(1),
                id: uid(60),
                rows: 2,
                cols: 2,
                cells: vec!["項目".into(), "數量".into(), "筆記本".into(), "3".into()],
                header_row: true,
                created_at: NotebookTime::from_micros(8_000_000),
            },
            DocOp::SetTableCell {
                id: uid(60),
                row: 1,
                col: 1,
                text: "5".into(),
            },
            DocOp::SetZIndex {
                id: uid(61),
                index: 2,
            },
            DocOp::SetPageSize {
                id: uid(1),
                width: 595.0,
                height: 3200.0,
            },
            DocOp::SetBlockPosition {
                id: uid(61),
                x: 120.5,
                y: 480.25,
            },
            DocOp::SetBlockAppearance {
                id: uid(61),
                json: "{\"backgroundColorHex\":\"clear\",\"lineSpacing\":8}".into(),
            },
            DocOp::SetNotebookMeta {
                json: "{\"template\":\"cornell\",\"folderId\":\"abc\"}".into(),
            },
            DocOp::AddShapeObject {
                page: uid(1),
                id: uid(70),
                shape: shape(),
                transform: Affine2::translate(3.0, 4.0),
            },
            DocOp::AddConnectionObject {
                page: uid(1),
                id: uid(72),
                connection: connection(),
                transform: Affine2::IDENTITY,
            },
            DocOp::InsertTableRow {
                id: uid(60),
                index: 1,
                cells: vec!["小計".into(), "42".into()],
            },
            DocOp::DeleteTableRow {
                id: uid(60),
                index: 2,
            },
            DocOp::InsertTableColumn {
                id: uid(60),
                index: 1,
                cells: vec!["單價".into(), "99".into()],
            },
            DocOp::DeleteTableColumn {
                id: uid(60),
                index: 0,
            },
            DocOp::MergeTableCells {
                id: uid(60),
                span: CellSpan {
                    row: 0,
                    col: 0,
                    row_span: 1,
                    col_span: 2,
                },
            },
            DocOp::UnmergeTableCell {
                id: uid(60),
                row: 0,
                col: 0,
            },
        ]
    }

    #[test]
    fn every_op_kind_roundtrips() {
        let ops = all_op_kinds();
        assert_eq!(decode(&encode(&ops)).unwrap(), ops);
    }

    #[test]
    fn covers_all_op_tags() {
        // 新增 DocOp 變體卻忘記加進測試，這條會提醒你。
        let ops = all_op_kinds();
        let tags: std::collections::HashSet<u8> = ops
            .iter()
            .map(|o| encode(std::slice::from_ref(o))[0])
            .collect();
        assert_eq!(
            tags.len(),
            34,
            "34 種操作標籤都要被測到，實得 {}",
            tags.len()
        );
    }

    #[test]
    fn every_page_template_roundtrips() {
        for t in [
            PageTemplate::Blank,
            PageTemplate::Lined,
            PageTemplate::Grid,
            PageTemplate::Dotted,
            PageTemplate::Cornell,
            PageTemplate::MusicStaff,
            PageTemplate::Custom { blob: "x".into() },
        ] {
            let op = DocOp::AddPage {
                id: uid(1),
                template: t.clone(),
                index: 0,
            };
            assert_eq!(
                decode(&encode(std::slice::from_ref(&op))).unwrap()[0],
                op,
                "{t:?}"
            );
        }
    }

    #[test]
    fn every_text_style_roundtrips() {
        for s in [
            TextStyle::Body,
            TextStyle::Heading1,
            TextStyle::Heading2,
            TextStyle::Heading3,
            TextStyle::Bullet,
            TextStyle::Numbered,
            TextStyle::Quote,
            TextStyle::Code,
            TextStyle::Todo { done: false },
            TextStyle::Todo { done: true },
        ] {
            let op = DocOp::SetBlockStyle {
                id: uid(1),
                style: s,
            };
            assert_eq!(
                decode(&encode(std::slice::from_ref(&op))).unwrap()[0],
                op,
                "{s:?}"
            );
        }
    }

    #[test]
    fn object_kinds_roundtrip() {
        for kind in [
            ObjectKind::Strokes(vec![uid(1), uid(2)]),
            ObjectKind::Strokes(vec![]),
            ObjectKind::Block(uid(3)),
            ObjectKind::Group(vec![uid(4)]),
            ObjectKind::Shape(shape()),
            ObjectKind::Connection(connection()),
        ] {
            let op = DocOp::AddObject {
                page: uid(1),
                id: uid(2),
                kind: kind.clone(),
                transform: Affine2::IDENTITY,
            };
            assert_eq!(
                decode(&encode(std::slice::from_ref(&op))).unwrap()[0],
                op,
                "{kind:?}"
            );
        }
    }

    #[test]
    fn transforms_survive_exactly() {
        // 變換是 f32，必須位元級無損 —— 否則反覆存讀會讓物件緩慢漂移。
        let t = Affine2 {
            a: 1.5,
            b: -0.25,
            c: 0.125,
            d: 2.0,
            tx: 123.456,
            ty: -789.012,
        };
        let op = DocOp::SetObjectTransform {
            id: uid(1),
            transform: t,
        };
        let DocOp::SetObjectTransform { transform, .. } =
            &decode(&encode(std::slice::from_ref(&op))).unwrap()[0]
        else {
            panic!()
        };
        assert_eq!(*transform, t);
    }

    #[test]
    fn unknown_object_kind_is_rejected() {
        let mut bytes = vec![OP_ADD_OBJECT];
        bytes.extend_from_slice(&[1u8; 32]); // page + id
        bytes.push(99); // 未知類型
        assert_eq!(decode(&bytes), Err(DocCodecError::UnknownObjectKind(99)));
    }

    #[test]
    fn multibyte_strings_survive() {
        // 字串長度用位元組數而非字元數 —— 搞錯會把中文切一半。
        let op = DocOp::SetTitle {
            title: "線性代數 🖋️ Linear Algebra".into(),
        };
        assert_eq!(decode(&encode(std::slice::from_ref(&op))).unwrap()[0], op);
    }

    #[test]
    fn empty_input_is_empty_output() {
        assert!(decode(&[]).unwrap().is_empty());
        assert!(encode(&[]).is_empty());
    }

    #[test]
    fn truncated_data_is_reported_not_silently_dropped() {
        let ops = all_op_kinds();
        let mut bytes = encode(&ops);
        bytes.truncate(bytes.len() - 3);
        assert_eq!(decode(&bytes), Err(DocCodecError::Truncated));
    }

    #[test]
    fn unknown_op_tag_is_rejected() {
        assert_eq!(decode(&[200u8]), Err(DocCodecError::UnknownOp(200)));
    }

    #[test]
    fn unknown_template_tag_is_rejected() {
        let mut bytes = vec![OP_ADD_PAGE];
        bytes.extend_from_slice(&[1u8; 16]);
        bytes.push(99); // 未知模板
        assert_eq!(decode(&bytes), Err(DocCodecError::UnknownTemplate(99)));
    }

    #[test]
    fn invalid_utf8_is_rejected() {
        let mut bytes = vec![OP_SET_TITLE];
        bytes.extend_from_slice(&2u32.to_le_bytes());
        bytes.extend_from_slice(&[0xFF, 0xFE]);
        assert_eq!(decode(&bytes), Err(DocCodecError::InvalidUtf8));
    }
}
