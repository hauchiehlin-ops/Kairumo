//! 筆畫檔的二進位編解碼（`docs/format-spec.md` §5）。小端序。
//!
//! 這是**公開格式**的參考實作。任何人可依規格自行解析，不需要 Padnote。

use crate::{InkPoint, InkRecord, Stroke, Tool};
use padnote_doc::{NotebookTime, Uuid};
use std::f32::consts::{PI, TAU};

pub const MAGIC: [u8; 8] = *b"PADNINK\0";
pub const VERSION: u16 = 1;
pub const HEADER_LEN: usize = 32;
pub const POINT_LEN: usize = 16;

const KIND_ADD: u8 = 1;
const KIND_REMOVE: u8 = 2;

#[derive(Debug)]
pub enum CodecError {
    BadMagic,
    /// 讀取器不支援的版本 —— 必須拒絕而非猜測解析（format-spec §8）。
    UnsupportedVersion(u16),
    Truncated,
    UnknownTool(u16),
    UnknownRecordKind(u8),
}

impl std::fmt::Display for CodecError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::BadMagic => write!(f, "不是 PADNINK 筆畫檔"),
            Self::UnsupportedVersion(v) => write!(f, "不支援的格式版本：{v}"),
            Self::Truncated => write!(f, "檔案被截斷"),
            Self::UnknownTool(t) => write!(f, "未知的 tool_id：{t}"),
            Self::UnknownRecordKind(k) => write!(f, "未知的記錄類型：{k}"),
        }
    }
}

impl std::error::Error for CodecError {}

// ---- 定點數編碼（format-spec §5.4）----

fn enc_unit(v: f32) -> u16 {
    (v.clamp(0.0, 1.0) * u16::MAX as f32).round() as u16
}
fn dec_unit(v: u16) -> f32 {
    f32::from(v) / f32::from(u16::MAX)
}
fn enc_angle(v: f32, max: f32) -> u16 {
    enc_unit(v / max)
}
fn dec_angle(v: u16, max: f32) -> f32 {
    dec_unit(v) * max
}

/// 寫入筆畫檔。Append-only：`push` 只會加在尾端。
#[derive(Debug)]
pub struct StrokeWriter {
    buf: Vec<u8>,
}

impl StrokeWriter {
    pub fn new(page_id: Uuid) -> Self {
        let mut buf = Vec::with_capacity(HEADER_LEN);
        buf.extend_from_slice(&MAGIC);
        buf.extend_from_slice(&VERSION.to_le_bytes());
        buf.extend_from_slice(&0u16.to_le_bytes()); // flags
        buf.extend_from_slice(&0u32.to_le_bytes()); // reserved
        buf.extend_from_slice(page_id.as_bytes());
        debug_assert_eq!(buf.len(), HEADER_LEN);
        Self { buf }
    }

    pub fn push(&mut self, record: &InkRecord) {
        let mut body = Vec::new();
        match record {
            InkRecord::Add(s) => {
                body.push(KIND_ADD);
                body.extend_from_slice(s.id.as_bytes());
                body.extend_from_slice(&s.started_at.as_micros().to_le_bytes());
                body.extend_from_slice(&(s.tool as u16).to_le_bytes());
                body.extend_from_slice(&s.color_rgba8);
                body.extend_from_slice(&s.base_width.to_le_bytes());
                body.extend_from_slice(&(s.points.len() as u32).to_le_bytes());
                for p in &s.points {
                    body.extend_from_slice(&p.x.to_le_bytes());
                    body.extend_from_slice(&p.y.to_le_bytes());
                    body.extend_from_slice(&enc_unit(p.pressure).to_le_bytes());
                    body.extend_from_slice(&enc_angle(p.tilt, PI / 2.0).to_le_bytes());
                    body.extend_from_slice(&enc_angle(p.azimuth, TAU).to_le_bytes());
                    // >65535µs 的間隔在上層以重複點拆分（format-spec §5.4）
                    body.extend_from_slice(
                        &(p.dt_us.min(u32::from(u16::MAX)) as u16).to_le_bytes(),
                    );
                }
            }
            InkRecord::Remove(id) => {
                body.push(KIND_REMOVE);
                body.extend_from_slice(id.as_bytes());
            }
        }
        self.buf
            .extend_from_slice(&(body.len() as u32).to_le_bytes());
        self.buf.extend_from_slice(&body);
    }

    pub fn as_bytes(&self) -> &[u8] {
        &self.buf
    }

    pub fn into_bytes(self) -> Vec<u8> {
        self.buf
    }
}

/// 讀取筆畫檔。
#[derive(Debug)]
pub struct StrokeReader<'a> {
    data: &'a [u8],
    pos: usize,
    page_id: Uuid,
}

impl<'a> StrokeReader<'a> {
    pub fn new(data: &'a [u8]) -> Result<Self, CodecError> {
        if data.len() < HEADER_LEN {
            return Err(CodecError::Truncated);
        }
        if data[0..8] != MAGIC {
            return Err(CodecError::BadMagic);
        }
        let version = u16::from_le_bytes([data[8], data[9]]);
        if version != VERSION {
            return Err(CodecError::UnsupportedVersion(version));
        }
        let mut page = [0u8; 16];
        page.copy_from_slice(&data[16..32]);
        Ok(Self {
            data,
            pos: HEADER_LEN,
            page_id: Uuid::from_bytes(page),
        })
    }

    pub fn page_id(&self) -> Uuid {
        self.page_id
    }

    /// 讀出所有記錄。截斷的尾端記錄會回報 `Truncated` 而非靜默忽略。
    pub fn read_all(mut self) -> Result<Vec<InkRecord>, CodecError> {
        let mut out = Vec::new();
        while self.pos < self.data.len() {
            out.push(self.next_record()?);
        }
        Ok(out)
    }

    fn take(&mut self, n: usize) -> Result<&'a [u8], CodecError> {
        let end = self.pos.checked_add(n).ok_or(CodecError::Truncated)?;
        let s = self.data.get(self.pos..end).ok_or(CodecError::Truncated)?;
        self.pos = end;
        Ok(s)
    }

    fn next_record(&mut self) -> Result<InkRecord, CodecError> {
        let len = u32::from_le_bytes(self.take(4)?.try_into().unwrap()) as usize;
        let body = self.take(len)?;
        let (&kind, rest) = body.split_first().ok_or(CodecError::Truncated)?;

        let uuid_of = |s: &[u8]| -> Result<Uuid, CodecError> {
            Ok(Uuid::from_bytes(
                s.get(..16)
                    .ok_or(CodecError::Truncated)?
                    .try_into()
                    .unwrap(),
            ))
        };

        match kind {
            KIND_REMOVE => Ok(InkRecord::Remove(uuid_of(rest)?)),
            KIND_ADD => {
                if rest.len() < 38 {
                    return Err(CodecError::Truncated);
                }
                let id = uuid_of(rest)?;
                let started = u64::from_le_bytes(rest[16..24].try_into().unwrap());
                let tool_id = u16::from_le_bytes(rest[24..26].try_into().unwrap());
                let tool = Tool::from_id(tool_id).ok_or(CodecError::UnknownTool(tool_id))?;
                let color: [u8; 4] = rest[26..30].try_into().unwrap();
                let base_width = f32::from_le_bytes(rest[30..34].try_into().unwrap());
                let count = u32::from_le_bytes(rest[34..38].try_into().unwrap()) as usize;

                let pts = rest.get(38..).ok_or(CodecError::Truncated)?;
                if pts.len() < count * POINT_LEN {
                    return Err(CodecError::Truncated);
                }
                let points = pts
                    .chunks_exact(POINT_LEN)
                    .take(count)
                    .map(|c| InkPoint {
                        x: f32::from_le_bytes(c[0..4].try_into().unwrap()),
                        y: f32::from_le_bytes(c[4..8].try_into().unwrap()),
                        pressure: dec_unit(u16::from_le_bytes(c[8..10].try_into().unwrap())),
                        tilt: dec_angle(
                            u16::from_le_bytes(c[10..12].try_into().unwrap()),
                            PI / 2.0,
                        ),
                        azimuth: dec_angle(u16::from_le_bytes(c[12..14].try_into().unwrap()), TAU),
                        dt_us: u32::from(u16::from_le_bytes(c[14..16].try_into().unwrap())),
                    })
                    .collect();

                Ok(InkRecord::Add(Stroke {
                    id,
                    started_at: NotebookTime::from_micros(started),
                    tool,
                    color_rgba8: color,
                    base_width,
                    points,
                }))
            }
            k => Err(CodecError::UnknownRecordKind(k)),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample_stroke() -> Stroke {
        Stroke {
            id: Uuid::now_v7(),
            started_at: NotebookTime::from_micros(12_345_678),
            tool: Tool::Highlighter,
            color_rgba8: [255, 200, 0, 128],
            base_width: 4.25,
            points: vec![
                InkPoint {
                    x: 1.5,
                    y: -2.25,
                    pressure: 0.5,
                    tilt: PI / 4.0,
                    azimuth: PI,
                    dt_us: 0,
                },
                InkPoint {
                    x: 100.0,
                    y: 250.75,
                    pressure: 1.0,
                    tilt: 0.0,
                    azimuth: 0.0,
                    dt_us: 8_333,
                },
            ],
        }
    }

    #[test]
    fn roundtrip_preserves_stroke() {
        let page = Uuid::now_v7();
        let original = sample_stroke();
        let mut w = StrokeWriter::new(page);
        w.push(&InkRecord::Add(original.clone()));

        let bytes = w.into_bytes();
        let r = StrokeReader::new(&bytes).unwrap();
        assert_eq!(r.page_id(), page);
        let records = r.read_all().unwrap();
        assert_eq!(records.len(), 1);

        let InkRecord::Add(got) = &records[0] else {
            panic!("應為 Add 記錄");
        };
        assert_eq!(got.id, original.id);
        assert_eq!(got.started_at, original.started_at);
        assert_eq!(got.tool, original.tool);
        assert_eq!(got.color_rgba8, original.color_rgba8);
        assert_eq!(got.base_width, original.base_width);
        assert_eq!(got.points.len(), 2);

        // 座標是 f32，必須位元級無損 —— 縮放無損的前提。
        assert_eq!(got.points[0].x, 1.5);
        assert_eq!(got.points[0].y, -2.25);
        assert_eq!(got.points[1].dt_us, 8_333);
    }

    #[test]
    fn quantized_fields_stay_within_tolerance() {
        let bytes = {
            let mut w = StrokeWriter::new(Uuid::now_v7());
            w.push(&InkRecord::Add(sample_stroke()));
            w.into_bytes()
        };
        let records = StrokeReader::new(&bytes).unwrap().read_all().unwrap();
        let InkRecord::Add(got) = &records[0] else {
            unreachable!()
        };

        // u16 量化誤差上限：1/65535
        assert!((got.points[0].pressure - 0.5).abs() < 1e-4);
        assert!((got.points[0].tilt - PI / 4.0).abs() < 1e-4);
        assert!((got.points[0].azimuth - PI).abs() < 1e-3);
    }

    #[test]
    fn append_only_writer_preserves_record_order() {
        let s = sample_stroke();
        let id = s.id;
        let mut w = StrokeWriter::new(Uuid::now_v7());
        w.push(&InkRecord::Add(s));
        w.push(&InkRecord::Remove(id));

        let bytes = w.into_bytes();
        let records = StrokeReader::new(&bytes).unwrap().read_all().unwrap();
        assert!(matches!(records[0], InkRecord::Add(_)));
        assert!(matches!(records[1], InkRecord::Remove(x) if x == id));
        assert!(crate::materialize(&records).is_empty());
    }

    #[test]
    fn rejects_foreign_file() {
        let junk = vec![0u8; 64];
        assert!(matches!(
            StrokeReader::new(&junk),
            Err(CodecError::BadMagic)
        ));
    }

    #[test]
    fn rejects_future_version_instead_of_guessing() {
        let mut w = StrokeWriter::new(Uuid::now_v7());
        w.push(&InkRecord::Add(sample_stroke()));
        let mut bytes = w.into_bytes();
        bytes[8..10].copy_from_slice(&999u16.to_le_bytes());

        // format-spec §8：不支援的版本必須拒絕，絕不嘗試解析。
        assert!(matches!(
            StrokeReader::new(&bytes),
            Err(CodecError::UnsupportedVersion(999))
        ));
    }

    #[test]
    fn truncated_tail_is_reported_not_ignored() {
        let mut w = StrokeWriter::new(Uuid::now_v7());
        w.push(&InkRecord::Add(sample_stroke()));
        let mut bytes = w.into_bytes();
        bytes.truncate(bytes.len() - 5);

        assert!(matches!(
            StrokeReader::new(&bytes).unwrap().read_all(),
            Err(CodecError::Truncated)
        ));
    }

    #[test]
    fn header_layout_matches_spec() {
        let bytes = StrokeWriter::new(Uuid::from_bytes([7; 16])).into_bytes();
        assert_eq!(bytes.len(), HEADER_LEN);
        assert_eq!(&bytes[0..8], &MAGIC);
        assert_eq!(u16::from_le_bytes([bytes[8], bytes[9]]), VERSION);
        assert_eq!(&bytes[16..32], &[7u8; 16]);
    }
}
