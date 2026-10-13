// 擴充素材線圖（第二批之三）：數位產品、美學構圖、字體排印、造型語彙、跨平台元件、互動動效、資訊架構、設計系統。
// 見 `asset_art_more.rs` 的說明。每個家族用 `參數` 選款式。

fn draw_more3(code: &str, b: &mut Builder) -> bool {
    let (name, p) = split_code(code);
    match name {
        "device_frame" => device_frame(b, p),
        "wire" => wire(b, p),
        "ai_spatial_ui" => ai_spatial_ui(b),
        "ai_adaptive_dashboard" => ai_adaptive_dashboard(b),
        "comp" => comp(b, p),
        "ai_generative_layout" => ai_generative_layout(b),
        "ai_balance_heatmap" => ai_balance_heatmap(b),
        "typo" => typo(b, p),
        "ai_variable_font" => ai_variable_font(b),
        "ai_type_pairing" => ai_type_pairing(b),
        "motif" => motif(b, p),
        "ai_fractal_tile" => ai_fractal_tile(b),
        "ui" => ui_part(b, p),
        "ai_adaptive_component" => ai_adaptive_component(b),
        "ai_gesture_palette" => ai_gesture_palette(b),
        "gesture" => gesture(b, p),
        "ease" => ease(b, p),
        "ai_predictive_motion" => ai_predictive_motion(b),
        "ai_haptic_map" => ai_haptic_map(b),
        "ia" => ia(b, p),
        "ai_intent_map" => ai_intent_map(b),
        "ai_adaptive_ia" => ai_adaptive_ia(b),
        "token" => token(b, p),
        "ai_token_generator" => ai_token_generator(b),
        "ai_theme_morph" => ai_theme_morph(b),
        _ => return draw_more4(code, b),
    }
    true
}

// ═══ 數位產品 ═══════════════════════════════════════════════════════

fn device_frame(b: &mut Builder, p: &str) {
    match p {
        "tablet" => {
            b.rounded(80.0, 70.0, 240.0, 200.0, 18.0);
            b.rounded(94.0, 84.0, 212.0, 172.0, 6.0);
            b.circle(200.0, 77.0, 2.5);
        }
        "laptop" => {
            b.rounded(100.0, 80.0, 200.0, 140.0, 10.0);
            b.rounded(110.0, 90.0, 180.0, 120.0, 4.0);
            b.poly(&[(70.0, 236.0), (330.0, 236.0), (318.0, 252.0), (82.0, 252.0), (70.0, 236.0)]);
            b.poly(&[(170.0, 236.0), (170.0, 242.0), (230.0, 242.0), (230.0, 236.0)]);
        }
        "monitor" => {
            b.rounded(70.0, 60.0, 260.0, 160.0, 8.0);
            b.rect_open(82.0, 72.0, 236.0, 128.0);
            b.poly(&[(180.0, 220.0), (170.0, 270.0), (230.0, 270.0), (220.0, 220.0)]);
            b.rounded(140.0, 270.0, 120.0, 12.0, 6.0);
        }
        "watch" => {
            b.rounded(150.0, 120.0, 100.0, 120.0, 28.0);
            b.rounded(160.0, 132.0, 80.0, 96.0, 18.0);
            b.rounded(165.0, 50.0, 70.0, 70.0, 8.0);
            b.rounded(165.0, 240.0, 70.0, 60.0, 8.0);
            b.rect_open(250.0, 160.0, 8.0, 22.0);
        }
        _ => {
            b.rounded(140.0, 50.0, 120.0, 240.0, 22.0);
            b.rounded(150.0, 66.0, 100.0, 200.0, 8.0);
            b.rounded(180.0, 56.0, 40.0, 8.0, 4.0);
            b.rounded(184.0, 276.0, 32.0, 6.0, 3.0);
        }
    }
}

fn wire(b: &mut Builder, p: &str) {
    b.rounded(70.0, 50.0, 260.0, 250.0, 10.0);
    b.poly(&[(70.0, 80.0), (330.0, 80.0)]);
    for x in [86.0_f32, 100.0, 114.0] {
        b.circle(x, 65.0, 4.0);
    }
    match p {
        "dashboard" => {
            b.rect_open(84.0, 94.0, 60.0, 196.0);
            for k in 0..4 {
                b.poly(&[(92.0, 114.0 + k as f32 * 30.0), (136.0, 114.0 + k as f32 * 30.0)]);
            }
            for k in 0..3 {
                b.rounded(156.0 + k as f32 * 56.0, 94.0, 48.0, 40.0, 6.0);
            }
            b.poly(&[(160.0, 270.0), (190.0, 230.0), (220.0, 250.0), (250.0, 190.0), (316.0, 210.0)]);
            b.rect_open(156.0, 146.0, 160.0, 134.0);
        }
        "login" => {
            b.circle(200.0, 118.0, 20.0);
            b.rounded(130.0, 158.0, 140.0, 26.0, 6.0);
            b.rounded(130.0, 194.0, 140.0, 26.0, 6.0);
            b.rounded(130.0, 236.0, 140.0, 28.0, 14.0);
        }
        "card_list" => {
            for k in 0..3 {
                let y = 94.0 + k as f32 * 66.0;
                b.rounded(84.0, y, 232.0, 56.0, 8.0);
                b.rect_open(94.0, y + 8.0, 40.0, 40.0);
                b.poly(&[(144.0, y + 20.0), (260.0, y + 20.0)]);
                b.poly(&[(144.0, y + 36.0), (220.0, y + 36.0)]);
            }
        }
        "kanban" => {
            for k in 0..3 {
                let x = 84.0 + k as f32 * 78.0;
                b.rect_open(x, 94.0, 70.0, 196.0);
                for j in 0..(3 - k) {
                    b.rounded(x + 6.0, 108.0 + j as f32 * 50.0, 58.0, 40.0, 4.0);
                }
            }
        }
        "chat" => {
            b.rounded(90.0, 100.0, 140.0, 36.0, 12.0);
            b.rounded(170.0, 150.0, 140.0, 36.0, 12.0);
            b.rounded(90.0, 200.0, 110.0, 36.0, 12.0);
            b.rounded(84.0, 258.0, 190.0, 30.0, 15.0);
            b.circle(296.0, 273.0, 14.0);
        }
        _ => {
            b.rect_open(84.0, 94.0, 232.0, 70.0);
            b.poly(&[(100.0, 120.0), (220.0, 120.0)]);
            b.rounded(100.0, 134.0, 70.0, 20.0, 10.0);
            for k in 0..3 {
                b.rect_open(84.0 + k as f32 * 80.0, 180.0, 72.0, 60.0);
            }
            b.poly(&[(84.0, 262.0), (316.0, 262.0)]);
            b.poly(&[(84.0, 276.0), (260.0, 276.0)]);
        }
    }
}

fn ai_spatial_ui(b: &mut Builder) {
    // 空間運算介面：浮在空間中的多層面板與視線游標
    b.shape(&[(70.0, 120.0), (190.0, 100.0), (190.0, 210.0), (70.0, 230.0)]);
    b.shape(&[(210.0, 90.0), (330.0, 110.0), (330.0, 220.0), (210.0, 200.0)]);
    b.rounded(150.0, 240.0, 100.0, 50.0, 12.0);
    b.circle(200.0, 160.0, 14.0);
    b.circle(200.0, 160.0, 4.0);
    b.dash(&[(200.0, 160.0), (200.0, 240.0)]);
    b.accent(true);
    b.poly(&[(170.0, 160.0), (150.0, 160.0)]);
    b.poly(&[(230.0, 160.0), (250.0, 160.0)]);
    b.accent(false);
}

fn ai_adaptive_dashboard(b: &mut Builder) {
    // 會依使用者重組的儀表板：磚塊 + 重排箭頭
    for (x, y, w, h) in [(60.0_f32, 70.0_f32, 120.0_f32, 80.0_f32), (190.0, 70.0, 150.0, 40.0), (190.0, 118.0, 70.0, 32.0), (270.0, 118.0, 70.0, 32.0), (60.0, 160.0, 90.0, 110.0), (160.0, 160.0, 180.0, 110.0)] {
        b.rounded(x, y, w, h, 8.0);
    }
    b.accent(true);
    b.path(vec![m(120.0, 290.0), c(160.0, 310.0, 240.0, 310.0, 280.0, 290.0)]);
    b.poly(&[(270.0, 284.0), (280.0, 290.0), (272.0, 298.0)]);
    b.accent(false);
}

// ═══ 美學構圖 ═══════════════════════════════════════════════════════

fn comp(b: &mut Builder, p: &str) {
    let (x, y, w, h) = (70.0_f32, 60.0_f32, 260.0_f32, 220.0_f32);
    b.rect_open(x, y, w, h);
    match p {
        "golden_rect" => {
            let phi = 1.618_f32;
            let a = w / phi;
            b.poly(&[(x + a, y), (x + a, y + h)]);
            let b2 = h / phi;
            b.poly(&[(x + a, y + b2), (x + w, y + b2)]);
            let c2 = (w - a) / phi;
            b.poly(&[(x + a + c2, y + b2), (x + a + c2, y + h)]);
        }
        "fibonacci_tiles" => {
            // 黃金矩形逐步切出正方形：左、上、右、下輪流（斐波那契方塊的標準排法）。
            let (mut rx, mut ry, mut rw, mut rh) = (x, y + 20.0, w, w / 1.618);
            for step in 0..7 {
                let side = rw.min(rh);
                match step % 4 {
                    0 => { b.rect_open(rx, ry, side, side); rx += side; rw -= side; }
                    1 => { b.rect_open(rx, ry, side, side); ry += side; rh -= side; }
                    2 => { b.rect_open(rx + rw - side, ry, side, side); rw -= side; }
                    _ => { b.rect_open(rx, ry + rh - side, side, side); rh -= side; }
                }
            }
        }
        "diagonal" => {
            b.poly(&[(x, y + h), (x + w, y)]);
            b.poly(&[(x, y), (x + w * 0.5, y + h * 0.5)]);
            b.poly(&[(x + w * 0.5, y + h * 0.5), (x + w, y + h)]);
            b.circle(x + w * 0.62, y + h * 0.38, 12.0);
        }
        "radial" => {
            let (cx, cy) = (x + w / 2.0, y + h / 2.0);
            for k in 0..12 {
                let a = TAU / 12.0 * k as f32;
                b.poly(&[(cx + 20.0 * a.cos(), cy + 20.0 * a.sin()), (cx + 100.0 * a.cos(), cy + 100.0 * a.sin())]);
            }
            b.circle(cx, cy, 20.0);
            b.circle(cx, cy, 60.0);
        }
        "triangle" => {
            b.poly(&[(x + w / 2.0, y + 20.0), (x + 30.0, y + h - 20.0), (x + w - 30.0, y + h - 20.0), (x + w / 2.0, y + 20.0)]);
            b.dash(&[(x + w / 2.0, y + 20.0), (x + w / 2.0, y + h - 20.0)]);
            b.circle(x + w / 2.0, y + 90.0, 14.0);
        }
        "leading_lines" => {
            for k in 0..7 {
                b.poly(&[(x + k as f32 * 43.0, y + h), (x + w / 2.0, y + h * 0.35)]);
            }
            b.circle(x + w / 2.0, y + h * 0.35, 10.0);
        }
        "frame_in_frame" => {
            b.rect_open(x + 40.0, y + 36.0, w - 80.0, h - 72.0);
            b.rect_open(x + 76.0, y + 66.0, w - 152.0, h - 132.0);
            b.circle(x + w / 2.0, y + h / 2.0, 14.0);
        }
        "symmetry" => {
            b.dash(&[(x + w / 2.0, y - 12.0), (x + w / 2.0, y + h + 12.0)]);
            b.poly(&[(x + 40.0, y + h - 30.0), (x + 70.0, y + 60.0), (x + 120.0, y + h - 30.0)]);
            b.poly(&[(x + w - 40.0, y + h - 30.0), (x + w - 70.0, y + 60.0), (x + w - 120.0, y + h - 30.0)]);
        }
        "negative_space" => {
            b.circle(x + w * 0.78, y + h * 0.72, 24.0);
            b.dash(&[(x + w * 0.78, y + h * 0.72), (x + 24.0, y + 24.0)]);
        }
        _ => {
            // s_curve
            b.path(vec![
                m(x + 20.0, y + h - 20.0),
                c(x + 120.0, y + h - 20.0, x + 40.0, y + 20.0, x + w - 20.0, y + 20.0),
            ]);
            b.circle(x + w - 20.0, y + 20.0, 8.0);
        }
    }
}

fn ai_generative_layout(b: &mut Builder) {
    // 生成式版面：網格內不規則分割，帶一條生成軌跡
    b.rect_open(70.0, 60.0, 260.0, 220.0);
    for (x, y, w, h) in [(80.0_f32, 70.0_f32, 130.0_f32, 90.0_f32), (220.0, 70.0, 100.0, 40.0), (220.0, 118.0, 100.0, 42.0), (80.0, 170.0, 70.0, 100.0), (160.0, 170.0, 160.0, 100.0)] {
        b.rect_open(x, y, w, h);
    }
    b.accent(true);
    b.dash(&[(80.0, 300.0), (150.0, 290.0), (220.0, 304.0), (320.0, 292.0)]);
    b.accent(false);
}

fn ai_balance_heatmap(b: &mut Builder) {
    // 視覺重量熱度圖：同心橢圓 + 重心十字
    b.rect_open(70.0, 60.0, 260.0, 220.0);
    for r in [90.0_f32, 62.0, 36.0] {
        b.ellipse(230.0 - r, 150.0 - r * 0.8, r * 2.0, r * 1.6);
    }
    b.accent(true);
    b.poly(&[(210.0, 150.0), (250.0, 150.0)]);
    b.poly(&[(230.0, 130.0), (230.0, 170.0)]);
    b.accent(false);
    b.dash(&[(200.0, 60.0), (200.0, 280.0)]);
    b.dash(&[(70.0, 170.0), (330.0, 170.0)]);
}

// ═══ 字體排印 ═══════════════════════════════════════════════════════

fn typo(b: &mut Builder, p: &str) {
    match p {
        "baseline_grid" => {
            b.rect_open(70.0, 60.0, 260.0, 230.0);
            for k in 0..12 {
                let y = 74.0 + k as f32 * 18.0;
                b.dash(&[(70.0, y), (330.0, y)]);
            }
            for k in 0..9 {
                b.poly(&[(86.0, 92.0 + k as f32 * 18.0), (86.0 + 200.0 - (k % 3) as f32 * 40.0, 92.0 + k as f32 * 18.0)]);
            }
        }
        "grid_12col" => {
            b.rect_open(70.0, 60.0, 260.0, 230.0);
            for k in 0..12 {
                b.rect_open(80.0 + k as f32 * 20.5, 70.0, 14.0, 210.0);
            }
        }
        "margins_vdg" => {
            b.rect_open(60.0, 50.0, 280.0, 250.0);
            b.poly(&[(60.0, 300.0), (340.0, 50.0)]);
            b.poly(&[(60.0, 50.0), (340.0, 300.0)]);
            b.rect_open(60.0 + 280.0 / 9.0, 50.0 + 250.0 / 9.0, 280.0 * 7.0 / 9.0, 250.0 * 7.0 / 9.0);
        }
        "measure" => {
            for k in 0..9 {
                b.poly(&[(100.0, 90.0 + k as f32 * 20.0), (300.0 - (k % 4) as f32 * 14.0, 90.0 + k as f32 * 20.0)]);
            }
            b.accent(true);
            b.poly(&[(100.0, 280.0), (300.0, 280.0)]);
            b.poly(&[(100.0, 274.0), (100.0, 286.0)]);
            b.poly(&[(300.0, 274.0), (300.0, 286.0)]);
            b.accent(false);
        }
        "hierarchy" => {
            b.poly(&[(90.0, 100.0), (310.0, 100.0)]);
            b.width(6.0);
            b.poly(&[(90.0, 100.0), (250.0, 100.0)]);
            b.width(DEFAULT_WIDTH);
            b.poly(&[(90.0, 140.0), (280.0, 140.0)]);
            for k in 0..5 {
                b.width(1.2);
                b.poly(&[(90.0, 180.0 + k as f32 * 18.0), (310.0 - (k % 2) as f32 * 40.0, 180.0 + k as f32 * 18.0)]);
            }
            b.width(DEFAULT_WIDTH);
        }
        "drop_cap" => {
            b.rect_open(90.0, 90.0, 70.0, 70.0);
            b.poly(&[(106.0, 144.0), (125.0, 106.0), (144.0, 144.0)]);
            for k in 0..8 {
                let x0 = if k < 4 { 172.0 } else { 90.0 };
                b.poly(&[(x0, 96.0 + k as f32 * 18.0), (310.0, 96.0 + k as f32 * 18.0)]);
            }
        }
        "kerning_pairs" => {
            b.rect_open(80.0, 120.0, 90.0, 110.0);
            b.rect_open(190.0, 120.0, 90.0, 110.0);
            b.accent(true);
            b.poly(&[(170.0, 250.0), (190.0, 250.0)]);
            b.poly(&[(170.0, 244.0), (170.0, 256.0)]);
            b.poly(&[(190.0, 244.0), (190.0, 256.0)]);
            b.accent(false);
            b.dash(&[(60.0, 230.0), (340.0, 230.0)]);
        }
        "serif_anatomy" => {
            b.poly(&[(120.0, 250.0), (160.0, 250.0)]);
            b.poly(&[(140.0, 250.0), (140.0, 100.0)]);
            b.poly(&[(120.0, 100.0), (160.0, 100.0)]);
            b.poly(&[(210.0, 250.0), (210.0, 100.0)]);
            b.dash(&[(80.0, 250.0), (330.0, 250.0)]);
            b.dash(&[(80.0, 100.0), (330.0, 100.0)]);
            b.dash(&[(80.0, 150.0), (330.0, 150.0)]);
        }
        "leading_scale" => {
            for (k, gap) in [14.0_f32, 20.0, 30.0].iter().enumerate() {
                let x = 80.0 + k as f32 * 85.0;
                for j in 0..6 {
                    b.poly(&[(x, 90.0 + j as f32 * gap), (x + 66.0, 90.0 + j as f32 * gap)]);
                }
            }
        }
        _ => {
            // ligatures
            b.path(vec![m(110.0, 250.0), l(110.0, 120.0), c(110.0, 90.0, 150.0, 90.0, 150.0, 120.0)]);
            b.poly(&[(90.0, 150.0), (170.0, 150.0)]);
            b.poly(&[(210.0, 250.0), (210.0, 120.0)]);
            b.circle(210.0, 100.0, 6.0);
            b.path(vec![m(240.0, 250.0), l(240.0, 120.0), c(240.0, 90.0, 280.0, 90.0, 280.0, 120.0)]);
            b.dash(&[(190.0, 250.0), (310.0, 250.0)]);
        }
    }
}

fn ai_variable_font(b: &mut Builder) {
    // 可變字型：同一個字形在粗細軸上的三種權重
    for (k, w) in [3.0_f32, 8.0, 16.0].iter().enumerate() {
        let x = 100.0 + k as f32 * 90.0;
        b.width(*w);
        b.poly(&[(x, 240.0), (x + 22.0, 110.0), (x + 44.0, 240.0)]);
        b.width(DEFAULT_WIDTH);
    }
    b.accent(true);
    b.poly(&[(90.0, 270.0), (330.0, 270.0)]);
    b.poly(&[(320.0, 264.0), (330.0, 270.0), (320.0, 276.0)]);
    b.accent(false);
}

fn ai_type_pairing(b: &mut Builder) {
    // 字體配對：襯線與無襯線的 A，中間以相容性連線
    b.poly(&[(90.0, 240.0), (130.0, 110.0), (170.0, 240.0)]);
    b.poly(&[(78.0, 240.0), (102.0, 240.0)]);
    b.poly(&[(158.0, 240.0), (182.0, 240.0)]);
    b.poly(&[(230.0, 240.0), (270.0, 110.0), (310.0, 240.0)]);
    b.poly(&[(245.0, 190.0), (295.0, 190.0)]);
    b.accent(true);
    b.dash(&[(180.0, 175.0), (222.0, 175.0)]);
    b.circle(200.0, 175.0, 10.0);
    b.accent(false);
}

// ═══ 造型語彙與工藝紋樣 ═════════════════════════════════════════════

fn motif(b: &mut Builder, p: &str) {
    match p {
        "seigaiha" => {
            for row in 0..5 {
                for col in 0..5 {
                    let cx = 90.0 + col as f32 * 56.0 + if row % 2 == 1 { 28.0 } else { 0.0 };
                    let cy = 90.0 + row as f32 * 32.0;
                    for r in [26.0_f32, 18.0, 10.0] {
                        b.path(arc_segs_start(cx, cy, r, 180.0, 360.0));
                    }
                }
            }
        }
        "asanoha" => {
            for row in 0..4 {
                for col in 0..4 {
                    let (cx, cy) = (110.0 + col as f32 * 60.0, 100.0 + row as f32 * 60.0);
                    for k in 0..6 {
                        let a = TAU / 6.0 * k as f32;
                        b.poly(&[(cx, cy), (cx + 30.0 * a.cos(), cy + 30.0 * a.sin())]);
                    }
                    b.shape(&hex_pts(cx, cy, 30.0));
                }
            }
        }
        "kikko" => {
            for row in 0..4 {
                for col in 0..5 {
                    let cx = 90.0 + col as f32 * 52.0 + if row % 2 == 1 { 26.0 } else { 0.0 };
                    let cy = 90.0 + row as f32 * 45.0;
                    b.shape(&hex_pts(cx, cy, 30.0));
                }
            }
        }
        "meander" => {
            let mut pts = vec![(70.0_f32, 200.0_f32)];
            let mut x = 70.0;
            while x < 320.0 {
                pts.extend([(x, 150.0), (x + 40.0, 150.0), (x + 40.0, 190.0), (x + 20.0, 190.0), (x + 20.0, 170.0), (x + 40.0, 170.0)]);
                pts.push((x + 40.0, 200.0));
                x += 50.0;
            }
            b.poly(&pts);
            b.poly(&[(70.0, 100.0), (330.0, 100.0)]);
            b.poly(&[(70.0, 230.0), (330.0, 230.0)]);
        }
        "quatrefoil" => {
            for (dx, dy) in [(-28.0_f32, 0.0_f32), (28.0, 0.0), (0.0, -28.0), (0.0, 28.0)] {
                b.circle(200.0 + dx, 170.0 + dy, 40.0);
            }
            b.circle(200.0, 170.0, 12.0);
        }
        "herringbone" => {
            for row in 0..6 {
                for col in 0..6 {
                    let (x, y) = (80.0 + col as f32 * 40.0, 80.0 + row as f32 * 36.0);
                    if (row + col) % 2 == 0 {
                        b.shape(&[(x, y), (x + 36.0, y + 14.0), (x + 30.0, y + 28.0), (x - 6.0, y + 14.0)]);
                    } else {
                        b.shape(&[(x, y + 14.0), (x + 36.0, y), (x + 42.0, y + 14.0), (x + 6.0, y + 28.0)]);
                    }
                }
            }
        }
        "chevron" => {
            for k in 0..7 {
                let y = 70.0 + k as f32 * 34.0;
                b.poly(&[(80.0, y + 24.0), (200.0, y), (320.0, y + 24.0)]);
            }
        }
        "trellis" => {
            let mut x0 = 60.0_f32;
            while x0 <= 340.0 {
                if x0 + 120.0 <= 340.0 {
                    b.poly(&[(x0, 60.0), (x0 + 120.0, 300.0)]);
                }
                if x0 - 120.0 >= 60.0 {
                    b.poly(&[(x0, 60.0), (x0 - 120.0, 300.0)]);
                }
                x0 += 36.0;
            }
            b.rect_open(60.0, 60.0, 280.0, 240.0);
        }
        "mandala" => {
            let n = 12;
            for k in 0..n {
                let a = TAU / n as f32 * k as f32;
                b.ellipse(200.0 + 70.0 * a.cos() - 14.0, 170.0 + 70.0 * a.sin() - 14.0, 28.0, 28.0);
            }
            b.circle(200.0, 170.0, 40.0);
            b.circle(200.0, 170.0, 100.0);
            for k in 0..n {
                let a = TAU / n as f32 * (k as f32 + 0.5);
                b.poly(&[(200.0 + 40.0 * a.cos(), 170.0 + 40.0 * a.sin()), (200.0 + 100.0 * a.cos(), 170.0 + 100.0 * a.sin())]);
            }
        }
        _ => {
            // star:8 角星（伊斯蘭幾何）
            let n = 8;
            let mut pts = Vec::new();
            for k in 0..n * 2 {
                let r = if k % 2 == 0 { 110.0 } else { 56.0 };
                let a = TAU / (n * 2) as f32 * k as f32 - PI / 2.0;
                pts.push((200.0 + r * a.cos(), 170.0 + r * a.sin()));
            }
            b.shape(&pts);
            b.circle(200.0, 170.0, 28.0);
            b.circle(200.0, 170.0, 128.0);
        }
    }
}

/// 以圓心、半徑、起訖角（度）畫圓弧，含起點 Move。
fn arc_segs_start(cx: f32, cy: f32, r: f32, a0: f32, a1: f32) -> Vec<FfiPathSeg> {
    let mut v = vec![m(cx + r * a0.to_radians().cos(), cy + r * a0.to_radians().sin())];
    v.extend(arc_segs(cx, cy, r, a0, a1));
    v
}

fn ai_fractal_tile(b: &mut Builder) {
    // 自相似拼貼：三層遞減的三角形
    fn tri(b: &mut Builder, cx: f32, cy: f32, r: f32, depth: u32) {
        let pts: Vec<(f32, f32)> = (0..3)
            .map(|i| {
                let a = TAU / 3.0 * i as f32 - PI / 2.0;
                (cx + r * a.cos(), cy + r * a.sin())
            })
            .collect();
        b.shape(&pts);
        if depth > 0 {
            for p in &pts {
                tri(b, (cx + p.0) / 2.0 + (p.0 - cx) * 0.0, (cy + p.1) / 2.0, r / 2.0, depth - 1);
            }
        }
    }
    tri(b, 200.0, 190.0, 120.0, 2);
}

// ═══ 跨平台系統標準件 ═══════════════════════════════════════════════

fn ui_part(b: &mut Builder, p: &str) {
    match p {
        "button_ios" => {
            b.rounded(110.0, 140.0, 180.0, 50.0, 25.0);
            b.poly(&[(160.0, 165.0), (240.0, 165.0)]);
            b.rounded(110.0, 210.0, 180.0, 50.0, 12.0);
        }
        "button_material" => {
            b.rounded(110.0, 140.0, 180.0, 44.0, 8.0);
            b.poly(&[(160.0, 162.0), (240.0, 162.0)]);
            b.circle(300.0, 230.0, 28.0);
            b.poly(&[(290.0, 230.0), (310.0, 230.0)]);
            b.poly(&[(300.0, 220.0), (300.0, 240.0)]);
        }
        "toggle" => {
            b.rounded(90.0, 120.0, 90.0, 50.0, 25.0);
            b.circle(155.0, 145.0, 19.0);
            b.rounded(220.0, 120.0, 90.0, 50.0, 25.0);
            b.circle(245.0, 145.0, 19.0);
            b.rounded(90.0, 200.0, 220.0, 8.0, 4.0);
            b.circle(240.0, 204.0, 16.0);
        }
        "nav_bar" => {
            b.rounded(70.0, 100.0, 260.0, 56.0, 6.0);
            b.poly(&[(86.0, 128.0), (100.0, 116.0)]);
            b.poly(&[(86.0, 128.0), (100.0, 140.0)]);
            b.poly(&[(170.0, 128.0), (240.0, 128.0)]);
            b.circle(308.0, 128.0, 8.0);
        }
        "tab_bar" => {
            b.rounded(70.0, 220.0, 260.0, 60.0, 6.0);
            for k in 0..4 {
                let x = 100.0 + k as f32 * 66.0;
                b.circle(x, 242.0, 10.0);
                b.poly(&[(x - 14.0, 266.0), (x + 14.0, 266.0)]);
            }
            b.accent(true);
            b.circle(100.0, 242.0, 10.0);
            b.accent(false);
        }
        "dialog" => {
            b.rounded(100.0, 90.0, 200.0, 140.0, 16.0);
            b.poly(&[(124.0, 124.0), (250.0, 124.0)]);
            b.poly(&[(124.0, 148.0), (276.0, 148.0)]);
            b.poly(&[(124.0, 164.0), (230.0, 164.0)]);
            b.poly(&[(100.0, 192.0), (300.0, 192.0)]);
            b.poly(&[(200.0, 192.0), (200.0, 230.0)]);
        }
        "list_row" => {
            for k in 0..4 {
                let y = 90.0 + k as f32 * 50.0;
                b.circle(104.0, y + 20.0, 14.0);
                b.poly(&[(132.0, y + 14.0), (250.0, y + 14.0)]);
                b.poly(&[(132.0, y + 30.0), (210.0, y + 30.0)]);
                b.poly(&[(296.0, y + 14.0), (306.0, y + 22.0), (296.0, y + 30.0)]);
                b.poly(&[(80.0, y + 44.0), (320.0, y + 44.0)]);
            }
        }
        "search_bar" => {
            b.rounded(80.0, 140.0, 240.0, 44.0, 22.0);
            b.circle(110.0, 162.0, 9.0);
            b.poly(&[(117.0, 169.0), (126.0, 178.0)]);
            b.poly(&[(140.0, 162.0), (240.0, 162.0)]);
            b.circle(296.0, 162.0, 8.0);
        }
        "segmented" => {
            b.rounded(80.0, 140.0, 240.0, 40.0, 10.0);
            b.poly(&[(160.0, 140.0), (160.0, 180.0)]);
            b.poly(&[(240.0, 140.0), (240.0, 180.0)]);
            b.rounded(84.0, 144.0, 72.0, 32.0, 8.0);
        }
        _ => {
            // slider
            b.rounded(80.0, 160.0, 240.0, 8.0, 4.0);
            b.rounded(80.0, 160.0, 150.0, 8.0, 4.0);
            b.circle(230.0, 164.0, 16.0);
            b.poly(&[(80.0, 190.0), (80.0, 200.0)]);
            b.poly(&[(200.0, 190.0), (200.0, 200.0)]);
            b.poly(&[(320.0, 190.0), (320.0, 200.0)]);
        }
    }
}

fn ai_adaptive_component(b: &mut Builder) {
    // 隨情境變形的元件：同一個按鈕的三種形態
    b.rounded(70.0, 130.0, 70.0, 70.0, 35.0);
    b.rounded(160.0, 140.0, 100.0, 50.0, 12.0);
    b.rounded(280.0, 120.0, 60.0, 90.0, 8.0);
    b.accent(true);
    b.poly(&[(142.0, 165.0), (158.0, 165.0)]);
    b.poly(&[(262.0, 165.0), (278.0, 165.0)]);
    b.accent(false);
}

fn ai_gesture_palette(b: &mut Builder) {
    // 手勢調色盤：環狀選單
    b.circle(200.0, 170.0, 110.0);
    b.circle(200.0, 170.0, 40.0);
    for k in 0..6 {
        let a = TAU / 6.0 * k as f32;
        b.poly(&[(200.0 + 40.0 * a.cos(), 170.0 + 40.0 * a.sin()), (200.0 + 110.0 * a.cos(), 170.0 + 110.0 * a.sin())]);
        let a2 = a + TAU / 12.0;
        b.circle(200.0 + 75.0 * a2.cos(), 170.0 + 75.0 * a2.sin(), 9.0);
    }
    b.accent(true);
    b.circle(200.0, 170.0, 12.0);
    b.accent(false);
}

// ═══ 互動手勢與動效軌跡 ═════════════════════════════════════════════

fn gesture(b: &mut Builder, p: &str) {
    // 手指點用圓表示，箭頭表示移動方向
    fn finger(b: &mut Builder, x: f32, y: f32) {
        b.circle(x, y, 18.0);
        b.circle(x, y, 6.0);
    }
    match p {
        "tap" => {
            finger(b, 200.0, 170.0);
            b.circle(200.0, 170.0, 40.0);
        }
        "double_tap" => {
            finger(b, 200.0, 170.0);
            b.circle(200.0, 170.0, 40.0);
            b.circle(200.0, 170.0, 62.0);
        }
        "long_press" => {
            finger(b, 200.0, 170.0);
            for k in 0..12 {
                let a = TAU / 12.0 * k as f32;
                b.poly(&[(200.0 + 44.0 * a.cos(), 170.0 + 44.0 * a.sin()), (200.0 + 52.0 * a.cos(), 170.0 + 52.0 * a.sin())]);
            }
        }
        "swipe" => {
            finger(b, 110.0, 170.0);
            b.accent(true);
            b.poly(&[(140.0, 170.0), (300.0, 170.0)]);
            b.poly(&[(286.0, 156.0), (300.0, 170.0), (286.0, 184.0)]);
            b.accent(false);
        }
        "pinch" => {
            finger(b, 150.0, 210.0);
            finger(b, 250.0, 130.0);
            b.accent(true);
            b.poly(&[(172.0, 192.0), (190.0, 174.0)]);
            b.poly(&[(228.0, 148.0), (210.0, 166.0)]);
            b.accent(false);
        }
        "rotate" => {
            finger(b, 150.0, 200.0);
            finger(b, 250.0, 140.0);
            b.accent(true);
            b.path(vec![m(250.0, 190.0), c(290.0, 190.0, 290.0, 120.0, 250.0, 100.0)]);
            b.accent(false);
        }
        "drag" => {
            finger(b, 130.0, 150.0);
            b.rounded(180.0, 120.0, 100.0, 60.0, 8.0);
            b.accent(true);
            b.poly(&[(160.0, 150.0), (178.0, 150.0)]);
            b.accent(false);
            b.dash(&[(230.0, 190.0), (230.0, 250.0)]);
        }
        _ => {
            // scroll
            finger(b, 200.0, 250.0);
            b.rect_open(150.0, 60.0, 100.0, 140.0);
            b.accent(true);
            b.poly(&[(200.0, 230.0), (200.0, 130.0)]);
            b.poly(&[(188.0, 144.0), (200.0, 130.0), (212.0, 144.0)]);
            b.accent(false);
        }
    }
}

fn ease(b: &mut Builder, p: &str) {
    // 畫一條 100% 方框內的時間—進度曲線
    let (x0, y0, w, h) = (90.0_f32, 60.0_f32, 220.0_f32, 220.0_f32);
    b.rect_open(x0, y0, w, h);
    b.dash(&[(x0, y0 + h), (x0 + w, y0)]);
    let pt = |t: f32, v: f32| (x0 + t * w, y0 + h - v * h);
    b.accent(true);
    match p {
        "ease_in" => b.path(vec![m(x0, y0 + h), c(x0 + 0.42 * w, y0 + h, x0 + w, y0 + h - h, x0 + w, y0)]),
        "ease_out" => b.path(vec![m(x0, y0 + h), c(x0, y0 + h - 0.58 * h, x0 + 0.58 * w, y0, x0 + w, y0)]),
        "ease_in_out" => b.path(vec![m(x0, y0 + h), c(x0 + 0.42 * w, y0 + h, x0 + 0.58 * w, y0, x0 + w, y0)]),
        "linear" => b.poly(&[pt(0.0, 0.0), pt(1.0, 1.0)]),
        "bounce" => b.poly(&[pt(0.0, 0.0), pt(0.36, 1.0), pt(0.52, 0.76), pt(0.68, 1.0), pt(0.8, 0.92), pt(0.9, 1.0), pt(1.0, 1.0)]),
        _ => b.path(vec![m(x0, y0 + h), c(x0 + 0.3 * w, y0 + h, x0 + 0.4 * w, y0 - 0.25 * h, x0 + 0.62 * w, y0 - 0.08 * h), c(x0 + 0.8 * w, y0 + 0.02 * h, x0 + 0.9 * w, y0, x0 + w, y0)]),
    };
    b.accent(false);
}

fn ai_predictive_motion(b: &mut Builder) {
    // 預測動效：實線是已發生的軌跡，虛線是預測
    b.path(vec![m(70.0, 250.0), c(120.0, 250.0, 150.0, 120.0, 210.0, 130.0)]);
    b.accent(true);
    b.dash(&[(210.0, 130.0), (250.0, 124.0), (290.0, 100.0), (330.0, 80.0)]);
    b.accent(false);
    b.circle(210.0, 130.0, 10.0);
    b.circle(330.0, 80.0, 18.0);
}

fn ai_haptic_map(b: &mut Builder) {
    // 觸覺地圖：螢幕區塊對應不同震動強度的波形
    b.rounded(70.0, 70.0, 150.0, 220.0, 16.0);
    for k in 0..3 {
        let y = 100.0 + k as f32 * 64.0;
        b.rect_open(86.0, y, 118.0, 48.0);
    }
    for k in 0..3 {
        let y = 124.0 + k as f32 * 64.0;
        let amp = 8.0 + k as f32 * 10.0;
        let mut pts = Vec::new();
        for i in 0..14 {
            pts.push((240.0 + i as f32 * 7.5, y + if i % 2 == 0 { -amp } else { amp }));
        }
        b.poly(&pts);
    }
}

// ═══ 資訊架構與服務流程 ═════════════════════════════════════════════

fn ia(b: &mut Builder, p: &str) {
    match p {
        "user_flow" => {
            b.rounded(60.0, 130.0, 70.0, 40.0, 20.0);
            b.poly(&[(130.0, 150.0), (160.0, 150.0)]);
            b.rect_open(160.0, 125.0, 80.0, 50.0);
            b.poly(&[(200.0, 175.0), (200.0, 210.0)]);
            b.poly(&[(200.0, 210.0), (240.0, 235.0), (200.0, 260.0), (160.0, 235.0), (200.0, 210.0)]);
            b.poly(&[(240.0, 150.0), (280.0, 150.0)]);
            b.rounded(280.0, 130.0, 60.0, 40.0, 20.0);
        }
        "journey_map" => {
            b.poly(&[(60.0, 230.0), (120.0, 190.0), (180.0, 210.0), (240.0, 120.0), (300.0, 160.0), (340.0, 100.0)]);
            for (x, y) in [(60.0_f32, 230.0_f32), (120.0, 190.0), (180.0, 210.0), (240.0, 120.0), (300.0, 160.0)] {
                b.circle(x, y, 8.0);
            }
            for k in 0..5 {
                b.rect_open(60.0 + k as f32 * 56.0, 260.0, 48.0, 22.0);
            }
        }
        "card_sort" => {
            for k in 0..9 {
                b.rounded(70.0 + (k % 3) as f32 * 52.0, 80.0 + (k / 3) as f32 * 52.0, 44.0, 44.0, 6.0);
            }
            b.rect_open(250.0, 80.0, 80.0, 150.0);
            b.rounded(258.0, 94.0, 64.0, 30.0, 6.0);
            b.rounded(258.0, 136.0, 64.0, 30.0, 6.0);
        }
        "funnel" => {
            b.poly(&[(80.0, 80.0), (320.0, 80.0), (260.0, 150.0), (140.0, 150.0), (80.0, 80.0)]);
            b.poly(&[(140.0, 150.0), (260.0, 150.0), (230.0, 220.0), (170.0, 220.0), (140.0, 150.0)]);
            b.poly(&[(170.0, 220.0), (230.0, 220.0), (215.0, 280.0), (185.0, 280.0), (170.0, 220.0)]);
        }
        "pyramid" => {
            b.poly(&[(200.0, 70.0), (320.0, 280.0), (80.0, 280.0), (200.0, 70.0)]);
            for y in [130.0_f32, 190.0, 240.0] {
                let half = (y - 70.0) / 210.0 * 120.0;
                b.poly(&[(200.0 - half, y), (200.0 + half, y)]);
            }
        }
        "venn" => {
            b.circle(160.0, 150.0, 80.0);
            b.circle(240.0, 150.0, 80.0);
            b.circle(200.0, 210.0, 80.0);
        }
        "swimlane" => {
            for k in 0..3 {
                b.rect_open(60.0, 70.0 + k as f32 * 70.0, 280.0, 64.0);
                b.rect_open(60.0, 70.0 + k as f32 * 70.0, 28.0, 64.0);
            }
            b.rounded(110.0, 90.0, 60.0, 26.0, 6.0);
            b.rounded(190.0, 160.0, 60.0, 26.0, 6.0);
            b.rounded(260.0, 230.0, 60.0, 26.0, 6.0);
            b.poly(&[(170.0, 103.0), (220.0, 103.0), (220.0, 160.0)]);
            b.poly(&[(250.0, 173.0), (290.0, 173.0), (290.0, 230.0)]);
        }
        "kanban_flow" => {
            for k in 0..4 {
                b.rect_open(60.0 + k as f32 * 68.0, 80.0, 60.0, 190.0);
                for j in 0..((4 - k) as usize).min(3) {
                    b.rounded(66.0 + k as f32 * 68.0, 96.0 + j as f32 * 44.0, 48.0, 34.0, 4.0);
                }
            }
        }
        "tree_nav" => {
            b.rounded(160.0, 60.0, 80.0, 30.0, 6.0);
            b.poly(&[(200.0, 90.0), (200.0, 120.0)]);
            b.poly(&[(100.0, 120.0), (300.0, 120.0)]);
            for x in [100.0_f32, 200.0, 300.0] {
                b.poly(&[(x, 120.0), (x, 140.0)]);
                b.rounded(x - 36.0, 140.0, 72.0, 30.0, 6.0);
                b.poly(&[(x, 170.0), (x, 200.0)]);
                b.rounded(x - 30.0, 200.0, 60.0, 26.0, 6.0);
            }
        }
        _ => {
            // hub_spoke
            b.circle(200.0, 170.0, 36.0);
            for k in 0..6 {
                let a = TAU / 6.0 * k as f32;
                b.poly(&[(200.0 + 36.0 * a.cos(), 170.0 + 36.0 * a.sin()), (200.0 + 96.0 * a.cos(), 170.0 + 96.0 * a.sin())]);
                b.circle(200.0 + 112.0 * a.cos(), 170.0 + 112.0 * a.sin(), 16.0);
            }
        }
    }
}

fn ai_intent_map(b: &mut Builder) {
    // 意圖地圖：中心問題向外長出的語意分支
    b.circle(200.0, 170.0, 24.0);
    for k in 0..5 {
        let a = TAU / 5.0 * k as f32 - PI / 2.0;
        let (mx, my) = (200.0 + 70.0 * a.cos(), 170.0 + 70.0 * a.sin());
        b.poly(&[(200.0 + 24.0 * a.cos(), 170.0 + 24.0 * a.sin()), (mx, my)]);
        b.circle(mx, my, 12.0);
        for s in [-0.45_f32, 0.45] {
            b.dash(&[(mx, my), (200.0 + 118.0 * (a + s).cos(), 170.0 + 118.0 * (a + s).sin())]);
        }
    }
    b.accent(true);
    b.circle(200.0, 170.0, 8.0);
    b.accent(false);
}

fn ai_adaptive_ia(b: &mut Builder) {
    // 自適應導覽：同一棵樹依使用者重新排列（上下兩種排法）
    b.rounded(150.0, 60.0, 100.0, 26.0, 6.0);
    for x in [90.0_f32, 170.0, 250.0] {
        b.poly(&[(200.0, 86.0), (x + 30.0, 116.0)]);
        b.rounded(x, 116.0, 60.0, 24.0, 5.0);
    }
    b.accent(true);
    b.poly(&[(200.0, 160.0), (200.0, 190.0)]);
    b.poly(&[(190.0, 180.0), (200.0, 190.0), (210.0, 180.0)]);
    b.accent(false);
    b.rounded(150.0, 210.0, 100.0, 26.0, 6.0);
    for x in [250.0_f32, 170.0, 90.0] {
        b.poly(&[(200.0, 236.0), (x + 30.0, 262.0)]);
        b.rounded(x, 262.0, 60.0, 24.0, 5.0);
    }
}

// ═══ 設計系統原子元件 ═══════════════════════════════════════════════

fn token(b: &mut Builder, p: &str) {
    match p {
        "color_scale" => {
            for k in 0..10 {
                b.rect_open(60.0 + k as f32 * 28.0, 110.0, 28.0, 120.0);
            }
            b.poly(&[(60.0, 250.0), (340.0, 250.0)]);
        }
        "type_scale" => {
            let sizes = [14.0_f32, 18.0, 24.0, 32.0, 44.0];
            let mut x = 70.0;
            for s in sizes {
                b.poly(&[(x, 250.0), (x + s * 0.5, 250.0 - s * 3.0), (x + s, 250.0)]);
                x += s + 18.0;
            }
            b.dash(&[(60.0, 250.0), (340.0, 250.0)]);
        }
        "radius_scale" => {
            for (k, r) in [0.0_f32, 6.0, 12.0, 20.0, 36.0].iter().enumerate() {
                b.rounded(60.0 + k as f32 * 56.0, 130.0, 48.0, 90.0, *r);
            }
        }
        "elevation" => {
            for k in 0..4 {
                let y = 120.0 + k as f32 * 4.0;
                let x = 80.0 + k as f32 * 66.0;
                b.rounded(x, y, 56.0, 80.0, 8.0);
                b.rounded(x + 3.0, y + 8.0 + k as f32 * 2.0, 56.0, 80.0, 8.0);
            }
        }
        "breakpoints" => {
            b.rect_open(60.0, 70.0, 280.0, 200.0);
            for x in [120.0_f32, 200.0, 270.0] {
                b.dash(&[(x, 60.0), (x, 280.0)]);
            }
            b.poly(&[(60.0, 290.0), (340.0, 290.0)]);
        }
        "icon_sizes" => {
            let mut x = 70.0;
            for s in [16.0_f32, 24.0, 32.0, 48.0, 64.0] {
                b.rounded(x, 200.0 - s, s, s, s / 6.0);
                b.circle(x + s / 2.0, 200.0 - s / 2.0, s / 4.0);
                x += s + 16.0;
            }
        }
        "opacity_ramp" => {
            for k in 0..10 {
                b.rect_open(60.0 + k as f32 * 28.0, 120.0, 28.0, 100.0);
                for j in 0..(k / 2) {
                    b.poly(&[(60.0 + k as f32 * 28.0 + 4.0, 130.0 + j as f32 * 10.0), (60.0 + k as f32 * 28.0 + 24.0, 130.0 + j as f32 * 10.0)]);
                }
            }
        }
        "stroke_weights" => {
            for (k, w) in [1.0_f32, 2.0, 4.0, 6.0, 10.0].iter().enumerate() {
                b.width(*w);
                b.poly(&[(80.0, 100.0 + k as f32 * 40.0), (320.0, 100.0 + k as f32 * 40.0)]);
            }
            b.width(DEFAULT_WIDTH);
        }
        "motion_durations" => {
            for (k, w) in [40.0_f32, 80.0, 140.0, 220.0].iter().enumerate() {
                b.rounded(70.0, 100.0 + k as f32 * 44.0, *w, 24.0, 12.0);
            }
            b.poly(&[(70.0, 90.0), (70.0, 290.0)]);
        }
        _ => {
            // spacing_4pt
            let mut x = 70.0;
            for s in [4.0_f32, 8.0, 12.0, 16.0, 24.0, 32.0, 48.0] {
                b.rect_open(x, 220.0 - s, s, s);
                x += s + 10.0;
            }
        }
    }
}

fn ai_token_generator(b: &mut Builder) {
    // 設計變數產生器：一個種子色展開成一排色階
    b.circle(110.0, 170.0, 30.0);
    b.accent(true);
    b.poly(&[(146.0, 170.0), (186.0, 170.0)]);
    b.poly(&[(176.0, 160.0), (186.0, 170.0), (176.0, 180.0)]);
    b.accent(false);
    for k in 0..6 {
        b.rect_open(200.0 + k as f32 * 24.0, 140.0, 22.0, 60.0);
    }
    b.dash(&[(200.0, 220.0), (344.0, 220.0)]);
}

fn ai_theme_morph(b: &mut Builder) {
    // 主題變形：亮色與暗色元件之間的漸變
    b.rounded(60.0, 120.0, 90.0, 100.0, 12.0);
    b.rounded(250.0, 120.0, 90.0, 100.0, 12.0);
    for k in 0..4 {
        b.dash(&[(156.0 + k as f32 * 2.0, 130.0 + k as f32 * 6.0), (244.0 - k as f32 * 2.0, 130.0 + k as f32 * 6.0)]);
    }
    b.circle(105.0, 170.0, 14.0);
    b.accent(true);
    b.path(vec![m(250.0 + 45.0 - 14.0, 156.0), c(250.0 + 45.0 + 8.0, 160.0, 250.0 + 45.0 + 8.0, 182.0, 250.0 + 45.0 - 14.0, 184.0)]);
    b.accent(false);
}
