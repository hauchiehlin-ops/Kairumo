//
//  ConformanceVectorTests.swift
//  KairumoTests
//
//  一致性向量（閘門 1）。
//
//  # 這支測試存在的理由
//
//  在此之前，兩端有大量成對的測試，測的是同一件事，但**期望值各寫一份**。
//  查證時抓到的例子：Android 的範本測試檢查「區塊不可以掉到紙外面」，
//  這邊沒有這一條；反過來這邊檢查「頁數要放得下所有區塊」，Android 用
//  另一種寫法檢查。兩邊測的是同一件事的不同子集，
//  **而沒有人知道哪一邊漏了什麼**。
//
//  向量由核心產生（`crates/padnote-core/tests/conformance_vectors.rs`），
//  兩端讀同一份檔案。期望值只有一處，漏不掉也漂不走。
//
//  # 為什麼直接從磁碟讀，不打包進 bundle
//
//  它是測試用的期望值，使用者的裝置上一個位元組都不該有。
//  用 `#filePath` 回推 repo 根目錄，不需要任何建置設定。
//
//  # 失敗了怎麼辦
//
//  先確認核心的改動是不是故意的。是的話重新產生向量：
//  `UPDATE_CONFORMANCE=1 cargo test -p padnote-core --test conformance_vectors`
//  —— 然後**兩個平台的行為都會跟著改**，那正是要被看見的那一刻。
//

import XCTest

@testable import Kairumo

final class ConformanceVectorTests: XCTestCase {

    private func vector(_ name: String) throws -> [String: Any] {
        // apple/Tests/ConformanceVectorTests.swift → repo 根目錄要往上三層。
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = root.appendingPathComponent("docs/conformance/\(name)")
        let data = try Data(contentsOf: url)
        return try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any],
            "\(name) 不是一個 JSON 物件")
    }

    private func cases(_ name: String) throws -> [[String: Any]] {
        try XCTUnwrap(vector(name)["cases"] as? [[String: Any]])
    }

    func testLayoutMetricsMatchTheVector() throws {
        for c in try cases("layout.json") {
            let w = Float(c["width"] as! Double)
            let m = layoutMetrics(width: w)
            XCTAssertEqual(m.gutter, Float(c["gutter"] as! Double), accuracy: 0.001, "寬度 \(w) 的間距")
            XCTAssertEqual(
                m.contentMaxWidth, Float(c["content_max_width"] as! Double), accuracy: 0.001,
                "寬度 \(w) 的內容最大寬度")
            XCTAssertEqual(
                m.readableMaxWidth, Float(c["readable_max_width"] as! Double), accuracy: 0.001,
                "寬度 \(w) 的可讀最大寬度")
            XCTAssertEqual(
                m.sidebarWidth, Float(c["sidebar_width"] as! Double), accuracy: 0.001,
                "寬度 \(w) 的側欄寬度")
            XCTAssertEqual(
                m.sidebarIsInline, c["sidebar_is_inline"] as! Bool, "寬度 \(w) 的側欄是否並排")
            XCTAssertEqual(Int(m.noteColumns), c["note_columns"] as! Int, "寬度 \(w) 的卡片欄數")
            XCTAssertEqual(
                pascal(m.sizeClass), c["size_class"] as! String, "寬度 \(w) 的尺寸級別")
        }
    }

    func testInkPressureCurveMatchesTheVector() throws {
        let tools: [String: ToolKind] = [
            "FountainPen": .fountainPen, "BallPoint": .ballPoint, "Highlighter": .highlighter,
            "Pencil": .pencil, "Brush": .brush, "Marker": .marker, "Watercolor": .watercolor,
        ]
        for c in try cases("ink-curve.json") {
            let name = c["tool"] as! String
            let tool = try XCTUnwrap(tools[name], "向量裡有一個這邊不認得的工具：\(name)")
            XCTAssertEqual(
                inkToolIsPressureSensitive(tool: tool), c["pressure_sensitive"] as! Bool,
                "\(name) 是否吃壓感")
            let pressures = c["pressures"] as! [Double]
            let scales = c["width_scales"] as! [Double]
            for (p, s) in zip(pressures, scales) {
                XCTAssertEqual(
                    inkWidthScale(tool: tool, pressure: Float(p)), Float(s), accuracy: 0.0001,
                    "\(name) 在壓感 \(p) 的線寬倍率")
            }
        }
    }

    func testPalmThresholdsMatchTheVector() throws {
        let v = try vector("palm.json")
        let l = palmThresholdLimits()
        XCTAssertEqual(l.defaultRadiusDp, Float(v["default_radius_dp"] as! Double), accuracy: 0.001)
        XCTAssertEqual(
            l.fingerModeRadiusDp, Float(v["finger_mode_radius_dp"] as! Double), accuracy: 0.001)
        XCTAssertEqual(l.minRadiusDp, Float(v["min_radius_dp"] as! Double), accuracy: 0.001)
        XCTAssertEqual(l.maxRadiusDp, Float(v["max_radius_dp"] as! Double), accuracy: 0.001)
        XCTAssertEqual(Int(l.defaultRetractMs), v["default_retract_ms"] as! Int)
        XCTAssertEqual(Int(l.minRetractMs), v["min_retract_ms"] as! Int)
        XCTAssertEqual(Int(l.maxRetractMs), v["max_retract_ms"] as! Int)

        for c in v["clamped"] as! [[String: Any]] {
            let input = UInt32(c["in"] as! Int)
            XCTAssertEqual(
                Int(palmRetractMsClamped(ms: input)), c["out"] as! Int, "夾制 \(input)")
        }
    }

    /// 墨跡延遲預算（閘門 4）。
    ///
    /// 這兩個數字原本只寫在 `docs/TODO.md` 裡 —— 寫在文件裡的數字擋不住任何人。
    /// 實際的延遲要在實機上量（模擬器的數字沒有意義），但**判定的門檻**
    /// 兩端必須一致，否則同一支筆在兩台裝置上會得到不同結論。
    func testInkLatencyBudgetMatchesTheVector() throws {
        let v = try vector("ink-latency.json")
        let b = inkLatencyBudget()
        XCTAssertEqual(Int(b.medianUs), v["median_us"] as! Int)
        XCTAssertEqual(Int(b.p95Us), v["p95_us"] as! Int)

        for c in v["cases"] as! [[String: Any]] {
            let median = UInt64(c["median_us"] as! Int)
            let p95 = UInt64(c["p95_us"] as! Int)
            XCTAssertEqual(
                inkLatencyMeetsBudget(medianUs: median, p95Us: p95), c["ok"] as! Bool,
                "中位數 \(median) / p95 \(p95)")
        }
    }

    func testSymbolPalettesMatchTheVector() throws {
        let expected = try cases("symbols.json")
        let categories = symbolCategories()
        XCTAssertEqual(expected.count, categories.count, "符號分類數")
        for (c, category) in zip(expected, categories) {
            XCTAssertEqual(pascal(category), c["category"] as! String)
            XCTAssertEqual(
                symbolPalette(category: category), c["symbols"] as! [String],
                "\(c["category"]!) 的符號")
        }
    }

    func testPageGuidesMatchTheVector() throws {
        for c in try cases("page-guides.json") {
            let id = c["paper_id"] as! String
            let guides = pageGuides(paperId: id, width: 800, height: 1132)
            XCTAssertEqual(guides.count, c["count"] as! Int, "\(id) 的輔助線數量")
            for (k, g) in (c["guides"] as! [[String: Any]]).enumerated() {
                XCTAssertEqual(pascal(guides[k].kind), g["kind"] as! String, "\(id) 第 \(k) 條的種類")
                XCTAssertEqual(
                    guides[k].x, Float(g["x"] as! Double), accuracy: 0.001, "\(id) 第 \(k) 條的 x")
                XCTAssertEqual(
                    guides[k].y, Float(g["y"] as! Double), accuracy: 0.001, "\(id) 第 \(k) 條的 y")
            }
        }
    }

    func testPageGeometryMatchesTheVector() throws {
        let v = try vector("page-geometry.json")
        let size = standardPageSize()
        XCTAssertEqual(size[0], Float(v["width"] as! Double), accuracy: 0.001)
        XCTAssertEqual(size[1], Float(v["height"] as! Double), accuracy: 0.001)
    }

    /// Swift 的 enum case 是 `camelCase`，而向量記的是 Rust 那邊 `{:?}`
    /// 印出來的 `PascalCase`。在這裡換算一次，比在向量裡多存一種寫法好 ——
    /// 多存一種就是多一份會漂走的表示。
    private func pascal<T>(_ value: T) -> String {
        let s = String(describing: value)
        return s.prefix(1).uppercased() + s.dropFirst()
    }
}
