//! 隱藏線演算法的效能：離譜大的輪廓（兩百邊外框＋二十個三十二邊的孔）也要在手感可接受的時間內出圖。
//! 時間預算只在 release 組建檢查；真正的數字用 `cargo test --release -p padnote-solid --test perf -- --nocapture` 看。

use padnote_solid::sheet::{SheetOptions, compose};
use padnote_solid::solid::{Profile, Solid};
use std::time::Instant;

fn circle(cx: f32, cy: f32, r: f32, n: usize) -> Vec<(f32, f32)> {
    (0..n)
        .map(|i| {
            let a = i as f32 / n as f32 * std::f32::consts::TAU;
            (cx + r * a.cos(), cy + r * a.sin())
        })
        .collect()
}

fn busy_solid() -> Solid {
    let outer = circle(150.0, 150.0, 140.0, 200);
    let mut holes = Vec::new();
    for k in 0..20 {
        let a = k as f32 / 20.0 * std::f32::consts::TAU;
        holes.push(circle(
            150.0 + 90.0 * a.cos(),
            150.0 + 90.0 * a.sin(),
            12.0,
            32,
        ));
    }
    Solid::new(Profile::new(outer, holes).expect("profile"), 60.0)
}

#[test]
fn composing_a_very_busy_solid_stays_interactive() {
    let solid = busy_solid();
    let t = Instant::now();
    let sheet = compose(&solid, &SheetOptions::default());
    let ms = t.elapsed().as_millis();
    println!("busy solid: {} strokes in {ms} ms", sheet.strokes.len());
    assert!(!sheet.strokes.is_empty());
    // 只在 release 檢查時間：debug 組建（CI 預設）沒有最佳化，慢十倍以上，牆上時鐘的斷言只會製造假紅燈。
    if !cfg!(debug_assertions) {
        assert!(ms < 5000, "compose took {ms} ms");
    }
}

#[test]
fn typical_presets_compose_quickly() {
    for name in [
        "rect",
        "circle",
        "hexagon",
        "l_shape",
        "t_shape",
        "u_channel",
        "washer",
        "plate_holes",
    ] {
        let Some(p) = padnote_solid::solid::preset(name, 240.0, 180.0) else {
            continue;
        };
        let solid = Solid::new(p, 140.0);
        let t = Instant::now();
        let sheet = compose(&solid, &SheetOptions::default());
        println!(
            "{name}: {} strokes in {} ms",
            sheet.strokes.len(),
            t.elapsed().as_millis()
        );
    }
}
