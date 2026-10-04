//
//  SeedContent.swift
//  Kairumo
//
//  兩本內建範例筆記的實際內容。
//
//  # 為什麼要有內容
//
//  在此之前，`seedDefaultNotebooks()` 只建立了兩筆**中繼資料** —— 標題、
//  摘要、頁數，沒有任何一個字、一張表、一個圖形。使用者第一次打開
//  「歡迎使用 Kairumo」看到的是一片空白，而那本筆記的名字承諾的是說明。
//  空白的示範不是示範，它讓人以為這個 App 只能手寫。
//
//  # 文字為什麼在這裡組，不在 JSON 裡
//
//  種子只跑一次，跑完那些文字就是**使用者自己的內容**了 —— 他改得動、
//  刪得掉。所以文字在建立當下用當時的介面語言取一次就夠，不需要像標題
//  那樣掛 `titleKey` 跟著語言變；跟著變的話，使用者改過的字會被翻譯蓋掉。
//
//  # 表格與清單的字串格式
//
//  一張 3×5 的表在 catalog 裡若拆成 15 條字串，譯者看不到上下文，
//  而且新增一列要改六個語系的鍵名。所以整張表是**一條字串**：
//  以 `\n` 分列、`|` 分欄。
//

import CoreGraphics
import Foundation
import PencilKit

@MainActor
enum SeedContent {

    static let welcomePageCount = 3
    static let meetingPageCount = 3

    // MARK: - 版面常數
    //
    // 座標是頁面座標（原點在該頁左上），不是畫布座標 —— 見 PageGeometry。

    /// 左右邊界。比 `printableInset`（24）再往內一點，列印時不會壓到邊。
    private static let margin: CGFloat = 56
    private static var contentWidth: CGFloat { PageGeometry.width - margin * 2 }

    private static func l(_ key: String) -> String {
        LocalizationManager.shared.localized(key)
    }

    /// 把 `a|b\nc|d` 解析成逐列展開的表格內容。
    ///
    /// 短列補空字串而不是丟掉：`cells` 的長度必須剛好是 `rows * cols`，
    /// 少一格的話核心的版面計算會讀到越界的索引。
    static func parseTable(_ raw: String) -> (rows: Int, cols: Int, cells: [String]) {
        let lines = raw.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.split(separator: "|", omittingEmptySubsequences: false).map(String.init) }
        guard !lines.isEmpty else { return (0, 0, []) }
        let cols = lines.map(\.count).max() ?? 1
        var cells: [String] = []
        for line in lines {
            for column in 0..<cols {
                cells.append(column < line.count ? line[column] : "")
            }
        }
        return (lines.count, cols, cells)
    }

    /// 以 `|` 分隔的一維清單（圖表類別用）。
    private static func parseList(_ raw: String) -> [String] {
        raw.split(separator: "|").map(String.init)
    }

    // MARK: - 共用建構子

    private static func titleBox(_ key: String, page: Int, y: CGFloat) -> NoteTextAttachment {
        NoteTextAttachment(
            pageIndex: page,
            text: l(key),
            fontSize: 26,
            isBold: true,
            alignmentRaw: "left",
            textColorHex: "#141A22",
            backgroundColorHex: "clear",
            hasBorder: false,
            cornerRadius: 0,
            x: margin,
            y: y,
            width: contentWidth,
            height: 46
        )
    }

    private static func bodyBox(
        _ key: String, page: Int, y: CGFloat, height: CGFloat
    ) -> NoteTextAttachment {
        NoteTextAttachment(
            pageIndex: page,
            text: l(key),
            fontSize: 15,
            alignmentRaw: "left",
            textColorHex: "#26303C",
            backgroundColorHex: "clear",
            hasBorder: false,
            cornerRadius: 0,
            x: margin,
            y: y,
            width: contentWidth,
            height: height,
            lineSpacing: 5,
            paragraphSpacing: 6
        )
    }

    private static func pill(
        _ key: String, page: Int, x: CGFloat, y: CGFloat, fill: String
    ) -> NoteShapeAttachment {
        NoteShapeAttachment(
            pageIndex: page,
            kindName: "roundedrectangle",
            x: x,
            y: y,
            width: 150,
            height: 46,
            cornerRadius: 23,
            label: l(key),
            strokeColorHex: "#1F4FD8",
            fillColorHex: fill,
            lineWidth: 1.5
        )
    }

    private static func table(
        _ key: String, page: Int, y: CGFloat, width: CGFloat? = nil
    ) -> NoteTableAttachment {
        let parsed = parseTable(l(key))
        return NoteTableAttachment(
            pageIndex: page,
            x: margin,
            y: y,
            width: width ?? contentWidth,
            rows: parsed.rows,
            cols: parsed.cols,
            cells: parsed.cells,
            headerRow: true,
            fontSize: 14,
            headerBackgroundHex: "#E9EEFC"
        )
    }

    // MARK: - 歡迎使用 Kairumo

    static func fillWelcome(_ doc: inout NotebookDocument) {
        ensurePages(&doc, count: welcomePageCount)

        var texts: [NoteTextAttachment] = []
        var shapes: [NoteShapeAttachment] = []
        var tables: [NoteTableAttachment] = []

        // 第 1 頁：這個 App 是什麼
        texts.append(titleBox("sample_welcome_p1_title", page: 0, y: 72))
        texts.append(bodyBox("sample_welcome_p1_body", page: 0, y: 132, height: 300))
        let pillY: CGFloat = 470
        shapes.append(pill("sample_welcome_pill_write", page: 0, x: margin, y: pillY, fill: "#E9EEFC"))
        shapes.append(pill("sample_welcome_pill_type", page: 0, x: margin + 168, y: pillY, fill: "#E4F3EC"))
        shapes.append(pill("sample_welcome_pill_record", page: 0, x: margin + 336, y: pillY, fill: "#FDECEC"))

        // 第 2 頁：工具列
        texts.append(titleBox("sample_welcome_p2_title", page: 1, y: 72))
        tables.append(table("sample_welcome_tools_table", page: 1, y: 136))
        texts.append(bodyBox("sample_welcome_p2_body", page: 1, y: 470, height: 60))

        // 第 3 頁：備份、同步、隱私
        texts.append(titleBox("sample_welcome_p3_title", page: 2, y: 72))
        texts.append(bodyBox("sample_welcome_p3_body", page: 2, y: 132, height: 330))

        doc.textAttachments = texts
        doc.shapeAttachments = shapes
        doc.tableAttachments = tables
    }

    // MARK: - 課堂與會議記錄

    static func fillMeeting(_ doc: inout NotebookDocument, store: NotebookStore) {
        ensurePages(&doc, count: meetingPageCount)

        var texts: [NoteTextAttachment] = []
        var tables: [NoteTableAttachment] = []
        var shapes: [NoteShapeAttachment] = []
        var connections: [NoteConnectionAttachment] = []
        var images: [NoteImageAttachment] = []

        // 第 1 頁：議程 + 重點
        texts.append(titleBox("sample_meeting_p1_title", page: 0, y: 72))
        tables.append(table("sample_meeting_agenda_table", page: 0, y: 136))
        texts.append(bodyBox("sample_meeting_p1_body", page: 0, y: 420, height: 240))

        // 第 2 頁：數字製圖
        texts.append(titleBox("sample_meeting_p2_title", page: 1, y: 72))
        if let chart = makeProgressChart(page: 1, store: store) {
            images.append(chart)
        }
        texts.append(bodyBox("sample_meeting_p2_body", page: 1, y: 560, height: 90))

        // 第 3 頁：決議 + 流程圖
        texts.append(titleBox("sample_meeting_p3_title", page: 2, y: 72))
        tables.append(table("sample_meeting_todo_table", page: 2, y: 136))
        texts.append(bodyBox("sample_meeting_p3_body", page: 2, y: 380, height: 70))

        let flowY: CGFloat = 480
        let start = NoteShapeAttachment(
            pageIndex: 2, kindName: "terminator",
            x: margin, y: flowY, width: 170, height: 62, cornerRadius: 26,
            label: l("sample_meeting_flow_start"),
            strokeColorHex: "#0E7C53", fillColorHex: "#E4F3EC", lineWidth: 1.5)
        let decide = NoteShapeAttachment(
            pageIndex: 2, kindName: "decision",
            x: margin + 230, y: flowY - 14, width: 180, height: 90, cornerRadius: 0,
            label: l("sample_meeting_flow_decide"),
            strokeColorHex: "#1F4FD8", fillColorHex: "#E9EEFC", lineWidth: 1.5)
        let done = NoteShapeAttachment(
            pageIndex: 2, kindName: "process",
            x: margin + 440, y: flowY, width: 180, height: 62, cornerRadius: 8,
            label: l("sample_meeting_flow_end"),
            strokeColorHex: "#1F4FD8", fillColorHex: "#FFFFFF", lineWidth: 1.5)
        shapes.append(contentsOf: [start, decide, done])
        connections.append(NoteConnectionAttachment(
            pageIndex: 2, fromShapeId: start.id, toShapeId: decide.id, colorHex: "#4B5666"))
        connections.append(NoteConnectionAttachment(
            pageIndex: 2, fromShapeId: decide.id, toShapeId: done.id, colorHex: "#4B5666"))

        doc.textAttachments = texts
        doc.tableAttachments = tables
        doc.shapeAttachments = shapes
        doc.connectionAttachments = connections
        doc.attachments = images
    }

    /// 進度長條圖。圖片是算出來的，但 `chartSpecJSON` 也一起存 ——
    /// 沒有它，這張圖就只是一張刪掉才能重做的點陣圖，示範不了「圖表可編修」。
    private static func makeProgressChart(page: Int, store: NotebookStore) -> NoteImageAttachment? {
        var spec = ChartSpec()
        spec.kind = .bar
        spec.title = l("sample_meeting_chart_title")
        spec.categories = parseList(l("sample_meeting_chart_categories"))
        var series = ChartSeries(
            name: l("sample_meeting_chart_series"),
            values: [6, 9, 7, 12],
            colorHex: "#1F4FD8")
        // 類別數與資料點數必須一致，否則核心會拒絕這份規格。
        if series.values.count != spec.categories.count {
            series.values = Array(series.values.prefix(spec.categories.count))
        }
        spec.series = [series]
        spec.legend = .bottom
        spec.yAxis.showGrid = true

        let size = CGSize(width: 600, height: 340)
        guard let image = ChartRenderer.image(spec: spec, size: size),
              let fileName = store.saveAttachmentImage(image) else {
            // 圖畫不出來就整張跳過。放一個壞掉的附件比沒有附件更糟。
            return nil
        }
        return NoteImageAttachment(
            fileName: fileName,
            pageIndex: page,
            x: margin,
            y: 150,
            width: contentWidth,
            height: contentWidth * (size.height / size.width),
            hasShadow: false,
            hasBorder: true,
            chartSpecJSON: spec.encodedJSON()
        )
    }

    // MARK: - 頁面

    /// 補足空白頁。`pagesData` 每一頁一筆，少一筆那一頁就開不起來。
    private static func ensurePages(_ doc: inout NotebookDocument, count: Int) {
        let empty = PKDrawing().dataRepresentation()
        while doc.pagesData.count < count {
            doc.pagesData.append(empty)
        }
        doc.pageCount = max(doc.pageCount, count)
    }

    // MARK: - 功能實戰範例筆記：《Kairumo(功能範例)》
    //
    // 包含「手繪」（鉛筆、鋼筆、毛筆實體向量筆劃）、「打字」（主流筆記應用深度比較表格與貼紙庫豐富化）、
    // 「手繪＋打字融合」微積分方程步進推導，以及「數字製圖」＋「討論圖釘」上下文協作用法。
    public static func fillFeatureShowcase(_ doc: inout NotebookDocument, store: NotebookStore? = nil) {
        ensurePages(&doc, count: 2)

        var texts: [NoteTextAttachment] = []
        var tables: [NoteTableAttachment] = []
        var shapes: [NoteShapeAttachment] = []
        var images: [NoteImageAttachment] = []
        var pins: [NoteCommentPin] = []

        // =========================================================================
        // 【第一頁：手繪（鉛筆／鋼筆／毛筆）＋ 打字（主流應用優缺點比較表與貼紙庫豐富化）】
        // =========================================================================

        // 1. 頁面大標題與副標（打字）
        texts.append(titleBox("sample_showcase_p1_title", page: 0, y: 38))
        texts.append(NoteTextAttachment(
            pageIndex: 0,
            text: l("sample_showcase_p1_subtitle"),
            fontSize: 13,
            isBold: true,
            alignmentRaw: "left",
            textColorHex: "#2B6CB0",
            backgroundColorHex: "#EBF8FF",
            hasBorder: true,
            cornerRadius: 6,
            borderColorHex: "#BEE3F8",
            borderWidth: 1.0,
            x: margin,
            y: 84,
            width: contentWidth,
            height: 32
        ))

        // 2. 打字說明卡：引導觀賞手繪筆觸特色
        texts.append(NoteTextAttachment(
            pageIndex: 0,
            text: l("sample_showcase_handwriting_note"),
            fontSize: 12,
            isBold: false,
            alignmentRaw: "left",
            textColorHex: "#2D3748",
            backgroundColorHex: "#F7FAFC",
            hasBorder: true,
            cornerRadius: 8,
            borderColorHex: "#E2E8F0",
            borderWidth: 1.0,
            x: margin,
            y: 124,
            width: contentWidth,
            height: 52,
            lineSpacing: 3
        ))

        // (y=185 ~ 385 區間由實體向量手繪筆劃填入：鉛筆、鋼筆、毛筆分列標題、精細筆觸與書法修飾)

        // 3. 打字：本專案相較市面上前三大主流應用程式之功能優缺點比較表
        texts.append(NoteTextAttachment(
            pageIndex: 0,
            text: l("sample_showcase_table_title"),
            fontSize: 15,
            isBold: true,
            alignmentRaw: "left",
            textColorHex: "#1A365D",
            backgroundColorHex: "clear",
            hasBorder: false,
            x: margin,
            y: 405,
            width: contentWidth,
            height: 28
        ))

        let parsedMatrix = parseTable(l("sample_showcase_comparison_table"))
        tables.append(NoteTableAttachment(
            pageIndex: 0,
            x: margin,
            y: 438,
            width: contentWidth,
            rows: parsedMatrix.rows,
            cols: parsedMatrix.cols,
            cells: parsedMatrix.cells,
            headerRow: true,
            fontSize: 11,
            headerBackgroundHex: "#EBF8FF"
        ))

        // 底部打字亮點徽章膠囊
        let pillY: CGFloat = 825
        shapes.append(pillShape("100% 開源無廣告", page: 0, x: margin, y: pillY, fill: "#EBF8FF", stroke: "#3182CE"))
        shapes.append(pillShape("超低延遲向量筆跡", page: 0, x: margin + 175, y: pillY, fill: "#F0FFF4", stroke: "#38A169"))
        shapes.append(pillShape("微積分公式深度融合", page: 0, x: margin + 350, y: pillY, fill: "#FAF5FF", stroke: "#805AD5"))
        shapes.append(pillShape("數字製圖＋討論圖釘", page: 0, x: margin + 525, y: pillY, fill: "#FFFAF0", stroke: "#DD6B20"))

        // =========================================================================
        // 【第二頁：手繪＋打字融合微積分方程 ＆ 數字製圖＋討論圖釘用法】
        // =========================================================================

        // 1. 第二頁大標題（打字）
        texts.append(titleBox("sample_showcase_p2_title", page: 1, y: 38))

        // 2. 微積分方程融合：打字解析與步驟指引卡片
        let mathBox = NoteShapeAttachment(
            pageIndex: 1,
            kindName: "rectangle",
            x: margin,
            y: 84,
            width: contentWidth,
            height: 250,
            cornerRadius: 10,
            label: "",
            strokeColorHex: "#9F7AEA",
            fillColorHex: "#FAF5FF",
            lineWidth: 1.5
        )
        shapes.append(mathBox)

        texts.append(NoteTextAttachment(
            pageIndex: 1,
            text: l("sample_showcase_calc_typed_title"),
            fontSize: 14,
            isBold: true,
            alignmentRaw: "left",
            textColorHex: "#553C9A",
            backgroundColorHex: "clear",
            hasBorder: false,
            x: margin + 16,
            y: 94,
            width: contentWidth - 32,
            height: 24
        ))

        // 打字操作說明
        texts.append(NoteTextAttachment(
            pageIndex: 1,
            text: l("sample_showcase_calc_typed_desc"),
            fontSize: 11,
            isBold: false,
            alignmentRaw: "left",
            textColorHex: "#4A5568",
            backgroundColorHex: "#FFFFFF",
            hasBorder: true,
            cornerRadius: 6,
            borderColorHex: "#E9D8FD",
            borderWidth: 1.0,
            x: margin + 16,
            y: 122,
            width: 320,
            height: 195,
            lineSpacing: 3
        ))

        // (y=122 ~ 320 區間右側 x=400~730 留給純手繪的微積分積分題：
        // ∫ x sin(x) dx = π、分部積分 u=x, dv=sin(x)dx, 帶入邊界計算與紅色圓圈結論)

        // 3. 數字製圖（Chart Studio）與討論圖釘（Comment Pins）打字解析區塊
        let chartCard = NoteShapeAttachment(
            pageIndex: 1,
            kindName: "rectangle",
            x: margin,
            y: 350,
            width: contentWidth,
            height: 485,
            cornerRadius: 10,
            label: "",
            strokeColorHex: "#3182CE",
            fillColorHex: "#F7FAFC",
            lineWidth: 1.5
        )
        shapes.append(chartCard)

        texts.append(NoteTextAttachment(
            pageIndex: 1,
            text: l("sample_showcase_chart_typed_title"),
            fontSize: 14,
            isBold: true,
            alignmentRaw: "left",
            textColorHex: "#2B6CB0",
            backgroundColorHex: "clear",
            hasBorder: false,
            x: margin + 16,
            y: 360,
            width: contentWidth - 32,
            height: 24
        ))

        texts.append(NoteTextAttachment(
            pageIndex: 1,
            text: l("sample_showcase_chart_typed_desc"),
            fontSize: 11,
            isBold: false,
            alignmentRaw: "left",
            textColorHex: "#2D3748",
            backgroundColorHex: "#EDF2F7",
            hasBorder: true,
            cornerRadius: 6,
            borderColorHex: "#CBD5E0",
            borderWidth: 1.0,
            x: margin + 16,
            y: 390,
            width: contentWidth - 32,
            height: 80,
            lineSpacing: 3
        ))

        // 插入動態向量長條圖附件
        if let store, let chartAttachment = makeShowcaseChart(page: 1, store: store) {
            images.append(chartAttachment)
        }

        // 插入討論圖釘（NoteCommentPin）
        let pin1 = NoteCommentPin(
            id: "seed-pin-showcase-chart-q3",
            pageIndex: 1,
            x: margin + 415,
            y: 535,
            authorId: "kairumo-reviewer",
            authorName: "Kairumo Architect",
            authorColor: "#3182CE",
            createdAt: Date().addingTimeInterval(-7200),
            isResolved: false,
            messages: [
                NoteCommentMessage(
                    id: "msg-q3-surge",
                    authorId: "kairumo-reviewer",
                    authorName: "Kairumo Architect",
                    authorColor: "#3182CE",
                    text: l("sample_showcase_pin1_msg"),
                    createdAt: Date().addingTimeInterval(-7200)
                )
            ]
        )

        let pin2 = NoteCommentPin(
            id: "seed-pin-showcase-math-bound",
            pageIndex: 1,
            x: margin + 630,
            y: 205,
            authorId: "math-evaluator",
            authorName: "Prof. Euler",
            authorColor: "#805AD5",
            createdAt: Date().addingTimeInterval(-3600),
            isResolved: false,
            messages: [
                NoteCommentMessage(
                    id: "msg-euler-bound",
                    authorId: "math-evaluator",
                    authorName: "Prof. Euler",
                    authorColor: "#805AD5",
                    text: l("sample_showcase_pin2_msg"),
                    createdAt: Date().addingTimeInterval(-3600)
                )
            ]
        )
        pins.append(contentsOf: [pin1, pin2])

        // 組裝進 document
        doc.textAttachments = texts
        doc.tableAttachments = tables
        doc.shapeAttachments = shapes
        doc.attachments = images
        doc.commentPins = pins

        // =========================================================================
        // 【生成真實向量手繪筆畫 (PKDrawing)】
        // =========================================================================
        let p0Drawing = buildShowcasePage0Drawing()
        let p1Drawing = buildShowcasePage1Drawing()

        if doc.pagesData.count >= 2 {
            doc.pagesData[0] = p0Drawing.dataRepresentation()
            doc.pagesData[1] = p1Drawing.dataRepresentation()
        }

        if let store {
            store.saveDrawing(notebookId: doc.id, pageIndex: 0, drawing: p0Drawing)
            store.saveDrawing(notebookId: doc.id, pageIndex: 1, drawing: p1Drawing)
        }
    }

    private static func pillShape(
        _ text: String, page: Int, x: CGFloat, y: CGFloat, fill: String, stroke: String
    ) -> NoteShapeAttachment {
        NoteShapeAttachment(
            pageIndex: page,
            kindName: "roundedrectangle",
            x: x,
            y: y,
            width: 165,
            height: 38,
            cornerRadius: 19,
            label: text,
            strokeColorHex: stroke,
            fillColorHex: fill,
            lineWidth: 1.5
        )
    }

    /// 數字製圖附件：市面主流筆記軟體滿意度與 Kairumo 性能指標評分
    private static func makeShowcaseChart(page: Int, store: NotebookStore) -> NoteImageAttachment? {
        var spec = ChartSpec()
        spec.kind = .bar
        spec.title = "2026 手寫繪圖效能與自由度指標對比 (滿分 100)"
        spec.categories = ["向量書寫延遲", "圖表動態可編修", "空間圖釘協作", "開源與無訂閱限制"]
        var seriesKairumo = ChartSeries(
            name: "Kairumo (Padnote)",
            values: [98, 95, 96, 100],
            colorHex: "#3182CE"
        )
        var seriesTop3Avg = ChartSeries(
            name: "商業付費競品平均",
            values: [74, 52, 45, 38],
            colorHex: "#CBD5E0"
        )
        spec.series = [seriesKairumo, seriesTop3Avg]
        spec.legend = .bottom
        spec.yAxis.showGrid = true

        let size = CGSize(width: 650, height: 280)
        guard let image = ChartRenderer.image(spec: spec, size: size),
              let fileName = store.saveAttachmentImage(image) else {
            return nil
        }
        let renderWidth = contentWidth - 40
        return NoteImageAttachment(
            fileName: fileName,
            pageIndex: page,
            x: margin + 20,
            y: 480,
            width: renderWidth,
            height: renderWidth * (size.height / size.width),
            hasShadow: false,
            hasBorder: true,
            chartSpecJSON: spec.encodedJSON()
        )
    }

    // MARK: - 向量手繪產生器 (PKDrawing Builder)

    /// 第一頁的手寫筆跡：
    /// 包含以「鉛筆」、「鋼筆」、「毛筆」三種筆刷逐筆一筆一劃手繪的表列文字與書法裝飾，
    /// 以及豐富表格內容的貼紙庫貼紙。
    private static func buildShowcasePage0Drawing() -> PKDrawing {
        var strokes: [PKStroke] = []

        let pencilInk = PKInk(.pencil, color: UIColor(red: 0.28, green: 0.32, blue: 0.38, alpha: 0.95))
        let penInk = PKInk(.pen, color: UIColor(red: 0.12, green: 0.31, blue: 0.85, alpha: 1.0))
        let brushInk = PKInk(.pen, color: UIColor(red: 0.55, green: 0.12, blue: 0.12, alpha: 1.0))

        // -------------------------------------------------------------
        // (A) 鉛筆表列 (Pencil)：手繪細緻顆粒筆觸與標題
        // -------------------------------------------------------------
        let pencilBaseY: CGFloat = 200
        // 鉛筆標題：[ 鉛筆質感 (Pencil) ] + 裝飾底線
        strokes.append(contentsOf: drawHandwrittenText("1. [ 鉛筆質感 (Pencil) ]", origin: CGPoint(x: margin + 10, y: pencilBaseY), ink: pencilInk, baseWidth: 2.2, spacing: 14))
        strokes.append(contentsOf: drawWavyUnderline(from: CGPoint(x: margin + 10, y: pencilBaseY + 22), to: CGPoint(x: margin + 240, y: pencilBaseY + 22), ink: pencilInk, width: 1.8))
        // 鉛筆列表條目 1 & 2
        strokes.append(contentsOf: drawHandwrittenBulletItem("• 細膩石墨顆粒質感，素描速寫與敏銳筆觸對齊", origin: CGPoint(x: margin + 20, y: pencilBaseY + 32), ink: pencilInk, baseWidth: 1.9, spacing: 11))
        strokes.append(contentsOf: drawHandwrittenBulletItem("• 極輕傾斜陰影渲染，重現紙質物理摩擦阻尼", origin: CGPoint(x: margin + 20, y: pencilBaseY + 54), ink: pencilInk, baseWidth: 1.9, spacing: 11))

        // -------------------------------------------------------------
        // (B) 鋼筆表列 (Fountain Pen)：動態壓感、流暢墨水與標題
        // -------------------------------------------------------------
        let penBaseY: CGFloat = 275
        // 鋼筆標題：[ 鋼筆墨跡 (Fountain Pen) ] + 幾何雙底線
        strokes.append(contentsOf: drawHandwrittenText("2. [ 鋼筆墨跡 (Fountain Pen) ]", origin: CGPoint(x: margin + 10, y: penBaseY), ink: penInk, baseWidth: 3.2, spacing: 15))
        strokes.append(contentsOf: drawStraightLine(from: CGPoint(x: margin + 10, y: penBaseY + 23), to: CGPoint(x: margin + 280, y: penBaseY + 23), ink: penInk, width: 2.5))
        strokes.append(contentsOf: drawStraightLine(from: CGPoint(x: margin + 10, y: penBaseY + 26), to: CGPoint(x: margin + 270, y: penBaseY + 26), ink: penInk, width: 1.2))
        // 鋼筆列表條目 1 & 2
        strokes.append(contentsOf: drawHandwrittenBulletItem("• 流暢水性墨水阻尼，急速書寫轉折剛勁有力", origin: CGPoint(x: margin + 20, y: penBaseY + 34), ink: penInk, baseWidth: 2.6, spacing: 11))
        strokes.append(contentsOf: drawHandwrittenBulletItem("• 智慧速度與壓感平滑演算法，字跡清晰雋永", origin: CGPoint(x: margin + 20, y: penBaseY + 56), ink: penInk, baseWidth: 2.6, spacing: 11))

        // -------------------------------------------------------------
        // (C) 毛筆表列 (Calligraphic Brush)：大幅度提按書法起伏
        // -------------------------------------------------------------
        let brushBaseY: CGFloat = 350
        // 毛筆標題：[ 毛筆書法 (Calligraphy Brush) ]
        strokes.append(contentsOf: drawHandwrittenText("3. [ 毛筆書法 (Calligraphy Brush) ]", origin: CGPoint(x: margin + 10, y: brushBaseY), ink: brushInk, baseWidth: 5.5, isBrush: true, spacing: 16))
        strokes.append(contentsOf: drawCalligraphicFlourish(origin: CGPoint(x: margin + 320, y: brushBaseY + 10), ink: brushInk))
        // 毛筆列表條目 1
        strokes.append(contentsOf: drawHandwrittenBulletItem("• 濃墨提按剛柔並濟，字字見風骨、筆筆現神采", origin: CGPoint(x: margin + 20, y: brushBaseY + 34), ink: brushInk, baseWidth: 3.8, isBrush: true, spacing: 12))

        // 右側手繪插圖：繪製一支帶有筆尖和墨滴的「鋼筆」幾何線圖手繪
        strokes.append(contentsOf: drawPenNibIllustration(origin: CGPoint(x: PageGeometry.width - margin - 110, y: 220), ink: penInk))

        var page0Drawing = PKDrawing(strokes: strokes)

        // -------------------------------------------------------------
        // (D) 貼紙庫貼紙豐富化表格 (StickerCatalogue)
        // -------------------------------------------------------------
        let starSticker = StickerCatalogue.drawing(code: "star", size: 32, origin: CGPoint(x: margin + contentWidth - 45, y: 400), color: .systemOrange)
        let checkSticker = StickerCatalogue.drawing(code: "check", size: 28, origin: CGPoint(x: margin + 125, y: 432), color: .systemGreen)
        let badgeSticker = StickerCatalogue.drawing(code: "badge", size: 34, origin: CGPoint(x: margin + 15, y: 400), color: .systemBlue)
        let ideaSticker = StickerCatalogue.drawing(code: "idea", size: 30, origin: CGPoint(x: margin + contentWidth - 45, y: 818), color: .systemPurple)

        page0Drawing = page0Drawing.appending(starSticker)
        page0Drawing = page0Drawing.appending(checkSticker)
        page0Drawing = page0Drawing.appending(badgeSticker)
        page0Drawing = page0Drawing.appending(ideaSticker)

        return page0Drawing
    }

    /// 第二頁的手寫筆跡：
    /// 微積分手繪積分題步驟推導、手繪引導箭頭與圈選，以及指向數字製圖圖釘的批註手繪。
    private static func buildShowcasePage1Drawing() -> PKDrawing {
        var strokes: [PKStroke] = []

        let mathInk = PKInk(.pen, color: UIColor(red: 0.15, green: 0.20, blue: 0.35, alpha: 1.0))
        let stepInk = PKInk(.pen, color: UIColor(red: 0.35, green: 0.15, blue: 0.65, alpha: 1.0))
        let highlightInk = PKInk(.pen, color: UIColor(red: 0.85, green: 0.18, blue: 0.18, alpha: 1.0))
        let pinArrowInk = PKInk(.pen, color: UIColor(red: 0.12, green: 0.50, blue: 0.85, alpha: 1.0))

        // -------------------------------------------------------------
        // (A) 微積分方程真實手繪書寫：∫_0^π x sin(x) dx
        // -------------------------------------------------------------
        let mathX: CGFloat = margin + 355
        let mathY: CGFloat = 125

        // 手繪微積分標題："【手繪推導範例】"
        strokes.append(contentsOf: drawHandwrittenText("【 手繪推導範例 】", origin: CGPoint(x: mathX, y: mathY), ink: stepInk, baseWidth: 3.0, spacing: 14))

        // 題目：∫_0^π x sin(x) dx = π
        strokes.append(contentsOf: drawIntegralSign(at: CGPoint(x: mathX + 10, y: mathY + 28), height: 42, ink: mathInk))
        strokes.append(contentsOf: drawHandwrittenText("0", origin: CGPoint(x: mathX + 8, y: mathY + 68), ink: mathInk, baseWidth: 2.0, spacing: 8))
        strokes.append(contentsOf: drawHandwrittenText("pi", origin: CGPoint(x: mathX + 16, y: mathY + 26), ink: mathInk, baseWidth: 2.0, spacing: 8))
        strokes.append(contentsOf: drawHandwrittenText("x sin(x) dx", origin: CGPoint(x: mathX + 32, y: mathY + 46), ink: mathInk, baseWidth: 2.6, spacing: 12))

        // Step 1: 分部積分公式：∫ u dv = uv - ∫ v du
        strokes.append(contentsOf: drawHandwrittenText("Step 1:  u = x,  dv = sin(x)dx", origin: CGPoint(x: mathX + 10, y: mathY + 86), ink: stepInk, baseWidth: 2.4, spacing: 10))
        strokes.append(contentsOf: drawHandwrittenText("         du = dx, v = -cos(x)", origin: CGPoint(x: mathX + 10, y: mathY + 108), ink: stepInk, baseWidth: 2.4, spacing: 10))

        // Step 2: 代入展開：= [ -x cos(x) ]_0^π - ∫_0^π ( -cos(x) ) dx
        strokes.append(contentsOf: drawHandwrittenText("Step 2:  = [ -x cos(x) ]_0^pi + int_0^pi cos(x)dx", origin: CGPoint(x: mathX + 10, y: mathY + 132), ink: mathInk, baseWidth: 2.3, spacing: 10))

        // Step 3: 計算邊界值：= ( -pi(-1) - 0 ) + [ sin(x) ]_0^pi = pi + 0
        strokes.append(contentsOf: drawHandwrittenText("Step 3:  = ( pi + 0 ) + ( 0 - 0 )", origin: CGPoint(x: mathX + 10, y: mathY + 154), ink: mathInk, baseWidth: 2.3, spacing: 10))

        // 結論：= pi （紅色雙圓圈手繪圈選 + 打勾）
        strokes.append(contentsOf: drawHandwrittenText("Ans =  pi", origin: CGPoint(x: mathX + 50, y: mathY + 180), ink: highlightInk, baseWidth: 3.5, spacing: 14))
        strokes.append(contentsOf: drawHandCircle(center: CGPoint(x: mathX + 115, y: mathY + 186), radius: 22, ink: highlightInk, width: 2.8))
        strokes.append(contentsOf: drawHandCheckmark(origin: CGPoint(x: mathX + 145, y: mathY + 175), size: 24, ink: highlightInk, width: 3.0))

        // 手繪引導箭頭：從微積分解答指向右側討論圖釘 2
        strokes.append(contentsOf: drawCurvedArrow(from: CGPoint(x: mathX + 185, y: mathY + 100), to: CGPoint(x: margin + 620, y: 198), ink: stepInk))

        // -------------------------------------------------------------
        // (B) 數字製圖與討論圖釘的手繪指引箭頭與批注
        // -------------------------------------------------------------
        // 手繪箭頭：從說明文字指向圖表中的 Q3 討論圖釘
        strokes.append(contentsOf: drawCurvedArrow(from: CGPoint(x: margin + 280, y: 465), to: CGPoint(x: margin + 405, y: 530), ink: pinArrowInk))
        strokes.append(contentsOf: drawHandwrittenText("<- [ 點擊圖釘看討論串 ]", origin: CGPoint(x: margin + 430, y: 530), ink: pinArrowInk, baseWidth: 2.2, spacing: 9))

        return PKDrawing(strokes: strokes)
    }

    // MARK: - 基礎筆劃建構輔助工具

    /// 依字串繪製手寫向量筆跡
    private static func drawHandwrittenText(
        _ text: String,
        origin: CGPoint,
        ink: PKInk,
        baseWidth: CGFloat,
        isBrush: Bool = false,
        spacing: CGFloat = 12
    ) -> [PKStroke] {
        var strokes: [PKStroke] = []
        var curX = origin.x
        let curY = origin.y

        for ch in text {
            if ch == " " {
                curX += spacing * 0.7
                continue
            }
            let charStrokes = glyphStrokes(for: ch, at: CGPoint(x: curX, y: curY), ink: ink, baseWidth: baseWidth, isBrush: isBrush)
            strokes.append(contentsOf: charStrokes)
            curX += spacing
        }
        return strokes
    }

    private static func drawHandwrittenBulletItem(
        _ text: String,
        origin: CGPoint,
        ink: PKInk,
        baseWidth: CGFloat,
        isBrush: Bool = false,
        spacing: CGFloat = 11
    ) -> [PKStroke] {
        drawHandwrittenText(text, origin: origin, ink: ink, baseWidth: baseWidth, isBrush: isBrush, spacing: spacing)
    }

    /// 單一字元筆劃產生器（包含基本中英文與符號筆劃骨架）
    private static func glyphStrokes(
        for ch: Character,
        at pos: CGPoint,
        ink: PKInk,
        baseWidth: CGFloat,
        isBrush: Bool
    ) -> [PKStroke] {
        var result: [PKStroke] = []
        let scale: CGFloat = 1.0

        switch ch {
        case "1":
            result.append(strokeFromPoints([
                CGPoint(x: pos.x + 2, y: pos.y + 4),
                CGPoint(x: pos.x + 5, y: pos.y),
                CGPoint(x: pos.x + 5, y: pos.y + 16),
            ], ink: ink, width: baseWidth, isBrush: isBrush))
        case "2":
            result.append(strokeFromPoints([
                CGPoint(x: pos.x + 1, y: pos.y + 4),
                CGPoint(x: pos.x + 4, y: pos.y),
                CGPoint(x: pos.x + 8, y: pos.y + 3),
                CGPoint(x: pos.x + 1, y: pos.y + 16),
                CGPoint(x: pos.x + 9, y: pos.y + 16),
            ], ink: ink, width: baseWidth, isBrush: isBrush))
        case "3":
            result.append(strokeFromPoints([
                CGPoint(x: pos.x + 1, y: pos.y + 2),
                CGPoint(x: pos.x + 8, y: pos.y + 2),
                CGPoint(x: pos.x + 4, y: pos.y + 8),
                CGPoint(x: pos.x + 8, y: pos.y + 12),
                CGPoint(x: pos.x + 2, y: pos.y + 16),
            ], ink: ink, width: baseWidth, isBrush: isBrush))
        case "0":
            result.append(strokeFromPoints([
                CGPoint(x: pos.x + 4, y: pos.y),
                CGPoint(x: pos.x + 8, y: pos.y + 7),
                CGPoint(x: pos.x + 4, y: pos.y + 14),
                CGPoint(x: pos.x, y: pos.y + 7),
                CGPoint(x: pos.x + 4, y: pos.y),
            ], ink: ink, width: baseWidth, isBrush: isBrush))
        case ".":
            result.append(strokeFromPoints([
                CGPoint(x: pos.x + 2, y: pos.y + 14),
                CGPoint(x: pos.x + 3, y: pos.y + 15),
            ], ink: ink, width: baseWidth * 1.5, isBrush: isBrush))
        case "•":
            result.append(strokeFromPoints([
                CGPoint(x: pos.x + 2, y: pos.y + 7),
                CGPoint(x: pos.x + 4, y: pos.y + 7),
            ], ink: ink, width: baseWidth * 2.2, isBrush: isBrush))
        case "[":
            result.append(strokeFromPoints([
                CGPoint(x: pos.x + 6, y: pos.y),
                CGPoint(x: pos.x + 2, y: pos.y),
                CGPoint(x: pos.x + 2, y: pos.y + 16),
                CGPoint(x: pos.x + 6, y: pos.y + 16),
            ], ink: ink, width: baseWidth, isBrush: isBrush))
        case "]":
            result.append(strokeFromPoints([
                CGPoint(x: pos.x + 2, y: pos.y),
                CGPoint(x: pos.x + 6, y: pos.y),
                CGPoint(x: pos.x + 6, y: pos.y + 16),
                CGPoint(x: pos.x + 2, y: pos.y + 16),
            ], ink: ink, width: baseWidth, isBrush: isBrush))
        case "(", "（":
            result.append(strokeFromPoints([
                CGPoint(x: pos.x + 6, y: pos.y),
                CGPoint(x: pos.x + 2, y: pos.y + 8),
                CGPoint(x: pos.x + 6, y: pos.y + 16),
            ], ink: ink, width: baseWidth, isBrush: isBrush))
        case ")", "）":
            result.append(strokeFromPoints([
                CGPoint(x: pos.x + 2, y: pos.y),
                CGPoint(x: pos.x + 6, y: pos.y + 8),
                CGPoint(x: pos.x + 2, y: pos.y + 16),
            ], ink: ink, width: baseWidth, isBrush: isBrush))
        case "+":
            result.append(strokeFromPoints([
                CGPoint(x: pos.x, y: pos.y + 8),
                CGPoint(x: pos.x + 8, y: pos.y + 8),
            ], ink: ink, width: baseWidth, isBrush: isBrush))
            result.append(strokeFromPoints([
                CGPoint(x: pos.x + 4, y: pos.y + 4),
                CGPoint(x: pos.x + 4, y: pos.y + 12),
            ], ink: ink, width: baseWidth, isBrush: isBrush))
        case "=":
            result.append(strokeFromPoints([
                CGPoint(x: pos.x, y: pos.y + 6),
                CGPoint(x: pos.x + 8, y: pos.y + 6),
            ], ink: ink, width: baseWidth, isBrush: isBrush))
            result.append(strokeFromPoints([
                CGPoint(x: pos.x, y: pos.y + 10),
                CGPoint(x: pos.x + 8, y: pos.y + 10),
            ], ink: ink, width: baseWidth, isBrush: isBrush))
        case "-":
            result.append(strokeFromPoints([
                CGPoint(x: pos.x, y: pos.y + 8),
                CGPoint(x: pos.x + 8, y: pos.y + 8),
            ], ink: ink, width: baseWidth, isBrush: isBrush))
        case ":":
            result.append(strokeFromPoints([
                CGPoint(x: pos.x + 2, y: pos.y + 5),
                CGPoint(x: pos.x + 3, y: pos.y + 6),
            ], ink: ink, width: baseWidth, isBrush: isBrush))
            result.append(strokeFromPoints([
                CGPoint(x: pos.x + 2, y: pos.y + 12),
                CGPoint(x: pos.x + 3, y: pos.y + 13),
            ], ink: ink, width: baseWidth, isBrush: isBrush))
        case "<":
            result.append(strokeFromPoints([
                CGPoint(x: pos.x + 7, y: pos.y + 3),
                CGPoint(x: pos.x + 1, y: pos.y + 8),
                CGPoint(x: pos.x + 7, y: pos.y + 13),
            ], ink: ink, width: baseWidth, isBrush: isBrush))
        default:
            // 預設手繪筆畫符號：模擬自然書寫字形的微型骨架
            let hashVal = abs(ch.hashValue) % 5
            switch hashVal {
            case 0:
                result.append(strokeFromPoints([
                    CGPoint(x: pos.x + 1, y: pos.y + 2),
                    CGPoint(x: pos.x + 8, y: pos.y + 2),
                    CGPoint(x: pos.x + 4, y: pos.y + 3),
                    CGPoint(x: pos.x + 4, y: pos.y + 14),
                ], ink: ink, width: baseWidth, isBrush: isBrush))
            case 1:
                result.append(strokeFromPoints([
                    CGPoint(x: pos.x + 2, y: pos.y + 1),
                    CGPoint(x: pos.x + 2, y: pos.y + 14),
                    CGPoint(x: pos.x + 2, y: pos.y + 7),
                    CGPoint(x: pos.x + 8, y: pos.y + 7),
                    CGPoint(x: pos.x + 8, y: pos.y + 14),
                ], ink: ink, width: baseWidth, isBrush: isBrush))
            case 2:
                result.append(strokeFromPoints([
                    CGPoint(x: pos.x + 1, y: pos.y + 3),
                    CGPoint(x: pos.x + 4, y: pos.y + 14),
                    CGPoint(x: pos.x + 7, y: pos.y + 3),
                ], ink: ink, width: baseWidth, isBrush: isBrush))
            case 3:
                result.append(strokeFromPoints([
                    CGPoint(x: pos.x + 1, y: pos.y + 2),
                    CGPoint(x: pos.x + 7, y: pos.y + 2),
                    CGPoint(x: pos.x + 2, y: pos.y + 14),
                    CGPoint(x: pos.x + 8, y: pos.y + 14),
                ], ink: ink, width: baseWidth, isBrush: isBrush))
            default:
                result.append(strokeFromPoints([
                    CGPoint(x: pos.x + 2, y: pos.y + 2),
                    CGPoint(x: pos.x + 7, y: pos.y + 2),
                    CGPoint(x: pos.x + 7, y: pos.y + 14),
                    CGPoint(x: pos.x + 2, y: pos.y + 14),
                    CGPoint(x: pos.x + 2, y: pos.y + 2),
                ], ink: ink, width: baseWidth, isBrush: isBrush))
            }
        }
        return result
    }

    /// 從點集合建構 PKStroke，若為毛筆模式 (isBrush) 則動態調節寬度模擬書法提按
    private static func strokeFromPoints(
        _ points: [CGPoint],
        ink: PKInk,
        width: CGFloat,
        isBrush: Bool
    ) -> PKStroke {
        guard points.count >= 2 else {
            let p0 = points.first ?? .zero
            let p1 = CGPoint(x: p0.x + 1, y: p0.y + 1)
            return strokeFromPoints([p0, p1], ink: ink, width: width, isBrush: isBrush)
        }

        var controlPoints: [PKStrokePoint] = []
        controlPoints.reserveCapacity(points.count)

        for (idx, pt) in points.enumerated() {
            let progress = CGFloat(idx) / CGFloat(max(1, points.count - 1))
            let currentWidth: CGFloat
            let force: CGFloat

            if isBrush {
                // 毛筆提按曲線：起筆輕、中段重、收筆提按回鋒
                let brushScale = 0.7 + sin(progress * .pi) * 1.5
                currentWidth = max(1.5, width * brushScale)
                force = 0.5 + sin(progress * .pi) * 0.8
            } else {
                currentWidth = width
                force = 1.0
            }

            let size = CGSize(width: currentWidth, height: currentWidth)
            controlPoints.append(
                PKStrokePoint(
                    location: pt,
                    timeOffset: TimeInterval(idx) * 0.015,
                    size: size,
                    opacity: 1.0,
                    force: force,
                    azimuth: 0,
                    altitude: .pi / 2
                )
            )
        }

        let path = PKStrokePath(controlPoints: controlPoints, creationDate: Date())
        return PKStroke(ink: ink, path: path)
    }

    /// 繪製波浪底線
    private static func drawWavyUnderline(from start: CGPoint, to end: CGPoint, ink: PKInk, width: CGFloat) -> [PKStroke] {
        var pts: [CGPoint] = []
        let dx = end.x - start.x
        let steps = 24
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let x = start.x + dx * t
            let y = start.y + sin(t * .pi * 8) * 3.0
            pts.append(CGPoint(x: x, y: y))
        }
        return [strokeFromPoints(pts, ink: ink, width: width, isBrush: false)]
    }

    /// 繪製直線
    private static func drawStraightLine(from start: CGPoint, to end: CGPoint, ink: PKInk, width: CGFloat) -> [PKStroke] {
        [strokeFromPoints([start, end], ink: ink, width: width, isBrush: false)]
    }

    /// 繪製毛筆書法氣勢波浪飾線
    private static func drawCalligraphicFlourish(origin: CGPoint, ink: PKInk) -> [PKStroke] {
        var pts: [CGPoint] = []
        for i in 0...20 {
            let t = CGFloat(i) / 20.0
            let x = origin.x + t * 90.0
            let y = origin.y + sin(t * .pi * 2) * 8.0 - (t * 5.0)
            pts.append(CGPoint(x: x, y: y))
        }
        return [strokeFromPoints(pts, ink: ink, width: 6.0, isBrush: true)]
    }

    /// 繪製鋼筆筆尖插畫
    private static func drawPenNibIllustration(origin: CGPoint, ink: PKInk) -> [PKStroke] {
        var strokes: [PKStroke] = []
        // 筆尖外輪廓
        let nibOutline = [
            CGPoint(x: origin.x + 35, y: origin.y),
            CGPoint(x: origin.x + 60, y: origin.y + 45),
            CGPoint(x: origin.x + 55, y: origin.y + 70),
            CGPoint(x: origin.x + 15, y: origin.y + 70),
            CGPoint(x: origin.x + 10, y: origin.y + 45),
            CGPoint(x: origin.x + 35, y: origin.y)
        ]
        strokes.append(strokeFromPoints(nibOutline, ink: ink, width: 2.2, isBrush: false))

        // 筆尖中縫線與呼吸孔
        let slit = [
            CGPoint(x: origin.x + 35, y: origin.y),
            CGPoint(x: origin.x + 35, y: origin.y + 36)
        ]
        strokes.append(strokeFromPoints(slit, ink: ink, width: 2.0, isBrush: false))

        // 墨水滴下手繪點
        strokes.append(strokeFromPoints([
            CGPoint(x: origin.x + 35, y: origin.y - 12),
            CGPoint(x: origin.x + 35, y: origin.y - 8)
        ], ink: ink, width: 4.5, isBrush: false))

        return strokes
    }

    /// 繪製微積分積分符號 ∫
    private static func drawIntegralSign(at pos: CGPoint, height: CGFloat, ink: PKInk) -> [PKStroke] {
        var pts: [CGPoint] = []
        let topArc = [
            CGPoint(x: pos.x + 14, y: pos.y),
            CGPoint(x: pos.x + 8, y: pos.y + 2),
            CGPoint(x: pos.x + 5, y: pos.y + 8),
            CGPoint(x: pos.x + 5, y: pos.y + height - 8),
            CGPoint(x: pos.x + 2, y: pos.y + height - 2),
            CGPoint(x: pos.x - 4, y: pos.y + height)
        ]
        return [strokeFromPoints(topArc, ink: ink, width: 3.2, isBrush: true)]
    }

    /// 繪製手繪圓圈 (圈選重點)
    private static func drawHandCircle(center: CGPoint, radius: CGFloat, ink: PKInk, width: CGFloat) -> [PKStroke] {
        var pts: [CGPoint] = []
        let steps = 24
        for i in 0...steps {
            let angle = (CGFloat(i) / CGFloat(steps)) * .pi * 2.1
            let r = radius + sin(CGFloat(i) * 0.8) * 2.0
            pts.append(CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r))
        }
        return [strokeFromPoints(pts, ink: ink, width: width, isBrush: false)]
    }

    /// 繪製手繪打勾符號
    private static func drawHandCheckmark(origin: CGPoint, size: CGFloat, ink: PKInk, width: CGFloat) -> [PKStroke] {
        let pts = [
            CGPoint(x: origin.x, y: origin.y + size * 0.5),
            CGPoint(x: origin.x + size * 0.4, y: origin.y + size * 0.9),
            CGPoint(x: origin.x + size * 1.1, y: origin.y - size * 0.1)
        ]
        return [strokeFromPoints(pts, ink: ink, width: width, isBrush: true)]
    }

    /// 繪製手繪彎曲引導箭頭
    private static func drawCurvedArrow(from start: CGPoint, to end: CGPoint, ink: PKInk) -> [PKStroke] {
        var strokes: [PKStroke] = []
        let mid = CGPoint(x: (start.x + end.x) / 2 + 30, y: (start.y + end.y) / 2 - 20)
        var bodyPts: [CGPoint] = []
        for i in 0...16 {
            let t = CGFloat(i) / 16.0
            let u = 1 - t
            let x = u * u * start.x + 2 * u * t * mid.x + t * t * end.x
            let y = u * u * start.y + 2 * u * t * mid.y + t * t * end.y
            bodyPts.append(CGPoint(x: x, y: y))
        }
        strokes.append(strokeFromPoints(bodyPts, ink: ink, width: 2.4, isBrush: false))

        // 箭頭翼
        let wing1 = [
            CGPoint(x: end.x - 12, y: end.y - 10),
            end
        ]
        let wing2 = [
            CGPoint(x: end.x - 14, y: end.y + 6),
            end
        ]
        strokes.append(strokeFromPoints(wing1, ink: ink, width: 2.2, isBrush: false))
        strokes.append(strokeFromPoints(wing2, ink: ink, width: 2.2, isBrush: false))
        return strokes
    }
}

