// 素材線圖本體。由 `ffi_asset_art.rs` 以 `include!` 併入 —— 它們共用
// `Builder` 與那一組小工具，拆成獨立模組只會多一層 `use`，而這個檔案
// 從頭到尾只有圖形資料。
//
// 每一個分支逐行對應 Apple 端 `AssetLibraryManager.drawObjectGraphics`
// 原本的 CoreGraphics 程式碼，**座標一律保持原值**，方便兩邊對照。
// 改動任何一個數字之前先確認 Apple 端也改 —— 兩張圖不一樣是使用者看得到的。

/// 有線圖的代號。順序不重要，但**不可以有重複**（有測試擋著）。
static CODES: &[&str] = &[
    "gear_pair",
    "bearing_iso",
    "linear_guide",
    "cam_follower",
    "stepper_motor",
    "phone_chassis",
    "ai_exoskeleton",
    "earbud_acoustic",
    "camera_lens",
    "keyboard_gasket",
    "ai_hud_display",
    "car_silhouette",
    "wheel_rim",
    "suspension_geometry",
    "steering_wheel",
    "ev_chassis",
    "ai_orbital_shuttle",
    "eames_chair",
    "standing_desk",
    "task_lamp",
    "modular_credenza",
    "hex_bolt",
    "countersunk_screw",
    "flange_nut",
    "blind_rivet",
    "compression_spring",
    "bracket_l",
    "wireframe_phone",
    "wireframe_tablet",
    "wireframe_browser",
    "wireframe_gestures",
    "golden_spiral",
    "rule_of_thirds",
    "dynamic_symmetry",
    "type_anatomy",
    "yong_eight_strokes",
    "modular_type_scale",
    "bauhaus_motif",
    "voronoi_pattern",
    "cyber_circuit",
    "draft_angle_mold",
    "plastic_rib_ratio",
    "boss_tower",
    "sheetmetal_bend",
    "cnc_dogbone",
    "pem_standoff",
    "anodizing_spec",
    "roughness_ra",
    "pneumatic_cylinder",
    "push_in_fitting",
    "dual_os_navbar",
    "bottom_sheet_ui",
    "cubic_bezier_curve",
    "spring_physics",
    "sitemap_tree",
    "state_machine_flow",
    "spacing_8pt_grid",
    "semantic_color_tokens",
];

fn draw(code: &str) -> Vec<FfiDrawPath> {
    let mut b = Builder::new();
    match code {
        // ── 機構設計 ──────────────────────────────────────────────
        "gear_pair" => {
            b.ellipse(70.0, 120.0, 120.0, 120.0);
            b.ellipse(110.0, 160.0, 40.0, 40.0);
            for i in 0..12 {
                let a = i as f32 * (PI / 6.0);
                b.poly(&[
                    (130.0 + a.cos() * 60.0, 180.0 + a.sin() * 60.0),
                    (130.0 + a.cos() * 72.0, 180.0 + a.sin() * 72.0),
                ]);
            }
            b.ellipse(180.0, 110.0, 160.0, 160.0);
            b.ellipse(230.0, 160.0, 60.0, 60.0);
            for i in 0..18 {
                let a = i as f32 * (PI / 9.0);
                b.poly(&[
                    (260.0 + a.cos() * 80.0, 190.0 + a.sin() * 80.0),
                    (260.0 + a.cos() * 94.0, 190.0 + a.sin() * 94.0),
                ]);
            }
        }

        "bearing_iso" => {
            b.ellipse(100.0, 75.0, 200.0, 200.0);
            b.ellipse(140.0, 115.0, 120.0, 120.0);
            for i in 0..8 {
                let a = i as f32 * (PI / 4.0);
                b.ellipse(
                    200.0 + a.cos() * 80.0 - 15.0,
                    175.0 + a.sin() * 80.0 - 15.0,
                    30.0,
                    30.0,
                );
            }
        }

        "linear_guide" => {
            // 滾珠螺桿滑軌：側視導軌 + 跨座滑塊 + 螺桿
            b.rounded(45.0, 205.0, 310.0, 34.0, 4.0);
            b.poly(&[(45.0, 222.0), (355.0, 222.0)]);
            b.rounded(150.0, 178.0, 110.0, 88.0, 8.0);
            // 四方向滾珠循環列
            for row in 0..2 {
                for col in 0..4 {
                    b.circle(168.0 + col as f32 * 25.0, 198.0 + row as f32 * 48.0, 6.0);
                }
            }
            // 螺桿與導程牙形
            b.width(1.4);
            b.thread(200.0, 100.0, 170.0, 14.0, 10.0);
            b.poly(&[(186.0, 100.0), (186.0, 170.0)]);
            b.poly(&[(214.0, 100.0), (214.0, 170.0)]);
            b.width(DEFAULT_WIDTH);
            for i in 0..4 {
                b.circle(75.0 + i as f32 * 83.0, 222.0, 5.0);
            }
        }

        "cam_follower" => {
            // 盤形凸輪 + 滾子從動件
            b.circle(165.0, 215.0, 16.0);
            let mut cam = Vec::new();
            let mut deg = 0;
            while deg <= 360 {
                let a = deg as f32 * PI / 180.0;
                let lift = 26.0 * (1.0 - a.cos()) / 2.0;
                let r = 58.0 + lift;
                cam.push((165.0 + a.cos() * r, 215.0 + a.sin() * r));
                deg += 6;
            }
            b.shape(&cam);
            b.circle(165.0, 122.0, 16.0);
            b.poly(&[(165.0, 106.0), (165.0, 62.0)]);
            b.rounded(148.0, 56.0, 34.0, 18.0, 3.0);
            // 行程標註
            b.width(1.2).accent(true);
            b.poly(&[(255.0, 96.0), (255.0, 122.0)]);
            b.poly(&[(249.0, 96.0), (261.0, 96.0)]);
            b.poly(&[(249.0, 122.0), (261.0, 122.0)]);
            b.accent(false).width(DEFAULT_WIDTH);
        }

        "stepper_motor" => {
            // NEMA 17 正視
            b.rounded(110.0, 95.0, 180.0, 180.0, 14.0);
            b.circle(200.0, 185.0, 36.0);
            b.circle(200.0, 185.0, 12.0);
            for dx in [-1.0_f32, 1.0] {
                for dy in [-1.0_f32, 1.0] {
                    b.circle(200.0 + dx * 62.0, 185.0 + dy * 62.0, 8.0);
                }
            }
            // D 形軸切邊
            b.poly(&[(191.0, 176.0), (191.0, 194.0)]);
            // 雙極四線出線
            b.width(1.5);
            for i in 0..4 {
                let y = 292.0 + i as f32 * 5.0;
                b.poly(&[(175.0 + i as f32 * 4.0, 275.0), (150.0, y)]);
            }
            b.width(DEFAULT_WIDTH);
        }

        // ── 3C 電子 ───────────────────────────────────────────────
        "phone_chassis" => {
            b.rounded(120.0, 50.0, 160.0, 260.0, 24.0);
            b.width(1.2);
            b.rounded(130.0, 65.0, 140.0, 230.0, 18.0);
            b.rounded(175.0, 72.0, 50.0, 12.0, 6.0);
            b.width(DEFAULT_WIDTH);
        }

        "ai_exoskeleton" => {
            // 外骨骼膝關節
            b.rounded(136.0, 62.0, 88.0, 30.0, 12.0);
            b.poly(&[(146.0, 92.0), (152.0, 164.0)]);
            b.poly(&[(214.0, 92.0), (208.0, 164.0)]);
            // 雙心瞬時迴轉軸
            b.rounded(140.0, 164.0, 80.0, 48.0, 14.0);
            b.circle(162.0, 180.0, 10.0);
            b.circle(198.0, 196.0, 10.0);
            b.poly(&[(162.0, 180.0), (198.0, 196.0)]);
            // 小腿護具
            b.poly(&[(152.0, 212.0), (158.0, 278.0)]);
            b.poly(&[(208.0, 212.0), (202.0, 278.0)]);
            b.rounded(150.0, 278.0, 60.0, 26.0, 10.0);
            b.poly(&[(150.0, 304.0), (246.0, 304.0)]);
            // 並聯線性致動器
            b.rounded(244.0, 96.0, 28.0, 74.0, 8.0);
            b.poly(&[(258.0, 170.0), (258.0, 214.0)]);
            b.circle(258.0, 222.0, 9.0);
            b.poly(&[(258.0, 96.0), (214.0, 78.0)]);
            b.poly(&[(258.0, 222.0), (208.0, 212.0)]);
        }

        "earbud_acoustic" => {
            // TWS 耳機剖面
            b.ellipse(104.0, 96.0, 132.0, 124.0);
            b.circle(170.0, 158.0, 40.0);
            b.circle(170.0, 158.0, 16.0);
            b.poly(&[(228.0, 128.0), (300.0, 176.0)]);
            b.poly(&[(220.0, 186.0), (292.0, 224.0)]);
            b.poly(&[(300.0, 176.0), (292.0, 224.0)]);
            // 矽膠耳塞（傘狀）
            b.path(vec![
                m(300.0, 176.0),
                q((300.0, 176.0), 350.0, 200.0, 292.0, 224.0),
            ]);
            // 麥克風臂
            b.rounded(128.0, 208.0, 30.0, 92.0, 15.0);
            b.circle(143.0, 284.0, 7.0);
            // 洩壓閥微孔
            b.width(1.2);
            for i in 0..6 {
                b.circle(178.0 + (i % 3) as f32 * 11.0, 224.0 + (i / 3) as f32 * 11.0, 3.0);
            }
            b.width(DEFAULT_WIDTH);
        }

        "camera_lens" => {
            // 鏡頭光學剖面
            b.rounded(88.0, 116.0, 212.0, 138.0, 8.0);
            for (x, bulge) in [
                (116.0_f32, 16.0_f32),
                (146.0, -11.0),
                (176.0, 20.0),
                (206.0, -9.0),
                (236.0, 14.0),
                (268.0, 18.0),
            ] {
                b.path(vec![m(x, 132.0), q((x, 132.0), x + bulge, 185.0, x, 238.0)]);
                b.path(vec![m(x, 132.0), q((x, 132.0), x - bulge, 185.0, x, 238.0)]);
            }
            // 光軸中心線
            b.width(1.0);
            b.dash(&[(70.0, 185.0), (336.0, 185.0)]);
            b.width(DEFAULT_WIDTH);
            // 金屬卡口法蘭
            b.poly(&[(300.0, 100.0), (300.0, 270.0)]);
            b.poly(&[(300.0, 100.0), (324.0, 100.0)]);
            b.poly(&[(300.0, 270.0), (324.0, 270.0)]);
            b.poly(&[(324.0, 100.0), (324.0, 270.0)]);
            // 對焦環滾花
            b.width(1.4);
            for i in 0..10 {
                let x = 120.0 + i as f32 * 9.0;
                b.poly(&[(x, 116.0), (x, 130.0)]);
            }
            b.width(DEFAULT_WIDTH);
        }

        "keyboard_gasket" => {
            // 75% 配列
            b.rounded(40.0, 128.0, 320.0, 145.0, 10.0);
            b.rounded(50.0, 138.0, 300.0, 125.0, 6.0);
            b.width(1.2);
            for i in 0..16 {
                b.rounded(57.0 + i as f32 * 18.3, 144.0, 15.0, 15.0, 2.0);
            }
            for row in 0..4 {
                let offset = [0.0_f32, 5.0, 9.0, 14.0][row];
                let count = [15, 14, 13, 12][row];
                for col in 0..count {
                    b.rounded(
                        57.0 + offset + col as f32 * 18.3,
                        164.0 + row as f32 * 19.0,
                        15.0,
                        16.0,
                        2.0,
                    );
                }
            }
            b.width(DEFAULT_WIDTH);
            // Gasket 矽膠襯墊位置
            b.accent(true).width(3.5);
            for i in 0..4 {
                b.poly(&[(70.0 + i as f32 * 78.0, 128.0), (110.0 + i as f32 * 78.0, 128.0)]);
                b.poly(&[(70.0 + i as f32 * 78.0, 273.0), (110.0 + i as f32 * 78.0, 273.0)]);
            }
            b.accent(false).width(DEFAULT_WIDTH);
        }

        "ai_hud_display" => {
            // 曲面座艙 HUD
            b.path(vec![
                m(60.0, 150.0),
                q((60.0, 150.0), 200.0, 100.0, 340.0, 150.0),
                l(340.0, 250.0),
                q((340.0, 250.0), 200.0, 200.0, 60.0, 250.0),
                seg(FfiPathVerb::Close, 60.0, 150.0),
            ]);
            b.circle(200.0, 188.0, 30.0);
            b.circle(200.0, 188.0, 6.0);
            b.poly(&[(160.0, 188.0), (182.0, 188.0)]);
            b.poly(&[(218.0, 188.0), (240.0, 188.0)]);
            b.poly(&[(200.0, 148.0), (200.0, 170.0)]);
            b.poly(&[(200.0, 206.0), (200.0, 228.0)]);
            b.width(1.5);
            for i in 0..5 {
                let w = [44.0_f32, 34.0, 40.0, 28.0, 36.0][i];
                let y = 168.0 + i as f32 * 12.0;
                b.poly(&[(74.0, y), (74.0 + w, y)]);
                b.poly(&[(326.0 - w, y), (326.0, y)]);
            }
            b.width(DEFAULT_WIDTH);
            b.ellipse(176.0, 274.0, 48.0, 24.0);
            b.circle(200.0, 286.0, 6.0);
        }

        // ── 汽車載具 ──────────────────────────────────────────────
        "car_silhouette" => {
            let mut segs = vec![
                m(50.0, 220.0),
                c(70.0, 210.0, 85.0, 175.0, 110.0, 170.0),
                c(140.0, 160.0, 170.0, 135.0, 200.0, 130.0),
                c(240.0, 125.0, 280.0, 140.0, 310.0, 165.0),
                c(330.0, 180.0, 345.0, 205.0, 355.0, 220.0),
                l(300.0, 220.0),
            ];
            // 輪拱往上拱起：角度由 0° 遞減到 -180°，中間經過正上方。
            segs.extend(arc_segs(270.0, 220.0, 30.0, 0.0, -180.0));
            segs.push(l(160.0, 220.0));
            segs.extend(arc_segs(130.0, 220.0, 30.0, 0.0, -180.0));
            segs.push(l(50.0, 220.0));
            b.path(segs);
            b.ellipse(105.0, 195.0, 50.0, 50.0);
            b.ellipse(245.0, 195.0, 50.0, 50.0);
        }

        "wheel_rim" => {
            // 五輻雙柱鍛造輪框正視
            b.circle(200.0, 190.0, 122.0);
            b.circle(200.0, 190.0, 108.0);
            b.circle(200.0, 190.0, 40.0);
            b.circle(200.0, 190.0, 14.0);
            for i in 0..5 {
                let a = i as f32 * (TAU / 5.0) - PI / 2.0;
                for side in [-1.0_f32, 1.0] {
                    let spread = side * 0.13;
                    b.poly(&[
                        (
                            200.0 + (a + spread * 2.2).cos() * 38.0,
                            190.0 + (a + spread * 2.2).sin() * 38.0,
                        ),
                        (
                            200.0 + (a + spread).cos() * 106.0,
                            190.0 + (a + spread).sin() * 106.0,
                        ),
                    ]);
                }
            }
            // PCD 5x114.3 螺栓孔
            for i in 0..5 {
                let a = i as f32 * (TAU / 5.0) - PI / 2.0;
                b.circle(200.0 + a.cos() * 27.0, 190.0 + a.sin() * 27.0, 6.0);
            }
        }

        "suspension_geometry" => {
            // 雙 A 臂懸吊
            b.width(3.0);
            b.poly(&[(62.0, 104.0), (62.0, 268.0)]);
            b.width(DEFAULT_WIDTH);
            b.poly(&[(62.0, 128.0), (214.0, 150.0)]);
            b.poly(&[(62.0, 152.0), (214.0, 150.0)]);
            b.poly(&[(62.0, 232.0), (238.0, 250.0)]);
            b.poly(&[(62.0, 256.0), (238.0, 250.0)]);
            b.width(3.0);
            b.poly(&[(214.0, 150.0), (238.0, 250.0)]);
            b.width(DEFAULT_WIDTH);
            b.circle(214.0, 150.0, 9.0);
            b.circle(238.0, 250.0, 9.0);
            // 倒插式避震器
            b.poly(&[(134.0, 92.0), (134.0, 240.0)]);
            b.poly(&[(174.0, 92.0), (174.0, 240.0)]);
            b.poly(&[(134.0, 92.0), (174.0, 92.0)]);
            b.width(1.8);
            let mut coil = Vec::new();
            let mut cy = 104.0;
            let mut left = true;
            while cy <= 232.0 {
                coil.push((if left { 136.0 } else { 172.0 }, cy));
                left = !left;
                cy += 11.0;
            }
            b.poly(&coil);
            b.width(DEFAULT_WIDTH);
            b.poly(&[(134.0, 240.0), (174.0, 240.0)]);
            b.poly(&[(154.0, 240.0), (226.0, 250.0)]);
            // 輪胎與輪輞
            b.width(1.6);
            b.circle(292.0, 200.0, 74.0);
            b.width(DEFAULT_WIDTH);
            b.circle(292.0, 200.0, 44.0);
            b.circle(292.0, 200.0, 12.0);
            b.poly(&[(238.0, 250.0), (292.0, 200.0)]);
        }

        "steering_wheel" => {
            // D 型平底三輻方向盤
            let (cx, cy) = (200.0_f32, 186.0_f32);
            let outer_r = 112.0_f32;
            let inner_r = 86.0_f32;
            let cut_deg = (78.0_f32 / outer_r).asin().to_degrees();
            let mut rim = Vec::new();
            let mut deg = cut_deg;
            let low = -(180.0 + cut_deg);
            while deg >= low {
                let a = deg.to_radians();
                rim.push((cx + a.cos() * outer_r, cy + a.sin() * outer_r));
                deg -= 4.0;
            }
            deg = low;
            while deg <= cut_deg {
                let a = deg.to_radians();
                rim.push((cx + a.cos() * inner_r, cy + a.sin() * inner_r));
                deg += 4.0;
            }
            b.shape(&rim);
            b.rounded(164.0, 158.0, 72.0, 58.0, 14.0);
            b.width(6.0);
            b.poly(&[(164.0, 176.0), (116.0, 168.0)]);
            b.poly(&[(236.0, 176.0), (284.0, 168.0)]);
            b.poly(&[(200.0, 216.0), (200.0, 262.0)]);
            b.width(DEFAULT_WIDTH);
            b.rounded(96.0, 132.0, 24.0, 54.0, 10.0);
            b.rounded(280.0, 132.0, 24.0, 54.0, 10.0);
            b.width(1.8);
            b.poly(&[(128.0, 108.0), (156.0, 94.0)]);
            b.poly(&[(272.0, 108.0), (244.0, 94.0)]);
            b.width(DEFAULT_WIDTH);
        }

        "ev_chassis" => {
            // 滑板底盤俯視
            b.rounded(78.0, 92.0, 244.0, 200.0, 24.0);
            b.rounded(96.0, 128.0, 208.0, 128.0, 10.0);
            b.width(1.2);
            for row in 0..4 {
                for col in 0..10 {
                    b.rounded(
                        103.0 + col as f32 * 20.0,
                        135.0 + row as f32 * 30.0,
                        16.0,
                        25.0,
                        2.0,
                    );
                }
            }
            b.width(DEFAULT_WIDTH);
            b.circle(200.0, 110.0, 16.0);
            b.circle(200.0, 274.0, 16.0);
            for (x, y) in [(68.0, 128.0), (332.0, 128.0), (68.0, 256.0), (332.0, 256.0)] {
                b.rounded(x - 12.0, y - 26.0, 24.0, 52.0, 8.0);
            }
        }

        "ai_orbital_shuttle" => {
            // 多面體隱形外殼 + 向量離子推進 + 環形重力艙
            b.shape(&[
                (200.0, 68.0),
                (276.0, 140.0),
                (296.0, 232.0),
                (200.0, 286.0),
                (104.0, 232.0),
                (124.0, 140.0),
            ]);
            b.poly(&[(200.0, 68.0), (200.0, 286.0)]);
            b.poly(&[(124.0, 140.0), (276.0, 140.0)]);
            b.poly(&[(104.0, 232.0), (296.0, 232.0)]);
            b.ellipse(176.0, 96.0, 48.0, 36.0);
            b.ellipse(96.0, 176.0, 208.0, 56.0);
            for x in [166.0_f32, 200.0, 234.0] {
                b.poly(&[
                    (x - 12.0, 286.0),
                    (x - 18.0, 312.0),
                    (x + 18.0, 312.0),
                    (x + 12.0, 286.0),
                ]);
            }
        }

        // ── 工業家具 ──────────────────────────────────────────────
        "eames_chair" => {
            b.path(vec![
                m(120.0, 130.0),
                c(140.0, 115.0, 170.0, 110.0, 200.0, 110.0),
                c(230.0, 110.0, 250.0, 140.0, 260.0, 160.0),
                c(265.0, 180.0, 260.0, 200.0, 250.0, 210.0),
                c(230.0, 225.0, 200.0, 230.0, 170.0, 230.0),
            ]);
            b.poly(&[(200.0, 230.0), (200.0, 270.0)]);
            b.poly(&[(140.0, 290.0), (200.0, 270.0), (260.0, 290.0)]);
        }

        "standing_desk" => {
            // 升降桌：桌板 + 雙三節升降柱 + 腳座 + 行程標註
            b.rounded(58.0, 104.0, 284.0, 18.0, 4.0);
            for x in [112.0_f32, 258.0] {
                b.rounded(x - 17.0, 122.0, 34.0, 70.0, 3.0);
                b.rounded(x - 13.0, 192.0, 26.0, 56.0, 3.0);
                b.rounded(x - 9.0, 248.0, 18.0, 42.0, 3.0);
                b.rounded(x - 44.0, 290.0, 88.0, 14.0, 4.0);
            }
            b.poly(&[(112.0, 150.0), (258.0, 150.0)]);
            b.accent(true).width(1.6);
            b.poly(&[(188.0, 176.0), (188.0, 268.0)]);
            b.poly(&[(182.0, 184.0), (188.0, 174.0), (194.0, 184.0)]);
            b.poly(&[(182.0, 260.0), (188.0, 270.0), (194.0, 260.0)]);
            b.accent(false).width(DEFAULT_WIDTH);
        }

        "task_lamp" => {
            // 包浩斯懸臂燈
            b.ellipse(96.0, 278.0, 116.0, 26.0);
            b.poly(&[(154.0, 278.0), (154.0, 214.0)]);
            b.poly(&[(154.0, 214.0), (236.0, 146.0)]);
            b.poly(&[(164.0, 224.0), (246.0, 156.0)]);
            b.poly(&[(236.0, 146.0), (300.0, 196.0)]);
            b.poly(&[(246.0, 156.0), (310.0, 206.0)]);
            b.circle(158.0, 218.0, 11.0);
            b.circle(241.0, 151.0, 11.0);
            b.circle(305.0, 216.0, 30.0);
            b.circle(305.0, 216.0, 18.0);
        }

        "modular_credenza" => {
            // 模組收納櫃
            b.rounded(66.0, 112.0, 268.0, 76.0, 4.0);
            b.rounded(66.0, 188.0, 268.0, 76.0, 4.0);
            b.poly(&[(200.0, 112.0), (200.0, 188.0)]);
            b.poly(&[(156.0, 188.0), (156.0, 264.0)]);
            b.poly(&[(244.0, 188.0), (244.0, 264.0)]);
            // 45° 倒角隱藏拉手
            b.width(1.6);
            for (x, y, w, h) in [
                (96.0_f32, 146.0_f32, 70.0_f32, 10.0_f32),
                (234.0, 146.0, 70.0, 10.0),
                (92.0, 220.0, 48.0, 10.0),
            ] {
                b.poly(&[(x, y + h), (x + 8.0, y), (x + w, y)]);
            }
            b.width(DEFAULT_WIDTH);
            for x in [110.0_f32, 200.0, 290.0] {
                b.circle(x, 188.0, 5.0);
            }
            b.poly(&[(92.0, 264.0), (84.0, 300.0)]);
            b.poly(&[(308.0, 264.0), (316.0, 300.0)]);
        }

        // ── 五金零件 ──────────────────────────────────────────────
        "hex_bolt" => {
            b.rect_open(150.0, 80.0, 100.0, 60.0);
            b.rect_open(165.0, 140.0, 70.0, 140.0);
            let mut y = 150.0;
            while y < 270.0 {
                b.poly(&[(165.0, y), (235.0, y + 8.0)]);
                y += 12.0;
            }
            b.ellipse(180.0, 95.0, 40.0, 30.0);
        }

        "countersunk_screw" => {
            // DIN 7991 沉頭螺釘側視 + 內六角頂視
            b.shape(&[(108.0, 118.0), (292.0, 118.0), (232.0, 166.0), (168.0, 166.0)]);
            b.width(1.2).accent(true);
            b.poly(&[(200.0, 118.0), (168.0, 166.0)]);
            b.poly(&[(200.0, 118.0), (232.0, 166.0)]);
            b.accent(false).width(DEFAULT_WIDTH);
            b.poly(&[(168.0, 166.0), (168.0, 286.0)]);
            b.poly(&[(232.0, 166.0), (232.0, 286.0)]);
            b.poly(&[(168.0, 286.0), (232.0, 286.0)]);
            b.width(1.4);
            b.thread(200.0, 176.0, 280.0, 32.0, 13.0);
            b.width(DEFAULT_WIDTH);
            let mut hex = Vec::new();
            for i in 0..6 {
                let a = i as f32 * PI / 3.0 - PI / 6.0;
                hex.push((200.0 + a.cos() * 20.0, 90.0 + a.sin() * 20.0));
            }
            b.shape(&hex);
        }

        "flange_nut" => {
            // 六角法蘭螺母
            b.circle(200.0, 148.0, 74.0);
            let mut nut = Vec::new();
            for i in 0..6 {
                let a = i as f32 * PI / 3.0;
                nut.push((200.0 + a.cos() * 54.0, 148.0 + a.sin() * 54.0));
            }
            b.shape(&nut);
            b.circle(200.0, 148.0, 26.0);
            b.width(1.2);
            b.circle(200.0, 148.0, 22.0);
            b.width(DEFAULT_WIDTH);
            b.shape(&[(126.0, 262.0), (146.0, 236.0), (254.0, 236.0), (274.0, 262.0)]);
            b.width(1.4);
            let mut teeth = Vec::new();
            let mut tx = 128.0;
            let mut up = false;
            while tx <= 272.0 {
                teeth.push((tx, if up { 262.0 } else { 270.0 }));
                up = !up;
                tx += 9.0;
            }
            b.poly(&teeth);
            b.width(DEFAULT_WIDTH);
        }

        "blind_rivet" => {
            // 封閉型抽芯盲鉚釘
            b.shape(&[(130.0, 112.0), (270.0, 112.0), (270.0, 130.0), (130.0, 130.0)]);
            b.poly(&[(172.0, 130.0), (172.0, 252.0)]);
            b.poly(&[(228.0, 130.0), (228.0, 252.0)]);
            // 封閉端：由 180° 遞減到 0°，中間經過正下方，形成向下的半圓收口。
            let mut segs = vec![m(172.0, 252.0)];
            segs.extend(arc_segs(200.0, 252.0, 28.0, 180.0, 0.0));
            b.path(segs);
            b.poly(&[(200.0, 112.0), (200.0, 64.0)]);
            b.width(1.4);
            b.poly(&[(192.0, 96.0), (208.0, 96.0)]);
            b.width(DEFAULT_WIDTH);
            b.circle(200.0, 60.0, 7.0);
            b.width(1.6);
            b.poly(&[(92.0, 130.0), (308.0, 130.0)]);
            b.poly(&[(92.0, 158.0), (308.0, 158.0)]);
            b.width(DEFAULT_WIDTH);
        }

        "compression_spring" => {
            // 圓柱螺旋壓縮彈簧側視
            let top = 84.0_f32;
            let bottom = 288.0_f32;
            let coils = 9;
            let pitch = (bottom - top) / coils as f32;
            let outer_r = 62.0_f32;
            for i in 0..=coils {
                let y = top + i as f32 * pitch;
                b.ellipse(200.0 - outer_r, y - 9.0, outer_r * 2.0, 18.0);
            }
            b.width(3.0);
            b.poly(&[(138.0, top - 9.0), (262.0, top - 9.0)]);
            b.poly(&[(138.0, bottom + 9.0), (262.0, bottom + 9.0)]);
            b.width(DEFAULT_WIDTH);
            b.accent(true).width(1.2);
            b.poly(&[(296.0, top - 9.0), (296.0, bottom + 9.0)]);
            b.poly(&[(290.0, top - 9.0), (302.0, top - 9.0)]);
            b.poly(&[(290.0, bottom + 9.0), (302.0, bottom + 9.0)]);
            b.accent(false).width(DEFAULT_WIDTH);
        }

        "bracket_l" => {
            // 90° 角鐵等角視
            b.shape(&[(96.0, 176.0), (176.0, 132.0), (176.0, 268.0), (96.0, 312.0)]);
            b.shape(&[(176.0, 132.0), (306.0, 132.0), (306.0, 268.0), (176.0, 268.0)]);
            b.poly(&[(176.0, 200.0), (244.0, 132.0)]);
            b.poly(&[(176.0, 200.0), (176.0, 268.0)]);
            for (x, y) in [(130.0, 208.0), (130.0, 264.0), (250.0, 172.0), (250.0, 228.0)] {
                b.circle(x, y, 10.0);
                b.width(1.2);
                b.circle(x, y, 15.0);
                b.width(DEFAULT_WIDTH);
            }
        }

        // ── 數位產品線框 ──────────────────────────────────────────
        "wireframe_phone" => {
            b.rounded(138.0, 46.0, 124.0, 270.0, 22.0);
            b.rounded(146.0, 54.0, 108.0, 254.0, 16.0);
            b.rounded(178.0, 62.0, 44.0, 12.0, 6.0);
            b.width(1.2).accent(true);
            b.poly(&[(146.0, 90.0), (254.0, 90.0)]);
            b.poly(&[(146.0, 282.0), (254.0, 282.0)]);
            b.accent(false);
            for i in 0..4 {
                b.rounded(156.0, 102.0 + i as f32 * 42.0, 88.0, 32.0, 4.0);
            }
            b.width(DEFAULT_WIDTH);
            b.rounded(176.0, 296.0, 48.0, 5.0, 2.5);
        }

        "wireframe_tablet" => {
            b.rounded(58.0, 76.0, 284.0, 216.0, 16.0);
            b.rounded(68.0, 86.0, 264.0, 196.0, 10.0);
            b.poly(&[(222.0, 86.0), (222.0, 252.0)]);
            b.width(1.4);
            for i in 0..5 {
                b.rounded(78.0, 96.0 + i as f32 * 26.0, 60.0, 18.0, 3.0);
            }
            b.rounded(232.0, 96.0, 90.0, 60.0, 4.0);
            for i in 0..3 {
                let y = 170.0 + i as f32 * 16.0;
                b.poly(&[(232.0, y), (322.0, y)]);
            }
            b.width(DEFAULT_WIDTH);
            b.rounded(128.0, 256.0, 144.0, 26.0, 13.0);
            for i in 0..5 {
                b.circle(148.0 + i as f32 * 26.0, 269.0, 7.0);
            }
        }

        "wireframe_browser" => {
            b.rounded(46.0, 92.0, 308.0, 212.0, 10.0);
            b.poly(&[(46.0, 156.0), (354.0, 156.0)]);
            // 紅黃綠控制鈕。指定填色而不是用配色 —— 三顆同色的圈圈認不出是什麼。
            for (i, hex) in ["#FF3B30", "#FF9500", "#34C759"].iter().enumerate() {
                b.fill_with(hex);
                b.ellipse(60.0 + i as f32 * 20.0, 102.0, 12.0, 12.0);
            }
            b.width(1.4);
            b.rounded(130.0, 98.0, 84.0, 22.0, 5.0);
            b.rounded(218.0, 98.0, 84.0, 22.0, 5.0);
            b.rounded(62.0, 128.0, 276.0, 20.0, 10.0);
            b.rounded(62.0, 170.0, 130.0, 82.0, 5.0);
            for i in 0..5 {
                let y = 180.0 + i as f32 * 17.0;
                b.poly(&[(204.0, y), (338.0, y)]);
            }
            for i in 0..3 {
                let y = 268.0 + i as f32 * 14.0;
                b.poly(&[(62.0, y), (338.0, y)]);
            }
            b.width(DEFAULT_WIDTH);
        }

        "wireframe_gestures" => {
            // 8 種核心手勢符號（2 列 x 4 欄）
            b.width(2.0);
            let cols = [86.0_f32, 162.0, 238.0, 314.0];
            let rows = [136.0_f32, 244.0];
            let mut idx = 0;
            for r in rows {
                for cx in cols {
                    let (x, y) = (cx, r);
                    b.circle(x, y, 13.0);
                    match idx {
                        0 => {
                            b.circle(x, y, 24.0);
                        }
                        1 => {
                            b.circle(x, y, 22.0);
                            b.circle(x, y, 30.0);
                        }
                        2 => {
                            // 長按：虛線圈。以正多邊形近似，才畫得出虛線。
                            let mut ring = Vec::new();
                            for k in 0..=36 {
                                let a = k as f32 * TAU / 36.0;
                                ring.push((x + a.cos() * 26.0, y + a.sin() * 26.0));
                            }
                            b.dash(&ring);
                        }
                        3 => {
                            b.poly(&[(x + 16.0, y), (x + 44.0, y)]);
                            b.poly(&[(x + 36.0, y - 7.0), (x + 46.0, y), (x + 36.0, y + 7.0)]);
                        }
                        4 => {
                            let start: f32 = -0.8 * 180.0;
                            let end: f32 = 0.5 * 180.0;
                            let a0 = start.to_radians();
                            let mut segs =
                                vec![m(x + 26.0 * f32::cos(a0), y + 26.0 * f32::sin(a0))];
                            segs.extend(arc_segs(x, y, 26.0, start, end));
                            b.path(segs);
                            b.poly(&[
                                (x - 4.0, y + 20.0),
                                (x, y + 30.0),
                                (x + 8.0, y + 24.0),
                            ]);
                        }
                        5 => {
                            b.poly(&[(x - 30.0, y - 30.0), (x - 14.0, y - 14.0)]);
                            b.poly(&[(x + 30.0, y + 30.0), (x + 14.0, y + 14.0)]);
                            b.poly(&[(x - 30.0, y - 30.0), (x - 30.0, y - 18.0)]);
                            b.poly(&[(x - 30.0, y - 30.0), (x - 18.0, y - 30.0)]);
                        }
                        6 => {
                            b.dash(&[(x - 26.0, y + 26.0), (x + 26.0, y - 22.0)]);
                        }
                        _ => {
                            b.circle(x + 22.0, y + 8.0, 13.0);
                        }
                    }
                    idx += 1;
                }
            }
            b.width(DEFAULT_WIDTH);
        }

        // ── 美學視覺 ──────────────────────────────────────────────
        "golden_spiral" => {
            b.rect_open(80.0, 80.0, 240.0, 148.3);
            b.poly(&[(228.3, 80.0), (228.3, 228.3)]);
            b.poly(&[(228.3, 171.7), (320.0, 171.7)]);
            b.path(vec![
                m(80.0, 228.3),
                c(80.0, 146.4, 146.4, 80.0, 228.3, 80.0),
                c(279.0, 80.0, 320.0, 121.0, 320.0, 171.7),
                c(320.0, 203.0, 295.0, 228.3, 263.3, 228.3),
            ]);
        }

        "rule_of_thirds" => {
            b.rect_open(70.0, 80.0, 260.0, 180.0);
            b.width(1.0);
            b.poly(&[(156.6, 80.0), (156.6, 260.0)]);
            b.poly(&[(243.3, 80.0), (243.3, 260.0)]);
            b.poly(&[(70.0, 140.0), (330.0, 140.0)]);
            b.poly(&[(70.0, 200.0), (330.0, 200.0)]);
            for (x, y) in [(156.6, 140.0), (243.3, 140.0), (156.6, 200.0), (243.3, 200.0)] {
                b.ellipse(x - 7.0, y - 7.0, 14.0, 14.0);
            }
            b.width(DEFAULT_WIDTH);
        }

        "dynamic_symmetry" => {
            b.rect_open(70.0, 70.0, 260.0, 184.0);
            b.poly(&[(70.0, 254.0), (330.0, 70.0)]);
            b.poly(&[(70.0, 70.0), (330.0, 254.0)]);
            b.poly(&[(70.0, 70.0), (220.0, 254.0)]);
            b.poly(&[(330.0, 254.0), (180.0, 70.0)]);
        }

        "type_anatomy" => {
            for (idx, y) in [90.0_f32, 120.0, 160.0, 210.0, 250.0].iter().enumerate() {
                b.width(if idx == 3 { 2.0 } else { 1.0 });
                b.poly(&[(60.0, *y), (340.0, *y)]);
            }
            b.width(DEFAULT_WIDTH);
            b.rect_open(90.0, 120.0, 60.0, 90.0);
            b.ellipse(180.0, 160.0, 50.0, 50.0);
            b.poly(&[(180.0, 160.0), (180.0, 250.0)]);
        }

        "yong_eight_strokes" => {
            b.rect_open(100.0, 70.0, 200.0, 200.0);
            b.width(1.0);
            b.poly(&[(100.0, 170.0), (300.0, 170.0)]);
            b.poly(&[(200.0, 70.0), (200.0, 270.0)]);
            b.poly(&[(100.0, 70.0), (300.0, 270.0)]);
            b.poly(&[(100.0, 270.0), (300.0, 70.0)]);
            b.width(3.0);
            b.ellipse(195.0, 85.0, 10.0, 16.0);
            b.poly(&[(130.0, 125.0), (270.0, 125.0)]);
            b.poly(&[(200.0, 125.0), (200.0, 235.0), (175.0, 215.0)]);
            b.poly(&[(200.0, 170.0), (140.0, 230.0)]);
            b.poly(&[(200.0, 180.0), (265.0, 240.0)]);
            b.width(DEFAULT_WIDTH);
        }

        "modular_type_scale" => {
            let mut y = 80.0;
            for sz in [36.0_f32, 28.0, 22.0, 18.0, 14.0, 11.0] {
                b.rect_open(80.0, y, sz * 6.5, sz);
                y += sz + 10.0;
            }
        }

        "bauhaus_motif" => {
            b.ellipse(80.0, 90.0, 110.0, 110.0);
            b.rect_open(150.0, 140.0, 100.0, 100.0);
            b.shape(&[(260.0, 90.0), (320.0, 200.0), (200.0, 200.0)]);
        }

        "voronoi_pattern" => {
            let centers = [
                (140.0_f32, 120.0_f32),
                (220.0, 110.0),
                (180.0, 180.0),
                (120.0, 220.0),
                (260.0, 210.0),
            ];
            for (x, y) in centers {
                b.ellipse(x - 4.0, y - 4.0, 8.0, 8.0);
            }
            b.poly(&[
                (140.0, 120.0),
                (220.0, 110.0),
                (260.0, 210.0),
                (180.0, 180.0),
                (120.0, 220.0),
                (140.0, 120.0),
            ]);
            b.poly(&[(180.0, 180.0), (140.0, 120.0)]);
            b.poly(&[(180.0, 180.0), (220.0, 110.0)]);
        }

        "cyber_circuit" => {
            b.poly(&[(80.0, 120.0), (160.0, 120.0), (210.0, 170.0), (290.0, 170.0)]);
            b.poly(&[(110.0, 240.0), (180.0, 240.0), (230.0, 190.0), (310.0, 190.0)]);
            for (x, y) in [(80.0, 120.0), (290.0, 170.0), (110.0, 240.0), (310.0, 190.0)] {
                b.ellipse(x - 6.0, y - 6.0, 12.0, 12.0);
            }
        }

        // ── 工程製程 ──────────────────────────────────────────────
        "draft_angle_mold" => {
            b.shape(&[(100.0, 80.0), (300.0, 80.0), (285.0, 180.0), (115.0, 180.0)]);
            b.width(1.0);
            b.poly(&[(70.0, 180.0), (330.0, 180.0)]);
            b.width(DEFAULT_WIDTH);
            b.poly(&[(115.0, 180.0), (130.0, 260.0), (270.0, 260.0), (285.0, 180.0)]);
        }

        "plastic_rib_ratio" => {
            b.rect_open(80.0, 220.0, 240.0, 35.0);
            b.rect_open(185.0, 100.0, 30.0, 120.0);
            b.ellipse(177.0, 212.0, 16.0, 16.0);
            b.ellipse(207.0, 212.0, 16.0, 16.0);
        }

        "boss_tower" => {
            b.rect_open(160.0, 80.0, 80.0, 140.0);
            b.rect_open(180.0, 80.0, 40.0, 100.0);
            b.poly(&[(160.0, 140.0), (110.0, 220.0), (160.0, 220.0)]);
            b.poly(&[(240.0, 140.0), (290.0, 220.0), (240.0, 220.0)]);
            b.rect_open(90.0, 220.0, 220.0, 25.0);
        }

        "sheetmetal_bend" => {
            b.shape(&[
                (80.0, 110.0),
                (200.0, 110.0),
                (200.0, 240.0),
                (230.0, 240.0),
                (230.0, 80.0),
                (80.0, 80.0),
            ]);
            b.width(1.2);
            b.poly(&[(80.0, 95.0), (215.0, 95.0), (215.0, 240.0)]);
            b.width(DEFAULT_WIDTH);
        }

        "cnc_dogbone" => {
            b.rect_open(120.0, 90.0, 160.0, 160.0);
            let r = 12.0_f32;
            for (x, y) in [(120.0, 90.0), (280.0, 90.0), (120.0, 250.0), (280.0, 250.0)] {
                b.ellipse(x - r / 2.0, y - r / 2.0, r, r);
            }
        }

        "pem_standoff" => {
            b.rect_open(155.0, 90.0, 90.0, 40.0);
            b.rect_open(165.0, 130.0, 70.0, 120.0);
            b.rect_open(180.0, 90.0, 40.0, 160.0);
        }

        "anodizing_spec" => {
            b.rect_open(80.0, 140.0, 240.0, 120.0);
            b.rect_open(80.0, 90.0, 240.0, 50.0);
            let mut px = 100.0;
            while px < 310.0 {
                b.poly(&[(px, 90.0), (px, 135.0)]);
                px += 18.0;
            }
        }

        "roughness_ra" => {
            let mut pts = vec![(80.0_f32, 160.0_f32)];
            for i in 0..8 {
                let x = 80.0 + i as f32 * 30.0;
                pts.push((x + 15.0, if i % 2 == 0 { 120.0 } else { 200.0 }));
                pts.push((x + 30.0, 160.0));
            }
            b.poly(&pts);
            b.width(1.0);
            b.poly(&[(70.0, 160.0), (330.0, 160.0)]);
            b.width(DEFAULT_WIDTH);
        }

        "pneumatic_cylinder" => {
            b.rect_open(110.0, 120.0, 180.0, 90.0);
            b.rect_open(70.0, 135.0, 40.0, 15.0);
            b.rect_open(70.0, 180.0, 40.0, 15.0);
            b.rect_open(60.0, 110.0, 15.0, 110.0);
            b.ellipse(130.0, 105.0, 14.0, 14.0);
            b.ellipse(250.0, 105.0, 14.0, 14.0);
        }

        "push_in_fitting" => {
            b.rect_open(130.0, 130.0, 80.0, 60.0);
            b.rect_open(150.0, 190.0, 40.0, 60.0);
            b.rect_open(210.0, 140.0, 50.0, 40.0);
        }

        // ── 數位體驗 ──────────────────────────────────────────────
        "dual_os_navbar" => {
            b.rect_open(70.0, 90.0, 120.0, 150.0);
            b.rect_open(210.0, 120.0, 120.0, 120.0);
            b.ellipse(85.0, 105.0, 12.0, 12.0);
            b.ellipse(225.0, 135.0, 12.0, 12.0);
        }

        "bottom_sheet_ui" => {
            // 只有上緣兩角是圓的 —— Bottom Sheet 的識別特徵就是它。
            let (x, y, w, h, r) = (90.0_f32, 120.0_f32, 220.0_f32, 180.0_f32, 20.0_f32);
            let k = r * KAPPA;
            b.path(vec![
                m(x, y + h),
                l(x, y + r),
                c(x, y + r - k, x + r - k, y, x + r, y),
                l(x + w - r, y),
                c(x + w - r + k, y, x + w, y + r - k, x + w, y + r),
                l(x + w, y + h),
            ]);
            // 抓手 Grabber
            b.rounded(175.0, 135.0, 50.0, 6.0, 3.0);
        }

        "cubic_bezier_curve" => {
            b.rect_open(80.0, 80.0, 240.0, 180.0);
            b.path(vec![
                m(80.0, 260.0),
                c(160.0, 260.0, 240.0, 80.0, 320.0, 80.0),
            ]);
            b.width(1.0);
            b.poly(&[(80.0, 260.0), (160.0, 260.0)]);
            b.ellipse(156.0, 256.0, 8.0, 8.0);
            b.poly(&[(320.0, 80.0), (240.0, 80.0)]);
            b.ellipse(236.0, 76.0, 8.0, 8.0);
            b.width(DEFAULT_WIDTH);
        }

        "spring_physics" => {
            let mut pts = vec![(70.0_f32, 160.0_f32)];
            let mut sx = 70.0;
            while sx <= 330.0 {
                let t = (sx - 70.0) / 260.0;
                let amplitude = 80.0 * (-3.0_f32 * t).exp();
                pts.push((sx, 160.0 - amplitude * (t * PI * 8.0).sin()));
                sx += 4.0;
            }
            b.poly(&pts);
        }

        "sitemap_tree" => {
            b.rect_open(160.0, 80.0, 80.0, 40.0);
            b.rect_open(80.0, 180.0, 65.0, 35.0);
            b.rect_open(167.0, 180.0, 65.0, 35.0);
            b.rect_open(255.0, 180.0, 65.0, 35.0);
            b.poly(&[(200.0, 120.0), (200.0, 150.0)]);
            b.poly(&[(112.0, 150.0), (287.0, 150.0)]);
            b.poly(&[(112.0, 150.0), (112.0, 180.0)]);
            b.poly(&[(200.0, 150.0), (200.0, 180.0)]);
            b.poly(&[(287.0, 150.0), (287.0, 180.0)]);
        }

        "state_machine_flow" => {
            b.rounded(80.0, 140.0, 70.0, 50.0, 10.0);
            b.rounded(250.0, 140.0, 70.0, 50.0, 10.0);
            b.poly(&[(150.0, 155.0), (250.0, 155.0)]);
            b.poly(&[(250.0, 175.0), (150.0, 175.0)]);
        }

        "spacing_8pt_grid" => {
            let mut gx = 70.0_f32;
            for gs in [8.0_f32, 16.0, 24.0, 32.0, 48.0, 64.0] {
                b.rect_open(gx, 180.0 - gs, gs, gs);
                gx += gs + 8.0;
                if gx > 320.0 {
                    break;
                }
            }
        }

        "semantic_color_tokens" => {
            for (x, y) in [(80.0, 90.0), (215.0, 90.0), (80.0, 180.0), (215.0, 180.0)] {
                b.rounded(x, y, 105.0, 60.0, 8.0);
            }
        }

        // 認不得的代號：立體透視立方幾何。與 Apple 端的 `default:` 相同。
        _ => {
            b.shape(&[
                (200.0, 90.0),
                (300.0, 145.0),
                (300.0, 255.0),
                (200.0, 310.0),
                (100.0, 255.0),
                (100.0, 145.0),
            ]);
            b.poly(&[(200.0, 90.0), (200.0, 200.0), (300.0, 145.0)]);
            b.poly(&[(200.0, 200.0), (100.0, 145.0)]);
        }
    }
    b.finish()
}
