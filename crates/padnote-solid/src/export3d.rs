//! 立體匯出：STL、OBJ、GLB、USDZ。
//!
//! 立體是「輪廓拉伸」的柱體：前後兩個蓋面（可能有洞）加上沿輪廓的側壁。蓋面要先三角化
//! （洞用橋接線併進外環，再耳切），側壁每一段是一個四邊形（兩個三角形）。
//!
//! # 座標與單位
//!
//! 與立體本身相同：x 向右、y 向上、z 朝向正視圖的觀看者（前面 z = 0，往 −z 拉伸）。
//! 這是右手系、y 向上 —— glTF 與 USD（`upAxis = "Y"`）都直接吃，不必轉軸。
//! `unit_scale` 把模型單位換成目標檔案的單位：STL／OBJ 用毫米，GLB／USDZ 用公尺（呼叫端傳 0.001 × 毫米換算）。
//!
//! 每個面用自己的法向量（平面著色），所以頂點在稜線上是重複的 —— 稜線要看得出來，不能被平滑掉。

use crate::geom::P2;
use crate::solid::Solid;

pub type V3 = [f32; 3];

/// 三角網格：頂點、每個頂點的法向量、三角形索引。
#[derive(Clone, Debug, Default)]
pub struct TriMesh {
    pub positions: Vec<V3>,
    pub normals: Vec<V3>,
    pub triangles: Vec<[u32; 3]>,
}

impl TriMesh {
    fn push_tri(&mut self, pts: [V3; 3], n: V3) {
        let base = self.positions.len() as u32;
        for p in pts {
            self.positions.push(p);
            self.normals.push(n);
        }
        self.triangles.push([base, base + 1, base + 2]);
    }

    /// 包圍盒 `(最小, 最大)`。空網格回 `None`。
    pub fn bounds(&self) -> Option<(V3, V3)> {
        let first = *self.positions.first()?;
        let (mut lo, mut hi) = (first, first);
        for p in &self.positions {
            for k in 0..3 {
                lo[k] = lo[k].min(p[k]);
                hi[k] = hi[k].max(p[k]);
            }
        }
        Some((lo, hi))
    }

    /// 網格的體積（散度定理）。封閉、法向量朝外時為正。
    pub fn volume(&self) -> f32 {
        let mut v = 0.0f64;
        for t in &self.triangles {
            let a = self.positions[t[0] as usize];
            let b = self.positions[t[1] as usize];
            let c = self.positions[t[2] as usize];
            let (a, b, c) = (to64(a), to64(b), to64(c));
            v += dot64(a, cross64(b, c)) / 6.0;
        }
        v as f32
    }

    /// 表面積。
    pub fn area(&self) -> f32 {
        let mut s = 0.0f64;
        for t in &self.triangles {
            let a = to64(self.positions[t[0] as usize]);
            let b = to64(self.positions[t[1] as usize]);
            let c = to64(self.positions[t[2] as usize]);
            let ab = [b[0] - a[0], b[1] - a[1], b[2] - a[2]];
            let ac = [c[0] - a[0], c[1] - a[1], c[2] - a[2]];
            let n = cross64(ab, ac);
            s += (n[0] * n[0] + n[1] * n[1] + n[2] * n[2]).sqrt() / 2.0;
        }
        s as f32
    }
}

fn to64(p: V3) -> [f64; 3] {
    [p[0] as f64, p[1] as f64, p[2] as f64]
}
fn cross64(a: [f64; 3], b: [f64; 3]) -> [f64; 3] {
    [
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    ]
}
fn dot64(a: [f64; 3], b: [f64; 3]) -> f64 {
    a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
}

// MARK: - 三角化（帶洞的多邊形）

fn cross2(o: P2, a: P2, b: P2) -> f32 {
    (a.0 - o.0) * (b.1 - o.1) - (a.1 - o.1) * (b.0 - o.0)
}

fn seg_cross(a: P2, b: P2, c: P2, d: P2) -> bool {
    // 嚴格相交（端點相碰不算）。
    let d1 = cross2(a, b, c);
    let d2 = cross2(a, b, d);
    let d3 = cross2(c, d, a);
    let d4 = cross2(c, d, b);
    ((d1 > 1e-6 && d2 < -1e-6) || (d1 < -1e-6 && d2 > 1e-6))
        && ((d3 > 1e-6 && d4 < -1e-6) || (d3 < -1e-6 && d4 > 1e-6))
}

fn same(a: P2, b: P2) -> bool {
    (a.0 - b.0).abs() < 1e-5 && (a.1 - b.1).abs() < 1e-5
}

fn in_triangle(p: P2, a: P2, b: P2, c: P2) -> bool {
    let (d1, d2, d3) = (cross2(a, b, p), cross2(b, c, p), cross2(c, a, p));
    d1 >= -1e-7 && d2 >= -1e-7 && d3 >= -1e-7
}

/// 把洞用橋接線併進外環，回傳一個弱簡單多邊形（逆時針；橋的兩端點各出現兩次）。
fn bridge_holes(outer: &[P2], holes: &[Vec<P2>]) -> Vec<P2> {
    let mut merged: Vec<P2> = outer.to_vec();
    // 由右到左處理：最右邊的洞最不容易被別的洞擋住。
    let mut order: Vec<usize> = (0..holes.len()).collect();
    let max_x = |h: &Vec<P2>| h.iter().map(|p| p.0).fold(f32::MIN, f32::max);
    order.sort_by(|a, b| max_x(&holes[*b]).total_cmp(&max_x(&holes[*a])));
    let mut pending: Vec<Vec<P2>> = holes.to_vec();
    for hi in order {
        let hole = holes[hi].clone();
        // 洞上最右的點。
        let (hk, hp) = hole
            .iter()
            .copied()
            .enumerate()
            .max_by(|a, b| a.1.0.total_cmp(&b.1.0))
            .unwrap();
        // 在 merged 裡找離 hp 最近、而且連線不穿過任何邊的點。
        let mut cands: Vec<usize> = (0..merged.len()).collect();
        cands.sort_by(|a, b| {
            let da = (merged[*a].0 - hp.0).hypot(merged[*a].1 - hp.1);
            let db = (merged[*b].0 - hp.0).hypot(merged[*b].1 - hp.1);
            da.total_cmp(&db)
        });
        let blocked = |m: P2, merged: &[P2], pending: &[Vec<P2>]| -> bool {
            let edges_cross = |ring: &[P2]| {
                (0..ring.len()).any(|i| {
                    let (c, d) = (ring[i], ring[(i + 1) % ring.len()]);
                    !(same(c, m) || same(d, m) || same(c, hp) || same(d, hp))
                        && seg_cross(hp, m, c, d)
                })
            };
            edges_cross(merged) || pending.iter().any(|h| edges_cross(h))
        };
        let mut chosen = cands[0];
        for c in &cands {
            if !blocked(merged[*c], &merged, &pending) {
                chosen = *c;
                break;
            }
        }
        // merged[..=chosen] + hole(從 hk 起繞一圈回到 hk) + merged[chosen] + merged[chosen+1..]
        let mut next: Vec<P2> = merged[..=chosen].to_vec();
        for i in 0..=hole.len() {
            next.push(hole[(hk + i) % hole.len()]);
        }
        next.push(merged[chosen]);
        next.extend_from_slice(&merged[chosen + 1..]);
        merged = next;
        pending
            .retain(|h| !(h.len() == hole.len() && h.iter().zip(&hole).all(|(a, b)| same(*a, *b))));
    }
    merged
}

/// 多邊形（逆時針外環、順時針洞）→ 三角形。回傳 `(頂點, 三角形索引)`；頂點是橋接之後的環，
/// 橋的兩端點在裡面會重複。
pub fn triangulate(outer: &[P2], holes: &[Vec<P2>]) -> (Vec<P2>, Vec<[usize; 3]>) {
    let poly = bridge_holes(outer, holes);
    let n = poly.len();
    let mut idx: Vec<usize> = (0..n).collect();
    let mut tris = Vec::with_capacity(n.saturating_sub(2));
    let mut guard = 0;
    while idx.len() > 3 && guard < n * n + 16 {
        guard += 1;
        let m = idx.len();
        let mut clipped = false;
        for i in 0..m {
            let (ia, ib, ic) = (idx[(i + m - 1) % m], idx[i], idx[(i + 1) % m]);
            let (a, b, c) = (poly[ia], poly[ib], poly[ic]);
            // 凸角（逆時針）。
            if cross2(a, b, c) <= 1e-7 {
                continue;
            }
            // 三角形裡不能有別的頂點（與三角形頂點重合的略過：橋接點是重複的）。
            let blocked = idx.iter().any(|&j| {
                j != ia
                    && j != ib
                    && j != ic
                    && !same(poly[j], a)
                    && !same(poly[j], b)
                    && !same(poly[j], c)
                    && in_triangle(poly[j], a, b, c)
            });
            if blocked {
                continue;
            }
            tris.push([ia, ib, ic]);
            idx.remove(i);
            clipped = true;
            break;
        }
        if !clipped {
            // 退化（共線、重合）：丟掉一個點繼續，免得卡死。面積為零的三角形不產出。
            idx.remove(0);
        }
    }
    if idx.len() == 3 {
        let (a, b, c) = (poly[idx[0]], poly[idx[1]], poly[idx[2]]);
        if cross2(a, b, c).abs() > 1e-7 {
            tris.push([idx[0], idx[1], idx[2]]);
        }
    }
    (poly, tris)
}

// MARK: - 立體 → 網格

/// 柱體 → 三角網格（平面著色）。`unit_scale` 把模型單位換成輸出單位。
pub fn solid_to_mesh(solid: &Solid, unit_scale: f32) -> TriMesh {
    let k = unit_scale;
    let mut mesh = TriMesh::default();
    let d = solid.depth;
    let p3 = |p: P2, z: f32| -> V3 { [p.0 * k, p.1 * k, z * k] };
    // 蓋面。
    let (poly, tris) = triangulate(&solid.profile.outer, &solid.profile.holes);
    for t in &tris {
        let (a, b, c) = (poly[t[0]], poly[t[1]], poly[t[2]]);
        mesh.push_tri([p3(a, 0.0), p3(b, 0.0), p3(c, 0.0)], [0.0, 0.0, 1.0]);
        // 後蓋：反向繞，法向量朝 −Z。
        mesh.push_tri([p3(a, -d), p3(c, -d), p3(b, -d)], [0.0, 0.0, -1.0]);
    }
    // 側壁：外環逆時針、洞順時針，所以「行進方向的右手邊」永遠是朝外（離開材料）。
    for ring in solid.profile.rings() {
        let m = ring.len();
        for i in 0..m {
            let (p, q) = (ring[i], ring[(i + 1) % m]);
            let (dx, dy) = (q.0 - p.0, q.1 - p.1);
            let len = dx.hypot(dy);
            if len < 1e-6 {
                continue;
            }
            let n = [dy / len, -dx / len, 0.0];
            let (a, b, c, e) = (p3(p, 0.0), p3(q, 0.0), p3(q, -d), p3(p, -d));
            mesh.push_tri([a, e, c], n);
            mesh.push_tri([a, c, b], n);
        }
    }
    mesh
}

// MARK: - STL

/// 二進位 STL。三角形的法向量取自網格。
pub fn to_stl(mesh: &TriMesh) -> Vec<u8> {
    let mut out = Vec::with_capacity(84 + mesh.triangles.len() * 50);
    let mut header = [0u8; 80];
    let tag = b"Kairumo solid (binary STL)";
    header[..tag.len()].copy_from_slice(tag);
    out.extend_from_slice(&header);
    out.extend_from_slice(&(mesh.triangles.len() as u32).to_le_bytes());
    for t in &mesh.triangles {
        let n = mesh.normals[t[0] as usize];
        for v in n {
            out.extend_from_slice(&v.to_le_bytes());
        }
        for i in t {
            for v in mesh.positions[*i as usize] {
                out.extend_from_slice(&v.to_le_bytes());
            }
        }
        out.extend_from_slice(&0u16.to_le_bytes());
    }
    out
}

// MARK: - OBJ

fn fmt(v: f32) -> String {
    // 六位小數、去掉尾端的零：檔案小一點，也避開 `-0`。
    let s = format!("{v:.6}");
    let s = s.trim_end_matches('0').trim_end_matches('.');
    if s == "-0" || s.is_empty() {
        "0".into()
    } else {
        s.into()
    }
}

pub fn to_obj(mesh: &TriMesh, name: &str) -> String {
    let mut s = String::with_capacity(mesh.positions.len() * 40);
    s.push_str("# Kairumo solid\n");
    s.push_str(&format!("o {name}\n"));
    for p in &mesh.positions {
        s.push_str(&format!("v {} {} {}\n", fmt(p[0]), fmt(p[1]), fmt(p[2])));
    }
    for n in &mesh.normals {
        s.push_str(&format!("vn {} {} {}\n", fmt(n[0]), fmt(n[1]), fmt(n[2])));
    }
    for t in &mesh.triangles {
        let (a, b, c) = (t[0] + 1, t[1] + 1, t[2] + 1);
        s.push_str(&format!("f {a}//{a} {b}//{b} {c}//{c}\n"));
    }
    s
}

// MARK: - GLB

fn pad4(v: &mut Vec<u8>, byte: u8) {
    while !v.len().is_multiple_of(4) {
        v.push(byte);
    }
}

/// glTF 2.0 二進位（單一網格、平面著色、淺灰材質）。
pub fn to_glb(mesh: &TriMesh) -> Vec<u8> {
    let (lo, hi) = mesh.bounds().unwrap_or(([0.0; 3], [0.0; 3]));
    let nv = mesh.positions.len();
    let ni = mesh.triangles.len() * 3;
    let mut bin: Vec<u8> = Vec::new();
    for p in &mesh.positions {
        for v in p {
            bin.extend_from_slice(&v.to_le_bytes());
        }
    }
    let normals_at = bin.len();
    for n in &mesh.normals {
        for v in n {
            bin.extend_from_slice(&v.to_le_bytes());
        }
    }
    let indices_at = bin.len();
    for t in &mesh.triangles {
        for i in t {
            bin.extend_from_slice(&i.to_le_bytes());
        }
    }
    let json = format!(
        concat!(
            "{{\"asset\":{{\"version\":\"2.0\",\"generator\":\"Kairumo\"}},",
            "\"scene\":0,\"scenes\":[{{\"nodes\":[0]}}],\"nodes\":[{{\"mesh\":0,\"name\":\"Solid\"}}],",
            "\"meshes\":[{{\"primitives\":[{{\"attributes\":{{\"POSITION\":0,\"NORMAL\":1}},\"indices\":2,\"material\":0,\"mode\":4}}]}}],",
            "\"materials\":[{{\"pbrMetallicRoughness\":{{\"baseColorFactor\":[0.78,0.8,0.84,1],\"metallicFactor\":0.1,\"roughnessFactor\":0.7}},\"doubleSided\":false}}],",
            "\"accessors\":[",
            "{{\"bufferView\":0,\"componentType\":5126,\"count\":{nv},\"type\":\"VEC3\",\"min\":[{lx},{ly},{lz}],\"max\":[{hx},{hy},{hz}]}},",
            "{{\"bufferView\":1,\"componentType\":5126,\"count\":{nv},\"type\":\"VEC3\"}},",
            "{{\"bufferView\":2,\"componentType\":5125,\"count\":{ni},\"type\":\"SCALAR\"}}],",
            "\"bufferViews\":[",
            "{{\"buffer\":0,\"byteOffset\":0,\"byteLength\":{pl},\"target\":34962}},",
            "{{\"buffer\":0,\"byteOffset\":{na},\"byteLength\":{nl},\"target\":34962}},",
            "{{\"buffer\":0,\"byteOffset\":{ia},\"byteLength\":{il},\"target\":34963}}],",
            "\"buffers\":[{{\"byteLength\":{bl}}}]}}"
        ),
        nv = nv,
        ni = ni,
        lx = lo[0],
        ly = lo[1],
        lz = lo[2],
        hx = hi[0],
        hy = hi[1],
        hz = hi[2],
        pl = normals_at,
        na = normals_at,
        nl = indices_at - normals_at,
        ia = indices_at,
        il = bin.len() - indices_at,
        bl = bin.len(),
    );
    let mut json = json.into_bytes();
    pad4(&mut json, b' ');
    pad4(&mut bin, 0);
    let total = 12 + 8 + json.len() + 8 + bin.len();
    let mut out = Vec::with_capacity(total);
    out.extend_from_slice(b"glTF");
    out.extend_from_slice(&2u32.to_le_bytes());
    out.extend_from_slice(&(total as u32).to_le_bytes());
    out.extend_from_slice(&(json.len() as u32).to_le_bytes());
    out.extend_from_slice(b"JSON");
    out.extend_from_slice(&json);
    out.extend_from_slice(&(bin.len() as u32).to_le_bytes());
    out.extend_from_slice(b"BIN\0");
    out.extend_from_slice(&bin);
    out
}

// MARK: - USDZ

/// USD 的文字格式（usda）。
pub fn to_usda(mesh: &TriMesh) -> String {
    let counts = vec!["3"; mesh.triangles.len()].join(", ");
    let indices = mesh
        .triangles
        .iter()
        .map(|t| format!("{}, {}, {}", t[0], t[1], t[2]))
        .collect::<Vec<_>>()
        .join(", ");
    let pts = mesh
        .positions
        .iter()
        .map(|p| format!("({}, {}, {})", fmt(p[0]), fmt(p[1]), fmt(p[2])))
        .collect::<Vec<_>>()
        .join(", ");
    let ns = mesh
        .normals
        .iter()
        .map(|n| format!("({}, {}, {})", fmt(n[0]), fmt(n[1]), fmt(n[2])))
        .collect::<Vec<_>>()
        .join(", ");
    format!(
        "#usda 1.0\n(\n    defaultPrim = \"Solid\"\n    metersPerUnit = 1\n    upAxis = \"Y\"\n)\n\n\
         def Xform \"Solid\" (\n    kind = \"component\"\n)\n{{\n    def Mesh \"Body\"\n    {{\n\
         \x20       int[] faceVertexCounts = [{counts}]\n\
         \x20       int[] faceVertexIndices = [{indices}]\n\
         \x20       point3f[] points = [{pts}]\n\
         \x20       normal3f[] normals = [{ns}] (\n            interpolation = \"vertex\"\n        )\n\
         \x20       color3f[] primvars:displayColor = [(0.78, 0.8, 0.84)]\n\
         \x20       uniform token subdivisionScheme = \"none\"\n    }}\n}}\n"
    )
}

fn crc32(data: &[u8]) -> u32 {
    let mut table = [0u32; 256];
    for (i, slot) in table.iter_mut().enumerate() {
        let mut c = i as u32;
        for _ in 0..8 {
            c = if c & 1 != 0 {
                0xEDB8_8320 ^ (c >> 1)
            } else {
                c >> 1
            };
        }
        *slot = c;
    }
    let mut crc = 0xFFFF_FFFFu32;
    for b in data {
        crc = table[((crc ^ *b as u32) & 0xFF) as usize] ^ (crc >> 8);
    }
    !crc
}

/// USDZ：不壓縮的 zip，**每個檔案的資料起點對齊 64 位元組**（規格要求，AR Quick Look 靠它直接映射檔案）。
pub fn to_usdz(mesh: &TriMesh) -> Vec<u8> {
    let name = b"solid.usda";
    let data = to_usda(mesh).into_bytes();
    let crc = crc32(&data);
    let mut out: Vec<u8> = Vec::new();
    // 本地檔頭：30 位元組 + 檔名 + extra；extra 補到資料起點是 64 的倍數。
    let header_len = 30 + name.len();
    let pad = (64 - (header_len + 4) % 64) % 64;
    out.extend_from_slice(&0x0403_4b50u32.to_le_bytes());
    out.extend_from_slice(&20u16.to_le_bytes()); // 需要的版本
    out.extend_from_slice(&0u16.to_le_bytes()); // 旗標
    out.extend_from_slice(&0u16.to_le_bytes()); // 儲存、不壓縮
    out.extend_from_slice(&0u16.to_le_bytes()); // 時間
    out.extend_from_slice(&0x21u16.to_le_bytes()); // 日期（1980-01-01）
    out.extend_from_slice(&crc.to_le_bytes());
    out.extend_from_slice(&(data.len() as u32).to_le_bytes());
    out.extend_from_slice(&(data.len() as u32).to_le_bytes());
    out.extend_from_slice(&(name.len() as u16).to_le_bytes());
    out.extend_from_slice(&((4 + pad) as u16).to_le_bytes());
    out.extend_from_slice(name);
    // extra：一個自訂欄位（id 0x1986，USDZ 慣例的對齊填充）。
    out.extend_from_slice(&0x1986u16.to_le_bytes());
    out.extend_from_slice(&(pad as u16).to_le_bytes());
    out.extend(std::iter::repeat_n(0u8, pad));
    debug_assert_eq!(out.len() % 64, 0);
    let local_offset = 0u32;
    out.extend_from_slice(&data);
    // 中央目錄。
    let cd_start = out.len() as u32;
    out.extend_from_slice(&0x0201_4b50u32.to_le_bytes());
    out.extend_from_slice(&20u16.to_le_bytes()); // 製作版本
    out.extend_from_slice(&20u16.to_le_bytes()); // 需要的版本
    out.extend_from_slice(&0u16.to_le_bytes());
    out.extend_from_slice(&0u16.to_le_bytes());
    out.extend_from_slice(&0u16.to_le_bytes());
    out.extend_from_slice(&0x21u16.to_le_bytes());
    out.extend_from_slice(&crc.to_le_bytes());
    out.extend_from_slice(&(data.len() as u32).to_le_bytes());
    out.extend_from_slice(&(data.len() as u32).to_le_bytes());
    out.extend_from_slice(&(name.len() as u16).to_le_bytes());
    out.extend_from_slice(&0u16.to_le_bytes()); // extra
    out.extend_from_slice(&0u16.to_le_bytes()); // 註解
    out.extend_from_slice(&0u16.to_le_bytes()); // 磁碟
    out.extend_from_slice(&0u16.to_le_bytes()); // 內部屬性
    out.extend_from_slice(&0u32.to_le_bytes()); // 外部屬性
    out.extend_from_slice(&local_offset.to_le_bytes());
    out.extend_from_slice(name);
    let cd_len = out.len() as u32 - cd_start;
    out.extend_from_slice(&0x0605_4b50u32.to_le_bytes());
    out.extend_from_slice(&0u16.to_le_bytes());
    out.extend_from_slice(&0u16.to_le_bytes());
    out.extend_from_slice(&1u16.to_le_bytes());
    out.extend_from_slice(&1u16.to_le_bytes());
    out.extend_from_slice(&cd_len.to_le_bytes());
    out.extend_from_slice(&cd_start.to_le_bytes());
    out.extend_from_slice(&0u16.to_le_bytes());
    out
}

/// 匯出格式。
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Format {
    Stl,
    Obj,
    Glb,
    Usdz,
}

pub const FORMATS: [Format; 4] = [Format::Stl, Format::Obj, Format::Glb, Format::Usdz];

impl Format {
    pub fn id(self) -> &'static str {
        match self {
            Format::Stl => "stl",
            Format::Obj => "obj",
            Format::Glb => "glb",
            Format::Usdz => "usdz",
        }
    }

    pub fn from_id(id: &str) -> Option<Format> {
        FORMATS.iter().copied().find(|f| f.id() == id)
    }

    /// 輸出單位：STL、OBJ 用毫米，GLB、USDZ 用公尺。回傳「一個毫米等於幾個輸出單位」。
    pub fn per_mm(self) -> f32 {
        match self {
            Format::Stl | Format::Obj => 1.0,
            Format::Glb | Format::Usdz => 0.001,
        }
    }
}

/// 立體 → 檔案內容。`mm_per_unit` 是一個模型單位等於幾毫米（頁面單位用 `1 / UNITS_PER_MM`）。
pub fn export(solid: &Solid, format: Format, mm_per_unit: f32) -> Vec<u8> {
    let mesh = solid_to_mesh(solid, mm_per_unit * format.per_mm());
    match format {
        Format::Stl => to_stl(&mesh),
        Format::Obj => to_obj(&mesh, "solid").into_bytes(),
        Format::Glb => to_glb(&mesh),
        Format::Usdz => to_usdz(&mesh),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::solid::{Profile, preset};

    fn area(ring: &[P2]) -> f32 {
        crate::geom::signed_area(ring)
    }

    #[test]
    fn a_square_triangulates_into_two_triangles() {
        let (poly, tris) = triangulate(&[(0.0, 0.0), (10.0, 0.0), (10.0, 10.0), (0.0, 10.0)], &[]);
        assert_eq!(tris.len(), 2);
        let sum: f32 = tris
            .iter()
            .map(|t| 0.5 * cross2(poly[t[0]], poly[t[1]], poly[t[2]]))
            .sum();
        assert!((sum - 100.0).abs() < 1e-3);
    }

    #[test]
    fn a_concave_l_shape_and_every_preset_cover_exactly_their_area() {
        for name in crate::solid::PRESETS {
            let p = preset(name, 60.0, 40.0).unwrap();
            let (poly, tris) = triangulate(&p.outer, &p.holes);
            let sum: f32 = tris
                .iter()
                .map(|t| 0.5 * cross2(poly[t[0]], poly[t[1]], poly[t[2]]))
                .sum();
            assert!(
                (sum - p.area()).abs() < p.area() * 1e-3,
                "{name}: 三角形面積 {sum} 應是 {}",
                p.area()
            );
            assert!(
                tris.iter()
                    .all(|t| cross2(poly[t[0]], poly[t[1]], poly[t[2]]) > 0.0),
                "{name}: 有反向或退化的三角形"
            );
        }
    }

    #[test]
    fn holes_are_left_empty() {
        // 環與帶四個洞的板：任何三角形的重心都不在洞裡。
        for name in ["ring", "plate_holes"] {
            let p = preset(name, 80.0, 80.0).unwrap();
            let (poly, tris) = triangulate(&p.outer, &p.holes);
            for t in &tris {
                let c = (
                    (poly[t[0]].0 + poly[t[1]].0 + poly[t[2]].0) / 3.0,
                    (poly[t[0]].1 + poly[t[1]].1 + poly[t[2]].1) / 3.0,
                );
                for h in &p.holes {
                    assert!(
                        !crate::geom::point_in_ring(c, h),
                        "{name}: 三角形落在洞裡 {c:?}"
                    );
                }
            }
        }
    }

    #[test]
    fn the_extruded_mesh_has_the_right_volume_surface_and_bounds() {
        let solid = Solid::new(preset("rect", 40.0, 30.0).unwrap(), 20.0);
        let mesh = solid_to_mesh(&solid, 1.0);
        assert!(
            (mesh.volume() - 40.0 * 30.0 * 20.0).abs() < 1.0,
            "體積 {}",
            mesh.volume()
        );
        assert!((mesh.area() - 2.0 * (40.0 * 30.0 + 40.0 * 20.0 + 30.0 * 20.0)).abs() < 1.0);
        let (lo, hi) = mesh.bounds().unwrap();
        assert_eq!((lo, hi), ([0.0, 0.0, -20.0], [40.0, 30.0, 0.0]));
        // 每個法向量都是單位長度。
        assert!(
            mesh.normals
                .iter()
                .all(|n| ((n[0] * n[0] + n[1] * n[1] + n[2] * n[2]).sqrt() - 1.0).abs() < 1e-5)
        );
    }

    #[test]
    fn volumes_of_shapes_with_holes_subtract_the_holes_and_are_positive() {
        for name in crate::solid::PRESETS {
            let p = preset(name, 60.0, 40.0).unwrap();
            let want = p.area() * 25.0;
            let mesh = solid_to_mesh(&Solid::new(p, 25.0), 1.0);
            assert!(mesh.volume() > 0.0, "{name}: 法向量朝內（體積為負）");
            assert!(
                (mesh.volume() - want).abs() < want * 2e-3,
                "{name}: 體積 {} 應是 {want}",
                mesh.volume()
            );
        }
    }

    #[test]
    fn every_triangle_normal_agrees_with_its_winding() {
        // 三角形的繞向（右手定則）要與頂點法向量同向：否則 AR 裡面會是裡外翻過來的。
        let mesh = solid_to_mesh(
            &Solid::new(preset("u_shape", 50.0, 40.0).unwrap(), 30.0),
            1.0,
        );
        for t in &mesh.triangles {
            let (a, b, c) = (
                to64(mesh.positions[t[0] as usize]),
                to64(mesh.positions[t[1] as usize]),
                to64(mesh.positions[t[2] as usize]),
            );
            let n = cross64(
                [b[0] - a[0], b[1] - a[1], b[2] - a[2]],
                [c[0] - a[0], c[1] - a[1], c[2] - a[2]],
            );
            let want = to64(mesh.normals[t[0] as usize]);
            assert!(dot64(n, want) > 0.0, "三角形繞向與法向量相反");
        }
    }

    #[test]
    fn stl_has_the_binary_layout() {
        let solid = Solid::new(preset("rect", 10.0, 10.0).unwrap(), 5.0);
        let bytes = export(&solid, Format::Stl, 1.0);
        let n = u32::from_le_bytes(bytes[80..84].try_into().unwrap()) as usize;
        assert_eq!(bytes.len(), 84 + n * 50);
        assert_eq!(n, 12, "長方體 12 個三角形");
    }

    #[test]
    fn obj_lists_vertices_normals_and_faces() {
        let solid = Solid::new(preset("rect", 10.0, 10.0).unwrap(), 5.0);
        let text = String::from_utf8(export(&solid, Format::Obj, 1.0)).unwrap();
        assert_eq!(text.lines().filter(|l| l.starts_with("v ")).count(), 36);
        assert_eq!(text.lines().filter(|l| l.starts_with("vn ")).count(), 36);
        assert_eq!(text.lines().filter(|l| l.starts_with("f ")).count(), 12);
        assert!(!text.contains("-0 ") && !text.contains("NaN"));
    }

    #[test]
    fn glb_has_valid_chunks_and_accessors_that_fit_the_buffer() {
        let solid = Solid::new(preset("plate_holes", 60.0, 40.0).unwrap(), 10.0);
        let bytes = export(&solid, Format::Glb, 1.0);
        assert_eq!(&bytes[0..4], b"glTF");
        assert_eq!(u32::from_le_bytes(bytes[4..8].try_into().unwrap()), 2);
        assert_eq!(
            u32::from_le_bytes(bytes[8..12].try_into().unwrap()) as usize,
            bytes.len()
        );
        let jl = u32::from_le_bytes(bytes[12..16].try_into().unwrap()) as usize;
        assert_eq!(&bytes[16..20], b"JSON");
        assert_eq!(jl % 4, 0);
        let json = std::str::from_utf8(&bytes[20..20 + jl]).unwrap();
        assert!(json.contains("\"POSITION\":0") && json.contains("\"componentType\":5125"));
        let bl_at = 20 + jl;
        let bl = u32::from_le_bytes(bytes[bl_at..bl_at + 4].try_into().unwrap()) as usize;
        assert_eq!(&bytes[bl_at + 4..bl_at + 8], b"BIN\0");
        assert_eq!(bl_at + 8 + bl, bytes.len());
        assert_eq!(bl % 4, 0);
        // buffer 的 byteLength 要和 BIN 區塊一致（頂點 + 法向量 + 索引）。
        let mesh = solid_to_mesh(&solid, 1.0);
        let want = mesh.positions.len() * 12 * 2 + mesh.triangles.len() * 12;
        assert_eq!(want.div_ceil(4) * 4, bl);
        assert!(json.contains(&format!("\"byteLength\":{want}")));
        // JSON 是合法的（括號配對、沒有 NaN）。
        assert_eq!(json.matches('{').count(), json.matches('}').count());
        assert_eq!(json.matches('[').count(), json.matches(']').count());
        assert!(!json.contains("NaN") && !json.contains("inf"));
    }

    #[test]
    fn usdz_is_an_aligned_stored_zip_with_a_valid_usda() {
        let solid = Solid::new(preset("l_shape", 50.0, 40.0).unwrap(), 20.0);
        let bytes = export(&solid, Format::Usdz, 1.0);
        assert_eq!(&bytes[0..4], &[0x50, 0x4b, 0x03, 0x04]);
        // 檔案資料起點在 64 的倍數。
        let name_len = u16::from_le_bytes(bytes[26..28].try_into().unwrap()) as usize;
        let extra_len = u16::from_le_bytes(bytes[28..30].try_into().unwrap()) as usize;
        let data_at = 30 + name_len + extra_len;
        assert_eq!(data_at % 64, 0, "資料起點 {data_at} 沒有對齊 64");
        assert_eq!(
            u16::from_le_bytes(bytes[8..10].try_into().unwrap()),
            0,
            "不壓縮"
        );
        let size = u32::from_le_bytes(bytes[22..26].try_into().unwrap()) as usize;
        let data = &bytes[data_at..data_at + size];
        // CRC 對得上。
        assert_eq!(
            crc32(data),
            u32::from_le_bytes(bytes[14..18].try_into().unwrap())
        );
        let text = std::str::from_utf8(data).unwrap();
        assert!(
            text.starts_with("#usda 1.0")
                && text.contains("upAxis = \"Y\"")
                && text.contains("def Mesh")
        );
        // 面數 = 索引數 / 3；點數 = 法向量數。
        let counts = text
            .split("faceVertexCounts = [")
            .nth(1)
            .unwrap()
            .split(']')
            .next()
            .unwrap();
        let indices = text
            .split("faceVertexIndices = [")
            .nth(1)
            .unwrap()
            .split(']')
            .next()
            .unwrap();
        assert_eq!(counts.split(", ").count() * 3, indices.split(", ").count());
        // 結尾是 EOCD，而且指向中央目錄。
        let eocd = bytes.len() - 22;
        assert_eq!(&bytes[eocd..eocd + 4], &[0x50, 0x4b, 0x05, 0x06]);
        let cd_at = u32::from_le_bytes(bytes[eocd + 16..eocd + 20].try_into().unwrap()) as usize;
        assert_eq!(&bytes[cd_at..cd_at + 4], &[0x50, 0x4b, 0x01, 0x02]);
    }

    #[test]
    fn units_are_millimetres_for_stl_obj_and_metres_for_glb_usdz() {
        // 模型單位 = 頁面單位，3.81 單位 = 1 mm；一個 38.1 單位寬的方塊 = 10 mm。
        let solid = Solid::new(preset("rect", 38.1, 38.1).unwrap(), 38.1);
        let mm_per_unit = 1.0 / 3.81;
        let stl = export(&solid, Format::Stl, mm_per_unit);
        let max_x = (0..12)
            .flat_map(|t| (0..3).map(move |v| 84 + t * 50 + 12 + v * 12))
            .map(|o| f32::from_le_bytes(stl[o..o + 4].try_into().unwrap()))
            .fold(f32::MIN, f32::max);
        assert!((max_x - 10.0).abs() < 0.01, "STL 是毫米：{max_x}");
        let glb = export(&solid, Format::Glb, mm_per_unit);
        let json_len = u32::from_le_bytes(glb[12..16].try_into().unwrap()) as usize;
        let json = std::str::from_utf8(&glb[20..20 + json_len]).unwrap();
        assert!(json.contains("\"max\":[0.01"), "GLB 是公尺：{json}");
    }

    #[test]
    fn format_ids_round_trip_and_unknown_is_none() {
        for f in FORMATS {
            assert_eq!(Format::from_id(f.id()), Some(f));
        }
        assert!(Format::from_id("step").is_none());
    }

    #[test]
    fn a_degenerate_profile_does_not_hang_the_triangulator() {
        // 共線的點、重複點：不會無窮迴圈，也不產出面積為零的三角形。
        let (poly, tris) = triangulate(
            &[
                (0.0, 0.0),
                (5.0, 0.0),
                (10.0, 0.0),
                (10.0, 10.0),
                (0.0, 10.0),
            ],
            &[],
        );
        assert!(
            tris.iter()
                .all(|t| cross2(poly[t[0]], poly[t[1]], poly[t[2]]) > 1e-7)
        );
        let p = Profile::new(
            vec![(0.0, 0.0), (10.0, 0.0), (10.0, 10.0), (0.0, 10.0)],
            vec![],
        )
        .unwrap();
        assert!(area(&p.outer) > 0.0);
    }
}
