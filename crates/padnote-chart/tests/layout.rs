//! 圖表版面的行為測試。
//!
//! 這裡釘住的不是「畫出來好不好看」，而是幾件**錯了使用者會被誤導**的事：
//! 長條圖的基線、堆疊的總和、扇形的角度總和、以及規格能不能原封不動地
//! 存回來再讀出來（那是「可重新編修」的唯一依據）。

use padnote_chart::*;

fn series(name: &str, values: &[f64]) -> Series {
    Series {
        name: name.into(),
        values: values.to_vec(),
        ..Default::default()
    }
}

fn sample(kind: ChartKind) -> ChartSpec {
    ChartSpec {
        kind,
        title: "季度營收".into(),
        categories: vec!["Q1".into(), "Q2".into(), "Q3".into(), "Q4".into()],
        series: vec![
            series("北區", &[120.0, 150.0, 90.0, 200.0]),
            series("南區", &[80.0, 60.0, 130.0, 110.0]),
        ],
        ..Default::default()
    }
}

// ── 規格往返 ────────────────────────────────────────────────

#[test]
fn spec_survives_a_json_round_trip() {
    // 「可重新編修」就是這一件事：存進筆記檔的是規格，不是算繪好的圖。
    // 這條測試掉了，使用者再打開圖表時就只剩一張改不動的圖片。
    let mut original = sample(ChartKind::StackedArea);
    original.data_labels = LabelPosition::Inside;
    original.label_decimals = 2;
    original.y_axis.title = "新台幣（千元）".into();
    original.y_axis.min = Some(-50.0);
    original.doughnut_hole_ratio = 0.31;

    let restored = ChartSpec::from_json(&original.to_json()).expect("規格要讀得回來");

    assert_eq!(restored.kind, ChartKind::StackedArea);
    assert_eq!(restored.title, original.title);
    assert_eq!(restored.categories, original.categories);
    assert_eq!(restored.series[1].values, original.series[1].values);
    assert_eq!(restored.data_labels, LabelPosition::Inside);
    assert_eq!(restored.label_decimals, 2);
    assert_eq!(restored.y_axis.title, "新台幣（千元）");
    assert_eq!(restored.y_axis.min, Some(-50.0));
    assert!((restored.doughnut_hole_ratio - 0.31).abs() < 1e-9);
}

#[test]
fn unknown_fields_do_not_break_an_older_build() {
    // 未來的版本多寫了欄位，舊版仍要打得開這張圖 —— 讀不回來等於資料遺失。
    let json = r#"{"kind":"bar","series":[{"name":"a","values":[1,2]}],"futureField":42}"#;
    let spec = ChartSpec::from_json(json).expect("多出來的欄位要忽略，不是報錯");
    assert_eq!(spec.series[0].values, vec![1.0, 2.0]);
}

#[test]
fn missing_fields_fall_back_to_defaults() {
    let spec = ChartSpec::from_json(r#"{"series":[{"values":[3]}]}"#).unwrap();
    assert_eq!(spec.kind, ChartKind::Bar);
    assert_eq!(spec.legend, LegendPosition::Bottom);
    assert!(
        spec.y_axis.show_grid,
        "Y 軸格線預設要開，沒有格線的長條圖讀不出數量級"
    );
}

#[test]
fn an_empty_spec_is_rejected_with_a_reason() {
    assert_eq!(ChartSpec::default().validate(), Err(SpecError::NoSeries));
    let spec = ChartSpec {
        series: vec![series("空", &[])],
        ..Default::default()
    };
    assert_eq!(spec.validate(), Err(SpecError::NoValues));
}

// ── 長條 ────────────────────────────────────────────────────

#[test]
fn bars_start_from_zero() {
    // 長條不從 0 起算的話，長度比例會騙人 —— 那是統計圖表最常見的誤導。
    let mut spec = sample(ChartKind::Bar);
    spec.series = vec![series("只有高值", &[100.0, 102.0, 104.0])];
    let layout = layout(&spec, 480.0, 320.0).unwrap();

    let shortest = layout
        .bars
        .iter()
        .map(|b| b.height)
        .fold(f64::INFINITY, f64::min);
    let tallest = layout.bars.iter().map(|b| b.height).fold(0.0, f64::max);
    let ratio = shortest / tallest;
    assert!(
        ratio > 0.9,
        "100 與 104 的長條長度不該差這麼多（比例 {ratio}）"
    );
}

#[test]
fn every_bar_stays_inside_the_plot_area() {
    for kind in [
        ChartKind::Bar,
        ChartKind::StackedBar,
        ChartKind::HorizontalBar,
    ] {
        let layout = layout(&sample(kind), 520.0, 360.0).unwrap();
        for bar in &layout.bars {
            assert!(bar.x >= layout.plot_x - 0.5, "{kind:?} 有長條伸出左邊界");
            assert!(
                bar.x + bar.width <= layout.plot_x + layout.plot_width + 0.5,
                "{kind:?} 有長條伸出右邊界"
            );
            assert!(bar.y >= layout.plot_y - 0.5, "{kind:?} 有長條伸出上邊界");
            assert!(
                bar.y + bar.height <= layout.plot_y + layout.plot_height + 0.5,
                "{kind:?} 有長條伸出下邊界"
            );
        }
    }
}

#[test]
fn grouped_bars_do_not_overlap() {
    let layout = layout(&sample(ChartKind::Bar), 600.0, 360.0).unwrap();
    let first: Vec<&PlotBar> = layout.bars.iter().filter(|b| b.point_index == 0).collect();
    assert_eq!(first.len(), 2, "同一類別要有兩根長條");
    let (a, b) = (first[0], first[1]);
    assert!(
        a.x + a.width <= b.x + 0.01 || b.x + b.width <= a.x + 0.01,
        "同一類別的兩根長條疊在一起了"
    );
}

#[test]
fn stacked_bars_sit_on_top_of_each_other() {
    let spec = sample(ChartKind::StackedBar);
    let layout = layout(&spec, 600.0, 360.0).unwrap();
    let mut first: Vec<&PlotBar> = layout.bars.iter().filter(|b| b.point_index == 0).collect();
    first.sort_by_key(|a| a.series_index);

    assert_eq!(first[0].x, first[1].x, "堆疊的長條要在同一欄");
    assert_eq!(first[0].width, first[1].width);
    // 第二段的底要接在第一段的頂（螢幕 y 向下，所以第二段在上方）。
    assert!(
        (first[1].y + first[1].height - first[0].y).abs() < 0.5,
        "堆疊之間有縫或重疊"
    );
}

#[test]
fn negative_values_extend_below_the_baseline() {
    let mut spec = sample(ChartKind::Bar);
    spec.series = vec![series("損益", &[50.0, -30.0])];
    let layout = layout(&spec, 480.0, 320.0).unwrap();

    let positive = &layout.bars[0];
    let negative = &layout.bars[1];
    assert!(negative.y > positive.y, "負值的長條要落在正值下方");
    // 兩根共用同一條基線：正值的底 == 負值的頂。
    assert!(
        (positive.y + positive.height - negative.y).abs() < 0.5,
        "正負長條沒有共用基線"
    );
}

#[test]
fn bar_width_ratio_narrows_the_bars() {
    let mut wide = sample(ChartKind::Bar);
    wide.bar_width_ratio = 0.9;
    let mut narrow = wide.clone();
    narrow.bar_width_ratio = 0.3;

    let w = layout(&wide, 600.0, 360.0).unwrap().bars[0].width;
    let n = layout(&narrow, 600.0, 360.0).unwrap().bars[0].width;
    assert!(n < w * 0.5, "類別間距調窄之後長條沒有變窄（{n} vs {w}）");
}

// ── 折線與區域 ──────────────────────────────────────────────

#[test]
fn a_line_has_one_point_per_category() {
    let layout = layout(&sample(ChartKind::Line), 520.0, 340.0).unwrap();
    assert_eq!(layout.polylines.len(), 2, "兩個數列要有兩條線");
    for line in &layout.polylines {
        assert_eq!(line.points.len(), 4);
        assert!(line.fill_to_y.is_none(), "折線圖不該填色");
    }
}

#[test]
fn an_area_chart_fills_down_to_the_baseline() {
    let layout = layout(&sample(ChartKind::Area), 520.0, 340.0).unwrap();
    for line in &layout.polylines {
        let fill = line.fill_to_y.expect("區域圖要有填色基線");
        assert!(fill >= layout.plot_y && fill <= layout.plot_y + layout.plot_height);
    }
}

#[test]
fn stacked_areas_accumulate() {
    let spec = sample(ChartKind::StackedArea);
    let layout = layout(&spec, 520.0, 340.0).unwrap();
    // 第二層在畫面上要比第一層更高（y 更小），因為它畫的是累加值。
    for i in 0..4 {
        let lower = layout.polylines[0].points[i].y;
        let upper = layout.polylines[1].points[i].y;
        assert!(upper < lower, "第 {i} 點的堆疊沒有累加");
    }
    // 但標籤與回報的值仍是**原始值**，不是累加後的值 —— 使用者看的是自己輸入的數字。
    assert_eq!(layout.polylines[1].points[0].value, 80.0);
}

#[test]
fn a_smooth_line_is_flagged_for_the_platform() {
    assert!(
        layout(&sample(ChartKind::SmoothLine), 400.0, 300.0)
            .unwrap()
            .polylines[0]
            .smooth
    );
    assert!(
        !layout(&sample(ChartKind::Line), 400.0, 300.0)
            .unwrap()
            .polylines[0]
            .smooth
    );
}

#[test]
fn scatter_points_span_the_full_width() {
    let layout = layout(&sample(ChartKind::Scatter), 520.0, 340.0).unwrap();
    let xs: Vec<f64> = layout
        .scatter_points
        .iter()
        .filter(|p| p.series_index == 0)
        .map(|p| p.x)
        .collect();
    assert_eq!(xs.len(), 4);
    assert!((xs[0] - layout.plot_x).abs() < 0.5, "第一點要貼齊左邊界");
    assert!(
        (xs[3] - (layout.plot_x + layout.plot_width)).abs() < 0.5,
        "最後一點要貼齊右邊界"
    );
}

// ── 圓餅與環圈 ──────────────────────────────────────────────

#[test]
fn pie_slices_add_up_to_a_full_turn() {
    let mut spec = sample(ChartKind::Pie);
    spec.series = vec![series("市佔", &[30.0, 45.0, 25.0])];
    let layout = layout(&spec, 400.0, 400.0).unwrap();

    assert_eq!(layout.slices.len(), 3);
    let sweep: f64 = layout
        .slices
        .iter()
        .map(|s| s.end_angle - s.start_angle)
        .sum();
    assert!(
        (sweep - std::f64::consts::TAU).abs() < 1e-9,
        "扇形加起來不是一整圈"
    );
    let fractions: f64 = layout.slices.iter().map(|s| s.fraction).sum();
    assert!((fractions - 1.0).abs() < 1e-9);
}

#[test]
fn pie_slices_are_contiguous() {
    let mut spec = sample(ChartKind::Pie);
    spec.series = vec![series("市佔", &[10.0, 20.0, 30.0, 40.0])];
    let layout = layout(&spec, 400.0, 400.0).unwrap();
    for pair in layout.slices.windows(2) {
        assert!(
            (pair[0].end_angle - pair[1].start_angle).abs() < 1e-12,
            "扇形之間有縫"
        );
    }
}

#[test]
fn a_pie_ignores_the_second_series() {
    // 第二個數列畫上去會得到一個誰也看不懂的圖，所以刻意只取第一個。
    let layout = layout(&sample(ChartKind::Pie), 400.0, 400.0).unwrap();
    assert_eq!(layout.slices.len(), 4, "扇形數應等於第一個數列的項數");
}

#[test]
fn each_pie_slice_gets_its_own_colour() {
    let layout = layout(&sample(ChartKind::Pie), 400.0, 400.0).unwrap();
    let colours: Vec<&str> = layout.slices.iter().map(|s| s.color_hex.as_str()).collect();
    for i in 0..colours.len() {
        for j in (i + 1)..colours.len() {
            assert_ne!(colours[i], colours[j], "第 {i} 與第 {j} 塊撞色了");
        }
    }
}

#[test]
fn a_doughnut_has_a_hole_and_a_pie_does_not() {
    let doughnut = layout(&sample(ChartKind::Doughnut), 400.0, 400.0).unwrap();
    assert!(doughnut.slices[0].inner_radius > 0.0);
    assert!(doughnut.slices[0].inner_radius < doughnut.slices[0].radius);
    assert_eq!(
        layout(&sample(ChartKind::Pie), 400.0, 400.0)
            .unwrap()
            .slices[0]
            .inner_radius,
        0.0
    );
}

#[test]
fn the_pie_fits_inside_the_canvas() {
    let layout = layout(&sample(ChartKind::Pie), 300.0, 420.0).unwrap();
    let s = &layout.slices[0];
    assert!(s.center_x - s.radius >= 0.0 && s.center_x + s.radius <= layout.width);
    assert!(s.center_y - s.radius >= 0.0 && s.center_y + s.radius <= layout.height);
}

#[test]
fn an_all_zero_pie_draws_nothing_instead_of_dividing_by_zero() {
    let mut spec = sample(ChartKind::Pie);
    spec.series = vec![series("全零", &[0.0, 0.0])];
    assert!(layout(&spec, 400.0, 400.0).unwrap().slices.is_empty());
}

// ── 雷達 ────────────────────────────────────────────────────

#[test]
fn a_radar_closes_its_outline() {
    let layout = layout(&sample(ChartKind::Radar), 420.0, 420.0).unwrap();
    let points = &layout.polylines[0].points;
    assert_eq!(points.len(), 5, "四個軸的輪廓要有五個頂點（頭尾相接）");
    assert!((points[0].x - points[4].x).abs() < 1e-9);
    assert!((points[0].y - points[4].y).abs() < 1e-9);
}

#[test]
fn a_radar_has_one_spoke_per_category() {
    let layout = layout(&sample(ChartKind::Radar), 420.0, 420.0).unwrap();
    assert_eq!(layout.radar_spokes.len(), 4);
    assert!(
        !layout.radar_rings.is_empty(),
        "沒有同心圈的雷達圖讀不出數值"
    );
}

#[test]
fn a_radar_with_two_axes_draws_nothing() {
    // 兩個軸的雷達圖是一條線，畫出來只會誤導。
    let mut spec = sample(ChartKind::Radar);
    spec.categories.truncate(2);
    spec.series = vec![series("兩軸", &[1.0, 2.0])];
    let layout = layout(&spec, 400.0, 400.0).unwrap();
    assert!(layout.polylines.is_empty());
}

// ── 軸與刻度 ────────────────────────────────────────────────

#[test]
fn tick_steps_are_readable_numbers() {
    let mut spec = sample(ChartKind::Line);
    spec.series = vec![series("零散", &[0.0, 33.3, 66.7, 97.4])];
    let layout = layout(&spec, 520.0, 340.0).unwrap();

    let values: Vec<f64> = layout
        .y_ticks
        .iter()
        .filter_map(|t| t.label.parse().ok())
        .collect();
    assert!(values.len() >= 3);
    let step = values[1] - values[0];
    let normalized = step / 10f64.powf(step.log10().floor());
    assert!(
        [1.0, 2.0, 5.0]
            .iter()
            .any(|n| (normalized - n).abs() < 1e-9),
        "刻度間距 {step} 不是 1/2/5 的次方倍，軸上會出現沒人想讀的數字"
    );
}

#[test]
fn ticks_are_evenly_spaced() {
    let layout = layout(&sample(ChartKind::Bar), 520.0, 340.0).unwrap();
    let ys: Vec<f64> = layout.y_ticks.iter().map(|t| t.y).collect();
    let gap = ys[1] - ys[0];
    for pair in ys.windows(2) {
        assert!(((pair[1] - pair[0]) - gap).abs() < 0.01, "刻度間距不一致");
    }
}

#[test]
fn a_fixed_axis_range_is_honoured() {
    let mut spec = sample(ChartKind::Line);
    spec.y_axis.min = Some(0.0);
    spec.y_axis.max = Some(500.0);
    spec.y_axis.step = Some(100.0);
    let layout = layout(&spec, 520.0, 340.0).unwrap();

    let values: Vec<f64> = layout
        .y_ticks
        .iter()
        .filter_map(|t| t.label.parse().ok())
        .collect();
    assert_eq!(values, vec![0.0, 100.0, 200.0, 300.0, 400.0, 500.0]);
}

#[test]
fn turning_off_the_grid_removes_the_lines() {
    let mut spec = sample(ChartKind::Bar);
    assert!(!layout(&spec, 520.0, 340.0).unwrap().grid_lines.is_empty());
    spec.y_axis.show_grid = false;
    assert!(layout(&spec, 520.0, 340.0).unwrap().grid_lines.is_empty());
}

#[test]
fn a_missing_category_name_falls_back_to_its_number() {
    let mut spec = sample(ChartKind::Bar);
    spec.categories = vec!["Q1".into()];
    let layout = layout(&spec, 520.0, 340.0).unwrap();
    let labels: Vec<&str> = layout.x_ticks.iter().map(|t| t.label.as_str()).collect();
    assert_eq!(
        labels,
        vec!["Q1", "2", "3", "4"],
        "缺名字要補序號，留白會讓軸看起來壞掉"
    );
}

#[test]
fn axis_titles_leave_room_for_themselves() {
    let mut without = sample(ChartKind::Bar);
    without.y_axis.title = String::new();
    let mut with = without.clone();
    with.y_axis.title = "新台幣".into();

    let a = layout(&without, 520.0, 340.0).unwrap();
    let b = layout(&with, 520.0, 340.0).unwrap();
    assert!(b.plot_x > a.plot_x, "加了 Y 軸標題，繪圖區沒有讓出空間");
}

// ── 圖例與標籤 ──────────────────────────────────────────────

#[test]
fn the_legend_names_every_series() {
    let layout = layout(&sample(ChartKind::Bar), 520.0, 340.0).unwrap();
    let names: Vec<&str> = layout.legend.iter().map(|e| e.text.as_str()).collect();
    assert_eq!(names, vec!["北區", "南區"]);
}

#[test]
fn a_pie_legend_names_the_categories_not_the_series() {
    let layout = layout(&sample(ChartKind::Pie), 420.0, 420.0).unwrap();
    let names: Vec<&str> = layout.legend.iter().map(|e| e.text.as_str()).collect();
    assert_eq!(names, vec!["Q1", "Q2", "Q3", "Q4"]);
}

#[test]
fn legend_swatches_match_the_drawn_colours() {
    let layout = layout(&sample(ChartKind::Bar), 520.0, 340.0).unwrap();
    for bar in &layout.bars {
        assert_eq!(
            bar.color_hex, layout.legend[bar.series_index].color_hex,
            "圖例的色塊跟長條的顏色對不起來，圖例就是錯的"
        );
    }
}

#[test]
fn a_right_legend_shrinks_the_plot_area() {
    let mut bottom = sample(ChartKind::Bar);
    bottom.legend = LegendPosition::Bottom;
    let mut right = bottom.clone();
    right.legend = LegendPosition::Right;

    let b = layout(&bottom, 520.0, 340.0).unwrap();
    let r = layout(&right, 520.0, 340.0).unwrap();
    assert!(
        r.plot_width < b.plot_width,
        "圖例放右邊卻沒有讓出寬度，會蓋到圖上"
    );
    assert!(r.plot_height > b.plot_height);
}

#[test]
fn turning_off_the_legend_reclaims_the_space() {
    let mut spec = sample(ChartKind::Bar);
    let with = layout(&spec, 520.0, 340.0).unwrap();
    spec.legend = LegendPosition::None;
    let without = layout(&spec, 520.0, 340.0).unwrap();
    assert!(without.legend.is_empty());
    assert!(without.plot_height > with.plot_height);
}

#[test]
fn data_labels_show_the_original_values() {
    let mut spec = sample(ChartKind::Bar);
    spec.data_labels = LabelPosition::Outside;
    let layout = layout(&spec, 600.0, 380.0).unwrap();
    let texts: Vec<&str> = layout.labels.iter().map(|l| l.text.as_str()).collect();
    assert!(texts.contains(&"120"), "找不到資料標籤 120：{texts:?}");
    assert!(texts.contains(&"200"));
}

#[test]
fn label_decimals_are_respected() {
    let mut spec = sample(ChartKind::Line);
    spec.series = vec![series("比率", &[0.125, 0.5])];
    spec.data_labels = LabelPosition::Outside;
    spec.label_decimals = 2;
    let layout = layout(&spec, 520.0, 340.0).unwrap();
    let texts: Vec<&str> = layout.labels.iter().map(|l| l.text.as_str()).collect();
    assert!(
        texts.contains(&"0.13") || texts.contains(&"0.12"),
        "{texts:?}"
    );
}

#[test]
fn the_title_is_emitted_once_and_centred() {
    let layout = layout(&sample(ChartKind::Bar), 520.0, 340.0).unwrap();
    let titles: Vec<&TextLabel> = layout
        .labels
        .iter()
        .filter(|l| l.text == "季度營收")
        .collect();
    assert_eq!(titles.len(), 1);
    assert!((titles[0].x - 260.0).abs() < 0.5);
}

#[test]
fn an_empty_title_leaves_no_gap() {
    let mut spec = sample(ChartKind::Bar);
    let with = layout(&spec, 520.0, 340.0).unwrap();
    spec.title = String::new();
    let without = layout(&spec, 520.0, 340.0).unwrap();
    assert!(without.plot_y < with.plot_y);
}

// ── 邊界 ────────────────────────────────────────────────────

#[test]
fn a_tiny_canvas_reports_an_error_instead_of_drawing_nonsense() {
    assert!(matches!(
        layout(&sample(ChartKind::Bar), 20.0, 20.0),
        Err(LayoutError::TooSmall)
    ));
}

#[test]
fn identical_values_do_not_divide_by_zero() {
    let mut spec = sample(ChartKind::Line);
    spec.series = vec![series("平的", &[7.0, 7.0, 7.0])];
    let layout = layout(&spec, 400.0, 300.0).unwrap();
    for point in &layout.polylines[0].points {
        assert!(point.y.is_finite(), "值全部相同時算出了 NaN");
    }
}

#[test]
fn non_finite_values_are_skipped_rather_than_poisoning_the_chart() {
    let mut spec = sample(ChartKind::Line);
    spec.series = vec![series("有洞", &[10.0, f64::NAN, 30.0])];
    let layout = layout(&spec, 400.0, 300.0).unwrap();
    assert_eq!(
        layout.polylines[0].points.len(),
        2,
        "NaN 應該跳過，不是畫到畫布外"
    );
    for point in &layout.polylines[0].points {
        assert!(point.x.is_finite() && point.y.is_finite());
    }
}

#[test]
fn series_shorter_than_the_category_list_still_render() {
    let mut spec = sample(ChartKind::Bar);
    spec.series = vec![series("只有兩季", &[10.0, 20.0])];
    let layout = layout(&spec, 520.0, 340.0).unwrap();
    assert_eq!(layout.bars.len(), 2);
    assert_eq!(layout.x_ticks.len(), 2);
}

#[test]
fn every_chart_kind_produces_something_drawable() {
    // 新增類型時最容易發生的事，是忘了接上版面引擎 —— 圖表會靜靜地空白。
    for kind in [
        ChartKind::Bar,
        ChartKind::StackedBar,
        ChartKind::HorizontalBar,
        ChartKind::Line,
        ChartKind::SmoothLine,
        ChartKind::Area,
        ChartKind::StackedArea,
        ChartKind::Pie,
        ChartKind::Doughnut,
        ChartKind::Scatter,
        ChartKind::Radar,
    ] {
        let layout =
            layout(&sample(kind), 520.0, 400.0).unwrap_or_else(|e| panic!("{kind:?}：{e}"));
        let drawn = layout.bars.len()
            + layout.slices.len()
            + layout.scatter_points.len()
            + layout
                .polylines
                .iter()
                .map(|p| p.points.len())
                .sum::<usize>();
        assert!(drawn > 0, "{kind:?} 算不出任何圖形");
    }
}

#[test]
fn layout_is_deterministic() {
    // 兩個平台各算一次，結果必須一模一樣 —— 這是把版面放進核心的全部理由。
    let spec = sample(ChartKind::Bar);
    let a = layout(&spec, 512.0, 384.0).unwrap();
    let b = layout(&spec, 512.0, 384.0).unwrap();
    assert_eq!(a.bars, b.bars);
    assert_eq!(a.y_ticks, b.y_ticks);
    assert_eq!(a.legend, b.legend);
}
