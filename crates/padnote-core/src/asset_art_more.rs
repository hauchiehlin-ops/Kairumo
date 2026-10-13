// 擴充素材線圖（第二批）。由 `ffi_asset_art.rs` 以 `include!` 併入，共用 `Builder` 與小工具。
//
// 與第一批（`asset_art_shapes.rs`）的差別：這一批是**參數化的家族**。
// 代號寫成 `家族` 或 `家族:參數`（例如 `spur_gear:24` 是 24 齒的正齒輪、`hex_bolt_m:M8` 是 M8 六角螺栓），
// 同一個家族只寫一個繪圖函式，各規格共用 —— 十幾個尺寸不必各抄一份。
// 目錄（`asset_catalog_more.rs`）由 `scripts/gen_asset_catalog.py` 產生，代號清單 `MORE_CODES` 也在那裡。
//
// 座標一律在 400 × 400 的方框裡，安全區約 40–360；y > 310 留給藍圖風格的尺寸引線與標題欄，圖形不要畫到那裡。

/// 把代號拆成「家族」與「參數」。
fn split_code(code: &str) -> (&str, &str) {
    code.split_once(':').unwrap_or((code, ""))
}

/// 參數裡的數字（`M8` → 8、`24` → 24）。沒有數字回預設值。
fn num(param: &str, default: f32) -> f32 {
    let digits: String = param
        .chars()
        .skip_while(|c| !c.is_ascii_digit())
        .take_while(|c| c.is_ascii_digit() || *c == '.')
        .collect();
    digits.parse().unwrap_or(default)
}

/// 近似圓的多邊形點。
fn ring_pts(cx: f32, cy: f32, r: f32, n: usize) -> Vec<(f32, f32)> {
    (0..n)
        .map(|i| {
            let a = i as f32 * TAU / n as f32;
            (cx + r * a.cos(), cy + r * a.sin())
        })
        .collect()
}

/// 梯形齒的輪廓（封閉）。`root` 齒根圓半徑、`tip` 齒頂圓半徑、`n` 齒數。
fn gear_outline(cx: f32, cy: f32, root: f32, tip: f32, n: usize) -> Vec<(f32, f32)> {
    let step = TAU / n as f32;
    let mut pts = Vec::with_capacity(n * 4);
    for i in 0..n {
        let a = i as f32 * step;
        for (k, r) in [(0.0, root), (0.18, tip), (0.48, tip), (0.66, root)] {
            let t = a + k * step;
            pts.push((cx + r * t.cos(), cy + r * t.sin()));
        }
    }
    pts
}

/// 虛線圓（節圓、中心線）。
fn dashed_circle(b: &mut Builder, cx: f32, cy: f32, r: f32) {
    let mut pts = ring_pts(cx, cy, r, 72);
    pts.push(pts[0]);
    b.dash(&pts);
}

/// 水平／垂直的中心線（虛線）。
fn center_cross(b: &mut Builder, cx: f32, cy: f32, half: f32) {
    b.dash(&[(cx - half, cy), (cx + half, cy)]);
    b.dash(&[(cx, cy - half), (cx, cy + half)]);
}

/// 正六邊形頂點（平頂朝上）。
fn hex_pts(cx: f32, cy: f32, r: f32) -> Vec<(f32, f32)> {
    (0..6)
        .map(|i| {
            let a = TAU / 6.0 * i as f32 + PI / 6.0;
            (cx + r * a.cos(), cy + r * a.sin())
        })
        .collect()
}

/// 往 `draw()` 的備援分支：認得就畫並回 true。
fn draw_more(code: &str, b: &mut Builder) -> bool {
    let (name, p) = split_code(code);
    match name {
        // ── 機構設計 ─────────────────────────────────────────────
        "spur_gear" => spur_gear(b, p),
        "timing_pulley" => timing_pulley(b, p),
        "coil_spring" => coil_spring(b, p),
        "four_bar" => four_bar(b),
        "slider_crank" => slider_crank(b),
        "rack_pinion" => rack_pinion(b),
        "worm_gear" => worm_gear(b),
        "planetary_gear" => planetary_gear(b),
        "ratchet_pawl" => ratchet_pawl(b),
        "universal_joint" => universal_joint(b),
        "bevel_gear" => bevel_gear(b),
        "ai_bionic_muscle" => ai_bionic_muscle(b),
        "ai_origami_fold" => ai_origami_fold(b),
        // ── 五金零件 ─────────────────────────────────────────────
        "hex_bolt_m" => hex_bolt_m(b, p),
        "hex_nut" => hex_nut(b, p),
        "socket_cap" => socket_cap(b, p),
        "washer" => washer(b, p),
        "dowel_pin" => dowel_pin(b),
        "feather_key" => feather_key(b),
        "eye_bolt" => eye_bolt(b),
        "clevis_pin" => clevis_pin(b),
        "turnbuckle" => turnbuckle(b),
        "butt_hinge" => butt_hinge(b),
        "caster_wheel" => caster_wheel(b),
        "u_bolt" => u_bolt(b),
        "threaded_rod" => threaded_rod(b),
        "ai_gecko_clamp" => ai_gecko_clamp(b),
        "ai_memory_fastener" => ai_memory_fastener(b),
        _ => return draw_more2(code, b),
    }
    true
}

// ═══ 機構設計 ═══════════════════════════════════════════════════════

fn spur_gear(b: &mut Builder, p: &str) {
    let n = num(p, 24.0).clamp(8.0, 60.0) as usize;
    let (cx, cy) = (200.0, 170.0);
    let tip = 120.0;
    let root = tip - (tip * 2.0 * PI / n as f32 * 0.45).clamp(8.0, 26.0);
    b.shape(&gear_outline(cx, cy, root, tip, n));
    dashed_circle(b, cx, cy, (root + tip) / 2.0);
    b.circle(cx, cy, 22.0);
    b.circle(cx, cy, root * 0.62);
    // 鍵槽
    b.rect_open(cx - 5.0, cy - 30.0, 10.0, 8.0);
    center_cross(b, cx, cy, 138.0);
}

fn timing_pulley(b: &mut Builder, p: &str) {
    let n = num(p, 20.0).clamp(12.0, 60.0) as usize;
    let (cx, cy) = (200.0, 170.0);
    b.circle(cx, cy, 128.0); // 擋邊
    let pts = gear_outline(cx, cy, 88.0, 100.0, n);
    b.shape(&pts);
    b.circle(cx, cy, 30.0);
    b.circle(cx, cy, 52.0);
    for a in [0.0_f32, PI / 2.0, PI, 3.0 * PI / 2.0] {
        b.circle(cx + 41.0 * a.cos(), cy + 41.0 * a.sin(), 5.0);
    }
    dashed_circle(b, cx, cy, 94.0);
    center_cross(b, cx, cy, 140.0);
}

fn coil_spring(b: &mut Builder, p: &str) {
    let turns = num(p, 6.0).clamp(3.0, 12.0) as usize;
    let (x0, x1) = (140.0, 260.0);
    let (top, bottom) = (70.0, 290.0);
    b.rect_open(x0 - 20.0, top - 12.0, x1 - x0 + 40.0, 12.0);
    b.rect_open(x0 - 20.0, bottom, x1 - x0 + 40.0, 12.0);
    let pitch = (bottom - top) / turns as f32;
    for i in 0..turns {
        let y = top + pitch * i as f32;
        b.poly(&[(x0, y + pitch * 0.15), (x1, y + pitch * 0.65)]);
        b.poly(&[(x1, y + pitch * 0.65), (x1 + 6.0, y + pitch)]);
    }
    b.dash(&[(200.0, top - 20.0), (200.0, bottom + 24.0)]);
}

fn four_bar(b: &mut Builder) {
    let (a, d) = ((110.0, 260.0), (290.0, 260.0));
    let (bp, cp) = ((150.0, 120.0), (260.0, 150.0));
    b.poly(&[a, bp]);
    b.poly(&[bp, cp]);
    b.poly(&[cp, d]);
    b.accent(true);
    b.poly(&[a, d]);
    b.accent(false);
    for p in [a, bp, cp, d] {
        b.circle(p.0, p.1, 9.0);
    }
    b.poly(&[(a.0 - 24.0, a.1 + 18.0), (a.0 + 24.0, a.1 + 18.0)]);
    b.poly(&[(d.0 - 24.0, d.1 + 18.0), (d.0 + 24.0, d.1 + 18.0)]);
}

fn slider_crank(b: &mut Builder) {
    let (cx, cy) = (110.0, 200.0);
    b.circle(cx, cy, 46.0);
    b.circle(cx, cy, 8.0);
    let pin = (cx + 32.0, cy - 33.0);
    b.circle(pin.0, pin.1, 7.0);
    b.poly(&[(cx, cy), pin]);
    let slider = (290.0, 200.0);
    b.poly(&[pin, slider]);
    b.rect_open(slider.0 - 6.0, slider.1 - 22.0, 56.0, 44.0);
    b.poly(&[(170.0, 170.0), (350.0, 170.0)]);
    b.poly(&[(170.0, 230.0), (350.0, 230.0)]);
    b.dash(&[(cx, cy - 70.0), (cx, cy + 70.0)]);
}

fn rack_pinion(b: &mut Builder) {
    let (cx, cy) = (200.0, 130.0);
    b.shape(&gear_outline(cx, cy, 44.0, 58.0, 14));
    b.circle(cx, cy, 14.0);
    // 齒條
    let y = 205.0;
    b.rect_open(60.0, y + 12.0, 280.0, 38.0);
    let mut x = 66.0;
    while x < 332.0 {
        b.poly(&[(x, y + 12.0), (x + 4.0, y), (x + 14.0, y), (x + 18.0, y + 12.0)]);
        x += 22.0;
    }
    dashed_circle(b, cx, cy, 51.0);
    b.dash(&[(60.0, y + 4.0), (340.0, y + 4.0)]);
}

fn worm_gear(b: &mut Builder) {
    // 蝸桿（側視）
    b.rect_open(70.0, 60.0, 260.0, 54.0);
    let mut x = 82.0;
    while x < 316.0 {
        b.poly(&[(x, 114.0), (x + 18.0, 60.0)]);
        x += 18.0;
    }
    // 蝸輪
    let (cx, cy) = (200.0, 250.0);
    b.shape(&gear_outline(cx, cy, 52.0, 64.0, 30));
    b.circle(cx, cy, 14.0);
    b.circle(cx, cy, 36.0);
    b.dash(&[(70.0, 87.0), (330.0, 87.0)]);
}

fn planetary_gear(b: &mut Builder) {
    let (cx, cy) = (200.0, 170.0);
    b.circle(cx, cy, 132.0); // 內齒圈外徑
    b.shape(&gear_outline(cx, cy, 108.0, 120.0, 48)); // 內齒（以外輪廓示意）
    b.shape(&gear_outline(cx, cy, 20.0, 30.0, 12)); // 太陽輪
    for i in 0..3 {
        let a = TAU / 3.0 * i as f32 - PI / 2.0;
        let (px, py) = (cx + 62.0 * a.cos(), cy + 62.0 * a.sin());
        b.shape(&gear_outline(px, py, 22.0, 32.0, 14));
        b.circle(px, py, 6.0);
    }
    b.circle(cx, cy, 8.0);
}

fn ratchet_pawl(b: &mut Builder) {
    let (cx, cy) = (190.0, 170.0);
    let n = 14;
    let mut pts = Vec::new();
    for i in 0..n {
        let a = i as f32 * TAU / n as f32;
        pts.push((cx + 108.0 * a.cos(), cy + 108.0 * a.sin()));
        let a2 = a + TAU / n as f32 * 0.85;
        pts.push((cx + 84.0 * a2.cos(), cy + 84.0 * a2.sin()));
    }
    b.shape(&pts);
    b.circle(cx, cy, 20.0);
    // 棘爪
    b.accent(true);
    b.shape(&[(300.0, 70.0), (326.0, 78.0), (296.0, 120.0), (270.0, 100.0)]);
    b.circle(312.0, 74.0, 7.0);
    b.accent(false);
    center_cross(b, cx, cy, 120.0);
}

fn universal_joint(b: &mut Builder) {
    // 兩個叉耳與十字軸
    b.rect_open(50.0, 140.0, 80.0, 60.0);
    b.rect_open(270.0, 140.0, 80.0, 60.0);
    b.poly(&[(130.0, 150.0), (170.0, 110.0), (170.0, 90.0), (230.0, 90.0), (230.0, 110.0)]);
    b.poly(&[(270.0, 150.0), (230.0, 110.0)]);
    b.poly(&[(130.0, 190.0), (170.0, 230.0), (170.0, 250.0), (230.0, 250.0), (230.0, 230.0)]);
    b.poly(&[(270.0, 190.0), (230.0, 230.0)]);
    b.circle(200.0, 170.0, 12.0);
    b.poly(&[(172.0, 170.0), (228.0, 170.0)]);
    b.poly(&[(200.0, 118.0), (200.0, 222.0)]);
    b.dash(&[(30.0, 170.0), (370.0, 170.0)]);
}

fn bevel_gear(b: &mut Builder) {
    // 剖面：圓錐台
    b.shape(&[(130.0, 80.0), (270.0, 80.0), (300.0, 190.0), (100.0, 190.0)]);
    let mut x = 112.0;
    while x < 292.0 {
        b.poly(&[(x, 190.0), (x + 4.0, 214.0), (x + 20.0, 214.0), (x + 24.0, 190.0)]);
        x += 28.0;
    }
    b.rect_open(180.0, 190.0, 40.0, 100.0);
    b.rect_open(150.0, 80.0, 100.0, 14.0);
    b.dash(&[(200.0, 60.0), (200.0, 310.0)]);
}

fn ai_bionic_muscle(b: &mut Builder) {
    // 仿生肌纖維束：多條彎曲纖維夾在兩端接頭之間
    b.rounded(60.0, 150.0, 40.0, 60.0, 10.0);
    b.rounded(300.0, 150.0, 40.0, 60.0, 10.0);
    for k in 0..7 {
        let dy = (k as f32 - 3.0) * 12.0;
        b.path(vec![
            m(100.0, 180.0 + dy * 0.3),
            c(150.0, 110.0 + dy, 250.0, 110.0 + dy, 300.0, 180.0 + dy * 0.3),
        ]);
        b.path(vec![
            m(100.0, 180.0 + dy * 0.3),
            c(150.0, 250.0 + dy, 250.0, 250.0 + dy, 300.0, 180.0 + dy * 0.3),
        ]);
    }
    b.accent(true);
    b.poly(&[(100.0, 180.0), (300.0, 180.0)]);
    b.accent(false);
}

fn ai_origami_fold(b: &mut Builder) {
    // 摺紙機構：三角形折板，折線以虛線標示
    let tri = [
        [(80.0, 250.0), (160.0, 110.0), (200.0, 250.0)],
        [(200.0, 250.0), (160.0, 110.0), (250.0, 130.0)],
        [(200.0, 250.0), (250.0, 130.0), (320.0, 250.0)],
    ];
    for t in tri {
        b.shape(&t);
    }
    b.dash(&[(160.0, 110.0), (200.0, 250.0)]);
    b.dash(&[(250.0, 130.0), (200.0, 250.0)]);
    b.accent(true);
    b.poly(&[(80.0, 270.0), (320.0, 270.0)]);
    b.accent(false);
}

// ═══ 五金零件 ═══════════════════════════════════════════════════════

/// 螺栓的比例：M 值決定粗細，長度取 5 倍公稱徑再夾在安全範圍。
fn bolt_dims(p: &str) -> (f32, f32) {
    let d = num(p, 8.0).clamp(3.0, 16.0);
    let shank = (d * 5.0).clamp(60.0, 190.0);
    (d, shank)
}

fn hex_bolt_m(b: &mut Builder, p: &str) {
    let (d, shank) = bolt_dims(p);
    let w = (d * 5.2).clamp(24.0, 70.0); // 桿徑（畫面上放大）
    let head_w = w * 1.7;
    let head_h = w * 0.7;
    let cx = 200.0;
    let top = 90.0;
    b.rect_open(cx - head_w / 2.0, top, head_w, head_h);
    b.poly(&[(cx - head_w / 6.0, top), (cx - head_w / 6.0, top + head_h)]);
    b.poly(&[(cx + head_w / 6.0, top), (cx + head_w / 6.0, top + head_h)]);
    let y0 = top + head_h;
    b.rect_open(cx - w / 2.0, y0, w, shank);
    b.thread(cx, y0 + shank * 0.4, y0 + shank, w / 2.0, 7.0);
    b.dash(&[(cx, top - 14.0), (cx, y0 + shank + 14.0)]);
    // 端面
    b.circle(320.0, 130.0, head_w / 2.4);
    b.shape(&hex_pts(320.0, 130.0, head_w / 2.4));
}

fn hex_nut(b: &mut Builder, p: &str) {
    let d = num(p, 8.0).clamp(3.0, 16.0);
    let r = (d * 6.0).clamp(30.0, 92.0);
    let (cx, cy) = (150.0, 170.0);
    b.shape(&hex_pts(cx, cy, r));
    b.circle(cx, cy, r * 0.5);
    dashed_circle(b, cx, cy, r * 0.56);
    // 側視
    let h = r * 0.9;
    b.rect_open(270.0, cy - h / 2.0, 70.0, h);
    b.poly(&[(290.0, cy - h / 2.0), (290.0, cy + h / 2.0)]);
    b.poly(&[(320.0, cy - h / 2.0), (320.0, cy + h / 2.0)]);
    b.dash(&[(270.0, cy), (340.0, cy)]);
}

fn socket_cap(b: &mut Builder, p: &str) {
    let (d, shank) = bolt_dims(p);
    let w = (d * 5.0).clamp(22.0, 64.0);
    let cx = 200.0;
    let top = 80.0;
    let head_h = w;
    b.rounded(cx - w * 0.8, top, w * 1.6, head_h, 4.0);
    b.rect_open(cx - w * 0.3, top + 4.0, w * 0.6, head_h * 0.55); // 內六角凹槽
    b.rect_open(cx - w / 2.0, top + head_h, w, shank);
    b.thread(cx, top + head_h + shank * 0.45, top + head_h + shank, w / 2.0, 7.0);
    b.dash(&[(cx, top - 14.0), (cx, top + head_h + shank + 14.0)]);
    b.shape(&hex_pts(330.0, 130.0, w * 0.4));
    b.circle(330.0, 130.0, w * 0.8);
}

fn washer(b: &mut Builder, p: &str) {
    let d = num(p, 8.0).clamp(3.0, 16.0);
    let ro = (d * 8.0).clamp(46.0, 118.0);
    let ri = ro * 0.52;
    let (cx, cy) = (160.0, 170.0);
    b.circle(cx, cy, ro);
    b.circle(cx, cy, ri);
    center_cross(b, cx, cy, ro + 14.0);
    // 剖面
    let t = (d * 1.2).clamp(8.0, 18.0);
    b.rect_open(290.0, cy - ro, t, ro - ri);
    b.rect_open(290.0, cy + ri, t, ro - ri);
    b.dash(&[(280.0, cy), (320.0, cy)]);
}

fn dowel_pin(b: &mut Builder) {
    b.rounded(80.0, 140.0, 240.0, 60.0, 6.0);
    b.poly(&[(80.0, 150.0), (96.0, 140.0)]);
    b.poly(&[(320.0, 150.0), (304.0, 140.0)]);
    b.dash(&[(60.0, 170.0), (340.0, 170.0)]);
    b.circle(200.0, 250.0, 30.0);
    center_cross(b, 200.0, 250.0, 42.0);
}

fn feather_key(b: &mut Builder) {
    b.rounded(70.0, 120.0, 260.0, 56.0, 28.0);
    b.rounded(100.0, 136.0, 200.0, 24.0, 12.0);
    b.circle(200.0, 240.0, 56.0);
    b.rect_open(188.0, 176.0, 24.0, 10.0);
    center_cross(b, 200.0, 240.0, 70.0);
}

fn eye_bolt(b: &mut Builder) {
    let cx = 200.0;
    b.circle(cx, 112.0, 52.0);
    b.circle(cx, 112.0, 32.0);
    b.rect_open(cx - 34.0, 160.0, 68.0, 14.0);
    b.rect_open(cx - 14.0, 174.0, 28.0, 120.0);
    b.thread(cx, 210.0, 294.0, 14.0, 7.0);
    b.dash(&[(cx, 40.0), (cx, 304.0)]);
}

fn clevis_pin(b: &mut Builder) {
    b.rounded(70.0, 135.0, 260.0, 44.0, 4.0);
    b.rounded(54.0, 126.0, 16.0, 62.0, 3.0);
    b.circle(306.0, 157.0, 7.0);
    b.rounded(280.0, 130.0, 12.0, 54.0, 3.0);
    b.dash(&[(40.0, 157.0), (350.0, 157.0)]);
    b.circle(200.0, 250.0, 22.0);
    center_cross(b, 200.0, 250.0, 34.0);
}

fn turnbuckle(b: &mut Builder) {
    b.rounded(110.0, 140.0, 180.0, 40.0, 8.0);
    b.rect_open(150.0, 124.0, 100.0, 12.0);
    b.rect_open(150.0, 184.0, 100.0, 12.0);
    for x in [60.0_f32, 290.0] {
        b.circle(x + if x < 100.0 { 0.0 } else { 56.0 }, 160.0, 26.0);
        b.circle(x + if x < 100.0 { 0.0 } else { 56.0 }, 160.0, 12.0);
    }
    b.poly(&[(86.0, 160.0), (110.0, 160.0)]);
    b.poly(&[(290.0, 160.0), (316.0, 160.0)]);
    b.thread(130.0, 148.0, 172.0, 6.0, 5.0);
}

fn butt_hinge(b: &mut Builder) {
    b.rect_open(70.0, 70.0, 100.0, 220.0);
    b.rect_open(230.0, 70.0, 100.0, 220.0);
    b.rect_open(170.0, 70.0, 60.0, 220.0);
    for y in [100.0_f32, 170.0, 240.0] {
        b.circle(120.0, y, 8.0);
        b.circle(280.0, y, 8.0);
    }
    for k in 0..5 {
        let y = 70.0 + k as f32 * 44.0;
        b.poly(&[(170.0, y), (230.0, y)]);
    }
    b.dash(&[(200.0, 56.0), (200.0, 304.0)]);
}

fn caster_wheel(b: &mut Builder) {
    b.rect_open(150.0, 60.0, 100.0, 12.0);
    b.rounded(170.0, 72.0, 60.0, 30.0, 4.0);
    b.poly(&[(175.0, 102.0), (160.0, 200.0), (240.0, 200.0), (225.0, 102.0)]);
    b.circle(200.0, 230.0, 66.0);
    b.circle(200.0, 230.0, 46.0);
    b.circle(200.0, 230.0, 10.0);
    b.dash(&[(200.0, 40.0), (200.0, 304.0)]);
}

fn u_bolt(b: &mut Builder) {
    b.path(vec![
        m(130.0, 70.0),
        l(130.0, 190.0),
        c(130.0, 260.0, 270.0, 260.0, 270.0, 190.0),
        l(270.0, 70.0),
    ]);
    b.path(vec![
        m(158.0, 70.0),
        l(158.0, 190.0),
        c(158.0, 232.0, 242.0, 232.0, 242.0, 190.0),
        l(242.0, 70.0),
    ]);
    b.thread(144.0, 76.0, 130.0, 8.0, 6.0);
    b.thread(256.0, 76.0, 130.0, 8.0, 6.0);
    b.rect_open(120.0, 150.0, 160.0, 12.0);
}

fn threaded_rod(b: &mut Builder) {
    b.rect_open(60.0, 150.0, 280.0, 40.0);
    let mut x = 66.0;
    while x < 336.0 {
        b.poly(&[(x, 190.0), (x + 8.0, 150.0)]);
        x += 10.0;
    }
    b.dash(&[(40.0, 170.0), (360.0, 170.0)]);
    b.circle(200.0, 250.0, 26.0);
    b.circle(200.0, 250.0, 20.0);
}

fn ai_gecko_clamp(b: &mut Builder) {
    // 仿壁虎微結構夾具：兩片夾板與密集剛毛
    b.rounded(70.0, 90.0, 260.0, 26.0, 6.0);
    b.rounded(70.0, 220.0, 260.0, 26.0, 6.0);
    let mut x = 82.0;
    while x < 326.0 {
        b.poly(&[(x, 116.0), (x - 3.0, 150.0), (x + 2.0, 168.0)]);
        b.poly(&[(x, 220.0), (x + 3.0, 190.0), (x - 2.0, 170.0)]);
        x += 12.0;
    }
    b.accent(true);
    b.poly(&[(60.0, 168.0), (340.0, 168.0)]);
    b.accent(false);
}

fn ai_memory_fastener(b: &mut Builder) {
    // 形狀記憶合金扣件：受熱前後兩種形態並排
    b.path(vec![m(80.0, 240.0), c(80.0, 120.0, 180.0, 120.0, 180.0, 240.0)]);
    b.path(vec![m(220.0, 240.0), l(220.0, 150.0), c(220.0, 100.0, 320.0, 100.0, 320.0, 150.0), l(320.0, 240.0)]);
    b.accent(true);
    b.poly(&[(186.0, 170.0), (214.0, 170.0)]);
    b.poly(&[(206.0, 162.0), (214.0, 170.0), (206.0, 178.0)]);
    b.accent(false);
    b.rect_open(60.0, 240.0, 280.0, 14.0);
}
