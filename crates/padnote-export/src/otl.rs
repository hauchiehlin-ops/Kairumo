//! 最小的 OpenType 排版引擎，只為了在 PDF 裡畫泰文。
//!
//! 泰文不能「一個字碼配一個字形」：聲調符號要疊在子音或上母音的**上面**，ำ 要拆成兩個字形，
//! ฐ／ญ 遇到下母音要換成沒有下腳的樣子。這些全部寫在字型自己的 GSUB（字形替換）與 GPOS（字形定位）表裡，
//! 所以只要照表執行就能得到正確的結果，不需要在程式裡寫死泰文的規則。
//!
//! 只實作 Noto Sans Thai 用到的那幾種子表（GSUB 1/2/4/5/6/7、GPOS 1/2/4/6/8/9，加上 GDEF 的字形類別與
//! 標記過濾集），其他格式遇到就略過那個子表 —— 寧可少一個調整，也不要在列印時當掉。
//!
//! 全部是唯讀的位元組讀取，任何越界都回傳 `None`，不會 panic。

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
}

#[derive(Debug)]
pub struct Font {
    data: &'static [u8],
    pub units_per_em: u16,
    pub num_glyphs: u16,
    /// head 表的 xMin, yMin, xMax, yMax（字型單位）。
    pub bbox: [i16; 4],
    advances: Vec<u16>,
    cmap: HashMap<u32, u16>,
    gsub: Option<usize>,
    gpos: Option<usize>,
    gdef: Option<usize>,
    /// 泰文用得到的 GSUB／GPOS 查詢索引（依索引排序）。
    gsub_lookups: Vec<u16>,
    gpos_lookups: Vec<u16>,
}

impl Font {
    pub fn parse(data: &'static [u8]) -> Option<Font> {
        let n = u16_at(data, 4)? as usize;
        let mut tables: HashMap<[u8; 4], usize> = HashMap::new();
        for i in 0..n {
            let r = 12 + 16 * i;
            let tag = [
                *data.get(r)?,
                *data.get(r + 1)?,
                *data.get(r + 2)?,
                *data.get(r + 3)?,
            ];
            tables.insert(tag, u32_at(data, r + 8)? as usize);
        }
        let head = *tables.get(b"head")?;
        let units_per_em = u16_at(data, head + 18)?;
        let hhea = *tables.get(b"hhea")?;
        let n_h = u16_at(data, hhea + 34)? as usize;
        let num_glyphs = u16_at(data, *tables.get(b"maxp")? + 4)?;
        let hmtx = *tables.get(b"hmtx")?;
        let mut advances = Vec::with_capacity(num_glyphs as usize);
        for g in 0..num_glyphs as usize {
            let idx = g.min(n_h.saturating_sub(1));
            advances.push(u16_at(data, hmtx + 4 * idx)?);
        }
        let cmap = Self::read_cmap(data, *tables.get(b"cmap")?)?;
        let mut font = Font {
            data,
            units_per_em,
            num_glyphs,
            bbox: [
                i16_at(data, head + 36)?,
                i16_at(data, head + 38)?,
                i16_at(data, head + 40)?,
                i16_at(data, head + 42)?,
            ],
            advances,
            cmap,
            gsub: tables.get(b"GSUB").copied(),
            gpos: tables.get(b"GPOS").copied(),
            gdef: tables.get(b"GDEF").copied(),
            gsub_lookups: Vec::new(),
            gpos_lookups: Vec::new(),
        };
        font.gsub_lookups =
            font.script_lookups(font.gsub, &[*b"ccmp", *b"liga", *b"rlig", *b"calt"]);
        font.gpos_lookups =
            font.script_lookups(font.gpos, &[*b"dist", *b"kern", *b"mark", *b"mkmk"]);
        Some(font)
    }

    fn read_cmap(d: &[u8], cmap: usize) -> Option<HashMap<u32, u16>> {
        let n = u16_at(d, cmap + 2)? as usize;
        let mut best: Option<(usize, u16)> = None;
        for i in 0..n {
            let pid = u16_at(d, cmap + 4 + 8 * i)?;
            let eid = u16_at(d, cmap + 6 + 8 * i)?;
            let off = cmap + u32_at(d, cmap + 8 + 8 * i)? as usize;
            let fmt = u16_at(d, off)?;
            let unicode = (pid == 0) || (pid == 3 && (eid == 1 || eid == 10));
            if unicode && (best.is_none() || fmt == 12) {
                best = Some((off, fmt));
            }
        }
        let (off, fmt) = best?;
        let mut map = HashMap::new();
        match fmt {
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
                    if st == 0xFFFF {
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
            12 => {
                let groups = u32_at(d, off + 12)? as usize;
                for g in 0..groups {
                    let b = off + 16 + 12 * g;
                    let (s, e, gid) = (u32_at(d, b)?, u32_at(d, b + 4)?, u32_at(d, b + 8)?);
                    for c in s..=e.min(s + 0xFFFF) {
                        map.insert(c, (gid + (c - s)) as u16);
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

    // ---- 表格導覽 ----

    /// 取 `thai`（沒有就 `DFLT`）文字系統的預設語言系統裡、指定特徵的所有查詢索引，由小到大排序。
    fn script_lookups(&self, table: Option<usize>, wanted: &[[u8; 4]]) -> Vec<u16> {
        let d = self.data;
        let Some(t) = table else { return Vec::new() };
        let go = || -> Option<Vec<u16>> {
            let sl = t + u16_at(d, t + 4)? as usize;
            let fl = t + u16_at(d, t + 6)? as usize;
            let n = u16_at(d, sl)? as usize;
            let mut chosen: Option<usize> = None;
            for pass in [*b"thai", *b"DFLT"] {
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
            let script = chosen?;
            let def = u16_at(d, script)? as usize;
            if def == 0 {
                return Some(Vec::new());
            }
            let ls = script + def;
            let fc = u16_at(d, ls + 4)? as usize;
            let mut out = Vec::new();
            for k in 0..fc {
                let fi = u16_at(d, ls + 6 + 2 * k)? as usize;
                let tag = [
                    *d.get(fl + 2 + 6 * fi)?,
                    *d.get(fl + 3 + 6 * fi)?,
                    *d.get(fl + 4 + 6 * fi)?,
                    *d.get(fl + 5 + 6 * fi)?,
                ];
                if !wanted.contains(&tag) {
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
        let d = self.data;
        let ll = table + u16_at(d, table + 8)? as usize;
        let n = u16_at(d, ll)?;
        if idx >= n {
            return None;
        }
        Some(ll + u16_at(d, ll + 2 + 2 * idx as usize)? as usize)
    }

    // ---- GDEF ----

    fn glyph_class(&self, gid: u16) -> u16 {
        let Some(g) = self.gdef else { return 0 };
        let d = self.data;
        let go = || -> Option<u16> {
            let off = u16_at(d, g + 4)? as usize;
            if off == 0 {
                return Some(0);
            }
            class_def(d, g + off, gid)
        };
        go().unwrap_or(0)
    }

    fn in_mark_set(&self, set: u16, gid: u16) -> bool {
        let Some(g) = self.gdef else { return false };
        let d = self.data;
        let go = || -> Option<bool> {
            let ms = u16_at(d, g + 10)? as usize;
            if ms == 0 {
                return Some(false);
            }
            let ms = g + ms;
            let n = u16_at(d, ms + 2)?;
            if set >= n {
                return Some(false);
            }
            let cov = ms + u32_at(d, ms + 4 + 4 * set as usize)? as usize;
            Some(coverage(d, cov, gid).is_some())
        };
        go().unwrap_or(false)
    }

    /// 這個查詢要不要略過這個字形（LookupFlag 的 ignoreMarks / useMarkFilteringSet）。
    fn skip(&self, flag: u16, mark_set: u16, gid: u16) -> bool {
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
            if flag & 0x10 != 0 {
                return !self.in_mark_set(mark_set, gid);
            }
        }
        false
    }

    // ---- 對外：排版 ----

    /// 把一段泰文（或任何字型有的字碼）排成字形。找不到字形的字碼回傳 `None`，由呼叫端決定怎麼辦。
    pub fn shape(&self, text: &str) -> Option<Vec<Glyph>> {
        let mut buf: Vec<Glyph> = Vec::new();
        for c in text.chars() {
            let gid = self.glyph_for(c)?;
            buf.push(Glyph {
                gid,
                cp: c,
                x_advance: self.advance(gid),
                x_offset: 0,
                y_offset: 0,
                attach: None,
            });
        }
        if let Some(t) = self.gsub {
            for &l in &self.gsub_lookups.clone() {
                self.gsub_apply_lookup_all(t, l, &mut buf);
            }
        }
        for g in buf.iter_mut() {
            g.x_advance = self.advance(g.gid);
        }
        if let Some(t) = self.gpos {
            for &l in &self.gpos_lookups.clone() {
                self.gpos_apply_lookup_all(t, l, &mut buf);
            }
        }
        // 標記附著：相對於底字的原點，扣掉中間走過的寬度。
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

    // ---- GSUB ----

    fn gsub_apply_lookup_all(&self, t: usize, lookup: u16, buf: &mut Vec<Glyph>) {
        let mut i = 0;
        while i < buf.len() {
            match self.gsub_apply_at(t, lookup, buf, i, 0) {
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
    ) -> Option<usize> {
        if depth > 4 {
            return None;
        }
        let d = self.data;
        let lo = self.lookup_offset(t, lookup)?;
        let mut ltype = u16_at(d, lo)?;
        let flag = u16_at(d, lo + 2)?;
        let n = u16_at(d, lo + 4)? as usize;
        let mark_set = if flag & 0x10 != 0 {
            u16_at(d, lo + 6 + 2 * n).unwrap_or(0)
        } else {
            0
        };
        if pos >= buf.len() || self.skip(flag, mark_set, buf[pos].gid) {
            return None;
        }
        for s in 0..n {
            let mut so = lo + u16_at(d, lo + 6 + 2 * s)? as usize;
            if ltype == 7 {
                ltype = u16_at(d, so + 2)?;
                so += u32_at(d, so + 4)? as usize;
            }
            let fmt = u16_at(d, so)?;
            let gid = buf[pos].gid;
            let r = match (ltype, fmt) {
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
                        let sub = u16_at(d, so + 6 + 2 * ci as usize)?;
                        buf[pos].gid = sub;
                        Some(pos + 1)
                    })
                }
                (2, 1) => {
                    let cov = so + u16_at(d, so + 2)? as usize;
                    let ci = coverage(d, cov, gid);
                    ci.and_then(|ci| {
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
                            });
                        }
                        buf.splice(pos..pos + 1, new);
                        Some(pos + cnt)
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
                                return Some(pos + 1);
                            }
                        }
                        None
                    })
                }
                (5, 1) => self.gsub_context1(t, so, buf, pos, flag, mark_set, depth),
                (6, 3) => self.gsub_chain3(t, so, buf, pos, flag, mark_set, depth),
                _ => None,
            };
            if r.is_some() {
                return r;
            }
        }
        None
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

    #[allow(clippy::too_many_arguments)]
    fn gsub_context1(
        &self,
        t: usize,
        so: usize,
        buf: &mut Vec<Glyph>,
        pos: usize,
        flag: u16,
        ms: u16,
        depth: u8,
    ) -> Option<usize> {
        let d = self.data;
        let cov = so + u16_at(d, so + 2)? as usize;
        let ci = coverage(d, cov, buf[pos].gid)?;
        let set = u16_at(d, so + 6 + 2 * ci as usize)? as usize;
        if set == 0 {
            return None;
        }
        let set = so + set;
        let rc = u16_at(d, set)? as usize;
        for k in 0..rc {
            let rule = set + u16_at(d, set + 2 + 2 * k)? as usize;
            let gc = u16_at(d, rule)? as usize;
            let sc = u16_at(d, rule + 2)? as usize;
            let mut matched = vec![pos];
            let mut p = pos;
            let mut ok = true;
            for j in 1..gc {
                let want = u16_at(d, rule + 2 + 2 * j)?;
                match self.next_non_skipped(buf, p, flag, ms) {
                    Some(q) if buf[q].gid == want => {
                        matched.push(q);
                        p = q;
                    }
                    _ => {
                        ok = false;
                        break;
                    }
                }
            }
            if !ok {
                continue;
            }
            let recs = rule + 4 + 2 * (gc - 1);
            let end = self.gsub_nested(t, d, recs, sc, &matched, buf, depth)?;
            return Some(end);
        }
        None
    }

    #[allow(clippy::too_many_arguments)]
    fn gsub_chain3(
        &self,
        t: usize,
        so: usize,
        buf: &mut Vec<Glyph>,
        pos: usize,
        flag: u16,
        ms: u16,
        depth: u8,
    ) -> Option<usize> {
        let d = self.data;
        let mut o = so + 2;
        let bc = u16_at(d, o)? as usize;
        let back: Vec<usize> = (0..bc)
            .map(|i| u16_at(d, o + 2 + 2 * i).map(|v| so + v as usize))
            .collect::<Option<_>>()?;
        o += 2 + 2 * bc;
        let ic = u16_at(d, o)? as usize;
        let input: Vec<usize> = (0..ic)
            .map(|i| u16_at(d, o + 2 + 2 * i).map(|v| so + v as usize))
            .collect::<Option<_>>()?;
        o += 2 + 2 * ic;
        let lc = u16_at(d, o)? as usize;
        let look: Vec<usize> = (0..lc)
            .map(|i| u16_at(d, o + 2 + 2 * i).map(|v| so + v as usize))
            .collect::<Option<_>>()?;
        o += 2 + 2 * lc;
        let sc = u16_at(d, o)? as usize;
        if ic == 0 {
            return None;
        }
        let mut matched = Vec::new();
        let mut p = pos;
        for (j, cov) in input.iter().enumerate() {
            if j > 0 {
                p = self.next_non_skipped(buf, p, flag, ms)?;
            }
            coverage(d, *cov, buf[p].gid)?;
            matched.push(p);
        }
        let mut b = pos;
        for cov in &back {
            b = self.prev_non_skipped(buf, b, flag, ms)?;
            coverage(d, *cov, buf[b].gid)?;
        }
        let mut a = *matched.last()?;
        for cov in &look {
            a = self.next_non_skipped(buf, a, flag, ms)?;
            coverage(d, *cov, buf[a].gid)?;
        }
        self.gsub_nested(t, d, o + 2, sc, &matched, buf, depth)
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
    ) -> Option<usize> {
        let mut delta: isize = 0;
        for r in 0..count {
            let seq = u16_at(d, recs + 4 * r)? as usize;
            let lk = u16_at(d, recs + 4 * r + 2)?;
            let at = (*matched.get(seq)? as isize + delta).max(0) as usize;
            let before = buf.len() as isize;
            self.gsub_apply_at(t, lk, buf, at, depth + 1);
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
        if depth > 4 {
            return None;
        }
        let d = self.data;
        let lo = self.lookup_offset(t, lookup)?;
        let mut ltype = u16_at(d, lo)?;
        let flag = u16_at(d, lo + 2)?;
        let n = u16_at(d, lo + 4)? as usize;
        let ms = if flag & 0x10 != 0 {
            u16_at(d, lo + 6 + 2 * n).unwrap_or(0)
        } else {
            0
        };
        if pos >= buf.len() {
            return None;
        }
        // 標記類的查詢（4、6）自己決定要看哪個字形；其餘的略過規則同 GSUB。
        let gid = buf[pos].gid;
        for s in 0..n {
            let mut so = lo + u16_at(d, lo + 6 + 2 * s)? as usize;
            if ltype == 9 {
                ltype = u16_at(d, so + 2)?;
                so += u32_at(d, so + 4)? as usize;
            }
            let fmt = u16_at(d, so)?;
            let done = match (ltype, fmt) {
                (1, _) => {
                    if self.skip(flag, ms, gid) {
                        None
                    } else {
                        self.gpos_single(so, fmt, buf, pos)
                    }
                }
                (2, _) => {
                    if self.skip(flag, ms, gid) {
                        None
                    } else {
                        self.gpos_pair(so, fmt, buf, pos, flag, ms)
                    }
                }
                (4, 1) => self.gpos_mark_base(so, buf, pos, flag, ms),
                (6, 1) => self.gpos_mark_mark(so, buf, pos, flag, ms),
                (8, 3) => {
                    if self.skip(flag, ms, gid) {
                        None
                    } else {
                        self.gpos_chain3(t, so, buf, pos, flag, ms, depth)
                    }
                }
                _ => None,
            };
            if done.is_some() {
                return done;
            }
        }
        None
    }

    fn read_value(&self, o: usize, fmt: u16) -> Option<([i32; 4], usize)> {
        let d = self.data;
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
        Some((v, off - o))
    }

    fn apply_value(buf: &mut [Glyph], pos: usize, v: [i32; 4]) {
        buf[pos].x_offset += v[0];
        buf[pos].y_offset += v[1];
        buf[pos].x_advance += v[2];
    }

    fn gpos_single(&self, so: usize, fmt: u16, buf: &mut [Glyph], pos: usize) -> Option<()> {
        let d = self.data;
        let cov = so + u16_at(d, so + 2)? as usize;
        let ci = coverage(d, cov, buf[pos].gid)?;
        let vf = u16_at(d, so + 4)?;
        let v = if fmt == 1 {
            self.read_value(so + 6, vf)?.0
        } else {
            let (_, sz) = self.read_value(so + 8, vf)?;
            self.read_value(so + 8 + sz * ci as usize, vf)?.0
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
        let d = self.data;
        let second = self.next_non_skipped(buf, pos, flag, ms)?;
        let cov = so + u16_at(d, so + 2)? as usize;
        let ci = coverage(d, cov, buf[pos].gid)?;
        let (vf1, vf2) = (u16_at(d, so + 4)?, u16_at(d, so + 6)?);
        let sz1 = value_size(vf1);
        let sz2 = value_size(vf2);
        if fmt == 1 {
            let set = so + u16_at(d, so + 10 + 2 * ci as usize)? as usize;
            let pc = u16_at(d, set)? as usize;
            let rec = 2 + sz1 + sz2;
            for k in 0..pc {
                let r = set + 2 + rec * k;
                if u16_at(d, r)? == buf[second].gid {
                    let v1 = self.read_value(r + 2, vf1)?.0;
                    let v2 = self.read_value(r + 2 + sz1, vf2)?.0;
                    Self::apply_value(buf, pos, v1);
                    Self::apply_value(buf, second, v2);
                    return Some(());
                }
            }
            None
        } else {
            let cd1 = so + u16_at(d, so + 8)? as usize;
            let cd2 = so + u16_at(d, so + 10)? as usize;
            let c1n = u16_at(d, so + 12)? as usize;
            let c2n = u16_at(d, so + 14)? as usize;
            let _ = c1n;
            let k1 = class_def(d, cd1, buf[pos].gid)? as usize;
            let k2 = class_def(d, cd2, buf[second].gid)? as usize;
            let rec = sz1 + sz2;
            let r = so + 16 + rec * (k1 * c2n + k2);
            let v1 = self.read_value(r, vf1)?.0;
            let v2 = self.read_value(r + sz1, vf2)?.0;
            Self::apply_value(buf, pos, v1);
            Self::apply_value(buf, second, v2);
            Some(())
        }
    }

    fn anchor(&self, o: usize) -> Option<(i32, i32)> {
        let d = self.data;
        Some((i16_at(d, o + 2)? as i32, i16_at(d, o + 4)? as i32))
    }

    fn gpos_mark_base(
        &self,
        so: usize,
        buf: &mut [Glyph],
        pos: usize,
        _flag: u16,
        _ms: u16,
    ) -> Option<()> {
        let d = self.data;
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

    fn gpos_mark_mark(
        &self,
        so: usize,
        buf: &mut [Glyph],
        pos: usize,
        flag: u16,
        ms: u16,
    ) -> Option<()> {
        let d = self.data;
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

    #[allow(clippy::too_many_arguments)]
    fn gpos_chain3(
        &self,
        t: usize,
        so: usize,
        buf: &mut [Glyph],
        pos: usize,
        flag: u16,
        ms: u16,
        depth: u8,
    ) -> Option<()> {
        let d = self.data;
        let mut o = so + 2;
        let bc = u16_at(d, o)? as usize;
        let back: Vec<usize> = (0..bc)
            .map(|i| u16_at(d, o + 2 + 2 * i).map(|v| so + v as usize))
            .collect::<Option<_>>()?;
        o += 2 + 2 * bc;
        let ic = u16_at(d, o)? as usize;
        let input: Vec<usize> = (0..ic)
            .map(|i| u16_at(d, o + 2 + 2 * i).map(|v| so + v as usize))
            .collect::<Option<_>>()?;
        o += 2 + 2 * ic;
        let lc = u16_at(d, o)? as usize;
        let look: Vec<usize> = (0..lc)
            .map(|i| u16_at(d, o + 2 + 2 * i).map(|v| so + v as usize))
            .collect::<Option<_>>()?;
        o += 2 + 2 * lc;
        let sc = u16_at(d, o)? as usize;
        let mut matched = Vec::new();
        let mut p = pos;
        for (j, cov) in input.iter().enumerate() {
            if j > 0 {
                p = self.next_non_skipped(buf, p, flag, ms)?;
            }
            coverage(d, *cov, buf[p].gid)?;
            matched.push(p);
        }
        let mut b = pos;
        for cov in &back {
            b = self.prev_non_skipped(buf, b, flag, ms)?;
            coverage(d, *cov, buf[b].gid)?;
        }
        let mut a = *matched.last()?;
        for cov in &look {
            a = self.next_non_skipped(buf, a, flag, ms)?;
            coverage(d, *cov, buf[a].gid)?;
        }
        for r in 0..sc {
            let seq = u16_at(d, o + 2 + 4 * r)? as usize;
            let lk = u16_at(d, o + 2 + 4 * r + 2)?;
            let at = *matched.get(seq)?;
            self.gpos_apply_at(t, lk, buf, at, depth + 1);
        }
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
            if gid >= start && gid < start + n {
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
        assert!(f.glyph_for('ก').is_some());
        assert!(f.glyph_for('\u{0E48}').is_some());
        assert!(!f.gsub_lookups.is_empty() && !f.gpos_lookups.is_empty());
    }

    #[test]
    fn sara_am_is_decomposed_by_the_font() {
        // 「น้ำ」= น ้ ำ；ำ（U+0E33）要拆成 ํ（U+0E4D）＋ า（U+0E32）。
        let g = font().shape("น้ำ").unwrap();
        assert_eq!(g.len(), 4, "{g:?}");
    }

    #[test]
    fn a_tone_mark_sits_on_top_of_its_consonant() {
        let f = font();
        let g = f.shape("ก่").unwrap();
        assert_eq!(g.len(), 2);
        // 聲調符號：寬度 0，並且被抬到基準線之上（y_offset 或字形本身的位置由 GPOS 給），水平上與子音重疊。
        assert!(g[1].x_advance == 0 || g[1].x_advance < 50, "{g:?}");
        assert!(g[1].x_offset < 0, "標記要往回壓到子音上：{g:?}");
    }

    #[test]
    fn a_tone_mark_over_an_upper_vowel_is_lifted_higher() {
        let f = font();
        let plain = f.shape("ก่").unwrap();
        let stacked = f.shape("กี่").unwrap();
        assert_eq!(stacked.len(), 3);
        let tone_plain = plain[1].y_offset; // 只有 GPOS 的偏移
        let tone_stacked = stacked[2].y_offset;
        // 疊在上母音之上時，GPOS（mark-to-mark）或 GSUB 的低位變體會讓它高於單獨在子音上的位置，或換了字形。
        assert!(
            tone_stacked != tone_plain || stacked[2].gid != plain[1].gid,
            "{plain:?} vs {stacked:?}"
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
}
