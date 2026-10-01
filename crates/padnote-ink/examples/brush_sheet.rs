//! 開發用：把每支自繪筆刷畫在一張圖上（PPM），用肉眼檢查筆跡像不像真的。
//!
//! 用法：`cargo run -p padnote-ink --example brush_sheet -- /tmp/sheet.ppm`
//! 算繪方式與兩個平台一致（橢圓、柔邊疊四層、明暗向黑白偏 35%），只是用軟體光柵化。

use padnote_ink::{InkPoint, Tool, dabs};

const W: usize = 960;
const H: usize = 780;

fn stroke(f: impl Fn(f32) -> (f32, f32, f32, f32), n: usize) -> Vec<InkPoint> {
    (0..=n)
        .map(|i| {
            let t = i as f32 / n as f32;
            let (x, y, p, tilt) = f(t);
            let mut pt = InkPoint::new(x, y, p, 8_000);
            pt.tilt = tilt;
            pt
        })
        .collect()
}

fn blend(img: &mut [f32], x: i32, y: i32, rgb: [f32; 3], a: f32) {
    if x < 0 || y < 0 || x >= W as i32 || y >= H as i32 || a <= 0.0 {
        return;
    }
    let i = (y as usize * W + x as usize) * 3;
    for c in 0..3 {
        img[i + c] = img[i + c] * (1.0 - a) + rgb[c] * a;
    }
}

fn ellipse(
    img: &mut [f32],
    d: &padnote_ink::Dab,
    base: [f32; 3],
    alpha_scale: f32,
    k: f32,
    rx: f32,
    ry: f32,
) {
    let target = if d.shade >= 0.0 { 1.0 } else { 0.0 };
    let m = d.shade.abs() * 0.35;
    let rgb = [
        base[0] + (target - base[0]) * m,
        base[1] + (target - base[1]) * m,
        base[2] + (target - base[2]) * m,
    ];
    let reach = rx.max(ry).ceil() as i32 + 1;
    let (s, c) = d.angle.sin_cos();
    for dy in -reach..=reach {
        for dx in -reach..=reach {
            let (px, py) = (
                (d.x as i32 + dx) as f32 + 0.5 - d.x,
                (d.y as i32 + dy) as f32 + 0.5 - d.y,
            );
            // 旋轉回橢圓座標。
            let (u, v) = (px * c + py * s, -px * s + py * c);
            let e = (u / rx).powi(2) + (v / ry).powi(2);
            // 邊緣 1px 內做反鋸齒；小於一個像素的顆粒用覆蓋率縮小 alpha。
            let cover = ((1.0 - e.sqrt()) * rx.min(ry).max(0.5) + 0.5).clamp(0.0, 1.0);
            if cover > 0.0 {
                blend(
                    img,
                    d.x as i32 + dx,
                    d.y as i32 + dy,
                    rgb,
                    d.alpha * alpha_scale * k * cover,
                );
            }
        }
    }
}

fn draw(img: &mut [f32], dabs: &[padnote_ink::Dab], base: [f32; 3]) {
    for d in dabs {
        if d.softness > 0.5 {
            for step in 0..4 {
                let f = 1.0 - step as f32 * 0.22;
                ellipse(img, d, base, 1.0, 0.34, d.rx * f, d.ry * f);
            }
        } else {
            ellipse(img, d, base, 1.0, 1.0, d.rx, d.ry);
        }
    }
}

fn main() {
    let out = std::env::args()
        .nth(1)
        .unwrap_or_else(|| "/tmp/brush_sheet.ppm".into());
    let mut img = vec![0.98f32; W * H * 3];
    let tools = [
        (Tool::Fineliner, "fineliner", [0.1, 0.1, 0.12], 6.0),
        (Tool::Calligraphy, "calligraphy", [0.1, 0.1, 0.12], 12.0),
        (Tool::Charcoal, "charcoal", [0.08, 0.08, 0.09], 14.0),
        (Tool::Crayon, "crayon", [0.84, 0.2, 0.42], 14.0),
        (Tool::Airbrush, "airbrush", [0.2, 0.4, 0.85], 18.0),
        (Tool::OilPaint, "oilpaint", [0.75, 0.2, 0.15], 18.0),
    ];
    for (row, (tool, _name, color, width)) in tools.iter().enumerate() {
        let y0 = 60.0 + row as f32 * 120.0;
        // 1. 輕壓到重壓的 S 形
        let s = stroke(
            |t| {
                (
                    30.0 + 300.0 * t,
                    y0 + 28.0 * (t * std::f32::consts::TAU).sin(),
                    0.15 + 0.85 * (t * std::f32::consts::PI).sin(),
                    0.2,
                )
            },
            80,
        );
        draw(&mut img, &dabs(*tool, &s, *width), *color);
        // 2. 重壓直線（看顆粒填滿的程度）
        let s = stroke(|t| (370.0 + 200.0 * t, y0 - 20.0 + 40.0 * t, 1.0, 0.2), 40);
        draw(&mut img, &dabs(*tool, &s, *width), *color);
        // 3. 輕壓直線
        let s = stroke(|t| (370.0 + 200.0 * t, y0 + 25.0 + 20.0 * t, 0.2, 0.2), 40);
        draw(&mut img, &dabs(*tool, &s, *width), *color);
        // 4. 側著畫（傾角大）
        let s = stroke(
            |t| (600.0 + 160.0 * t, y0 + 10.0 * (t * 9.0).sin(), 0.7, 1.2),
            40,
        );
        draw(&mut img, &dabs(*tool, &s, *width), *color);
        // 5. 兩筆交叉：紙紋要一致
        let a = stroke(|t| (790.0 + 150.0 * t, y0 - 25.0 + 50.0 * t, 0.7, 0.2), 30);
        let b = stroke(|t| (790.0 + 150.0 * t, y0 + 25.0 - 50.0 * t, 0.7, 0.2), 30);
        draw(&mut img, &dabs(*tool, &a, *width), *color);
        draw(&mut img, &dabs(*tool, &b, *width), *color);
    }
    let mut bytes = format!("P6\n{W} {H}\n255\n").into_bytes();
    bytes.extend(img.iter().map(|v| (v.clamp(0.0, 1.0) * 255.0) as u8));
    std::fs::write(&out, bytes).unwrap();
    println!("寫到 {out}");
}
