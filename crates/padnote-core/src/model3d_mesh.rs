//! 把使用者自己的 3D 檔案讀成網格。
//!
//! # 為什麼在核心，而不是各平台各自處理
//!
//! 核心裡**早就有一個完整的軟體算繪器**（`ffi_model3d::model3d_faces`）：
//! 旋轉、透視投影、背面剔除、深度排序、單一方向光著色，回傳一串排好序的
//! 2D 多邊形，兩個平台都只是拿去填色。缺的從來不是算繪器，是「檔案 → 網格」
//! 這一段。
//!
//! Apple 端原本在這裡**繞過核心**，改用 SceneKit 的 `SCNScene(url:)` ——
//! 於是匯入的模型在 iPad 上看得到、在 Android 上是一片空白（存得下、同步
//! 得動、畫不出來）。那不是「Android 少了算繪器」，是 Apple 走了一條對方
//! 沒有對應物的捷徑。
//!
//! 讀成 [`ImportedMesh`] 之後，兩端走的就是同一條路、得到同一個畫面。
//!
//! # 為什麼只收 OBJ 與 STL
//!
//! 這兩種格式的內容就是「一堆頂點」加「一堆面」，正好是算繪器要的東西，
//! 解析器各只有幾十行。
//!
//! USDZ 與 GLB 是另一回事：二進位容器、緩衝區檢視、壓縮、PBR 材質、骨架
//! 動畫 —— 那是一個函式庫的工作量，而且**收得進來卻畫不出來，比一開始就
//! 說不支援更糟**（`ffi_import` 的檔頭寫的就是這句話）。

/// 讀進來的網格。座標已經正規化到與內建幾何體相同的尺度。
#[derive(Clone, Debug)]
pub struct ImportedMesh {
    pub vertices: Vec<(f32, f32, f32)>,
    /// 每一面的頂點索引。三角形或多邊形都可能。
    pub faces: Vec<Vec<usize>>,
}

/// 讀不進來的理由。**都是語系鍵**，平台端查表 —— 與 `ffi_import` 同一套
/// 做法，同一個檔案在兩台裝置上不該得到不一樣的錯誤訊息。
#[derive(Debug, PartialEq, Eq)]
pub enum MeshError {
    /// 副檔名不是 obj 或 stl。
    UnsupportedFormat,
    /// 檔案讀得進來，但裡面一個面都沒有。
    NoGeometry,
    /// 面太多，畫起來會卡住整個介面。
    TooManyFaces,
}

impl MeshError {
    pub fn reason_key(&self) -> &'static str {
        match self {
            Self::UnsupportedFormat => "model_unsupported_format",
            Self::NoGeometry => "model_no_geometry",
            Self::TooManyFaces => "model_too_many_faces",
        }
    }
}

/// 面數上限。
///
/// # 這個數字怎麼來的
///
/// 算繪器是**純軟體**的，每一次旋轉都要把每一面重算一遍投影與明暗，而那
/// 發生在使用者拖動滑桿的時候。一個 30 萬面的掃描模型會讓畫面直接停住 ——
/// 而使用者看到的是「App 當掉了」，不是「這個模型太複雜」。
///
/// 兩萬面在手機上仍然滑得動，而絕大多數拿來放進筆記的模型（零件、公仔、
/// 建築量體）都在這個數量級以下。
pub const MAX_FACES: usize = 20_000;

/// 正規化之後模型的最大半徑。
///
/// 與內建幾何體同一個尺度（立方體邊長 1.4、球半徑 0.95）——
/// 不正規化的話，一個以公釐為單位的零件會小到看不見，而一個以公尺為單位
/// 的建築會大到只剩一片色塊填滿畫面。**兩種都像是「匯入壞掉了」。**
const TARGET_RADIUS: f32 = 0.95;

/// 依副檔名讀檔。`extension` 不分大小寫，可含或不含點。
pub fn parse(bytes: &[u8], extension: &str) -> Result<ImportedMesh, MeshError> {
    let ext = extension.trim_start_matches('.').to_ascii_lowercase();
    let mesh = match ext.as_str() {
        "obj" => parse_obj(bytes),
        "stl" => parse_stl(bytes),
        _ => return Err(MeshError::UnsupportedFormat),
    };

    if mesh.faces.is_empty() || mesh.vertices.is_empty() {
        return Err(MeshError::NoGeometry);
    }
    if mesh.faces.len() > MAX_FACES {
        return Err(MeshError::TooManyFaces);
    }
    Ok(normalise(mesh))
}

/// 置中並縮放到與內建幾何體相同的尺度。
///
/// 用**外接球**而不是逐軸縮放：逐軸會把模型拉變形，而使用者拿到一個被壓扁
/// 的自己的模型，會以為是檔案壞了。
fn normalise(mut mesh: ImportedMesh) -> ImportedMesh {
    let n = mesh.vertices.len() as f32;
    let (sx, sy, sz) = mesh
        .vertices
        .iter()
        .fold((0.0, 0.0, 0.0), |a, v| (a.0 + v.0, a.1 + v.1, a.2 + v.2));
    let centre = (sx / n, sy / n, sz / n);

    let mut radius: f32 = 0.0;
    for v in &mesh.vertices {
        let d = (v.0 - centre.0, v.1 - centre.1, v.2 - centre.2);
        radius = radius.max((d.0 * d.0 + d.1 * d.1 + d.2 * d.2).sqrt());
    }
    // 所有頂點重合（退化模型）時不要除以零 —— 那會產生 NaN，而 NaN 的
    // 座標畫出來是**什麼都沒有**，看起來跟「沒匯入成功」一模一樣。
    let k = if radius > f32::EPSILON {
        TARGET_RADIUS / radius
    } else {
        1.0
    };

    for v in &mut mesh.vertices {
        v.0 = (v.0 - centre.0) * k;
        v.1 = (v.1 - centre.1) * k;
        v.2 = (v.2 - centre.2) * k;
    }
    mesh
}

// ── OBJ ─────────────────────────────────────────────────────────────

/// Wavefront OBJ（文字）。
///
/// 只讀 `v`（頂點）與 `f`（面）。材質、法線、貼圖座標一律跳過 ——
/// 算繪器自己算法線與明暗，讀了也沒有地方放。
fn parse_obj(bytes: &[u8]) -> ImportedMesh {
    let text = String::from_utf8_lossy(bytes);
    let mut vertices: Vec<(f32, f32, f32)> = Vec::new();
    let mut faces: Vec<Vec<usize>> = Vec::new();

    for line in text.lines() {
        let line = line.trim();
        let mut parts = line.split_whitespace();
        match parts.next() {
            Some("v") => {
                let nums: Vec<f32> = parts.filter_map(|p| p.parse().ok()).collect();
                if nums.len() >= 3 {
                    vertices.push((nums[0], nums[1], nums[2]));
                }
            }
            Some("f") => {
                let mut idx = Vec::new();
                for token in parts {
                    // `f 1/2/3` `f 1//3` `f 1` 都要吃得下 —— 只有第一段是
                    // 頂點索引，後面是貼圖座標與法線。
                    let first = token.split('/').next().unwrap_or("");
                    let Ok(raw) = first.parse::<i64>() else {
                        continue;
                    };
                    // OBJ 的索引從 1 起算，**負數表示從尾端往回數**
                    // （相對索引）。忘了負數的話，那種檔案會整個讀成空的。
                    let resolved = if raw > 0 {
                        (raw - 1) as usize
                    } else if raw < 0 {
                        let back = (-raw) as usize;
                        if back > vertices.len() {
                            continue;
                        }
                        vertices.len() - back
                    } else {
                        continue;
                    };
                    if resolved < vertices.len() {
                        idx.push(resolved);
                    }
                }
                if idx.len() >= 3 {
                    faces.push(idx);
                }
            }
            _ => {}
        }
    }

    ImportedMesh { vertices, faces }
}

// ── STL ─────────────────────────────────────────────────────────────

const STL_HEADER: usize = 80;
const STL_TRIANGLE: usize = 50;

/// STL（二進位或 ASCII）。
///
/// **不能只看開頭是不是 `solid` 來判斷格式。** 很多匯出器產生的二進位 STL
/// header 裡也寫著 "solid"，照字串判斷會把二進位檔當成文字讀，結果是一個
/// 面都讀不到 —— 而錯誤訊息會變成「這個檔案裡沒有東西」。
/// 照**長度**判斷才可靠：二進位的大小正好是 84 + 50 × 三角形數。
fn parse_stl(bytes: &[u8]) -> ImportedMesh {
    if looks_binary(bytes) {
        parse_stl_binary(bytes)
    } else {
        parse_stl_ascii(bytes)
    }
}

fn looks_binary(bytes: &[u8]) -> bool {
    if bytes.len() < STL_HEADER + 4 {
        return false;
    }
    let count = u32::from_le_bytes([
        bytes[STL_HEADER],
        bytes[STL_HEADER + 1],
        bytes[STL_HEADER + 2],
        bytes[STL_HEADER + 3],
    ]) as usize;
    // 有些檔案尾端會多幾個位元組，所以用 >= 而不是 ==。
    count > 0 && bytes.len() >= STL_HEADER + 4 + count * STL_TRIANGLE
}

fn parse_stl_binary(bytes: &[u8]) -> ImportedMesh {
    let count = u32::from_le_bytes([
        bytes[STL_HEADER],
        bytes[STL_HEADER + 1],
        bytes[STL_HEADER + 2],
        bytes[STL_HEADER + 3],
    ]) as usize;

    let mut vertices = Vec::with_capacity(count * 3);
    let mut faces = Vec::with_capacity(count);
    let mut at = STL_HEADER + 4;

    for _ in 0..count {
        if at + STL_TRIANGLE > bytes.len() {
            break;
        }
        // 前 12 個位元組是法線，跳過 —— 算繪器自己從頂點算，而檔案裡的
        // 法線常常是錯的（很多匯出器直接寫 0,0,0）。
        let mut p = at + 12;
        let base = vertices.len();
        for _ in 0..3 {
            vertices.push((read_f32(bytes, p), read_f32(bytes, p + 4), read_f32(bytes, p + 8)));
            p += 12;
        }
        faces.push(vec![base, base + 1, base + 2]);
        at += STL_TRIANGLE;
    }

    ImportedMesh { vertices, faces }
}

fn read_f32(bytes: &[u8], at: usize) -> f32 {
    f32::from_le_bytes([bytes[at], bytes[at + 1], bytes[at + 2], bytes[at + 3]])
}

fn parse_stl_ascii(bytes: &[u8]) -> ImportedMesh {
    let text = String::from_utf8_lossy(bytes);
    let mut vertices: Vec<(f32, f32, f32)> = Vec::new();
    let mut faces: Vec<Vec<usize>> = Vec::new();
    let mut current: Vec<usize> = Vec::new();

    for line in text.lines() {
        let line = line.trim();
        if let Some(rest) = line.strip_prefix("vertex") {
            let nums: Vec<f32> = rest.split_whitespace().filter_map(|p| p.parse().ok()).collect();
            if nums.len() >= 3 {
                current.push(vertices.len());
                vertices.push((nums[0], nums[1], nums[2]));
            }
        } else if line.starts_with("endfacet") {
            if current.len() >= 3 {
                faces.push(std::mem::take(&mut current));
            } else {
                current.clear();
            }
        }
    }

    ImportedMesh { vertices, faces }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// 一個邊長 2、中心在 (10, 10, 10) 的四面體，故意偏離原點也故意很大 ——
    /// 正規化沒做的話，它會畫在畫布外面。
    const TETRA_OBJ: &str = "\
# a tetrahedron
v 9 9 9
v 11 9 9
v 10 11 9
v 10 10 11
f 1 2 3
f 1 2 4
f 2 3 4
f 1 3 4
";

    #[test]
    fn an_obj_file_becomes_a_mesh() {
        let m = parse(TETRA_OBJ.as_bytes(), "obj").unwrap();
        assert_eq!(m.vertices.len(), 4);
        assert_eq!(m.faces.len(), 4);
    }

    #[test]
    fn the_model_is_centred_and_scaled_to_the_built_in_size() {
        // **這一條守的是「匯入之後看得見」。** 沒有正規化的話，一個以公釐
        // 為單位的零件小到看不見、一個以公尺為單位的建築大到填滿畫面 ——
        // 兩種都像是匯入壞掉了。
        let m = parse(TETRA_OBJ.as_bytes(), "obj").unwrap();

        let n = m.vertices.len() as f32;
        let centre = m
            .vertices
            .iter()
            .fold((0.0, 0.0, 0.0), |a, v| (a.0 + v.0, a.1 + v.1, a.2 + v.2));
        let centre = (centre.0 / n, centre.1 / n, centre.2 / n);
        assert!(
            centre.0.abs() < 1e-4 && centre.1.abs() < 1e-4 && centre.2.abs() < 1e-4,
            "沒有置中：{centre:?}"
        );

        let radius = m
            .vertices
            .iter()
            .map(|v| (v.0 * v.0 + v.1 * v.1 + v.2 * v.2).sqrt())
            .fold(0.0f32, f32::max);
        assert!(
            (radius - TARGET_RADIUS).abs() < 1e-4,
            "外接半徑是 {radius}，應該是 {TARGET_RADIUS}"
        );
    }

    #[test]
    fn scaling_keeps_the_shape_it_does_not_squash_it() {
        // 逐軸縮放會把模型拉變形，而使用者拿到一個被壓扁的自己的模型，
        // 會以為是檔案壞了。這裡用一個刻意很扁的盒子驗證比例有保留。
        let flat = "v 0 0 0\nv 10 0 0\nv 10 1 0\nv 0 1 0\nf 1 2 3 4\n";
        let m = parse(flat.as_bytes(), "obj").unwrap();
        let w = m.vertices.iter().map(|v| v.0).fold(f32::MIN, f32::max)
            - m.vertices.iter().map(|v| v.0).fold(f32::MAX, f32::min);
        let h = m.vertices.iter().map(|v| v.1).fold(f32::MIN, f32::max)
            - m.vertices.iter().map(|v| v.1).fold(f32::MAX, f32::min);
        assert!((w / h - 10.0).abs() < 1e-3, "長寬比被改了：{}", w / h);
    }

    #[test]
    fn obj_indices_may_be_relative() {
        // 負索引是「從尾端往回數」。不支援的話，那種檔案會整個讀成空的，
        // 而錯誤訊息會說「裡面沒有東西」—— 完全指不到真正的原因。
        let obj = "v 0 0 0\nv 1 0 0\nv 0 1 0\nf -3 -2 -1\n";
        let m = parse(obj.as_bytes(), "obj").unwrap();
        assert_eq!(m.faces, vec![vec![0, 1, 2]]);
    }

    #[test]
    fn obj_face_tokens_may_carry_texture_and_normal_indices() {
        let obj = "v 0 0 0\nv 1 0 0\nv 0 1 0\nf 1/1/1 2/2/2 3//3\n";
        let m = parse(obj.as_bytes(), "obj").unwrap();
        assert_eq!(m.faces, vec![vec![0, 1, 2]]);
    }

    #[test]
    fn a_polygon_face_stays_a_polygon() {
        // 算繪器吃得下多邊形，不必在這裡切成三角形。
        let obj = "v 0 0 0\nv 1 0 0\nv 1 1 0\nv 0 1 0\nf 1 2 3 4\n";
        let m = parse(obj.as_bytes(), "obj").unwrap();
        assert_eq!(m.faces[0].len(), 4);
    }

    fn binary_stl(triangles: &[[(f32, f32, f32); 3]]) -> Vec<u8> {
        let mut out = vec![0u8; STL_HEADER];
        out.extend_from_slice(&(triangles.len() as u32).to_le_bytes());
        for t in triangles {
            out.extend_from_slice(&[0u8; 12]); // 法線，故意留 0
            for v in t {
                out.extend_from_slice(&v.0.to_le_bytes());
                out.extend_from_slice(&v.1.to_le_bytes());
                out.extend_from_slice(&v.2.to_le_bytes());
            }
            out.extend_from_slice(&[0u8; 2]); // 屬性位元組數
        }
        out
    }

    #[test]
    fn a_binary_stl_becomes_a_mesh() {
        let data = binary_stl(&[
            [(0.0, 0.0, 0.0), (1.0, 0.0, 0.0), (0.0, 1.0, 0.0)],
            [(0.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0)],
        ]);
        let m = parse(&data, "stl").unwrap();
        assert_eq!(m.faces.len(), 2);
        assert_eq!(m.vertices.len(), 6);
    }

    #[test]
    fn a_binary_stl_whose_header_says_solid_is_still_read_as_binary() {
        // **很多匯出器的二進位 STL header 裡就寫著 "solid"。** 照字串判斷
        // 會把它當成文字讀，結果一個面都讀不到，而錯誤訊息會變成
        // 「這個檔案裡沒有東西」—— 指不到真正的原因。
        let mut data = binary_stl(&[[(0.0, 0.0, 0.0), (1.0, 0.0, 0.0), (0.0, 1.0, 0.0)]]);
        data[..5].copy_from_slice(b"solid");
        let m = parse(&data, "stl").unwrap();
        assert_eq!(m.faces.len(), 1);
    }

    #[test]
    fn an_ascii_stl_becomes_a_mesh() {
        let ascii = "\
solid t
facet normal 0 0 1
  outer loop
    vertex 0 0 0
    vertex 1 0 0
    vertex 0 1 0
  endloop
endfacet
endsolid t
";
        let m = parse(ascii.as_bytes(), "stl").unwrap();
        assert_eq!(m.faces.len(), 1);
    }

    #[test]
    fn an_unknown_extension_is_refused_with_a_reason() {
        let e = parse(b"whatever", "glb").unwrap_err();
        assert_eq!(e, MeshError::UnsupportedFormat);
        assert_eq!(e.reason_key(), "model_unsupported_format");
    }

    #[test]
    fn a_file_with_no_faces_is_refused_not_shown_empty() {
        // 空白模型與「匯入失敗」在畫面上長得一模一樣。要讓使用者看到理由。
        let e = parse(b"v 0 0 0\nv 1 0 0\n", "obj").unwrap_err();
        assert_eq!(e, MeshError::NoGeometry);
    }

    #[test]
    fn a_huge_model_is_refused_before_it_freezes_the_ui() {
        // 算繪是純軟體的，每次旋轉都要重算每一面。幾十萬面會讓畫面停住，
        // 而使用者看到的是「App 當掉了」，不是「這個模型太複雜」。
        let mut obj = String::from("v 0 0 0\nv 1 0 0\nv 0 1 0\n");
        for _ in 0..(MAX_FACES + 1) {
            obj.push_str("f 1 2 3\n");
        }
        assert_eq!(parse(obj.as_bytes(), "obj").unwrap_err(), MeshError::TooManyFaces);
    }

    #[test]
    fn a_degenerate_model_does_not_produce_nan() {
        // 所有頂點重合時不能除以零 —— NaN 座標畫出來是**什麼都沒有**，
        // 看起來跟「沒匯入成功」一模一樣。
        let obj = "v 5 5 5\nv 5 5 5\nv 5 5 5\nf 1 2 3\n";
        let m = parse(obj.as_bytes(), "obj").unwrap();
        for v in &m.vertices {
            assert!(v.0.is_finite() && v.1.is_finite() && v.2.is_finite(), "{v:?}");
        }
    }

    #[test]
    fn the_extension_may_carry_a_dot_or_capitals() {
        assert!(parse(TETRA_OBJ.as_bytes(), ".OBJ").is_ok());
    }
}
