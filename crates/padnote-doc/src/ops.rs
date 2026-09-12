//! 文件操作日誌（工作項 S-23，`format-spec.md` §6）。
//!
//! 在此之前只有**筆畫**會落盤，頁面、區塊、錄音 session 都只活在記憶體裡 ——
//! 關掉 App 就沒了。這個模組補上整條文件的持久化。
//!
//! 與筆畫一樣是 **append-only**：每個變更追加一筆 `DocOp`，重開時重播得到
//! 目前狀態。刪除用墓碑而非移除記錄，保持記錄可交換（同步收斂的前提）。

use crate::object::ObjectKind;
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
    /// 一個轉錄詞，時間戳在筆記本時間軸上（format-spec §4.1）。
    AddWord {
        text: String,
        start: NotebookTime,
        end: NotebookTime,
        confidence: f32,
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

#[derive(Debug, PartialEq, Eq)]
pub enum DocCodecError {
    Truncated,
    UnknownOp(u8),
    UnknownTemplate(u8),
    UnknownStyle(u8),
    UnknownObjectKind(u8),
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
        }
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
    fn uuids(&mut self) -> Result<Vec<Uuid>, DocCodecError> {
        let n = self.u32()? as usize;
        (0..n).map(|_| self.uuid()).collect()
    }
    fn object_kind(&mut self) -> Result<ObjectKind, DocCodecError> {
        Ok(match self.u8()? {
            0 => ObjectKind::Strokes(self.uuids()?),
            1 => ObjectKind::Block(self.uuid()?),
            2 => ObjectKind::Group(self.uuids()?),
            k => return Err(DocCodecError::UnknownObjectKind(k)),
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
            DocOp::SetZIndex { id, index } => {
                w.u8(OP_SET_Z_INDEX).uuid(*id).u32(*index);
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
            OP_SET_Z_INDEX => DocOp::SetZIndex {
                id: r.uuid()?,
                index: r.u32()?,
            },
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
            21,
            "21 種操作標籤都要被測到，實得 {}",
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
