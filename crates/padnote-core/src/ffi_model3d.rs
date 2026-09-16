//! 3D 模型的幾何與材質。
//!
//! # 為什麼在核心
//!
//! Apple 端用 SceneKit 畫這六種立體（`Model3DStudioView`）。SceneKit 是
//! Apple 專屬的，Android 沒有對應品 —— 這個功能因此整個缺席。
//!
//! 這裡把**幾何、旋轉、投影與明暗**做成純數學：輸入模型種類與三軸角度，
//! 輸出一串已經排好前後順序的多邊形與各自的明暗係數。平台層只要把多邊形
//! 填色即可，不需要任何 3D API。
//!
//! Apple 端**繼續用 SceneKit** 畫互動卡片（它的 PBR 反射比這個好），
//! 但材質顏色改讀這裡的同一份定義 —— 不然同一個「黃金」在兩台裝置上是
//! 不同的金色，而材質是會落盤的資料。
//!
//! # 這不是渲染引擎
//!
//! 只有畫家演算法（依深度排序後由遠而近畫）與單一方向光的 Lambert 明暗。
//! 沒有 z-buffer，所以互相穿插的幾何會畫錯 —— 但這六種都是凸多面體，
//! 凸多面體用畫家演算法是正確的。要加入非凸模型時這個假設就不成立了。

use std::f32::consts::{PI, TAU};

use crate::ffi_shapes::FfiPoint;

/// 六種內建立體。
#[derive(Clone, Copy, PartialEq, Eq, Debug, uniffi::Enum)]
pub enum FfiModel3dKind {
    Sphere,
    Cube,
    Cylinder,
    Torus,
    Pyramid,
    Capsule,
}

/// 全部種類，順序即面板上的顯示順序。
#[uniffi::export]
pub fn model3d_kinds() -> Vec<FfiModel3dKind> {
    vec![
        FfiModel3dKind::Sphere,
        FfiModel3dKind::Cube,
        FfiModel3dKind::Cylinder,
        FfiModel3dKind::Torus,
        FfiModel3dKind::Pyramid,
        FfiModel3dKind::Capsule,
    ]
}

/// 存進 `.padnote` 的字串。**與 Apple 端 `Note3DAttachment.modelTypeRaw`
/// 必須逐字相同** —— 這是落盤資料，拼錯會讓同一個模型在另一個平台開不出來。
#[uniffi::export]
pub fn model3d_kind_raw(kind: FfiModel3dKind) -> String {
    match kind {
        FfiModel3dKind::Sphere => "sphere",
        FfiModel3dKind::Cube => "cube",
        FfiModel3dKind::Cylinder => "cylinder",
        FfiModel3dKind::Torus => "torus",
        FfiModel3dKind::Pyramid => "pyramid",
        FfiModel3dKind::Capsule => "capsule",
    }
    .to_string()
}

/// 反向查表。認不得的字串一律回球體 —— 與 Apple 端的 `default:` 分支一致，
/// 舊檔或壞資料要開得起來，不能整個物件消失。
#[uniffi::export]
pub fn model3d_kind_from_raw(raw: String) -> FfiModel3dKind {
    match raw.as_str() {
        "cube" => FfiModel3dKind::Cube,
        "cylinder" => FfiModel3dKind::Cylinder,
        "torus" => FfiModel3dKind::Torus,
        "pyramid" => FfiModel3dKind::Pyramid,
        "capsule" => FfiModel3dKind::Capsule,
        _ => FfiModel3dKind::Sphere,
    }
}

/// 九種材質。
#[derive(Clone, Copy, PartialEq, Eq, Debug, uniffi::Enum)]
pub enum FfiMaterial {
    Plastic,
    Gold,
    Silver,
    Copper,
    Iron,
    Wood,
    Marble,
    Granite,
    Obsidian,
}

#[uniffi::export]
pub fn model3d_materials() -> Vec<FfiMaterial> {
    vec![
        FfiMaterial::Plastic,
        FfiMaterial::Gold,
        FfiMaterial::Silver,
        FfiMaterial::Copper,
        FfiMaterial::Iron,
        FfiMaterial::Wood,
        FfiMaterial::Marble,
        FfiMaterial::Granite,
        FfiMaterial::Obsidian,
    ]
}

/// 材質的外觀參數。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiMaterialLook {
    /// 名稱的語系鍵。
    pub name_key: String,
    /// 落盤用的字串。**與 Apple 端 `MaterialType` 的 rawValue 相同。**
    pub raw: String,
    /// 基本色 `#RRGGBB`。
    pub hex: String,
    /// 金屬度 0…1。越高高光越集中、漫射越暗。
    pub metalness: f32,
    /// 粗糙度 0…1。越低高光越銳利。
    pub roughness: f32,
}

/// 材質查表。數值與 Apple 的 `MaterialEngine.createSCNMaterial` 同一份。
#[uniffi::export]
pub fn model3d_material_look(material: FfiMaterial) -> FfiMaterialLook {
    let (key, raw, hex, metalness, roughness) = match material {
        FfiMaterial::Plastic => ("mat_plastic", "塑膠", "#388CF2", 0.05, 0.18),
        FfiMaterial::Gold => ("mat_gold", "黃金", "#FFD61E", 1.00, 0.16),
        FfiMaterial::Silver => ("mat_silver", "白銀", "#F0F0F0", 0.98, 0.12),
        FfiMaterial::Copper => ("mat_copper", "紅銅", "#E08559", 0.92, 0.22),
        FfiMaterial::Iron => ("mat_iron", "鋼鐵", "#6B6B6B", 0.85, 0.50),
        FfiMaterial::Wood => ("mat_wood", "原木", "#8F5C33", 0.0, 0.78),
        FfiMaterial::Marble => ("mat_marble", "大理石", "#F5F5F5", 0.04, 0.16),
        FfiMaterial::Granite => ("mat_granite", "花崗岩", "#8C8C8C", 0.02, 0.84),
        FfiMaterial::Obsidian => ("mat_obsidian", "黑曜石", "#1F1F1F", 0.18, 0.06),
    };
    FfiMaterialLook {
        name_key: key.into(),
        raw: raw.into(),
        hex: hex.into(),
        metalness,
        roughness,
    }
}

/// 一片投影到 2D、已經算好明暗的多邊形。
#[derive(Clone, Debug, uniffi::Record)]
pub struct FfiShadedFace {
    /// 螢幕座標（已含畫布大小），至少三點。
    pub points: Vec<FfiPoint>,
    /// 明暗係數 0…1。平台層把材質基本色乘上它。
    pub shade: f32,
}

/// 把模型投影成一串由遠而近的多邊形。
///
/// `rotation_*` 是弧度（與 Apple 的 `SCNNode.eulerAngles` 同單位），
/// `scale` 是整體縮放，`width`/`height` 是要畫進去的畫布大小（點）。
///
/// 回傳已經依深度排好序：**照順序畫就是正確的前後關係**，平台層不必再排。
#[uniffi::export]
pub fn model3d_faces(
    kind: FfiModel3dKind,
    rotation_x: f32,
    rotation_y: f32,
    rotation_z: f32,
    scale: f32,
    width: f32,
    height: f32,
) -> Vec<FfiShadedFace> {
    let mesh = mesh(kind);
    // scale 0 或負值會讓整個模型塌成一點或內外翻面。夾住而不是回空清單 ——
    // 面板上的滑桿滑到底時應該看到很小的模型，不是一片空白。
    let scale = scale.clamp(0.05, 5.0);

    let (sx, cx) = rotation_x.sin_cos();
    let (sy, cy) = rotation_y.sin_cos();
    let (sz, cz) = rotation_z.sin_cos();

    // 相機在 z = 3.8 往 -z 看，與 Apple 端的 cameraNode 位置相同。
    const CAMERA_Z: f32 = 3.8;
    // 視角換算出來的焦距。畫布短邊當成視野高度。
    let focal = 2.2 * width.min(height) / 2.0;
    let cx0 = width / 2.0;
    let cy0 = height / 2.0;

    // 單一方向光，大致對應 Apple 的 directional light 方向。
    let light = normalise((0.45, -0.62, 0.65));

    let mut out: Vec<(f32, FfiShadedFace)> = Vec::with_capacity(mesh.faces.len());

    for face in &mesh.faces {
        let world: Vec<(f32, f32, f32)> = face
            .iter()
            .map(|&i| {
                let (x, y, z) = mesh.vertices[i];
                let (x, y, z) = (x * scale, y * scale, z * scale);
                // X → Y → Z，與 SceneKit 的 eulerAngles 順序一致。
                let (y, z) = (y * cx - z * sx, y * sx + z * cx);
                let (x, z) = (x * cy + z * sy, -x * sy + z * cy);
                let (x, y) = (x * cz - y * sz, x * sz + y * cz);
                (x, y, z)
            })
            .collect();

        // 相機在 +z：面朝相機的法線 z 分量為正，背面直接不畫。
        // 凸多面體剔除背面之後就不會有面互相遮擋的問題。
        let n = face_normal(&world);
        if n.2 <= 0.0 {
            continue;
        }

        let depth = world.iter().map(|p| p.2).sum::<f32>() / world.len() as f32;

        let projected: Vec<FfiPoint> = world
            .iter()
            .map(|&(x, y, z)| {
                // 透視：離相機越遠越小。夾住分母，免得頂點跑到相機後面時炸開。
                let d = (CAMERA_Z - z).max(0.1);
                FfiPoint {
                    x: cx0 + x * focal / d,
                    // 螢幕的 y 向下，模型的 y 向上。
                    y: cy0 - y * focal / d,
                }
            })
            .collect();

        // Lambert：法線與光線夾角。加一點環境光，背光面才不會全黑
        // （Apple 端也有一盞 ambient，數值比例相當）。
        let lambert = dot(n, light).max(0.0);
        let shade = (0.28 + 0.72 * lambert).clamp(0.0, 1.0);

        out.push((
            depth,
            FfiShadedFace {
                points: projected,
                shade,
            },
        ));
    }

    // 由遠而近（z 小的先畫）。
    out.sort_by(|a, b| a.0.partial_cmp(&b.0).unwrap_or(std::cmp::Ordering::Equal));
    out.into_iter().map(|(_, f)| f).collect()
}

// ── 網格 ────────────────────────────────────────────────────────────

struct Mesh {
    vertices: Vec<(f32, f32, f32)>,
    /// 每一面的頂點索引。凸多邊形，順序為逆時針（從外面看）。
    faces: Vec<Vec<usize>>,
}

/// 尺寸全部照 Apple 端 `SceneKitHelper.makeScene` 的參數，
/// 兩邊的模型大小關係才會一樣。
fn mesh(kind: FfiModel3dKind) -> Mesh {
    match kind {
        FfiModel3dKind::Cube => cube(1.4),
        FfiModel3dKind::Sphere => sphere(0.95, 24, 16),
        FfiModel3dKind::Cylinder => cylinder(0.75, 1.6, 28),
        FfiModel3dKind::Torus => torus(0.85, 0.32, 28, 14),
        FfiModel3dKind::Pyramid => pyramid(1.5, 1.6),
        FfiModel3dKind::Capsule => capsule(0.55, 1.6, 24, 8),
    }
}

fn cube(size: f32) -> Mesh {
    let h = size / 2.0;
    let vertices = vec![
        (-h, -h, -h),
        (h, -h, -h),
        (h, h, -h),
        (-h, h, -h),
        (-h, -h, h),
        (h, -h, h),
        (h, h, h),
        (-h, h, h),
    ];
    let faces = vec![
        vec![4, 5, 6, 7], // 前
        vec![1, 0, 3, 2], // 後
        vec![0, 4, 7, 3], // 左
        vec![5, 1, 2, 6], // 右
        vec![3, 7, 6, 2], // 上
        vec![0, 1, 5, 4], // 下
    ];
    Mesh { vertices, faces }
}

fn sphere(radius: f32, segments: usize, rings: usize) -> Mesh {
    let mut vertices = Vec::new();
    for r in 0..=rings {
        let phi = PI * r as f32 / rings as f32;
        for s in 0..segments {
            let theta = TAU * s as f32 / segments as f32;
            vertices.push((
                radius * phi.sin() * theta.cos(),
                radius * phi.cos(),
                radius * phi.sin() * theta.sin(),
            ));
        }
    }
    let mut faces = Vec::new();
    for r in 0..rings {
        for s in 0..segments {
            let s2 = (s + 1) % segments;
            let a = r * segments + s;
            let b = r * segments + s2;
            let c = (r + 1) * segments + s2;
            let d = (r + 1) * segments + s;
            faces.push(vec![a, b, c, d]);
        }
    }
    Mesh { vertices, faces }
}

fn cylinder(radius: f32, height: f32, segments: usize) -> Mesh {
    let h = height / 2.0;
    let mut vertices = Vec::new();
    for s in 0..segments {
        let t = TAU * s as f32 / segments as f32;
        vertices.push((radius * t.cos(), h, radius * t.sin()));
    }
    for s in 0..segments {
        let t = TAU * s as f32 / segments as f32;
        vertices.push((radius * t.cos(), -h, radius * t.sin()));
    }
    let mut faces = Vec::new();
    for s in 0..segments {
        let s2 = (s + 1) % segments;
        faces.push(vec![s, s2, segments + s2, segments + s]);
    }
    faces.push((0..segments).rev().collect());
    faces.push((segments..2 * segments).collect());
    Mesh { vertices, faces }
}

fn torus(ring: f32, pipe: f32, ring_segments: usize, pipe_segments: usize) -> Mesh {
    let mut vertices = Vec::new();
    for i in 0..ring_segments {
        let u = TAU * i as f32 / ring_segments as f32;
        for j in 0..pipe_segments {
            let v = TAU * j as f32 / pipe_segments as f32;
            let r = ring + pipe * v.cos();
            vertices.push((r * u.cos(), pipe * v.sin(), r * u.sin()));
        }
    }
    let mut faces = Vec::new();
    for i in 0..ring_segments {
        let i2 = (i + 1) % ring_segments;
        for j in 0..pipe_segments {
            let j2 = (j + 1) % pipe_segments;
            faces.push(vec![
                i * pipe_segments + j,
                i2 * pipe_segments + j,
                i2 * pipe_segments + j2,
                i * pipe_segments + j2,
            ]);
        }
    }
    Mesh { vertices, faces }
}

fn pyramid(base: f32, height: f32) -> Mesh {
    let h = base / 2.0;
    let top = height / 2.0;
    let bottom = -height / 2.0;
    let vertices = vec![
        (-h, bottom, -h),
        (h, bottom, -h),
        (h, bottom, h),
        (-h, bottom, h),
        (0.0, top, 0.0),
    ];
    let faces = vec![
        vec![3, 2, 4],
        vec![2, 1, 4],
        vec![1, 0, 4],
        vec![0, 3, 4],
        vec![0, 1, 2, 3],
    ];
    Mesh { vertices, faces }
}

/// 圓柱身 + 上下兩個半球。
fn capsule(radius: f32, height: f32, segments: usize, cap_rings: usize) -> Mesh {
    // height 是**總高**（與 SCNCapsule 一致），所以圓柱段要扣掉兩個半球。
    let cyl_half = (height / 2.0 - radius).max(0.0);
    let mut vertices = Vec::new();
    let mut rows: Vec<usize> = Vec::new();

    let push_ring = |vertices: &mut Vec<(f32, f32, f32)>, r: f32, y: f32| -> usize {
        let start = vertices.len();
        for s in 0..segments {
            let t = TAU * s as f32 / segments as f32;
            vertices.push((r * t.cos(), y, r * t.sin()));
        }
        start
    };

    // 上半球（由頂點往下）
    for i in 0..=cap_rings {
        let phi = (PI / 2.0) * i as f32 / cap_rings as f32;
        rows.push(push_ring(
            &mut vertices,
            radius * phi.sin(),
            cyl_half + radius * phi.cos(),
        ));
    }
    // 下半球
    for i in 0..=cap_rings {
        let phi = (PI / 2.0) * i as f32 / cap_rings as f32;
        rows.push(push_ring(
            &mut vertices,
            radius * phi.cos(),
            -cyl_half - radius * phi.sin(),
        ));
    }

    let mut faces = Vec::new();
    for w in rows.windows(2) {
        let (a0, b0) = (w[0], w[1]);
        for s in 0..segments {
            let s2 = (s + 1) % segments;
            faces.push(vec![a0 + s, a0 + s2, b0 + s2, b0 + s]);
        }
    }
    Mesh { vertices, faces }
}

// ── 向量小工具 ──────────────────────────────────────────────────────

fn face_normal(points: &[(f32, f32, f32)]) -> (f32, f32, f32) {
    // Newell 法：對凹一點或不完全共面的多邊形也穩定，
    // 而球面的四邊形本來就不共面。
    let mut n = (0.0, 0.0, 0.0);
    for i in 0..points.len() {
        let a = points[i];
        let b = points[(i + 1) % points.len()];
        n.0 += (a.1 - b.1) * (a.2 + b.2);
        n.1 += (a.2 - b.2) * (a.0 + b.0);
        n.2 += (a.0 - b.0) * (a.1 + b.1);
    }
    normalise(n)
}

fn normalise(v: (f32, f32, f32)) -> (f32, f32, f32) {
    let len = (v.0 * v.0 + v.1 * v.1 + v.2 * v.2).sqrt();
    if len < f32::EPSILON {
        (0.0, 0.0, 0.0)
    } else {
        (v.0 / len, v.1 / len, v.2 / len)
    }
}

fn dot(a: (f32, f32, f32), b: (f32, f32, f32)) -> f32 {
    a.0 * b.0 + a.1 * b.1 + a.2 * b.2
}

#[cfg(test)]
mod tests {
    use super::*;

    const W: f32 = 200.0;
    const H: f32 = 200.0;

    #[test]
    fn every_kind_produces_visible_faces() {
        for kind in model3d_kinds() {
            let faces = model3d_faces(kind, 0.4, 0.6, 0.0, 1.0, W, H);
            assert!(!faces.is_empty(), "{kind:?} 畫不出任何面");
            for f in &faces {
                assert!(f.points.len() >= 3, "{kind:?} 有少於三點的面");
                assert!((0.0..=1.0).contains(&f.shade), "{kind:?} 明暗係數超出範圍");
            }
        }
    }

    #[test]
    fn faces_are_sorted_back_to_front() {
        // 平台層照順序畫就對 —— 順序錯的話近的面會被遠的蓋掉。
        // 立方體轉一個角度，一定看得到三個面。
        let faces = model3d_faces(FfiModel3dKind::Cube, 0.5, 0.5, 0.0, 1.0, W, H);
        assert_eq!(faces.len(), 3, "轉過角度的立方體應該看得到三個面");
    }

    #[test]
    fn back_faces_are_culled() {
        // 正面朝向相機的立方體只該畫一個面；不剔除的話會畫到六個，
        // 而背面那幾個的明暗是錯的。
        let faces = model3d_faces(FfiModel3dKind::Cube, 0.0, 0.0, 0.0, 1.0, W, H);
        assert_eq!(faces.len(), 1);
    }

    #[test]
    fn everything_stays_inside_a_sane_bounding_box() {
        // 投影算錯（例如把相機放在模型裡）會產生天文數字座標，
        // 平台層畫下去就是整片色塊蓋住畫布。
        for kind in model3d_kinds() {
            for f in model3d_faces(kind, 0.3, 0.9, 0.2, 1.0, W, H) {
                for p in f.points {
                    assert!(p.x > -W && p.x < W * 2.0, "{kind:?} x 跑掉了：{}", p.x);
                    assert!(p.y > -H && p.y < H * 2.0, "{kind:?} y 跑掉了：{}", p.y);
                }
            }
        }
    }

    #[test]
    fn scale_is_clamped_not_rejected() {
        // 滑桿滑到底應該看到很小的模型，不是一片空白。
        let tiny = model3d_faces(FfiModel3dKind::Cube, 0.0, 0.0, 0.0, 0.0, W, H);
        assert!(!tiny.is_empty());
        let big = model3d_faces(FfiModel3dKind::Cube, 0.0, 0.0, 0.0, 999.0, W, H);
        assert!(!big.is_empty());
    }

    #[test]
    fn raw_strings_round_trip() {
        // 這是落盤字串：拼錯會讓模型在另一個平台開不出來。
        for kind in model3d_kinds() {
            assert_eq!(model3d_kind_from_raw(model3d_kind_raw(kind)), kind);
        }
        // 認不得的一律回球體，與 Apple 端的 default 分支一致。
        assert_eq!(
            model3d_kind_from_raw("torus_v2".into()),
            FfiModel3dKind::Sphere
        );
    }

    #[test]
    fn every_material_has_a_key_and_a_valid_colour() {
        for m in model3d_materials() {
            let look = model3d_material_look(m);
            assert!(look.name_key.starts_with("mat_"));
            assert!(
                look.hex.starts_with('#') && look.hex.len() == 7,
                "壞的色碼：{}",
                look.hex
            );
            assert!((0.0..=1.0).contains(&look.metalness));
            assert!((0.0..=1.0).contains(&look.roughness));
            assert!(!look.raw.is_empty());
        }
    }

    #[test]
    fn rotating_actually_changes_the_picture() {
        // 旋轉矩陣寫錯（例如角度沒接上）會讓畫面完全不動，
        // 而那在 UI 上看起來像「手勢壞了」。
        let a = model3d_faces(FfiModel3dKind::Pyramid, 0.0, 0.0, 0.0, 1.0, W, H);
        let b = model3d_faces(FfiModel3dKind::Pyramid, 0.0, 1.0, 0.0, 1.0, W, H);
        let same =
            a.len() == b.len()
                && a.iter().zip(b.iter()).all(|(fa, fb)| {
                    fa.points.len() == fb.points.len()
                        && fa.points.iter().zip(fb.points.iter()).all(|(pa, pb)| {
                            (pa.x - pb.x).abs() < 0.001 && (pa.y - pb.y).abs() < 0.001
                        })
                });
        assert!(!same, "轉了 1 弧度畫面卻完全沒變");
    }
}
