//! 圖學的二維製圖工具：尺寸標註、符號、圖框與標題欄、對齊輔助、編輯運算、批改、題庫、匯出。
//!
//! 純幾何，不碰 UI、不碰檔案。兩個平台從 `padnote-core` 的 FFI 呼叫它，同一個操作在
//! Apple 與 Android 上產生完全相同的線 —— 與 [`padnote_solid`] 同一個模式。
//!
//! # 座標與單位
//!
//! 一律是**頁面座標**（原點在左上、y 向下），與筆畫、圖紙排版相同。頁面單位與紙張毫米的關係固定：
//! A4（210 mm）寬 800 單位，所以 [`UNITS_PER_MM`] ≈ 3.81（A3、A2 與自訂尺寸都用同一個比例）。
//! 標註的數字是**紙上毫米 × 比例尺**（例如 1:2 的圖，紙上量 50 mm 標 100）。
//!
//! # 輸出
//!
//! 輸出是 [`Drawing`]：一組帶**角色**的折線（[`Role`]，由呼叫端換成實際的製圖筆與圖層），
//! 加上要放文字方塊的標籤（語系鍵，由平台翻成使用者的語言）。數字與符號都是筆畫字形，
//! 不是文字方塊 —— 這樣它們會跟著圖層、橡皮擦與匯出一起走。

pub mod dim;
pub mod fastener;
pub mod frame;
pub mod gdt;
pub mod symbols;

pub use padnote_solid::geom::P2;
pub use padnote_solid::sheet::{Role, SheetStroke};

/// 頁面單位／毫米。A4 寬 210 mm = 800 單位。
pub const UNITS_PER_MM: f32 = 800.0 / 210.0;

/// 要放在圖上的一段文字（語系鍵，由平台翻譯、建成文字方塊）。
#[derive(Clone, Debug, PartialEq)]
pub struct TextLabel {
    pub key: String,
    /// 方塊左上角（頁面座標）。
    pub x: f32,
    pub y: f32,
    pub width: f32,
    /// 字級（頁面單位）。
    pub size: f32,
    pub bold: bool,
}

/// 一組製圖成品：折線（含角色）與文字標籤。
#[derive(Clone, Debug, Default)]
pub struct Drawing {
    pub strokes: Vec<SheetStroke>,
    pub labels: Vec<TextLabel>,
}

impl Drawing {
    pub fn line(&mut self, role: Role, a: P2, b: P2) {
        self.strokes.push(SheetStroke {
            role,
            points: vec![a, b],
        });
    }

    pub fn polyline(&mut self, role: Role, points: Vec<P2>) {
        if points.len() >= 2 {
            self.strokes.push(SheetStroke { role, points });
        }
    }

    /// 所有折線的包圍盒。
    pub fn bounds(&self) -> Option<(P2, P2)> {
        let pts: Vec<P2> = self
            .strokes
            .iter()
            .flat_map(|s| s.points.iter().copied())
            .collect();
        padnote_solid::geom::bounds(&pts)
    }

    /// 整體平移。
    pub fn translate(&mut self, dx: f32, dy: f32) {
        for s in &mut self.strokes {
            for p in &mut s.points {
                *p = (p.0 + dx, p.1 + dy);
            }
        }
        for l in &mut self.labels {
            l.x += dx;
            l.y += dy;
        }
    }
}
