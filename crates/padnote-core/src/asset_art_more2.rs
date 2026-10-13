// 擴充素材線圖（第二批之二）：汽車載具、工業家具、3C 電子。見 `asset_art_more.rs` 的說明。

fn draw_more2(code: &str, b: &mut Builder) -> bool {
    let (name, p) = split_code(code);
    match name {
        // ── 汽車載具 ─────────────────────────────────────────────
        "rim_spokes" => rim_spokes(b, p),
        "brake_disc" => brake_disc(b, p),
        "car_profile" => car_profile(b, p),
        "turbocharger" => turbocharger(b),
        "shock_absorber" => shock_absorber(b),
        "piston_rod" => piston_rod(b),
        "ai_flying_car" => ai_flying_car(b),
        "ai_modular_ev" => ai_modular_ev(b),
        // ── 工業家具 ─────────────────────────────────────────────
        "chair" => chair(b, p),
        "table" => table(b, p),
        "shelf" => shelf(b, p),
        "sofa" => sofa(b, p),
        "bed_frame" => bed_frame(b),
        "floor_lamp" => floor_lamp(b),
        "cabinet" => cabinet(b),
        "ai_modular_furniture" => ai_modular_furniture(b),
        "ai_floating_lounge" => ai_floating_lounge(b),
        // ── 3C 電子 ──────────────────────────────────────────────
        "pcb" => pcb(b, p),
        "connector" => connector(b, p),
        "ic_qfp" => ic_qfp(b, p),
        "ic_dip" => ic_dip(b, p),
        "passive" => passive(b, p),
        "smartwatch" => smartwatch(b),
        "power_bank" => power_bank(b),
        "wireless_charger" => wireless_charger(b),
        "smart_speaker" => smart_speaker(b),
        "vr_headset" => vr_headset(b),
        "ai_foldable_display" => ai_foldable_display(b),
        "ai_neural_wearable" => ai_neural_wearable(b),
        _ => return draw_more3(code, b),
    }
    true
}

// ═══ 汽車載具 ═══════════════════════════════════════════════════════

fn rim_spokes(b: &mut Builder, p: &str) {
    let n = num(p, 5.0).clamp(3.0, 12.0) as usize;
    let (cx, cy) = (200.0, 170.0);
    b.circle(cx, cy, 130.0);
    b.circle(cx, cy, 112.0);
    b.circle(cx, cy, 30.0);
    for i in 0..n {
        let a = TAU / n as f32 * i as f32 - PI / 2.0;
        let (a0, a1) = (a - 0.12, a + 0.12);
        b.shape(&[
            (cx + 32.0 * a0.cos(), cy + 32.0 * a0.sin()),
            (cx + 108.0 * a0.cos(), cy + 108.0 * a0.sin()),
            (cx + 108.0 * a1.cos(), cy + 108.0 * a1.sin()),
            (cx + 32.0 * a1.cos(), cy + 32.0 * a1.sin()),
        ]);
    }
    for i in 0..5 {
        let a = TAU / 5.0 * i as f32;
        b.circle(cx + 18.0 * a.cos(), cy + 18.0 * a.sin(), 3.5);
    }
}

fn brake_disc(b: &mut Builder, p: &str) {
    let (cx, cy) = (200.0, 170.0);
    b.circle(cx, cy, 130.0);
    b.circle(cx, cy, 52.0);
    b.circle(cx, cy, 26.0);
    for i in 0..5 {
        let a = TAU / 5.0 * i as f32 - PI / 2.0;
        b.circle(cx + 38.0 * a.cos(), cy + 38.0 * a.sin(), 6.0);
    }
    if p == "vented" {
        // 通風槽
        for i in 0..24 {
            let a = TAU / 24.0 * i as f32;
            b.poly(&[
                (cx + 70.0 * a.cos(), cy + 70.0 * a.sin()),
                (cx + 118.0 * (a + 0.18).cos(), cy + 118.0 * (a + 0.18).sin()),
            ]);
        }
    } else {
        // 打孔
        for ring in [78.0_f32, 98.0, 118.0] {
            for i in 0..12 {
                let a = TAU / 12.0 * i as f32 + ring * 0.01;
                b.circle(cx + ring * a.cos(), cy + ring * a.sin(), 4.0);
            }
        }
    }
    center_cross(b, cx, cy, 146.0);
}

fn car_profile(b: &mut Builder, p: &str) {
    // 側視輪廓 + 兩個輪子。p：sedan / suv / hatch
    let (roof_h, rear_drop) = match p {
        "suv" => (88.0_f32, 0.0_f32),
        "hatch" => (100.0, 8.0),
        _ => (112.0, 36.0),
    };
    let base = 230.0;
    b.path(vec![
        m(50.0, base),
        l(50.0, base - 40.0),
        c(52.0, base - 60.0, 90.0, base - 66.0, 120.0, base - 70.0),
        c(150.0, base - 70.0 - roof_h * 0.2, 175.0, base - 70.0 - roof_h, 215.0, base - 70.0 - roof_h),
        c(255.0, base - 70.0 - roof_h, 285.0, base - 70.0 - roof_h * 0.55, 310.0 + rear_drop, base - 70.0),
        c(340.0, base - 64.0, 352.0, base - 56.0, 352.0, base - 36.0),
        l(352.0, base),
        l(50.0, base),
    ]);
    // 窗
    b.poly(&[(150.0, base - 74.0), (186.0, base - 70.0 - roof_h * 0.85), (258.0, base - 70.0 - roof_h * 0.85), (292.0, base - 74.0), (150.0, base - 74.0)]);
    b.poly(&[(220.0, base - 74.0), (220.0, base - 70.0 - roof_h * 0.85)]);
    for x in [118.0_f32, 290.0] {
        b.circle(x, base, 34.0);
        b.circle(x, base, 20.0);
        b.circle(x, base, 6.0);
    }
    b.poly(&[(30.0, base + 34.0), (372.0, base + 34.0)]);
}

fn turbocharger(b: &mut Builder) {
    // 渦輪（左）、壓縮機（右）與中間軸承座
    b.circle(130.0, 170.0, 76.0);
    b.circle(130.0, 170.0, 22.0);
    for i in 0..11 {
        let a = TAU / 11.0 * i as f32;
        b.poly(&[
            (130.0 + 22.0 * a.cos(), 170.0 + 22.0 * a.sin()),
            (130.0 + 70.0 * (a + 0.5).cos(), 170.0 + 70.0 * (a + 0.5).sin()),
        ]);
    }
    b.circle(290.0, 170.0, 56.0);
    b.circle(290.0, 170.0, 16.0);
    for i in 0..8 {
        let a = TAU / 8.0 * i as f32;
        b.poly(&[
            (290.0 + 16.0 * a.cos(), 170.0 + 16.0 * a.sin()),
            (290.0 + 50.0 * (a + 0.6).cos(), 170.0 + 50.0 * (a + 0.6).sin()),
        ]);
    }
    b.rect_open(188.0, 146.0, 50.0, 48.0);
    b.dash(&[(60.0, 170.0), (360.0, 170.0)]);
}

fn shock_absorber(b: &mut Builder) {
    b.rounded(160.0, 40.0, 80.0, 24.0, 6.0);
    b.rect_open(188.0, 64.0, 24.0, 70.0);
    b.rect_open(170.0, 134.0, 60.0, 130.0);
    // 彈簧
    for i in 0..9 {
        let y = 90.0 + i as f32 * 20.0;
        b.poly(&[(140.0, y), (260.0, y + 12.0)]);
    }
    b.rounded(160.0, 264.0, 80.0, 24.0, 6.0);
    b.circle(200.0, 300.0, 8.0);
    b.dash(&[(200.0, 30.0), (200.0, 312.0)]);
}

fn piston_rod(b: &mut Builder) {
    b.rounded(110.0, 60.0, 180.0, 100.0, 8.0);
    for y in [80.0_f32, 92.0, 104.0] {
        b.poly(&[(110.0, y), (290.0, y)]);
    }
    b.circle(200.0, 128.0, 8.0);
    b.rect_open(176.0, 160.0, 48.0, 100.0);
    b.circle(200.0, 280.0, 32.0);
    b.circle(200.0, 280.0, 18.0);
    b.dash(&[(200.0, 44.0), (200.0, 312.0)]);
}

fn ai_flying_car(b: &mut Builder) {
    b.path(vec![
        m(120.0, 210.0),
        c(120.0, 170.0, 160.0, 150.0, 200.0, 150.0),
        c(240.0, 150.0, 280.0, 170.0, 280.0, 210.0),
        l(120.0, 210.0),
    ]);
    for (x, y) in [(80.0_f32, 130.0_f32), (320.0, 130.0), (80.0, 250.0), (320.0, 250.0)] {
        b.circle(x, y, 34.0);
        b.circle(x, y, 8.0);
        b.poly(&[(x - 30.0, y), (x + 30.0, y)]);
        b.poly(&[(x, y - 30.0), (x, y + 30.0)]);
    }
    b.dash(&[(120.0, 190.0), (80.0, 150.0)]);
    b.dash(&[(280.0, 190.0), (320.0, 150.0)]);
    b.dash(&[(130.0, 205.0), (90.0, 235.0)]);
    b.dash(&[(270.0, 205.0), (310.0, 235.0)]);
}

fn ai_modular_ev(b: &mut Builder) {
    // 滑板底盤 + 可更換的上車體模組
    b.rounded(60.0, 230.0, 280.0, 36.0, 12.0);
    for x in [100.0_f32, 300.0] {
        b.circle(x, 270.0, 30.0);
        b.circle(x, 270.0, 12.0);
    }
    b.rounded(80.0, 190.0, 240.0, 30.0, 6.0);
    for k in 0..5 {
        b.rect_open(88.0 + k as f32 * 46.0, 238.0, 36.0, 20.0);
    }
    b.dash(&[(80.0, 150.0), (320.0, 150.0)]);
    b.accent(true);
    b.poly(&[(200.0, 120.0), (200.0, 184.0)]);
    b.poly(&[(190.0, 172.0), (200.0, 184.0), (210.0, 172.0)]);
    b.accent(false);
    b.rounded(110.0, 70.0, 180.0, 50.0, 16.0);
}

// ═══ 工業家具 ═══════════════════════════════════════════════════════

fn chair(b: &mut Builder, p: &str) {
    match p {
        "stool" => {
            b.rounded(120.0, 110.0, 160.0, 24.0, 12.0);
            for (x0, x1) in [(140.0_f32, 120.0_f32), (260.0, 280.0)] {
                b.poly(&[(x0, 134.0), (x1, 290.0)]);
            }
            b.poly(&[(130.0, 220.0), (270.0, 220.0)]);
        }
        "office" => {
            b.rounded(130.0, 60.0, 140.0, 90.0, 18.0);
            b.rounded(120.0, 160.0, 160.0, 28.0, 12.0);
            b.rect_open(192.0, 188.0, 16.0, 70.0);
            b.poly(&[(100.0, 285.0), (200.0, 258.0), (300.0, 285.0)]);
            for x in [100.0_f32, 200.0, 300.0] {
                b.circle(x, 296.0, 9.0);
            }
            b.path(vec![m(120.0, 175.0), c(90.0, 175.0, 90.0, 215.0, 120.0, 215.0)]);
        }
        _ => {
            b.rounded(130.0, 60.0, 130.0, 14.0, 4.0);
            b.poly(&[(140.0, 74.0), (140.0, 180.0)]);
            b.poly(&[(250.0, 74.0), (250.0, 180.0)]);
            b.rect_open(110.0, 180.0, 160.0, 20.0);
            b.poly(&[(124.0, 200.0), (112.0, 290.0)]);
            b.poly(&[(256.0, 200.0), (268.0, 290.0)]);
            b.poly(&[(140.0, 130.0), (250.0, 130.0)]);
        }
    }
}

fn table(b: &mut Builder, p: &str) {
    match p {
        "coffee" => {
            b.rounded(70.0, 150.0, 260.0, 18.0, 6.0);
            b.poly(&[(100.0, 168.0), (90.0, 260.0)]);
            b.poly(&[(300.0, 168.0), (310.0, 260.0)]);
            b.rect_open(110.0, 230.0, 180.0, 10.0);
        }
        "desk" => {
            b.rounded(60.0, 120.0, 280.0, 18.0, 4.0);
            b.rect_open(70.0, 138.0, 70.0, 120.0);
            b.poly(&[(70.0, 175.0), (140.0, 175.0)]);
            b.poly(&[(70.0, 215.0), (140.0, 215.0)]);
            b.poly(&[(328.0, 138.0), (328.0, 258.0)]);
            b.poly(&[(290.0, 138.0), (290.0, 258.0)]);
        }
        _ => {
            b.rounded(60.0, 110.0, 280.0, 20.0, 6.0);
            for x in [86.0_f32, 306.0] {
                b.rect_open(x, 130.0, 14.0, 150.0);
            }
            b.poly(&[(100.0, 150.0), (306.0, 150.0)]);
            b.dash(&[(200.0, 90.0), (200.0, 300.0)]);
        }
    }
}

fn shelf(b: &mut Builder, p: &str) {
    if p == "wall" {
        for y in [100.0_f32, 170.0, 240.0] {
            b.rect_open(100.0, y, 200.0, 8.0);
            b.poly(&[(120.0, y + 8.0), (120.0, y + 26.0)]);
            b.poly(&[(280.0, y + 8.0), (280.0, y + 26.0)]);
        }
    } else {
        b.rect_open(100.0, 60.0, 200.0, 240.0);
        for y in [110.0_f32, 160.0, 210.0, 260.0] {
            b.poly(&[(100.0, y), (300.0, y)]);
        }
        b.poly(&[(200.0, 60.0), (200.0, 160.0)]);
        b.rect_open(88.0, 300.0, 224.0, 10.0);
    }
}

fn sofa(b: &mut Builder, p: &str) {
    let seats = num(p, 2.0).clamp(1.0, 4.0) as usize;
    let w = 80.0 + 60.0 * seats as f32;
    let x0 = 200.0 - w / 2.0 - 20.0;
    b.rounded(x0 + 10.0, 100.0, w + 20.0, 70.0, 22.0);
    b.rounded(x0, 150.0, w + 40.0, 80.0, 16.0);
    for i in 1..seats {
        let x = x0 + 20.0 + w * i as f32 / seats as f32;
        b.poly(&[(x, 170.0), (x, 224.0)]);
    }
    b.rect_open(x0 + 14.0, 230.0, 14.0, 26.0);
    b.rect_open(x0 + w + 12.0, 230.0, 14.0, 26.0);
}

fn bed_frame(b: &mut Builder) {
    b.rect_open(80.0, 90.0, 24.0, 160.0);
    b.rect_open(80.0, 190.0, 240.0, 22.0);
    b.rect_open(296.0, 150.0, 24.0, 100.0);
    b.rounded(104.0, 150.0, 192.0, 40.0, 10.0);
    b.rounded(112.0, 128.0, 56.0, 24.0, 10.0);
    b.rect_open(100.0, 212.0, 12.0, 38.0);
    b.rect_open(288.0, 212.0, 12.0, 38.0);
}

fn floor_lamp(b: &mut Builder) {
    b.poly(&[(130.0, 100.0), (160.0, 50.0), (240.0, 50.0), (270.0, 100.0), (130.0, 100.0)]);
    b.rect_open(194.0, 100.0, 12.0, 160.0);
    b.ellipse(150.0, 252.0, 100.0, 24.0);
    b.dash(&[(200.0, 40.0), (200.0, 290.0)]);
}

fn cabinet(b: &mut Builder) {
    b.rect_open(100.0, 80.0, 200.0, 190.0);
    b.poly(&[(200.0, 80.0), (200.0, 270.0)]);
    b.rect_open(110.0, 92.0, 80.0, 166.0);
    b.rect_open(210.0, 92.0, 80.0, 166.0);
    b.circle(184.0, 175.0, 4.0);
    b.circle(216.0, 175.0, 4.0);
    b.rect_open(110.0, 270.0, 14.0, 22.0);
    b.rect_open(276.0, 270.0, 14.0, 22.0);
}

fn ai_modular_furniture(b: &mut Builder) {
    // 可自由組合的方塊模組
    for (x, y, w, h) in [(80.0_f32, 190.0_f32, 80.0_f32, 80.0_f32), (160.0, 190.0, 80.0, 80.0), (240.0, 190.0, 80.0, 80.0), (120.0, 110.0, 80.0, 80.0), (200.0, 110.0, 80.0, 80.0), (160.0, 40.0, 80.0, 70.0)] {
        b.rounded(x, y, w, h, 8.0);
        b.circle(x + w / 2.0, y + h / 2.0, 6.0);
    }
    b.accent(true);
    b.poly(&[(330.0, 190.0), (360.0, 190.0)]);
    b.poly(&[(345.0, 175.0), (345.0, 205.0)]);
    b.accent(false);
}

fn ai_floating_lounge(b: &mut Builder) {
    // 磁浮躺椅：本體懸浮在底座上方，中間以虛線表示磁場
    b.path(vec![m(90.0, 170.0), c(120.0, 100.0, 280.0, 100.0, 310.0, 170.0), l(310.0, 190.0), c(280.0, 150.0, 120.0, 150.0, 90.0, 190.0), l(90.0, 170.0)]);
    b.rounded(110.0, 262.0, 180.0, 18.0, 8.0);
    for k in 0..6 {
        let x = 130.0 + k as f32 * 28.0;
        b.dash(&[(x, 212.0), (x, 254.0)]);
    }
    b.accent(true);
    b.poly(&[(100.0, 236.0), (300.0, 236.0)]);
    b.accent(false);
}

// ═══ 3C 電子 ════════════════════════════════════════════════════════

fn pcb(b: &mut Builder, p: &str) {
    let (w, h) = match p {
        "raspi" => (260.0_f32, 170.0_f32),
        "esp32" => (120.0, 200.0),
        _ => (280.0, 180.0),
    };
    let (x0, y0) = (200.0 - w / 2.0, 170.0 - h / 2.0);
    b.rounded(x0, y0, w, h, 8.0);
    for (dx, dy) in [(8.0_f32, 8.0_f32), (w - 8.0, 8.0), (8.0, h - 8.0), (w - 8.0, h - 8.0)] {
        b.circle(x0 + dx, y0 + dy, 4.0);
    }
    b.rect_open(x0 + w * 0.3, y0 + h * 0.28, w * 0.3, h * 0.34); // 主晶片
    for k in 0..5 {
        let t = x0 + w * 0.3 + w * 0.3 * k as f32 / 4.0;
        b.poly(&[(t, y0 + h * 0.28), (t, y0 + h * 0.22)]);
        b.poly(&[(t, y0 + h * 0.62), (t, y0 + h * 0.68)]);
    }
    if p == "esp32" {
        b.rect_open(x0 + 12.0, y0 + 10.0, w - 24.0, 40.0); // 天線區
        for k in 0..10 {
            b.circle(x0 + 6.0, y0 + 64.0 + k as f32 * 12.0, 2.5);
            b.circle(x0 + w - 6.0, y0 + 64.0 + k as f32 * 12.0, 2.5);
        }
    } else {
        for k in 0..14 {
            b.circle(x0 + 20.0 + k as f32 * (w - 40.0) / 13.0, y0 + h - 12.0, 2.5);
        }
        b.rect_open(x0 - 10.0, y0 + h * 0.3, 34.0, h * 0.34); // 連接座
    }
}

fn connector(b: &mut Builder, p: &str) {
    match p {
        "usbc" => {
            b.rounded(120.0, 130.0, 160.0, 56.0, 28.0);
            b.rounded(138.0, 146.0, 124.0, 24.0, 12.0);
            b.rect_open(150.0, 156.0, 100.0, 4.0);
        }
        "hdmi" => {
            b.shape(&[(110.0, 130.0), (290.0, 130.0), (290.0, 160.0), (270.0, 186.0), (130.0, 186.0), (110.0, 160.0)]);
            for k in 0..19 {
                b.poly(&[(124.0 + k as f32 * 8.5, 142.0), (124.0 + k as f32 * 8.5, 164.0)]);
            }
        }
        "jack" => {
            b.rect_open(80.0, 150.0, 70.0, 40.0);
            b.rect_open(150.0, 160.0, 120.0, 20.0);
            b.poly(&[(270.0, 160.0), (300.0, 170.0), (270.0, 180.0)]);
            for x in [190.0_f32, 224.0] {
                b.poly(&[(x, 156.0), (x, 184.0)]);
            }
        }
        _ => {
            b.rect_open(110.0, 120.0, 180.0, 90.0);
            b.rect_open(150.0, 106.0, 100.0, 14.0);
            for k in 0..8 {
                b.poly(&[(128.0 + k as f32 * 20.0, 150.0), (128.0 + k as f32 * 20.0, 200.0)]);
            }
        }
    }
    b.dash(&[(60.0, 160.0), (340.0, 160.0)]);
}

fn ic_qfp(b: &mut Builder, p: &str) {
    let n = num(p, 32.0).clamp(16.0, 64.0) as usize;
    let per = n / 4;
    b.rect_open(120.0, 100.0, 160.0, 160.0);
    b.circle(138.0, 118.0, 5.0);
    for side in 0..4 {
        for k in 0..per {
            let t = 132.0 + (k as f32 + 0.5) * 136.0 / per as f32;
            let r = |dx: f32, dy: f32, w: f32, h: f32| (dx, dy, w, h);
            let (x, y, w, h) = match side {
                0 => r(t - 2.0, 80.0, 4.0, 20.0),
                1 => r(t - 2.0, 260.0, 4.0, 20.0),
                2 => r(100.0, t - 2.0 + 0.0, 20.0, 4.0),
                _ => r(280.0, t - 2.0, 20.0, 4.0),
            };
            b.rect_open(x, y, w, h);
        }
    }
}

fn ic_dip(b: &mut Builder, p: &str) {
    let n = num(p, 8.0).clamp(4.0, 40.0) as usize;
    let per = n / 2;
    let h = (per as f32 * 22.0 + 24.0).min(240.0);
    let y0 = 170.0 - h / 2.0;
    b.rect_open(150.0, y0, 100.0, h);
    b.path(vec![m(180.0, y0), c(180.0, y0 + 20.0, 220.0, y0 + 20.0, 220.0, y0)]);
    for k in 0..per {
        let y = y0 + 16.0 + k as f32 * (h - 32.0) / (per.max(2) - 1) as f32;
        b.rect_open(120.0, y - 4.0, 30.0, 8.0);
        b.rect_open(250.0, y - 4.0, 30.0, 8.0);
    }
}

fn passive(b: &mut Builder, p: &str) {
    match p {
        "cap" => {
            b.rounded(140.0, 90.0, 120.0, 150.0, 16.0);
            b.rect_open(140.0, 90.0, 120.0, 22.0);
            b.poly(&[(170.0, 240.0), (170.0, 290.0)]);
            b.poly(&[(230.0, 240.0), (230.0, 290.0)]);
            b.poly(&[(150.0, 130.0), (150.0, 220.0)]);
            b.poly(&[(160.0, 150.0), (160.0, 154.0)]);
        }
        "inductor" => {
            b.rounded(110.0, 120.0, 180.0, 90.0, 12.0);
            for k in 0..6 {
                b.poly(&[(130.0 + k as f32 * 28.0, 120.0), (146.0 + k as f32 * 28.0, 210.0)]);
            }
            b.rect_open(80.0, 156.0, 30.0, 18.0);
            b.rect_open(290.0, 156.0, 30.0, 18.0);
        }
        _ => {
            b.rect_open(150.0, 140.0, 100.0, 50.0);
            b.rect_open(130.0, 140.0, 20.0, 50.0);
            b.rect_open(250.0, 140.0, 20.0, 50.0);
            b.poly(&[(170.0, 150.0), (170.0, 180.0)]);
            b.poly(&[(200.0, 150.0), (200.0, 180.0)]);
            b.poly(&[(230.0, 150.0), (230.0, 180.0)]);
        }
    }
}

fn smartwatch(b: &mut Builder) {
    b.rounded(140.0, 110.0, 120.0, 140.0, 30.0);
    b.rounded(152.0, 124.0, 96.0, 112.0, 22.0);
    b.rounded(160.0, 40.0, 80.0, 70.0, 10.0);
    b.rounded(160.0, 250.0, 80.0, 60.0, 10.0);
    b.rect_open(260.0, 150.0, 8.0, 24.0);
    b.circle(200.0, 180.0, 30.0);
    b.poly(&[(200.0, 180.0), (200.0, 156.0)]);
    b.poly(&[(200.0, 180.0), (216.0, 190.0)]);
}

fn power_bank(b: &mut Builder) {
    b.rounded(110.0, 70.0, 180.0, 230.0, 24.0);
    b.rounded(130.0, 96.0, 140.0, 50.0, 10.0);
    for k in 0..4 {
        b.rect_open(142.0 + k as f32 * 32.0, 110.0, 24.0, 22.0);
    }
    b.rounded(150.0, 290.0, 100.0, 12.0, 4.0);
    b.rounded(170.0, 240.0, 60.0, 20.0, 10.0);
}

fn wireless_charger(b: &mut Builder) {
    b.ellipse(90.0, 210.0, 220.0, 70.0);
    b.ellipse(112.0, 220.0, 176.0, 50.0);
    for (r, y) in [(70.0_f32, 215.0_f32), (46.0, 215.0), (22.0, 215.0)] {
        b.ellipse(200.0 - r, y - r * 0.28, r * 2.0, r * 0.56);
    }
    b.rounded(150.0, 90.0, 100.0, 110.0, 14.0);
    b.accent(true);
    for k in 0..3 {
        let y = 70.0 - k as f32 * 18.0;
        b.path(vec![m(180.0, y + 40.0), c(190.0, y + 28.0, 210.0, y + 28.0, 220.0, y + 40.0)]);
    }
    b.accent(false);
}

fn smart_speaker(b: &mut Builder) {
    b.rounded(130.0, 70.0, 140.0, 200.0, 60.0);
    for k in 0..10 {
        let y = 100.0 + k as f32 * 14.0;
        b.poly(&[(146.0, y), (254.0, y)]);
    }
    b.ellipse(150.0, 76.0, 100.0, 24.0);
    b.rect_open(180.0, 270.0, 40.0, 14.0);
}

fn vr_headset(b: &mut Builder) {
    b.rounded(80.0, 110.0, 240.0, 120.0, 40.0);
    b.rounded(100.0, 128.0, 200.0, 84.0, 30.0);
    b.circle(160.0, 170.0, 28.0);
    b.circle(240.0, 170.0, 28.0);
    b.path(vec![m(80.0, 170.0), c(40.0, 170.0, 40.0, 100.0, 80.0, 100.0)]);
    b.path(vec![m(320.0, 170.0), c(360.0, 170.0, 360.0, 100.0, 320.0, 100.0)]);
    b.poly(&[(190.0, 230.0), (200.0, 248.0), (210.0, 230.0)]);
}

fn ai_foldable_display(b: &mut Builder) {
    // 三折式捲軸螢幕
    b.rounded(50.0, 110.0, 90.0, 140.0, 8.0);
    b.rounded(150.0, 110.0, 100.0, 140.0, 8.0);
    b.rounded(260.0, 110.0, 90.0, 140.0, 8.0);
    b.dash(&[(145.0, 100.0), (145.0, 260.0)]);
    b.dash(&[(255.0, 100.0), (255.0, 260.0)]);
    b.accent(true);
    b.path(vec![m(70.0, 80.0), c(140.0, 50.0, 260.0, 50.0, 330.0, 80.0)]);
    b.poly(&[(322.0, 70.0), (330.0, 80.0), (320.0, 86.0)]);
    b.accent(false);
}

fn ai_neural_wearable(b: &mut Builder) {
    // 腦波貼片：頭部弧線與電極陣列
    b.path(vec![m(90.0, 240.0), c(70.0, 100.0, 330.0, 100.0, 310.0, 240.0)]);
    for (x, y) in [(130.0_f32, 150.0_f32), (200.0, 120.0), (270.0, 150.0), (160.0, 190.0), (240.0, 190.0)] {
        b.circle(x, y, 12.0);
        b.circle(x, y, 4.0);
    }
    b.dash(&[(130.0, 150.0), (200.0, 120.0), (270.0, 150.0), (240.0, 190.0), (160.0, 190.0), (130.0, 150.0)]);
    b.accent(true);
    b.poly(&[(200.0, 120.0), (200.0, 190.0)]);
    b.accent(false);
}
