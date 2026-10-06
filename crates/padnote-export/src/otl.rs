//! OpenType 排版引擎（GSUB／GPOS／GDEF），給 PDF 匯出把文字排成字形用。
//!
//! 泰文不能「一個字碼配一個字形」：聲調符號要疊在子音或上母音的**上面**，ำ 要拆成兩個字形，
//! ฐ／ญ 遇到下母音要換成沒有下腳的樣子。這些全部寫在字型自己的 GSUB（字形替換）與 GPOS（字形定位）表裡，
//! 所以只要照表執行就能得到正確的結果，不需要在程式裡寫死泰文的規則。
//!
//! # 涵蓋範圍
//!
//! **OpenType 規格裡每一種查詢（lookup）型別與格式都有實作**，不是只有某一支字型用到的那幾種：
//!
//! | 表 | 型別 |
//! |---|---|
//! | GSUB | 1 單一替換（格式 1、2）· 2 一對多 · 3 替代字形 · 4 合字 · 5 上下文（格式 1、2、3）· 6 鏈結上下文（格式 1、2、3）· 7 擴充 · 8 反向鏈結單一替換 |
//! | GPOS | 1 單一調整（格式 1、2）· 2 配對調整（格式 1、2）· 3 草寫連接 · 4 標記對底字 · 5 標記對合字 · 6 標記對標記 · 7 上下文 · 8 鏈結上下文 · 9 擴充 |
//! | GDEF | 字形類別、標記附著類別（`markAttachmentType`）、標記過濾集（`useMarkFilteringSet`） |
//! | cmap | 格式 0、4、6、12、13（含 Windows／Unicode 兩種平台） |
//! | 容器 | 單一字型與 TrueType Collection（`.ttc`）；TrueType 與 CFF（`OTTO`）外框 |
//!
//! 查詢旗標（`ignoreBaseGlyphs`／`ignoreLigatures`／`ignoreMarks`／`useMarkFilteringSet`／`markAttachmentType`）全部照規格處理。
//!
//! # 沒有做的
//!
//! - **文字系統專屬的整形器**：阿拉伯文的連寫判定（init／medi／fina）、天城文等印度系文字的音節重排、
//!   緬甸文與高棉文的重排。這些不是「照表執行」，而是各自一套規則（HarfBuzz 的 `hb-ot-shape-complex-*`）。
//!   引擎照樣會跑這些字型的通用特徵，但輸出**不保證**對。泰文、拉丁文、希臘文、西里爾文、日文、韓文、
//!   希伯來文（不含連字與母音標記排序）不需要它們。
//! - 雙向文字（bidi）重排；可變字型的軸（`fvar`／`gvar`／`HVAR`）；裝置表（`Device`／`VariationIndex`，
//!   像素級微調，PDF 是向量用不到）；`kern` 舊表與 AAT（`morx`／`kerx`，Apple 專有）。
//!
//! 全部是唯讀的位元組讀取，任何越界都回傳 `None`，不會 panic。

use std::borrow::Cow;
use std::collections::HashMap;

fn u16_at(d: &[u8], o: usize) -> Option<u16> {
    Some(u16::from_be_bytes([*d.get(o)?, *d.get(o + 1)?]))
}
fn i16_at(d: &[u8], o: usize) -> Option<i16> {
    u16_at(d, o).map(|v| v as i16)
}
fn u32_at(d: &[u8], o: usize) -> Option<u32> {
    Some(u32::from_be_bytes([
        *d.get(o)?,
        *d.get(o + 1)?,
        *d.get(o + 2)?,
        *d.get(o + 3)?,
    ]))
}

/// 一個排好的字形。座標單位是字型單位（Noto Sans Thai 是 1000/em）。
#[derive(Clone, Debug, PartialEq)]
pub struct Glyph {
    pub gid: u16,
    /// 這個字形原本對應的字碼（替換、合併後沿用第一個）；供 ToUnicode 與測試用。
    pub cp: char,
    pub x_advance: i32,
    pub x_offset: i32,
    pub y_offset: i32,
    /// 附著在哪個字形上（標記）：位置在最後統一換算。
    attach: Option<(usize, i32, i32)>,
    /// 這個字形是被合成的（合字）時，原本有幾個部件；標記對合字用它挑部件。
    components: u8,
}

/// 排版選項。
#[derive(Clone, Debug, Default)]
pub struct ShapeOptions {
    /// OpenType 文字系統標籤（`thai`、`latn`…）。`None` = 由文字自動判斷。
    pub script: Option<[u8; 4]>,
    /// 語言系統標籤（`THA `、`ROM `…）。`None` = 預設語言系統。
    pub language: Option<[u8; 4]>,
    /// 額外開啟的特徵（例如 `smcp`、`salt`、`ss01`）。預設特徵一律開著。
    pub features: Vec<[u8; 4]>,
    /// 關掉的預設特徵（例如 `liga` 關閉合字）。
    pub disabled: Vec<[u8; 4]>,
    /// 替代字形（GSUB 型別 3）要選第幾個，從 1 算起。`None` = 1。
    pub alternate: Option<u16>,
}

/// 預設開啟的 GSUB 特徵（照 HarfBuzz 的通用順序，查詢索引決定實際執行順序）。
const DEFAULT_GSUB: &[[u8; 4]] = &[
    *b"ccmp", *b"locl", *b"rlig", *b"calt", *b"clig", *b"liga", *b"rclt",
];
/// 預設開啟的 GPOS 特徵。
const DEFAULT_GPOS: &[[u8; 4]] = &[*b"dist", *b"kern", *b"curs", *b"mark", *b"mkmk"];

#[derive(Debug)]
pub struct Font {
    data: Cow<'static, [u8]>,
    pub units_per_em: u16,
    pub num_glyphs: u16,
    /// head 表的 xMin, yMin, xMax, yMax（字型單位）。
    pub bbox: [i16; 4],
    /// 外框是 CFF（`OTTO`）而不是 TrueType；PDF 要用不同的方式嵌入。
    pub is_cff: bool,
    /// 字型檔裡「這一個字型」的開頭位元組範圍（TTC 時是整個檔案；嵌入 PDF 用整個檔案即可）。
    advances: Vec<u16>,
    cmap: HashMap<u32, u16>,
    gsub: Option<usize>,
    gpos: Option<usize>,
    gdef: Option<usize>,
}

/// 一個查詢的內容：(型別, 旗標, 標記集, 子表位移們)。
type LookupSubtables = (u16, u16, u16, Vec<(u16, usize)>);

impl Font {
    /// 解析靜態內嵌的字型（單一字型；TTC 取第 0 個）。
    pub fn parse(data: &'static [u8]) -> Option<Font> {
        Self::parse_index(Cow::Borrowed(data), 0)
    }

    /// 解析字型檔。`index` 只對 TrueType Collection 有意義。
    pub fn parse_index(data: Cow<'static, [u8]>, index: u32) -> Option<Font> {
        let d: &[u8] = &data;
        // TTC：'ttcf' + version + numFonts + offsets[]
        let base = if d.get(0..4)? == b"ttcf" {
            let n = u32_at(d, 8)?;
            if index >= n {
                return None;
            }
            u32_at(d, 12 + 4 * index as usize)? as usize
        } else {
            0
        };
        let sfnt = d.get(base..base + 4)?;
        let is_cff = sfnt == b"OTTO";
        if !(is_cff || sfnt == [0, 1, 0, 0] || sfnt == b"true" || sfnt == b"typ1") {
            return None;
        }
        let n = u16_at(d, base + 4)? as usize;
        let mut tables: HashMap<[u8; 4], usize> = HashMap::new();
        for i in 0..n {
            let r = base + 12 + 16 * i;
            let tag = [*d.get(r)?, *d.get(r + 1)?, *d.get(r + 2)?, *d.get(r + 3)?];
            tables.insert(tag, u32_at(d, r + 8)? as usize);
        }
        let head = *tables.get(b"head")?;
        let units_per_em = u16_at(d, head + 18)?;
        if units_per_em == 0 {
            return None;
        }
        let hhea = *tables.get(b"hhea")?;
        let n_h = u16_at(d, hhea + 34)? as usize;
        let num_glyphs = u16_at(d, *tables.get(b"maxp")? + 4)?;
        let hmtx = *tables.get(b"hmtx")?;
        let mut advances = Vec::with_capacity(num_glyphs as usize);
        for g in 0..num_glyphs as usize {
            let idx = g.min(n_h.saturating_sub(1));
            advances.push(u16_at(d, hmtx + 4 * idx)?);
        }
        let cmap = Self::read_cmap(d, *tables.get(b"cmap")?)?;
        let bbox = [
            i16_at(d, head + 36)?,
            i16_at(d, head + 38)?,
            i16_at(d, head + 40)?,
            i16_at(d, head + 42)?,
        ];
        let gsub = tables.get(b"GSUB").copied();
        let gpos = tables.get(b"GPOS").copied();
        let gdef = tables.get(b"GDEF").copied();
        drop(tables);
        Some(Font {
            data,
            units_per_em,
            num_glyphs,
            bbox,
            is_cff,
            advances,
            cmap,
            gsub,
            gpos,
            gdef,
        })
    }

    /// 整個字型檔的位元組（PDF 嵌入用）。
    pub fn bytes(&self) -> &[u8] {
        &self.data
    }

    fn read_cmap(d: &[u8], cmap: usize) -> Option<HashMap<u32, u16>> {
        let n = u16_at(d, cmap + 2)? as usize;
        // 優先序：完整 Unicode（12）> BMP Unicode（4）> 其他可讀格式。
        let mut best: Option<(usize, u16, u8)> = None;
        for i in 0..n {
            let pid = u16_at(d, cmap + 4 + 8 * i)?;
            let eid = u16_at(d, cmap + 6 + 8 * i)?;
            let off = cmap + u32_at(d, cmap + 8 + 8 * i)? as usize;
            let fmt = u16_at(d, off)?;
            let unicode = (pid == 0) || (pid == 3 && (eid == 1 || eid == 10));
            if !unicode || !matches!(fmt, 0 | 4 | 6 | 12 | 13) {
                continue;
            }
            let rank = match fmt {
                12 | 13 => 3,
                4 => 2,
                _ => 1,
            };
            if best.is_none_or(|(_, _, r)| rank > r) {
                best = Some((off, fmt, rank));
            }
        }
        let (off, fmt, _) = best?;
        let mut map = HashMap::new();
        match fmt {
            0 => {
                for c in 0..256usize {
                    let g = *d.get(off + 6 + c)? as u16;
                    if g != 0 {
                        map.insert(c as u32, g);
                    }
                }
            }
            4 => {
                let segx2 = u16_at(d, off + 6)? as usize;
                let seg = segx2 / 2;
                let end = off + 14;
                let start = end + segx2 + 2;
                let delta = start + segx2;
                let range = delta + segx2;
                for s in 0..seg {
                    let e = u16_at(d, end + 2 * s)?;
                    let st = u16_at(d, start + 2 * s)?;
                    let dl = u16_at(d, delta + 2 * s)?;
                    let ro = u16_at(d, range + 2 * s)?;
                    if st == 0xFFFF || st > e {
                        continue;
                    }
                    for c in st..=e {
                        let g = if ro == 0 {
                            c.wrapping_add(dl)
                        } else {
                            let p = range + 2 * s + ro as usize + 2 * (c - st) as usize;
                            let g = u16_at(d, p)?;
                            if g == 0 { 0 } else { g.wrapping_add(dl) }
                        };
                        if g != 0 {
                            map.insert(c as u32, g);
                        }
                    }
                }
            }
            6 => {
                let first = u16_at(d, off + 6)? as u32;
                let count = u16_at(d, off + 8)? as usize;
                for i in 0..count {
                    let g = u16_at(d, off + 10 + 2 * i)?;
                    if g != 0 {
                        map.insert(first + i as u32, g);
                    }
                }
            }
            12 | 13 => {
                let groups = u32_at(d, off + 12)? as usize;
                for g in 0..groups {
                    let b = off + 16 + 12 * g;
                    let (s, e, gid) = (u32_at(d, b)?, u32_at(d, b + 4)?, u32_at(d, b + 8)?);
                    if s > e {
                        continue;
                    }
                    for c in s..=e.min(s + 0xFFFF) {
                        // 格式 13：整段共用同一個字形（後備字型）。
                        let target = if fmt == 12 { gid + (c - s) } else { gid };
                        map.insert(c, target as u16);
                    }
                }
            }
            _ => return None,
        }
        Some(map)
    }

    pub fn glyph_for(&self, c: char) -> Option<u16> {
        self.cmap.get(&(c as u32)).copied()
    }

    pub fn advance(&self, gid: u16) -> i32 {
        self.advances.get(gid as usize).copied().unwrap_or(0) as i32
    }

    /// 字形 → 字碼（供 ToUnicode；替換出來的變體字形沒有對應，回傳 None）。
    pub fn reverse_cmap(&self) -> HashMap<u16, u32> {
        let mut m = HashMap::new();
        for (&c, &g) in &self.cmap {
            m.entry(g)
                .and_modify(|e: &mut u32| *e = (*e).min(c))
                .or_insert(c);
        }
        m
    }

    // ---- 文字系統與特徵 ----

    /// 由文字判斷 OpenType 文字系統標籤（取第一個有明確文字系統的字元）。
    pub fn detect_script(text: &str) -> [u8; 4] {
        for c in text.chars() {
            let u = c as u32;
            let tag: Option<&[u8; 4]> = match u {
                0x0E00..=0x0E7F => Some(b"thai"),
                0x0041..=0x005A | 0x0061..=0x007A | 0x00C0..=0x024F | 0x1E00..=0x1EFF => {
                    Some(b"latn")
                }
                0x0370..=0x03FF | 0x1F00..=0x1FFF => Some(b"grek"),
                0x0400..=0x052F => Some(b"cyrl"),
                0x0590..=0x05FF => Some(b"hebr"),
                0x0600..=0x06FF | 0x0750..=0x077F => Some(b"arab"),
                0x0900..=0x097F => Some(b"dev2"),
                0x3040..=0x30FF => Some(b"kana"),
                0x1100..=0x11FF | 0xAC00..=0xD7AF => Some(b"hang"),
                0x3400..=0x9FFF => Some(b"hani"),
                _ => None,
            };
            if let Some(t) = tag {
                return *t;
            }
        }
        *b"DFLT"
    }

    /// 取指定文字系統（找不到依序退 `DFLT`、`latn`）與語言系統裡、指定特徵的所有查詢索引，由小到大排序。
    fn feature_lookups(
        &self,
        table: Option<usize>,
        script: [u8; 4],
        language: Option<[u8; 4]>,
        wanted: &[[u8; 4]],
        disabled: &[[u8; 4]],
    ) -> Vec<u16> {
        let d: &[u8] = &self.data;
        let Some(t) = table else { return Vec::new() };
        let go = || -> Option<Vec<u16>> {
            let sl = t + u16_at(d, t + 4)? as usize;
            let fl = t + u16_at(d, t + 6)? as usize;
            let n = u16_at(d, sl)? as usize;
            let mut chosen: Option<usize> = None;
            for pass in [script, *b"DFLT", *b"latn"] {
                for i in 0..n {
                    let tag = [
                        *d.get(sl + 2 + 6 * i)?,
                        *d.get(sl + 3 + 6 * i)?,
                        *d.get(sl + 4 + 6 * i)?,
                        *d.get(sl + 5 + 6 * i)?,
                    ];
                    if tag == pass {
                        chosen = Some(sl + u16_at(d, sl + 6 + 6 * i)? as usize);
                        break;
                    }
                }
                if chosen.is_some() {
                    break;
                }
            }
            let script_off = chosen?;
            // 語言系統：指定的優先，沒有就用預設。
            let mut langsys = None;
            if let Some(lang) = language {
                let lc = u16_at(d, script_off + 2)? as usize;
                for j in 0..lc {
                    let r = script_off + 4 + 6 * j;
                    let tag = [*d.get(r)?, *d.get(r + 1)?, *d.get(r + 2)?, *d.get(r + 3)?];
                    if tag == lang {
                        langsys = Some(script_off + u16_at(d, r + 4)? as usize);
                        break;
                    }
                }
            }
            if langsys.is_none() {
                let def = u16_at(d, script_off)? as usize;
                if def != 0 {
                    langsys = Some(script_off + def);
                }
            }
            let ls = langsys?;
            let mut feature_indexes = Vec::new();
            let req = u16_at(d, ls + 2)?;
            if req != 0xFFFF {
                feature_indexes.push(req as usize);
            }
            let fc = u16_at(d, ls + 4)? as usize;
            for k in 0..fc {
                feature_indexes.push(u16_at(d, ls + 6 + 2 * k)? as usize);
            }
            let mut out = Vec::new();
            for fi in feature_indexes {
                let tag = [
                    *d.get(fl + 2 + 6 * fi)?,
                    *d.get(fl + 3 + 6 * fi)?,
                    *d.get(fl + 4 + 6 * fi)?,
                    *d.get(fl + 5 + 6 * fi)?,
                ];
                if !wanted.contains(&tag) || disabled.contains(&tag) {
                    continue;
                }
                let fo = fl + u16_at(d, fl + 6 + 6 * fi)? as usize;
                let lc = u16_at(d, fo + 2)? as usize;
                for j in 0..lc {
                    out.push(u16_at(d, fo + 4 + 2 * j)?);
                }
            }
            out.sort_unstable();
            out.dedup();
            Some(out)
        };
        go().unwrap_or_default()
    }

    fn lookup_offset(&self, table: usize, idx: u16) -> Option<usize> {
        let d: &[u8] = &self.data;
        let ll = table + u16_at(d, table + 8)? as usize;
        let n = u16_at(d, ll)?;
        if idx >= n {
            return None;
        }
        Some(ll + u16_at(d, ll + 2 + 2 * idx as usize)? as usize)
    }

    // ---- GDEF ----

    fn gdef_offset(&self, header_field: usize, min_minor: u16) -> Option<usize> {
        let g = self.gdef?;
        let d: &[u8] = &self.data;
        if min_minor > 0 && u16_at(d, g + 2)? < min_minor {
            return None;
        }
        let off = u16_at(d, g + header_field)? as usize;
        (off != 0).then_some(g + off)
    }

    /// 字形類別：1 底字、2 合字、3 標記、4 部件；0 = 沒有資料。
    fn glyph_class(&self, gid: u16) -> u16 {
        self.gdef_offset(4, 0)
            .and_then(|o| class_def(&self.data, o, gid))
            .unwrap_or(0)
    }

    fn mark_attach_class(&self, gid: u16) -> u16 {
        self.gdef_offset(10, 0)
            .and_then(|o| class_def(&self.data, o, gid))
            .unwrap_or(0)
    }

    fn in_mark_set(&self, set: u16, gid: u16) -> bool {
        // 標記字形集合（`markGlyphSetsDefOffset`）在 GDEF 1.2 以後，位移 12。
        let go = || -> Option<bool> {
            let ms = self.gdef_offset(12, 2)?;
            let d: &[u8] = &self.data;
            let n = u16_at(d, ms + 2)?;
            if set >= n {
                return Some(false);
            }
            let cov = ms + u32_at(d, ms + 4 + 4 * set as usize)? as usize;
            Some(coverage(d, cov, gid).is_some())
        };
        go().unwrap_or(false)
    }

    /// 這個查詢要不要略過這個字形（LookupFlag 的五個旗標）。
    fn skip(&self, flag: u16, mark_set: u16, gid: u16) -> bool {
        if flag & 0xFF1E == 0 {
            return false; // 沒有任何略過規則：不必查 GDEF。
        }
        let class = self.glyph_class(gid);
        if flag & 0x2 != 0 && class == 1 {
            return true;
        }
        if flag & 0x4 != 0 && class == 2 {
            return true;
        }
        if class == 3 {
            if flag & 0x8 != 0 {
                return true;
            }
            if flag & 0x10 != 0 && !self.in_mark_set(mark_set, gid) {
                return true;
            }
            let attach = flag >> 8;
            if attach != 0 && self.mark_attach_class(gid) != attach {
                return true;
            }
        }
        false
    }

    // ---- 對外：排版 ----

    /// 文字系統專屬的前處理（目前只有泰文）：在套用字型的 GSUB 之前先把字碼序列正規化。
    ///
    /// 這不是「照表執行」能涵蓋的 —— 規則寫在 Unicode 與整形器裡，不在字型裡：
    /// - 結合符號依「修正過的結合類別」排序：下母音（類別 103）要排在聲調符號（107）之前，
    ///   否則「กุ่」（聲調在前、下母音在後）的疊放順序會錯。
    /// - ำ（U+0E33）拆成 ํ（U+0E4D）＋ า（U+0E32），而且 ํ 要移到它前面的聲調符號**之前**
    ///   （「น้ำ」要排成 น ํ ้ า）；字型的 `ccmp` 只拆不排序，所以這裡先做。
    fn thai_normalize(&self, chars: &[char]) -> Vec<char> {
        fn ccc(c: char) -> u8 {
            match c as u32 {
                0x0E38..=0x0E3A => 103,
                0x0E48..=0x0E4B => 107,
                _ => 0,
            }
        }
        let can_split =
            self.glyph_for('\u{0E4D}').is_some() && self.glyph_for('\u{0E32}').is_some();
        let mut out: Vec<char> = Vec::with_capacity(chars.len() + 2);
        for &c in chars {
            if c == '\u{0E33}' && can_split {
                // ํ 移到前面連續的聲調符號之前。
                let mut at = out.len();
                while at > 0 && ccc(out[at - 1]) == 107 {
                    at -= 1;
                }
                out.insert(at, '\u{0E4D}');
                out.push('\u{0E32}');
            } else {
                out.push(c);
            }
        }
        // 結合類別排序：連續的、類別不為 0 的符號，穩定排序。
        let mut i = 0;
        while i < out.len() {
            if ccc(out[i]) == 0 {
                i += 1;
                continue;
            }
            let start = i;
            while i < out.len() && ccc(out[i]) != 0 {
                i += 1;
            }
            out[start..i].sort_by_key(|c| ccc(*c));
        }
        out
    }

    /// 把一段文字排成字形（文字系統由文字自動判斷）。
    /// 找不到字形的字碼回傳 `None`，由呼叫端決定怎麼辦。
    pub fn shape(&self, text: &str) -> Option<Vec<Glyph>> {
        self.shape_with(text, &ShapeOptions::default())
    }

    pub fn shape_with(&self, text: &str, opts: &ShapeOptions) -> Option<Vec<Glyph>> {
        let script = opts.script.unwrap_or_else(|| Self::detect_script(text));
        let mut buf: Vec<Glyph> = Vec::new();
        let chars: Vec<char> = if script == *b"thai" {
            self.thai_normalize(&text.chars().collect::<Vec<_>>())
        } else {
            text.chars().collect()
        };
        for c in chars {
            let gid = self.glyph_for(c)?;
            buf.push(Glyph {
                gid,
                cp: c,
                x_advance: self.advance(gid),
                x_offset: 0,
                y_offset: 0,
                attach: None,
                components: 1,
            });
        }
        let on_gsub: Vec<[u8; 4]> = DEFAULT_GSUB
            .iter()
            .chain(opts.features.iter())
            .copied()
            .collect();
        let on_gpos: Vec<[u8; 4]> = DEFAULT_GPOS
            .iter()
            .chain(opts.features.iter())
            .copied()
            .collect();
        if let Some(t) = self.gsub {
            let lookups =
                self.feature_lookups(Some(t), script, opts.language, &on_gsub, &opts.disabled);
            for l in lookups {
                self.gsub_apply_lookup_all(t, l, &mut buf, opts);
            }
        }
        for g in buf.iter_mut() {
            g.x_advance = self.advance(g.gid);
        }
        if let Some(t) = self.gpos {
            let lookups =
                self.feature_lookups(Some(t), script, opts.language, &on_gpos, &opts.disabled);
            for l in lookups {
                self.gpos_apply_lookup_all(t, l, &mut buf);
            }
        }
        // 標記附著：相對於底字的原點，扣掉中間走過的寬度。
        // 一個標記可能附著在另一個標記上（標記對標記），而那個標記又附著在底字上，
        // 所以由左而右算，被附著的字形一定已經算好了。
        for i in 0..buf.len() {
            if let Some((base, dx, dy)) = buf[i].attach
                && base < i
            {
                let walked: i32 = buf[base..i].iter().map(|g| g.x_advance).sum();
                buf[i].x_offset = buf[base].x_offset + dx - walked;
                buf[i].y_offset = buf[base].y_offset + dy;
            }
        }
        Some(buf)
    }

    // ---- 子表遍歷 ----

    /// 一個查詢的子表（擴充型別 7／9 已解開）。回傳 (型別, 旗標, 標記集, 子表位移們)。
    fn lookup_subtables(
        &self,
        table: usize,
        lookup: u16,
        extension_type: u16,
    ) -> Option<LookupSubtables> {
        let d: &[u8] = &self.data;
        let lo = self.lookup_offset(table, lookup)?;
        let ltype = u16_at(d, lo)?;
        let flag = u16_at(d, lo + 2)?;
        let n = u16_at(d, lo + 4)? as usize;
        let mark_set = if flag & 0x10 != 0 {
            u16_at(d, lo + 6 + 2 * n).unwrap_or(0)
        } else {
            0
        };
        let mut subs = Vec::with_capacity(n);
        for s in 0..n {
            let mut so = lo + u16_at(d, lo + 6 + 2 * s)? as usize;
            let mut ty = ltype;
            if ltype == extension_type {
                ty = u16_at(d, so + 2)?;
                so += u32_at(d, so + 4)? as usize;
            }
            subs.push((ty, so));
        }
        Some((ltype, flag, mark_set, subs))
    }

    fn next_non_skipped(
        &self,
        buf: &[Glyph],
        from: usize,
        flag: u16,
        mark_set: u16,
    ) -> Option<usize> {
        let mut q = from + 1;
        while q < buf.len() {
            if !self.skip(flag, mark_set, buf[q].gid) {
                return Some(q);
            }
            q += 1;
        }
        None
    }

    fn prev_non_skipped(
        &self,
        buf: &[Glyph],
        from: usize,
        flag: u16,
        mark_set: u16,
    ) -> Option<usize> {
        let mut q = from;
        while q > 0 {
            q -= 1;
            if !self.skip(flag, mark_set, buf[q].gid) {
                return Some(q);
            }
        }
        None
    }

    // ---- 上下文比對（GSUB 5／6、GPOS 7／8 共用） ----

    /// 比對上下文／鏈結上下文子表（格式 1、2、3）。成功回傳
    /// (輸入字形的位置們, 巢狀查詢紀錄的位移, 紀錄數)。
    #[allow(clippy::too_many_arguments)]
    fn match_context(
        &self,
        so: usize,
        chain: bool,
        buf: &[Glyph],
        pos: usize,
        flag: u16,
        ms: u16,
    ) -> Option<(Vec<usize>, usize, usize)> {
        let d: &[u8] = &self.data;
        let fmt = u16_at(d, so)?;
        let gid0 = buf.get(pos)?.gid;
        // 往後依序找 n 個輸入字形：`want(i, gid)` 決定第 i 個（從 1 開始）是否相符。
        let collect_input =
            |count: usize, want: &dyn Fn(usize, u16) -> bool| -> Option<Vec<usize>> {
                let mut matched = vec![pos];
                let mut p = pos;
                for i in 1..count {
                    p = self.next_non_skipped(buf, p, flag, ms)?;
                    if !want(i, buf[p].gid) {
                        return None;
                    }
                    matched.push(p);
                }
                Some(matched)
            };
        let check_back = |count: usize, want: &dyn Fn(usize, u16) -> bool| -> Option<()> {
            let mut b = pos;
            for i in 0..count {
                b = self.prev_non_skipped(buf, b, flag, ms)?;
                if !want(i, buf[b].gid) {
                    return None;
                }
            }
            Some(())
        };
        let check_ahead =
            |last: usize, count: usize, want: &dyn Fn(usize, u16) -> bool| -> Option<()> {
                let mut a = last;
                for i in 0..count {
                    a = self.next_non_skipped(buf, a, flag, ms)?;
                    if !want(i, buf[a].gid) {
                        return None;
                    }
                }
                Some(())
            };
        match fmt {
            1 => {
                let cov = so + u16_at(d, so + 2)? as usize;
                let ci = coverage(d, cov, gid0)? as usize;
                let set = u16_at(d, so + 6 + 2 * ci)? as usize;
                if set == 0 {
                    return None;
                }
                let set = so + set;
                let rc = u16_at(d, set)? as usize;
                for k in 0..rc {
                    let rule = set + u16_at(d, set + 2 + 2 * k)? as usize;
                    let mut o = rule;
                    let mut back: Vec<u16> = Vec::new();
                    if chain {
                        let bc = u16_at(d, o)? as usize;
                        for i in 0..bc {
                            back.push(u16_at(d, o + 2 + 2 * i)?);
                        }
                        o += 2 + 2 * bc;
                    }
                    let ic = u16_at(d, o)? as usize;
                    if ic == 0 {
                        continue;
                    }
                    let sc_at = if chain { None } else { Some(o + 2) };
                    let input_start = o + 2 + if chain { 0 } else { 2 };
                    let mut input: Vec<u16> = Vec::new();
                    for i in 0..ic - 1 {
                        input.push(u16_at(d, input_start + 2 * i)?);
                    }
                    o = input_start + 2 * (ic - 1);
                    let mut ahead: Vec<u16> = Vec::new();
                    if chain {
                        let lc = u16_at(d, o)? as usize;
                        for i in 0..lc {
                            ahead.push(u16_at(d, o + 2 + 2 * i)?);
                        }
                        o += 2 + 2 * lc;
                    }
                    let sc = match sc_at {
                        Some(at) => u16_at(d, at)? as usize,
                        None => u16_at(d, o)? as usize,
                    };
                    let recs = if chain { o + 2 } else { o };
                    let Some(matched) = collect_input(ic, &|i, g| input.get(i - 1) == Some(&g))
                    else {
                        continue;
                    };
                    if check_back(back.len(), &|i, g| back.get(i) == Some(&g)).is_none() {
                        continue;
                    }
                    let last = *matched.last()?;
                    if check_ahead(last, ahead.len(), &|i, g| ahead.get(i) == Some(&g)).is_none() {
                        continue;
                    }
                    return Some((matched, recs, sc));
                }
                None
            }
            2 => {
                let cov = so + u16_at(d, so + 2)? as usize;
                coverage(d, cov, gid0)?;
                let (back_cd, input_cd, ahead_cd, sets_at) = if chain {
                    (
                        Some(so + u16_at(d, so + 4)? as usize),
                        so + u16_at(d, so + 6)? as usize,
                        Some(so + u16_at(d, so + 8)? as usize),
                        so + 12,
                    )
                } else {
                    (None, so + u16_at(d, so + 4)? as usize, None, so + 8)
                };
                let class_of = |cd: usize, g: u16| class_def(d, cd, g).unwrap_or(0);
                let first_class = class_of(input_cd, gid0) as usize;
                let set_count = u16_at(d, sets_at - 2)? as usize;
                if first_class >= set_count {
                    return None;
                }
                let set = u16_at(d, sets_at + 2 * first_class)? as usize;
                if set == 0 {
                    return None;
                }
                let set = so + set;
                let rc = u16_at(d, set)? as usize;
                for k in 0..rc {
                    let rule = set + u16_at(d, set + 2 + 2 * k)? as usize;
                    let mut o = rule;
                    let mut back: Vec<u16> = Vec::new();
                    if chain {
                        let bc = u16_at(d, o)? as usize;
                        for i in 0..bc {
                            back.push(u16_at(d, o + 2 + 2 * i)?);
                        }
                        o += 2 + 2 * bc;
                    }
                    let ic = u16_at(d, o)? as usize;
                    if ic == 0 {
                        continue;
                    }
                    let (input_start, sc_at) = if chain {
                        (o + 2, None)
                    } else {
                        (o + 4, Some(o + 2))
                    };
                    let mut input: Vec<u16> = Vec::new();
                    for i in 0..ic - 1 {
                        input.push(u16_at(d, input_start + 2 * i)?);
                    }
                    o = input_start + 2 * (ic - 1);
                    let mut ahead: Vec<u16> = Vec::new();
                    if chain {
                        let lc = u16_at(d, o)? as usize;
                        for i in 0..lc {
                            ahead.push(u16_at(d, o + 2 + 2 * i)?);
                        }
                        o += 2 + 2 * lc;
                    }
                    let sc = match sc_at {
                        Some(at) => u16_at(d, at)? as usize,
                        None => u16_at(d, o)? as usize,
                    };
                    let recs = if chain { o + 2 } else { o };
                    let Some(matched) =
                        collect_input(ic, &|i, g| input.get(i - 1) == Some(&class_of(input_cd, g)))
                    else {
                        continue;
                    };
                    if let Some(bcd) = back_cd
                        && check_back(back.len(), &|i, g| back.get(i) == Some(&class_of(bcd, g)))
                            .is_none()
                    {
                        continue;
                    }
                    let last = *matched.last()?;
                    if let Some(acd) = ahead_cd
                        && check_ahead(last, ahead.len(), &|i, g| {
                            ahead.get(i) == Some(&class_of(acd, g))
                        })
                        .is_none()
                    {
                        continue;
                    }
                    return Some((matched, recs, sc));
                }
                None
            }
            3 => {
                let mut o = so + 2;
                let back: Vec<usize> = if chain {
                    let bc = u16_at(d, o)? as usize;
                    let v = (0..bc)
                        .map(|i| u16_at(d, o + 2 + 2 * i).map(|x| so + x as usize))
                        .collect::<Option<_>>()?;
                    o += 2 + 2 * bc;
                    v
                } else {
                    Vec::new()
                };
                let ic = u16_at(d, o)? as usize;
                if ic == 0 {
                    return None;
                }
                let (input_start, sc_at) = if chain {
                    (o + 2, None)
                } else {
                    (o + 4, Some(o + 2))
                };
                let input: Vec<usize> = (0..ic)
                    .map(|i| u16_at(d, input_start + 2 * i).map(|x| so + x as usize))
                    .collect::<Option<_>>()?;
                o = input_start + 2 * ic;
                let ahead: Vec<usize> = if chain {
                    let lc = u16_at(d, o)? as usize;
                    let v = (0..lc)
                        .map(|i| u16_at(d, o + 2 + 2 * i).map(|x| so + x as usize))
                        .collect::<Option<_>>()?;
                    o += 2 + 2 * lc;
                    v
                } else {
                    Vec::new()
                };
                let sc = match sc_at {
                    Some(at) => u16_at(d, at)? as usize,
                    None => u16_at(d, o)? as usize,
                };
                let recs = if chain { o + 2 } else { o };
                let matched = collect_input(ic, &|i, g| coverage(d, input[i], g).is_some())?;
                coverage(d, input[0], gid0)?;
                check_back(back.len(), &|i, g| coverage(d, back[i], g).is_some())?;
                let last = *matched.last()?;
                check_ahead(last, ahead.len(), &|i, g| {
                    coverage(d, ahead[i], g).is_some()
                })?;
                Some((matched, recs, sc))
            }
            _ => None,
        }
    }

    // ---- GSUB ----

    fn gsub_apply_lookup_all(
        &self,
        t: usize,
        lookup: u16,
        buf: &mut Vec<Glyph>,
        opts: &ShapeOptions,
    ) {
        // 型別 8（反向鏈結）規定從字串尾端往回套用。
        let reverse = self
            .lookup_subtables(t, lookup, 7)
            .is_some_and(|(_, _, _, subs)| subs.first().is_some_and(|s| s.0 == 8));
        if reverse {
            let mut i = buf.len();
            while i > 0 {
                i -= 1;
                if i < buf.len() {
                    self.gsub_apply_at(t, lookup, buf, i, 0, opts);
                }
            }
            return;
        }
        let mut i = 0;
        while i < buf.len() {
            match self.gsub_apply_at(t, lookup, buf, i, 0, opts) {
                Some(next) => i = next.max(i + 1),
                None => i += 1,
            }
        }
    }

    /// 在位置 `pos` 套用一個 GSUB 查詢。成功回傳「下一個要看的位置」。
    fn gsub_apply_at(
        &self,
        t: usize,
        lookup: u16,
        buf: &mut Vec<Glyph>,
        pos: usize,
        depth: u8,
        opts: &ShapeOptions,
    ) -> Option<usize> {
        if depth > 6 {
            return None;
        }
        let d: &[u8] = &self.data;
        let (_, flag, mark_set, subs) = self.lookup_subtables(t, lookup, 7)?;
        if pos >= buf.len() || self.skip(flag, mark_set, buf[pos].gid) {
            return None;
        }
        for (ltype, so) in subs {
            // 一個子表讀壞了或不相符，只放棄這個子表，接著試下一個 —— 不能讓 `?` 把整個查詢帶出去。
            let r = (|| -> Option<usize> {
                let fmt = u16_at(d, so)?;
                let gid = buf[pos].gid;
                match (ltype, fmt) {
                    (1, 1) => {
                        let cov = so + u16_at(d, so + 2)? as usize;
                        coverage(d, cov, gid).map(|_| {
                            let delta = i16_at(d, so + 4).unwrap_or(0);
                            buf[pos].gid = (gid as i32 + delta as i32) as u16;
                            pos + 1
                        })
                    }
                    (1, 2) => {
                        let cov = so + u16_at(d, so + 2)? as usize;
                        coverage(d, cov, gid).and_then(|ci| {
                            buf[pos].gid = u16_at(d, so + 6 + 2 * ci as usize)?;
                            Some(pos + 1)
                        })
                    }
                    (2, 1) => {
                        let cov = so + u16_at(d, so + 2)? as usize;
                        coverage(d, cov, gid).and_then(|ci| {
                            let seq = so + u16_at(d, so + 6 + 2 * ci as usize)? as usize;
                            let cnt = u16_at(d, seq)? as usize;
                            if cnt == 0 {
                                return None;
                            }
                            let cp = buf[pos].cp;
                            let mut new = Vec::new();
                            for k in 0..cnt {
                                new.push(Glyph {
                                    gid: u16_at(d, seq + 2 + 2 * k)?,
                                    cp,
                                    x_advance: 0,
                                    x_offset: 0,
                                    y_offset: 0,
                                    attach: None,
                                    components: 1,
                                });
                            }
                            buf.splice(pos..pos + 1, new);
                            Some(pos + cnt)
                        })
                    }
                    (3, 1) => {
                        let cov = so + u16_at(d, so + 2)? as usize;
                        coverage(d, cov, gid).and_then(|ci| {
                            let set = so + u16_at(d, so + 6 + 2 * ci as usize)? as usize;
                            let cnt = u16_at(d, set)?;
                            let pick = opts.alternate.unwrap_or(1).clamp(1, cnt.max(1));
                            if cnt == 0 {
                                return None;
                            }
                            buf[pos].gid = u16_at(d, set + 2 + 2 * (pick - 1) as usize)?;
                            Some(pos + 1)
                        })
                    }
                    (4, 1) => {
                        let cov = so + u16_at(d, so + 2)? as usize;
                        coverage(d, cov, gid).and_then(|ci| {
                            let set = so + u16_at(d, so + 6 + 2 * ci as usize)? as usize;
                            let lc = u16_at(d, set)? as usize;
                            for k in 0..lc {
                                let lig = set + u16_at(d, set + 2 + 2 * k)? as usize;
                                let out = u16_at(d, lig)?;
                                let cc = u16_at(d, lig + 2)? as usize;
                                let mut idx = vec![pos];
                                let mut p = pos;
                                let mut ok = true;
                                for c in 1..cc {
                                    let want = u16_at(d, lig + 2 + 2 * c)?;
                                    match self.next_non_skipped(buf, p, flag, mark_set) {
                                        Some(q) if buf[q].gid == want => {
                                            idx.push(q);
                                            p = q;
                                        }
                                        _ => {
                                            ok = false;
                                            break;
                                        }
                                    }
                                }
                                if ok {
                                    // 被略過的標記留在原處（排在合成字形之後）。
                                    for &q in idx.iter().skip(1).rev() {
                                        buf.remove(q);
                                    }
                                    buf[pos].gid = out;
                                    buf[pos].components = cc.min(255) as u8;
                                    return Some(pos + 1);
                                }
                            }
                            None
                        })
                    }
                    (5, 1..=3) | (6, 1..=3) => {
                        let (matched, recs, sc) =
                            self.match_context(so, ltype == 6, buf, pos, flag, mark_set)?;
                        self.gsub_nested(t, d, recs, sc, &matched, buf, depth, opts)
                    }
                    (8, 1) => {
                        // 反向鏈結單一替換：回溯與前瞻只用覆蓋表，沒有輸入序列。
                        let cov = so + u16_at(d, so + 2)? as usize;
                        let ci = coverage(d, cov, gid)?;
                        let bc = u16_at(d, so + 4)? as usize;
                        let back: Vec<usize> = (0..bc)
                            .map(|i| u16_at(d, so + 6 + 2 * i).map(|x| so + x as usize))
                            .collect::<Option<_>>()?;
                        let lo = so + 6 + 2 * bc;
                        let lc = u16_at(d, lo)? as usize;
                        let ahead: Vec<usize> = (0..lc)
                            .map(|i| u16_at(d, lo + 2 + 2 * i).map(|x| so + x as usize))
                            .collect::<Option<_>>()?;
                        let sub_at = lo + 2 + 2 * lc;
                        let mut b = pos;
                        for c in &back {
                            b = self.prev_non_skipped(buf, b, flag, mark_set)?;
                            coverage(d, *c, buf[b].gid)?;
                        }
                        let mut a = pos;
                        for c in &ahead {
                            a = self.next_non_skipped(buf, a, flag, mark_set)?;
                            coverage(d, *c, buf[a].gid)?;
                        }
                        let _count = u16_at(d, sub_at)?;
                        buf[pos].gid = u16_at(d, sub_at + 2 + 2 * ci as usize)?;
                        Some(pos + 1)
                    }
                    _ => None,
                }
            })();
            if r.is_some() {
                return r;
            }
        }
        None
    }

    #[allow(clippy::too_many_arguments)]
    fn gsub_nested(
        &self,
        t: usize,
        d: &[u8],
        recs: usize,
        count: usize,
        matched: &[usize],
        buf: &mut Vec<Glyph>,
        depth: u8,
        opts: &ShapeOptions,
    ) -> Option<usize> {
        let mut delta: isize = 0;
        for r in 0..count {
            let seq = u16_at(d, recs + 4 * r)? as usize;
            let lk = u16_at(d, recs + 4 * r + 2)?;
            let at = (*matched.get(seq)? as isize + delta).max(0) as usize;
            let before = buf.len() as isize;
            self.gsub_apply_at(t, lk, buf, at, depth + 1, opts);
            delta += buf.len() as isize - before;
        }
        let last = *matched.last()? as isize + delta;
        Some((last + 1).max(0) as usize)
    }

    // ---- GPOS ----

    fn gpos_apply_lookup_all(&self, t: usize, lookup: u16, buf: &mut [Glyph]) {
        for i in 0..buf.len() {
            self.gpos_apply_at(t, lookup, buf, i, 0);
        }
    }

    fn gpos_apply_at(
        &self,
        t: usize,
        lookup: u16,
        buf: &mut [Glyph],
        pos: usize,
        depth: u8,
    ) -> Option<()> {
        if depth > 6 {
            return None;
        }
        let d: &[u8] = &self.data;
        let (_, flag, ms, subs) = self.lookup_subtables(t, lookup, 9)?;
        if pos >= buf.len() {
            return None;
        }
        let gid = buf[pos].gid;
        for (ltype, so) in subs {
            // 標記類的查詢（4、5、6）自己決定要看哪個字形；其餘的略過規則同 GSUB。
            let marky = matches!(ltype, 4..=6);
            if !marky && self.skip(flag, ms, gid) {
                continue;
            }
            let done = (|| -> Option<()> {
                let fmt = u16_at(d, so)?;
                match (ltype, fmt) {
                    (1, 1 | 2) => self.gpos_single(so, fmt, buf, pos),
                    (2, 1 | 2) => self.gpos_pair(so, fmt, buf, pos, flag, ms),
                    (3, 1) => self.gpos_cursive(so, buf, pos, flag, ms),
                    (4, 1) => self.gpos_mark_base(so, buf, pos),
                    (5, 1) => self.gpos_mark_ligature(so, buf, pos),
                    (6, 1) => self.gpos_mark_mark(so, buf, pos, flag, ms),
                    (7 | 8, 1..=3) => {
                        let (matched, recs, sc) =
                            self.match_context(so, ltype == 8, buf, pos, flag, ms)?;
                        for r in 0..sc {
                            let seq = u16_at(d, recs + 4 * r)? as usize;
                            let lk = u16_at(d, recs + 4 * r + 2)?;
                            let at = *matched.get(seq)?;
                            self.gpos_apply_at(t, lk, buf, at, depth + 1);
                        }
                        Some(())
                    }
                    _ => None,
                }
            })();
            if done.is_some() {
                return done;
            }
        }
        None
    }

    fn read_value(&self, o: usize, fmt: u16) -> Option<[i32; 4]> {
        let d: &[u8] = &self.data;
        let mut v = [0i32; 4];
        let mut off = o;
        for bit in 0..8usize {
            if fmt & (1 << bit) != 0 {
                let x = i16_at(d, off)? as i32;
                if let Some(slot) = v.get_mut(bit) {
                    *slot = x;
                }
                off += 2;
            }
        }
        Some(v)
    }

    fn apply_value(buf: &mut [Glyph], pos: usize, v: [i32; 4]) {
        buf[pos].x_offset += v[0];
        buf[pos].y_offset += v[1];
        buf[pos].x_advance += v[2];
    }

    fn gpos_single(&self, so: usize, fmt: u16, buf: &mut [Glyph], pos: usize) -> Option<()> {
        let d: &[u8] = &self.data;
        let cov = so + u16_at(d, so + 2)? as usize;
        let ci = coverage(d, cov, buf[pos].gid)?;
        let vf = u16_at(d, so + 4)?;
        let v = if fmt == 1 {
            self.read_value(so + 6, vf)?
        } else {
            let sz = value_size(vf);
            self.read_value(so + 8 + sz * ci as usize, vf)?
        };
        Self::apply_value(buf, pos, v);
        Some(())
    }

    fn gpos_pair(
        &self,
        so: usize,
        fmt: u16,
        buf: &mut [Glyph],
        pos: usize,
        flag: u16,
        ms: u16,
    ) -> Option<()> {
        let d: &[u8] = &self.data;
        let second = self.next_non_skipped(buf, pos, flag, ms)?;
        let cov = so + u16_at(d, so + 2)? as usize;
        let ci = coverage(d, cov, buf[pos].gid)?;
        let (vf1, vf2) = (u16_at(d, so + 4)?, u16_at(d, so + 6)?);
        let (sz1, sz2) = (value_size(vf1), value_size(vf2));
        if fmt == 1 {
            let set = so + u16_at(d, so + 10 + 2 * ci as usize)? as usize;
            let pc = u16_at(d, set)? as usize;
            let rec = 2 + sz1 + sz2;
            for k in 0..pc {
                let r = set + 2 + rec * k;
                if u16_at(d, r)? == buf[second].gid {
                    let v1 = self.read_value(r + 2, vf1)?;
                    let v2 = self.read_value(r + 2 + sz1, vf2)?;
                    Self::apply_value(buf, pos, v1);
                    Self::apply_value(buf, second, v2);
                    return Some(());
                }
            }
            None
        } else {
            let cd1 = so + u16_at(d, so + 8)? as usize;
            let cd2 = so + u16_at(d, so + 10)? as usize;
            let c2n = u16_at(d, so + 14)? as usize;
            let k1 = class_def(d, cd1, buf[pos].gid)? as usize;
            let k2 = class_def(d, cd2, buf[second].gid)? as usize;
            let r = so + 16 + (sz1 + sz2) * (k1 * c2n + k2);
            let v1 = self.read_value(r, vf1)?;
            let v2 = self.read_value(r + sz1, vf2)?;
            Self::apply_value(buf, pos, v1);
            Self::apply_value(buf, second, v2);
            Some(())
        }
    }

    fn anchor(&self, o: usize) -> Option<(i32, i32)> {
        let d: &[u8] = &self.data;
        Some((i16_at(d, o + 2)? as i32, i16_at(d, o + 4)? as i32))
    }

    /// 草寫連接（GPOS 3）：前一個字形的出口錨點與這個字形的入口錨點對齊。
    fn gpos_cursive(
        &self,
        so: usize,
        buf: &mut [Glyph],
        pos: usize,
        flag: u16,
        ms: u16,
    ) -> Option<()> {
        let d: &[u8] = &self.data;
        let cov = so + u16_at(d, so + 2)? as usize;
        let ci = coverage(d, cov, buf[pos].gid)? as usize;
        let entry_off = u16_at(d, so + 6 + 4 * ci)? as usize;
        if entry_off == 0 {
            return None;
        }
        let prev = self.prev_non_skipped(buf, pos, flag, ms)?;
        let pci = coverage(d, cov, buf[prev].gid)? as usize;
        let exit_off = u16_at(d, so + 6 + 4 * pci + 2)? as usize;
        if exit_off == 0 {
            return None;
        }
        let (ex, ey) = self.anchor(so + exit_off)?;
        let (nx, ny) = self.anchor(so + entry_off)?;
        // 水平：前一個字形的寬度縮到出口錨點；這個字形從入口錨點開始。
        let prev_adv = ex + buf[prev].x_offset;
        buf[prev].x_advance = prev_adv;
        let shift = nx + buf[pos].x_offset;
        buf[pos].x_advance -= shift;
        buf[pos].x_offset -= shift;
        // 垂直：入口錨點與出口錨點等高。
        buf[pos].y_offset = buf[prev].y_offset + ey - ny;
        Some(())
    }

    fn gpos_mark_base(&self, so: usize, buf: &mut [Glyph], pos: usize) -> Option<()> {
        let d: &[u8] = &self.data;
        let mcov = so + u16_at(d, so + 2)? as usize;
        let mi = coverage(d, mcov, buf[pos].gid)?;
        // 往前找第一個不是標記的字形當底字。
        let mut b = pos;
        loop {
            if b == 0 {
                return None;
            }
            b -= 1;
            if self.glyph_class(buf[b].gid) != 3 {
                break;
            }
        }
        let bcov = so + u16_at(d, so + 4)? as usize;
        let bi = coverage(d, bcov, buf[b].gid)?;
        let classes = u16_at(d, so + 6)? as usize;
        let marks = so + u16_at(d, so + 8)? as usize;
        let bases = so + u16_at(d, so + 10)? as usize;
        let mrec = marks + 2 + 4 * mi as usize;
        let mclass = u16_at(d, mrec)? as usize;
        let manchor = marks + u16_at(d, mrec + 2)? as usize;
        let boff = u16_at(d, bases + 2 + 2 * (bi as usize * classes + mclass))?;
        if boff == 0 {
            return None;
        }
        let (bx, by) = self.anchor(bases + boff as usize)?;
        let (mx, my) = self.anchor(manchor)?;
        buf[pos].attach = Some((b, bx - mx, by - my));
        Some(())
    }

    /// 標記對合字（GPOS 5）：標記掛在合字的某一個部件上。
    ///
    /// 排版後的字形沒有保留「標記原本跟在合字的哪個部件後面」，所以掛在最後一個部件 ——
    /// 對只有一個標記的常見情形與完整資訊的結果相同。
    fn gpos_mark_ligature(&self, so: usize, buf: &mut [Glyph], pos: usize) -> Option<()> {
        let d: &[u8] = &self.data;
        let mcov = so + u16_at(d, so + 2)? as usize;
        let mi = coverage(d, mcov, buf[pos].gid)?;
        let mut b = pos;
        loop {
            if b == 0 {
                return None;
            }
            b -= 1;
            if self.glyph_class(buf[b].gid) != 3 {
                break;
            }
        }
        let lcov = so + u16_at(d, so + 4)? as usize;
        let li = coverage(d, lcov, buf[b].gid)?;
        let classes = u16_at(d, so + 6)? as usize;
        let marks = so + u16_at(d, so + 8)? as usize;
        let ligs = so + u16_at(d, so + 10)? as usize;
        let lig_attach = ligs + u16_at(d, ligs + 2 + 2 * li as usize)? as usize;
        let comps = u16_at(d, lig_attach)? as usize;
        if comps == 0 {
            return None;
        }
        let comp = comps.min(buf[b].components.max(1) as usize) - 1;
        let mrec = marks + 2 + 4 * mi as usize;
        let mclass = u16_at(d, mrec)? as usize;
        let manchor = marks + u16_at(d, mrec + 2)? as usize;
        let boff = u16_at(d, lig_attach + 2 + 2 * (comp * classes + mclass))?;
        if boff == 0 {
            return None;
        }
        let (bx, by) = self.anchor(lig_attach + boff as usize)?;
        let (mx, my) = self.anchor(manchor)?;
        buf[pos].attach = Some((b, bx - mx, by - my));
        Some(())
    }

    fn gpos_mark_mark(
        &self,
        so: usize,
        buf: &mut [Glyph],
        pos: usize,
        flag: u16,
        ms: u16,
    ) -> Option<()> {
        let d: &[u8] = &self.data;
        let m1cov = so + u16_at(d, so + 2)? as usize;
        let mi = coverage(d, m1cov, buf[pos].gid)?;
        // 前一個（沒被略過的）字形必須也是標記。
        let prev = self.prev_non_skipped(buf, pos, flag, ms)?;
        if self.glyph_class(buf[prev].gid) != 3 {
            return None;
        }
        let m2cov = so + u16_at(d, so + 4)? as usize;
        let pi = coverage(d, m2cov, buf[prev].gid)?;
        let classes = u16_at(d, so + 6)? as usize;
        let marks1 = so + u16_at(d, so + 8)? as usize;
        let marks2 = so + u16_at(d, so + 10)? as usize;
        let mrec = marks1 + 2 + 4 * mi as usize;
        let mclass = u16_at(d, mrec)? as usize;
        let manchor = marks1 + u16_at(d, mrec + 2)? as usize;
        let boff = u16_at(d, marks2 + 2 + 2 * (pi as usize * classes + mclass))?;
        if boff == 0 {
            return None;
        }
        let (bx, by) = self.anchor(marks2 + boff as usize)?;
        let (mx, my) = self.anchor(manchor)?;
        // 附著對象是前一個標記；它自己可能又附著在底字上，最後統一換算時會疊加。
        buf[pos].attach = Some((prev, bx - mx, by - my));
        Some(())
    }
}

fn value_size(fmt: u16) -> usize {
    2 * (fmt & 0xFF).count_ones() as usize
}

/// 覆蓋表：回傳字形在表裡的索引。
fn coverage(d: &[u8], o: usize, gid: u16) -> Option<u16> {
    let fmt = u16_at(d, o)?;
    let n = u16_at(d, o + 2)? as usize;
    match fmt {
        1 => {
            let (mut lo, mut hi) = (0usize, n);
            while lo < hi {
                let mid = (lo + hi) / 2;
                let v = u16_at(d, o + 4 + 2 * mid)?;
                if v == gid {
                    return Some(mid as u16);
                } else if v < gid {
                    lo = mid + 1;
                } else {
                    hi = mid;
                }
            }
            None
        }
        2 => {
            for i in 0..n {
                let r = o + 4 + 6 * i;
                let (s, e, si) = (u16_at(d, r)?, u16_at(d, r + 2)?, u16_at(d, r + 4)?);
                if gid >= s && gid <= e {
                    return Some(si + (gid - s));
                }
            }
            None
        }
        _ => None,
    }
}

fn class_def(d: &[u8], o: usize, gid: u16) -> Option<u16> {
    let fmt = u16_at(d, o)?;
    match fmt {
        1 => {
            let start = u16_at(d, o + 2)?;
            let n = u16_at(d, o + 4)?;
            if gid >= start && gid < start.saturating_add(n) {
                u16_at(d, o + 6 + 2 * (gid - start) as usize)
            } else {
                Some(0)
            }
        }
        2 => {
            let n = u16_at(d, o + 2)? as usize;
            for i in 0..n {
                let r = o + 4 + 6 * i;
                let (s, e, c) = (u16_at(d, r)?, u16_at(d, r + 2)?, u16_at(d, r + 4)?);
                if gid >= s && gid <= e {
                    return Some(c);
                }
            }
            Some(0)
        }
        _ => Some(0),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    static TTF: &[u8] =
        include_bytes!("../../../third_party/notosansthai/NotoSansThai-Regular.ttf");

    fn font() -> Font {
        Font::parse(TTF).expect("font parses")
    }

    #[test]
    fn the_font_parses_and_maps_thai() {
        let f = font();
        assert_eq!(f.units_per_em, 1000);
        assert!(!f.is_cff);
        assert!(f.glyph_for('ก').is_some());
        assert!(f.glyph_for('\u{0E48}').is_some());
        assert_eq!(Font::detect_script("การประชุม"), *b"thai");
        assert_eq!(Font::detect_script("123 abc"), *b"latn");
    }

    #[test]
    fn sara_am_is_decomposed_by_the_font() {
        // 「น้ำ」= น ้ ำ；ำ（U+0E33）要拆成 ํ（U+0E4D）＋ า（U+0E32），而且 ํ 排在聲調符號之前：น ํ ้ า。
        let f = font();
        let g = f.shape("น้ำ").unwrap();
        assert_eq!(g.len(), 4, "{g:?}");
        let nikhahit = f.glyph_for('\u{0E4D}').unwrap();
        assert_eq!(g[1].gid, nikhahit, "ํ 要排在聲調符號前面：{g:?}");
    }

    #[test]
    fn a_tone_mark_sits_on_top_of_its_consonant() {
        let g = font().shape("ก่").unwrap();
        assert_eq!(g.len(), 2);
        assert!(g[1].x_advance == 0 || g[1].x_advance < 50, "{g:?}");
        assert!(g[1].x_offset < 0, "標記要往回壓到子音上：{g:?}");
    }

    #[test]
    fn a_tone_mark_over_an_upper_vowel_uses_the_fonts_stacked_form() {
        // 「ที่」= ท ี ่：聲調符號疊在上母音之上時，字型用 GSUB 換成另一個（較低、較窄的）字形，
        // 而不是同一個字形單純抬高。這條需要三件事都對：GDEF 標記過濾集的位置（GDEF 1.2 位移 12）、
        // 鏈結上下文格式 3、以及「一個子表不相符要試下一個子表」—— 最後一件曾經因為 `?` 把整個查詢帶出去而漏掉。
        let f = font();
        let alone = f.shape("ท่").unwrap();
        let stacked = f.shape("ที่").unwrap();
        assert_eq!(stacked.len(), 3);
        assert_ne!(
            stacked[2].gid, alone[1].gid,
            "疊在上母音上的聲調符號要換成字型的堆疊形：{stacked:?} vs {alone:?}"
        );
    }

    #[test]
    fn shaping_never_panics_on_odd_input() {
        let f = font();
        for s in [
            "",
            "\u{0E48}",
            "\u{0E48}\u{0E48}\u{0E48}",
            "เเเเ",
            "ำำ",
            "ก\u{0E31}\u{0E48}\u{0E49}",
        ] {
            let _ = f.shape(s);
        }
    }

    #[test]
    fn thai_marks_are_sorted_by_combining_class() {
        // 聲調符號（107）在前、下母音（103）在後的錯誤輸入順序，要排成下母音在前。
        let f = font();
        let g = f.shape("ก\u{0E48}\u{0E38}").unwrap();
        let sara_u = f.glyph_for('\u{0E38}').unwrap();
        assert_eq!(g[1].gid, sara_u, "下母音要排在聲調符號之前：{g:?}");
    }

    #[test]
    fn features_can_be_turned_off_and_a_script_can_be_forced() {
        let f = font();
        let with = f.shape("ก่").unwrap();
        let without = f
            .shape_with(
                "ก่",
                &ShapeOptions {
                    disabled: vec![*b"mark", *b"mkmk", *b"ccmp", *b"locl"],
                    ..ShapeOptions::default()
                },
            )
            .unwrap();
        assert!(
            with.iter().any(|g| g.x_offset != 0)
                && without.iter().all(|g| g.y_offset == 0 && g.x_offset == 0),
            "關掉 mark 就不會把聲調符號移到子音上方：{with:?} / {without:?}"
        );
        let forced = f
            .shape_with(
                "ก่",
                &ShapeOptions {
                    script: Some(*b"thai"),
                    language: Some(*b"THA "),
                    ..ShapeOptions::default()
                },
            )
            .unwrap();
        assert_eq!(forced.len(), 2);
    }

    #[test]
    fn a_ttc_header_and_bad_containers_are_handled() {
        // 假的 TTC：指到第 0 個字型 = 這份 TTF 的前面接一個 12+4 位元組的表頭，位移要加上去。
        let mut ttc = Vec::new();
        ttc.extend_from_slice(b"ttcf");
        ttc.extend_from_slice(&[0, 1, 0, 0]);
        ttc.extend_from_slice(&1u32.to_be_bytes());
        ttc.extend_from_slice(&16u32.to_be_bytes());
        // 表目錄裡的位移是相對整個檔案的，所以要把每個表的位移加 16。
        let mut ttf = TTF.to_vec();
        let n = u16::from_be_bytes([ttf[4], ttf[5]]) as usize;
        for i in 0..n {
            let r = 12 + 16 * i + 8;
            let off = u32::from_be_bytes([ttf[r], ttf[r + 1], ttf[r + 2], ttf[r + 3]]) + 16;
            ttf[r..r + 4].copy_from_slice(&off.to_be_bytes());
        }
        ttc.extend_from_slice(&ttf);
        let f = Font::parse_index(Cow::Owned(ttc.clone()), 0).expect("ttc font 0");
        assert!(f.glyph_for('ก').is_some());
        assert!(
            Font::parse_index(Cow::Owned(ttc), 1).is_none(),
            "沒有第 1 個字型"
        );
        assert!(Font::parse_index(Cow::Owned(vec![1, 2, 3, 4, 5]), 0).is_none());
        assert!(Font::parse_index(Cow::Owned(Vec::new()), 0).is_none());
    }

    #[test]
    fn truncated_fonts_never_panic() {
        // 把字型從各個位置截斷：每一種都只能回 None 或排出結果，不能 panic。
        for cut in (0..TTF.len()).step_by(997) {
            let owned = TTF[..cut].to_vec();
            if let Some(f) = Font::parse_index(Cow::Owned(owned), 0) {
                let _ = f.shape("ที่การ");
            }
        }
    }
}
