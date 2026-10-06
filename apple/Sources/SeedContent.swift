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

    // MARK: - 《Kairumo手冊》：全部用手繪筆畫完成
    //
    // 沒有任何文字方塊或形狀物件：標題是逐字手寫、插圖是一筆一筆畫的。
    // 筆畫來自 `assets/seed/kairumo-manual-ink.json`（由 `scripts/manual_ink/manual.py` 產生，
    // Android 讀同一份），所以兩個平台畫出來是同一本。

    static let kairumoManualId = "seed-kairumo-manual-v1"
    static let kairumoManualTitle = "Kairumo手冊"

    /// 讀手冊的 JSON 資源（`Resources/Templates` 或 bundle 根目錄）。
    private static func manualJSON(_ name: String) -> [String: Any]? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "Templates")
            ?? Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return root
    }

    /// 把 JSON 的每一頁筆畫變成 `PKDrawing`。
    private static func manualDrawings(from root: [String: Any]) -> [PKDrawing] {
        guard let pages = root["pages"] as? [[String: Any]] else { return [] }
        return pages.map { page in
            var strokes: [PKStroke] = []
            for raw in (page["strokes"] as? [[String: Any]]) ?? [] {
                guard let hex = raw["color"] as? String,
                      let width = (raw["width"] as? NSNumber).map({ CGFloat($0.doubleValue) }),
                      let rawPoints = raw["points"] as? [[NSNumber]], rawPoints.count >= 2
                else { continue }
                let color = UIColor(hexString: hex) ?? .label
                let points = rawPoints.compactMap { p -> CGPoint? in
                    p.count == 2 ? CGPoint(x: p[0].doubleValue, y: p[1].doubleValue) : nil
                }
                strokes.append(manualStroke(points, color: color, width: width))
            }
            return PKDrawing(strokes: strokes)
        }
    }

    /// 手冊每一頁的筆畫（繁體中文版：標題與內文都是手寫）。讀不到資源就回空陣列
    /// （筆記本仍然建立，只是空白）。
    static func kairumoManualDrawings(language: AppLanguage = .zhHant) -> [PKDrawing] {
        manualDrawings(from: manualJSON(language == .zhHans ? "kairumo-manual-ink-zhHans" : "kairumo-manual-ink") ?? [:])
    }

    /// 英／日／韓／泰的手冊：同一套手繪插圖＋該語言排版的文字方塊（`kairumo-manual-typed.json`）。
    ///
    /// 手寫只有繁體與簡體中文：筆順資料只有漢字，沒有假名、諺文、泰文。位置與繁中版的手寫字一一對應。
    static func kairumoManualTyped(language: AppLanguage) -> (drawings: [PKDrawing], texts: [NoteTextAttachment])? {
        guard let root = manualJSON("kairumo-manual-typed"),
              let all = root["texts"] as? [String: Any],
              let perPage = all[language.rawValue] as? [[[String: Any]]]
        else { return nil }
        var texts: [NoteTextAttachment] = []
        for (pageIndex, boxes) in perPage.enumerated() {
            for b in boxes {
                guard let text = b["text"] as? String,
                      let x = (b["x"] as? NSNumber)?.doubleValue, let y = (b["y"] as? NSNumber)?.doubleValue,
                      let w = (b["w"] as? NSNumber)?.doubleValue, let h = (b["h"] as? NSNumber)?.doubleValue,
                      let size = (b["size"] as? NSNumber)?.doubleValue
                else { continue }
                texts.append(NoteTextAttachment(
                    pageIndex: pageIndex,
                    text: text,
                    fontSize: CGFloat(size),
                    isBold: (b["bold"] as? Bool) ?? false,
                    alignmentRaw: (b["align"] as? String) ?? "left",
                    textColorHex: (b["color"] as? String) ?? "#2D3748",
                    backgroundColorHex: "clear",
                    hasBorder: false,
                    x: CGFloat(x), y: CGFloat(y), width: CGFloat(w), height: CGFloat(h)
                ))
            }
        }
        return (manualDrawings(from: root), texts)
    }

    /// 起筆與收筆輕、中段重 —— 手寫的筆壓，不是等粗的線。
    private static func manualStroke(_ points: [CGPoint], color: UIColor, width: CGFloat) -> PKStroke {
        let count = points.count
        let controls = points.enumerated().map { index, point -> PKStrokePoint in
            let t = CGFloat(index) / CGFloat(max(1, count - 1))
            let edge = min(t, 1 - t) * min(CGFloat(count), 14)   // 前後各約 7 個點漸變
            let scale = 0.62 + 0.38 * min(1, edge / 4)
            let size = max(0.9, width * 1.2 * scale)
            return PKStrokePoint(
                location: point, timeOffset: TimeInterval(index) * 0.012,
                size: CGSize(width: size, height: size), opacity: 1,
                force: 0.6 + 0.3 * min(1, edge / 4), azimuth: 0, altitude: .pi / 2)
        }
        let path = PKStrokePath(controlPoints: controls, creationDate: Date())
        return PKStroke(ink: PKInk(.pen, color: color), path: path)
    }

    /// 填進《Kairumo手冊》。
    ///
    /// 繁體與簡體中文是手寫版；其他語言是同一套插圖＋排版文字（見 `kairumoManualTyped`）。
    static func fillKairumoManual(_ doc: inout NotebookDocument, store: NotebookStore? = nil) {
        let language = LocalizationManager.snapshotLanguage
        var drawings = kairumoManualDrawings(language: language)
        if language != .zhHant, language != .zhHans, let typed = kairumoManualTyped(language: language) {
            drawings = typed.drawings
            doc.textAttachments = typed.texts
        }
        ensurePages(&doc, count: max(2, drawings.count))
        for (index, drawing) in drawings.enumerated() where index < doc.pagesData.count {
            doc.pagesData[index] = drawing.dataRepresentation()
            store?.saveDrawing(notebookId: doc.id, pageIndex: index, drawing: drawing)
        }
    }

    // MARK: - 功能實戰範例筆記：《Kairumo(功能範例)》
    //
    // 全書共四頁頂級巨作：
    // 第 1 頁：應用程式用途說明、四大核心支柱、與市面上前 3 大主流軟體深度評測表
    // 第 2 頁：手繪模式下所有工具用法與實作筆跡範例（書寫／繪畫／標記三族 16 種筆刷實測與互動遮蔽膠帶）
    // 第 3 頁：文字模式下所有工具用法與實作範例（富文本、高階樣式表、流程圖、3D模型、網頁卡片、錄音卡片）
    // 第 4 頁：手繪＋文字終極融合示範（微積分方程推導、動態可編修圖表工坊、上下文空間討論圖釘）
    public static func fillFeatureShowcase(_ doc: inout NotebookDocument, store: NotebookStore? = nil) {
        ensurePages(&doc, count: 4)

        var texts: [NoteTextAttachment] = []
        var tables: [NoteTableAttachment] = []
        var shapes: [NoteShapeAttachment] = []
        var connections: [NoteConnectionAttachment] = []
        var images: [NoteImageAttachment] = []
        var tapes: [NoteTapeAttachment] = []
        var links: [NoteLinkAttachment] = []
        var audios: [NoteAudioAttachment] = []
        var models3D: [Note3DAttachment] = []
        var pins: [NoteCommentPin] = []

        // =========================================================================
        // 【第 1 頁：應用程式用途說明 ＆ 市面主流軟體深度全景評測】
        // =========================================================================

        // 1. 頁面標題與章節副標
        texts.append(titleBox("sample_showcase_p1_title", page: 0, y: 32))
        texts.append(subtitleBox("sample_showcase_p1_subtitle", page: 0, y: 76))

        // 2. 應用程式定位與核心使命卡片
        let p1MissionCard = cardShape(page: 0, x: margin, y: 114, width: contentWidth, height: 118,
                                      stroke: "#3182CE", fill: "#EBF8FF")
        shapes.append(p1MissionCard)

        texts.append(NoteTextAttachment(
            pageIndex: 0,
            text: l("sample_showcase_p1_mission_title"),
            fontSize: 14,
            isBold: true,
            alignmentRaw: "left",
            textColorHex: "#2B6CB0",
            backgroundColorHex: "clear",
            hasBorder: false,
            x: margin + 14,
            y: 122,
            width: contentWidth - 28,
            height: 22
        ))

        texts.append(NoteTextAttachment(
            pageIndex: 0,
            text: l("sample_showcase_p1_mission_body"),
            fontSize: 11.5,
            isBold: false,
            alignmentRaw: "left",
            textColorHex: "#2D3748",
            backgroundColorHex: "clear",
            hasBorder: false,
            x: margin + 14,
            y: 146,
            width: contentWidth - 28,
            height: 80,
            lineSpacing: 3
        ))

        // 3. 四大核心支柱卡片（2x2 矩陣佈局）
        let p1PillarsY: CGFloat = 242
        let colW: CGFloat = (contentWidth - 14) / 2
        let rowH: CGFloat = 92

        // Pillar 1: 100% 開源無廣告
        shapes.append(cardShape(page: 0, x: margin, y: p1PillarsY, width: colW, height: rowH,
                                stroke: "#38A169", fill: "#F0FFF4"))
        texts.append(pillarTitle(l("sample_showcase_p1_pillar1_title"), page: 0, x: margin + 10, y: p1PillarsY + 8, width: colW - 20, color: "#22543D"))
        texts.append(pillarBody(l("sample_showcase_p1_pillar1_body"), page: 0, x: margin + 10, y: p1PillarsY + 30, width: colW - 20, height: 56))

        // Pillar 2: 手繪與排版無縫融合
        shapes.append(cardShape(page: 0, x: margin + colW + 14, y: p1PillarsY, width: colW, height: rowH,
                                stroke: "#805AD5", fill: "#FAF5FF"))
        texts.append(pillarTitle(l("sample_showcase_p1_pillar2_title"), page: 0, x: margin + colW + 24, y: p1PillarsY + 8, width: colW - 20, color: "#44337A"))
        texts.append(pillarBody(l("sample_showcase_p1_pillar2_body"), page: 0, x: margin + colW + 24, y: p1PillarsY + 30, width: colW - 20, height: 56))

        // Pillar 3: 可隨時重新編輯的圖表
        shapes.append(cardShape(page: 0, x: margin, y: p1PillarsY + rowH + 10, width: colW, height: rowH,
                                stroke: "#DD6B20", fill: "#FFFAF0"))
        texts.append(pillarTitle(l("sample_showcase_p1_pillar3_title"), page: 0, x: margin + 10, y: p1PillarsY + rowH + 18, width: colW - 20, color: "#7B341E"))
        texts.append(pillarBody(l("sample_showcase_p1_pillar3_body"), page: 0, x: margin + 10, y: p1PillarsY + rowH + 40, width: colW - 20, height: 56))

        // Pillar 4: 空間圖釘與時間軸協同
        shapes.append(cardShape(page: 0, x: margin + colW + 14, y: p1PillarsY + rowH + 10, width: colW, height: rowH,
                                stroke: "#D69E2E", fill: "#FFFFF0"))
        texts.append(pillarTitle(l("sample_showcase_p1_pillar4_title"), page: 0, x: margin + colW + 24, y: p1PillarsY + rowH + 18, width: colW - 20, color: "#744210"))
        texts.append(pillarBody(l("sample_showcase_p1_pillar4_body"), page: 0, x: margin + colW + 24, y: p1PillarsY + rowH + 40, width: colW - 20, height: 56))

        // 4. 與市面主流前三大筆記軟體全景深度評測表
        let p1TableY: CGFloat = 450
        texts.append(NoteTextAttachment(
            pageIndex: 0,
            text: l("sample_showcase_p1_table_title"),
            fontSize: 14,
            isBold: true,
            alignmentRaw: "left",
            textColorHex: "#1A365D",
            backgroundColorHex: "clear",
            hasBorder: false,
            x: margin,
            y: p1TableY,
            width: contentWidth,
            height: 24
        ))

        let parsedMatrix = parseTable(l("sample_showcase_comparison_table"))
        tables.append(NoteTableAttachment(
            pageIndex: 0,
            x: margin,
            y: p1TableY + 28,
            width: contentWidth,
            rows: parsedMatrix.rows,
            cols: parsedMatrix.cols,
            cells: parsedMatrix.cells,
            headerRow: true,
            fontSize: 10,
            headerBackgroundHex: "#EBF8FF"
        ))

        // 底部品質徽章
        let pillY0: CGFloat = 825
        shapes.append(pillShape(L10n.t("seed_pill_01"), page: 0, x: margin, y: pillY0, fill: "#EBF8FF", stroke: "#3182CE"))
        shapes.append(pillShape(L10n.t("seed_pill_02"), page: 0, x: margin + 175, y: pillY0, fill: "#F0FFF4", stroke: "#38A169"))
        shapes.append(pillShape(L10n.t("seed_pill_03"), page: 0, x: margin + 350, y: pillY0, fill: "#FAF5FF", stroke: "#805AD5"))
        shapes.append(pillShape(L10n.t("seed_pill_04"), page: 0, x: margin + 525, y: pillY0, fill: "#FFFAF0", stroke: "#DD6B20"))


        // =========================================================================
        // 【第 2 頁：「手繪模式」下所有工具用法與實作範例】
        // =========================================================================

        texts.append(titleBox("sample_showcase_p2_title", page: 1, y: 32))
        texts.append(subtitleBox("sample_showcase_p2_subtitle", page: 1, y: 76))

        // 三大家族背景卡片
        // 家族 1：書寫家族（y=114 ~ 324）
        shapes.append(cardShape(page: 1, x: margin, y: 114, width: contentWidth, height: 216,
                                stroke: "#2B6CB0", fill: "#F7FAFC"))
        texts.append(NoteTextAttachment(
            pageIndex: 1,
            text: l("sample_showcase_p2_family_write"),
            fontSize: 13,
            isBold: true,
            alignmentRaw: "left",
            textColorHex: "#2B6CB0",
            backgroundColorHex: "clear",
            hasBorder: false,
            x: margin + 12,
            y: 122,
            width: contentWidth - 24,
            height: 22
        ))

        // 家族 2：彩繪家族（y=338 ~ 534）
        shapes.append(cardShape(page: 1, x: margin, y: 338, width: contentWidth, height: 196,
                                stroke: "#9F7AEA", fill: "#FAF5FF"))
        texts.append(NoteTextAttachment(
            pageIndex: 1,
            text: l("sample_showcase_p2_family_paint"),
            fontSize: 13,
            isBold: true,
            alignmentRaw: "left",
            textColorHex: "#6B46C1",
            backgroundColorHex: "clear",
            hasBorder: false,
            x: margin + 12,
            y: 346,
            width: contentWidth - 24,
            height: 22
        ))

        // 家族 3：標記與工具（y=542 ~ 780）
        shapes.append(cardShape(page: 1, x: margin, y: 542, width: contentWidth, height: 236,
                                stroke: "#DD6B20", fill: "#FFFAF0"))
        texts.append(NoteTextAttachment(
            pageIndex: 1,
            text: l("sample_showcase_p2_family_mark"),
            fontSize: 13,
            isBold: true,
            alignmentRaw: "left",
            textColorHex: "#C05621",
            backgroundColorHex: "clear",
            hasBorder: false,
            x: margin + 12,
            y: 550,
            width: contentWidth - 24,
            height: 22
        ))

        // 遮蔽膠帶說明與實體可互動膠帶
        texts.append(NoteTextAttachment(
            pageIndex: 1,
            text: l("sample_showcase_p2_tape_desc"),
            fontSize: 11,
            isBold: false,
            alignmentRaw: "left",
            textColorHex: "#744210",
            backgroundColorHex: "#FEFCBF",
            hasBorder: true,
            cornerRadius: 6,
            borderColorHex: "#ECC94B",
            borderWidth: 1.0,
            x: margin + 14,
            y: 692,
            width: contentWidth - 28,
            height: 40,
            lineSpacing: 2
        ))

        // 遮蔽膠帶背後要背誦的文字
        texts.append(NoteTextAttachment(
            pageIndex: 1,
            text: l("sample_showcase_tape_answer"),
            fontSize: 12,
            isBold: true,
            alignmentRaw: "left",
            textColorHex: "#2D3748",
            backgroundColorHex: "#FFFFFF",
            hasBorder: true,
            cornerRadius: 4,
            borderColorHex: "#E2E8F0",
            borderWidth: 1.0,
            x: margin + 20,
            y: 738,
            width: contentWidth - 40,
            height: 32
        ))

        // 覆蓋在文字上的 NoteTapeAttachment（預設遮蔽 isRevealed: false）
        tapes.append(NoteTapeAttachment(
            id: "seed-tape-showcase-p2",
            pageIndex: 1,
            rect: CGRect(x: margin + 18, y: 736, width: contentWidth - 36, height: 36),
            isRevealed: false,
            colorHex: "#ECC94B"
        ))

        // 底部手繪筆刷徽章
        let pillY1: CGFloat = 825
        shapes.append(pillShape(L10n.t("seed_pill_05"), page: 1, x: margin, y: pillY1, fill: "#EBF8FF", stroke: "#3182CE"))
        shapes.append(pillShape(L10n.t("seed_pill_06"), page: 1, x: margin + 175, y: pillY1, fill: "#F0FFF4", stroke: "#38A169"))
        shapes.append(pillShape(L10n.t("seed_pill_07"), page: 1, x: margin + 350, y: pillY1, fill: "#FFFFF0", stroke: "#D69E2E"))
        shapes.append(pillShape(L10n.t("seed_pill_08"), page: 1, x: margin + 525, y: pillY1, fill: "#FAF5FF", stroke: "#805AD5"))


        // =========================================================================
        // 【第 3 頁：「文字模式」下所有工具用法與實作範例】
        // =========================================================================

        texts.append(titleBox("sample_showcase_p3_title", page: 2, y: 32))
        texts.append(subtitleBox("sample_showcase_p3_subtitle", page: 2, y: 76))

        // 1. 富文本文字框展示（樣式、字型、圓角、自訂邊框）
        shapes.append(cardShape(page: 2, x: margin, y: 114, width: contentWidth, height: 116,
                                stroke: "#3182CE", fill: "#EBF8FF"))
        texts.append(NoteTextAttachment(
            pageIndex: 2,
            text: l("sample_showcase_p3_richtext_title"),
            fontSize: 14,
            isBold: true,
            alignmentRaw: "left",
            textColorHex: "#2B6CB0",
            backgroundColorHex: "clear",
            hasBorder: false,
            x: margin + 14,
            y: 122,
            width: contentWidth - 28,
            height: 22
        ))
        texts.append(NoteTextAttachment(
            pageIndex: 2,
            text: l("sample_showcase_p3_richtext_body"),
            fontSize: 11.5,
            isBold: false,
            alignmentRaw: "left",
            textColorHex: "#2D3748",
            backgroundColorHex: "#FFFFFF",
            hasBorder: true,
            cornerRadius: 6,
            borderColorHex: "#BEE3F8",
            borderWidth: 1.0,
            x: margin + 14,
            y: 146,
            width: contentWidth - 28,
            height: 76,
            lineSpacing: 3
        ))

        // 2. 原生高效數據表格（NoteTableAttachment）
        let p3TableY: CGFloat = 240
        texts.append(NoteTextAttachment(
            pageIndex: 2,
            text: l("sample_showcase_p3_table_title"),
            fontSize: 13,
            isBold: true,
            alignmentRaw: "left",
            textColorHex: "#1A365D",
            backgroundColorHex: "clear",
            hasBorder: false,
            x: margin,
            y: p3TableY,
            width: contentWidth,
            height: 22
        ))

        let parsedP3Table = parseTable(l("sample_showcase_p3_table_data"))
        tables.append(NoteTableAttachment(
            pageIndex: 2,
            x: margin,
            y: p3TableY + 26,
            width: contentWidth,
            rows: parsedP3Table.rows,
            cols: parsedP3Table.cols,
            cells: parsedP3Table.cells,
            headerRow: true,
            fontSize: 11,
            headerBackgroundHex: "#EDF2F7"
        ))

        // 3. 幾何圖形庫與智慧連接線（Flowchart: Start -> Engine -> Decision -> Done）
        let flowY: CGFloat = 430
        texts.append(NoteTextAttachment(
            pageIndex: 2,
            text: l("sample_showcase_p3_flow_title"),
            fontSize: 13,
            isBold: true,
            alignmentRaw: "left",
            textColorHex: "#2C5282",
            backgroundColorHex: "clear",
            hasBorder: false,
            x: margin,
            y: flowY,
            width: contentWidth,
            height: 22
        ))

        let flowBoxY = flowY + 30
        let sStart = NoteShapeAttachment(
            pageIndex: 2, kindName: "terminator",
            x: margin, y: flowBoxY, width: 140, height: 50, cornerRadius: 25,
            label: l("sample_showcase_p3_flow_start"),
            strokeColorHex: "#38A169", fillColorHex: "#F0FFF4", lineWidth: 1.5
        )
        let sEngine = NoteShapeAttachment(
            pageIndex: 2, kindName: "process",
            x: margin + 175, y: flowBoxY, width: 155, height: 50, cornerRadius: 8,
            label: l("sample_showcase_p3_flow_process"),
            strokeColorHex: "#3182CE", fillColorHex: "#EBF8FF", lineWidth: 1.5
        )
        let sDecide = NoteShapeAttachment(
            pageIndex: 2, kindName: "decision",
            x: margin + 365, y: flowBoxY - 8, width: 150, height: 66, cornerRadius: 0,
            label: l("sample_showcase_p3_flow_decision"),
            strokeColorHex: "#805AD5", fillColorHex: "#FAF5FF", lineWidth: 1.5
        )
        let sEnd = NoteShapeAttachment(
            pageIndex: 2, kindName: "terminator",
            x: margin + 550, y: flowBoxY, width: 138, height: 50, cornerRadius: 25,
            label: l("sample_showcase_p3_flow_end"),
            strokeColorHex: "#DD6B20", fillColorHex: "#FFFAF0", lineWidth: 1.5
        )
        shapes.append(contentsOf: [sStart, sEngine, sDecide, sEnd])

        connections.append(NoteConnectionAttachment(
            pageIndex: 2, fromShapeId: sStart.id, toShapeId: sEngine.id, colorHex: "#3182CE"))
        connections.append(NoteConnectionAttachment(
            pageIndex: 2, fromShapeId: sEngine.id, toShapeId: sDecide.id, colorHex: "#805AD5"))
        connections.append(NoteConnectionAttachment(
            pageIndex: 2, fromShapeId: sDecide.id, toShapeId: sEnd.id, colorHex: "#DD6B20"))

        // 4. 多媒體擴充：網頁預覽卡片、音訊錄音卡片、3D 空間立體模型
        let mediaY: CGFloat = 540
        texts.append(NoteTextAttachment(
            pageIndex: 2,
            text: l("sample_showcase_p3_media_title"),
            fontSize: 13,
            isBold: true,
            alignmentRaw: "left",
            textColorHex: "#1A365D",
            backgroundColorHex: "clear",
            hasBorder: false,
            x: margin,
            y: mediaY,
            width: contentWidth,
            height: 22
        ))

        let cardW: CGFloat = (contentWidth - 24) / 3
        let cardH: CGFloat = 190
        let cardRowY: CGFloat = mediaY + 30

        // 4a. 網頁連結卡片 (NoteLinkAttachment)
        links.append(NoteLinkAttachment(
            id: "seed-link-showcase",
            pageIndex: 2,
            urlString: "https://github.com/hauchiehlin-ops/Kairumo",
            title: "Kairumo GitHub Repository",
            descriptionText: "Next-gen vector note studio with 100% open source freedom, zero cloud lock-in & Rust core.",
            siteName: "GitHub",
            x: margin,
            y: cardRowY,
            width: cardW,
            height: cardH
        ))

        // 4b. 錄音時間軸卡片 (NoteAudioAttachment)
        audios.append(NoteAudioAttachment(
            id: "seed-audio-showcase",
            pageIndex: 2,
            recordingId: "rec-seed-showcase-01",
            fileName: "showcase-audio-intro.m4a",
            title: l("sample_showcase_audio_title"),
            durationSeconds: 184,
            x: margin + cardW + 12,
            y: cardRowY,
            width: cardW,
            height: cardH
        ))

        // 4c. 3D 空間幾何模型卡片 (Note3DAttachment)
        models3D.append(Note3DAttachment(
            id: "seed-3d-showcase",
            pageIndex: 2,
            title: l("sample_showcase_model3d_title"),
            modelTypeRaw: "sphere",
            x: margin + (cardW + 12) * 2,
            y: cardRowY,
            width: cardW,
            height: cardH,
            hasBorder: true,
            borderColorHex: "#CBD5E0",
            backgroundColorHex: "#F7FAFC"
        ))

        // 底部排版模式徽章
        let pillY2: CGFloat = 825
        shapes.append(pillShape(L10n.t("seed_pill_09"), page: 2, x: margin, y: pillY2, fill: "#EBF8FF", stroke: "#3182CE"))
        shapes.append(pillShape(L10n.t("seed_pill_10"), page: 2, x: margin + 175, y: pillY2, fill: "#F0FFF4", stroke: "#38A169"))
        shapes.append(pillShape(L10n.t("seed_pill_11"), page: 2, x: margin + 350, y: pillY2, fill: "#FAF5FF", stroke: "#805AD5"))
        shapes.append(pillShape(L10n.t("seed_pill_12"), page: 2, x: margin + 525, y: pillY2, fill: "#FFFAF0", stroke: "#DD6B20"))


        // =========================================================================
        // 【第 4 頁：「手繪＋文字」終極交響樂：說明 Kairumo 最大優勢】
        // =========================================================================

        texts.append(titleBox("sample_showcase_p4_title", page: 3, y: 32))
        texts.append(subtitleBox("sample_showcase_p4_subtitle", page: 3, y: 76))

        // 旗艦金色橫幅標章
        shapes.append(NoteShapeAttachment(
            pageIndex: 3,
            kindName: "roundedrectangle",
            x: margin,
            y: 114,
            width: contentWidth,
            height: 38,
            cornerRadius: 8,
            label: l("sample_showcase_p4_hero_badge"),
            strokeColorHex: "#D69E2E",
            fillColorHex: "#FEFCBF",
            lineWidth: 1.5
        ))

        // 1. 微積分方程融合：左側手寫真跡，右側打字解析卡片（y=160 ~ 380）
        shapes.append(cardShape(page: 3, x: margin, y: 160, width: contentWidth, height: 215,
                                stroke: "#805AD5", fill: "#FAF5FF"))

        texts.append(NoteTextAttachment(
            pageIndex: 3,
            text: l("sample_showcase_p4_math_card_title"),
            fontSize: 13,
            isBold: true,
            alignmentRaw: "left",
            textColorHex: "#553C9A",
            backgroundColorHex: "clear",
            hasBorder: false,
            x: margin + 14,
            y: 168,
            width: contentWidth - 28,
            height: 22
        ))

        // 右側打字說明與 LaTeX 步驟卡
        texts.append(NoteTextAttachment(
            pageIndex: 3,
            text: l("sample_showcase_p4_math_card_desc"),
            fontSize: 11,
            isBold: false,
            alignmentRaw: "left",
            textColorHex: "#4A5568",
            backgroundColorHex: "#FFFFFF",
            hasBorder: true,
            cornerRadius: 6,
            borderColorHex: "#E9D8FD",
            borderWidth: 1.0,
            x: margin + 340,
            y: 196,
            width: contentWidth - 354,
            height: 168,
            lineSpacing: 3
        ))

        // (x=margin+14 ~ margin+330, y=196 ~ 360 留給純手繪的真實微積分積分題：
        // ∫_0^π x sin(x) dx, 分部積分 u=x, v=-cos(x), 代入計算與紅色圈選 Ans=π)

        // 2. 數字製圖（Chart Studio）與空間討論圖釘（y=386 ~ 700）
        shapes.append(cardShape(page: 3, x: margin, y: 386, width: contentWidth, height: 300,
                                stroke: "#3182CE", fill: "#F7FAFC"))

        texts.append(NoteTextAttachment(
            pageIndex: 3,
            text: l("sample_showcase_p4_chart_card_title"),
            fontSize: 13,
            isBold: true,
            alignmentRaw: "left",
            textColorHex: "#2B6CB0",
            backgroundColorHex: "clear",
            hasBorder: false,
            x: margin + 14,
            y: 394,
            width: contentWidth - 28,
            height: 22
        ))

        texts.append(NoteTextAttachment(
            pageIndex: 3,
            text: l("sample_showcase_p4_chart_card_desc"),
            fontSize: 11,
            isBold: false,
            alignmentRaw: "left",
            textColorHex: "#2D3748",
            backgroundColorHex: "#EDF2F7",
            hasBorder: true,
            cornerRadius: 6,
            borderColorHex: "#CBD5E0",
            borderWidth: 1.0,
            x: margin + 14,
            y: 418,
            width: contentWidth - 28,
            height: 48,
            lineSpacing: 2
        ))

        // 插入動態向量長條圖
        if let store, let chartAttachment = makeShowcaseChart(page: 3, store: store) {
            images.append(chartAttachment)
        }

        // 插入空間討論圖釘（NoteCommentPin）
        let pinChart = NoteCommentPin(
            id: "seed-pin-showcase-chart-p4",
            pageIndex: 3,
            x: margin + 415,
            y: 535,
            authorId: "kairumo-reviewer",
            authorName: "Kairumo Architect",
            authorColor: "#3182CE",
            createdAt: Date().addingTimeInterval(-7200),
            isResolved: false,
            messages: [
                NoteCommentMessage(
                    id: "msg-p4-q3",
                    authorId: "kairumo-reviewer",
                    authorName: "Kairumo Architect",
                    authorColor: "#3182CE",
                    text: l("sample_showcase_pin1_msg"),
                    createdAt: Date().addingTimeInterval(-7200)
                )
            ]
        )

        let pinMath = NoteCommentPin(
            id: "seed-pin-showcase-math-p4",
            pageIndex: 3,
            x: margin + 280,
            y: 250,
            authorId: "math-evaluator",
            authorName: "Prof. Euler",
            authorColor: "#805AD5",
            createdAt: Date().addingTimeInterval(-3600),
            isResolved: false,
            messages: [
                NoteCommentMessage(
                    id: "msg-p4-euler",
                    authorId: "math-evaluator",
                    authorName: "Prof. Euler",
                    authorColor: "#805AD5",
                    text: l("sample_showcase_pin2_msg"),
                    createdAt: Date().addingTimeInterval(-3600)
                )
            ]
        )
        pins.append(contentsOf: [pinChart, pinMath])

        // 3. 底部總結：為什麼全球創作者與工程師讚嘆 Kairumo（y=694 ~ 815）
        shapes.append(cardShape(page: 3, x: margin, y: 694, width: contentWidth, height: 118,
                                stroke: "#38A169", fill: "#F0FFF4"))
        texts.append(NoteTextAttachment(
            pageIndex: 3,
            text: l("sample_showcase_p4_conclusion_title"),
            fontSize: 13,
            isBold: true,
            alignmentRaw: "left",
            textColorHex: "#22543D",
            backgroundColorHex: "clear",
            hasBorder: false,
            x: margin + 14,
            y: 702,
            width: contentWidth - 28,
            height: 22
        ))
        texts.append(NoteTextAttachment(
            pageIndex: 3,
            text: l("sample_showcase_p4_conclusion_body"),
            fontSize: 11,
            isBold: false,
            alignmentRaw: "left",
            textColorHex: "#276749",
            backgroundColorHex: "clear",
            hasBorder: false,
            x: margin + 14,
            y: 726,
            width: contentWidth - 28,
            height: 78,
            lineSpacing: 3
        ))

        // 底部亮點膠囊
        let pillY3: CGFloat = 825
        shapes.append(pillShape(L10n.t("seed_pill_13"), page: 3, x: margin, y: pillY3, fill: "#FAF5FF", stroke: "#805AD5"))
        shapes.append(pillShape(L10n.t("seed_pill_14"), page: 3, x: margin + 175, y: pillY3, fill: "#EBF8FF", stroke: "#3182CE"))
        shapes.append(pillShape(L10n.t("seed_pill_15"), page: 3, x: margin + 350, y: pillY3, fill: "#F0FFF4", stroke: "#38A169"))
        shapes.append(pillShape(L10n.t("seed_pill_16"), page: 3, x: margin + 525, y: pillY3, fill: "#FFFAF0", stroke: "#DD6B20"))

        // 組裝進 document
        doc.textAttachments = texts
        doc.tableAttachments = tables
        doc.shapeAttachments = shapes
        doc.connectionAttachments = connections
        doc.attachments = images
        doc.tapeAttachments = tapes
        doc.linkAttachments = links
        doc.audioAttachments = audios
        doc.model3DAttachments = models3D
        doc.commentPins = pins

        // =========================================================================
        // 【生成四頁真實向量手繪筆畫 (PKDrawing)】
        // =========================================================================
        let p0Drawing = buildShowcasePage0Drawing()
        let p1Drawing = buildShowcasePage1Drawing()
        let p2Drawing = buildShowcasePage2Drawing()
        let p3Drawing = buildShowcasePage3Drawing()

        if doc.pagesData.count >= 4 {
            doc.pagesData[0] = p0Drawing.dataRepresentation()
            doc.pagesData[1] = p1Drawing.dataRepresentation()
            doc.pagesData[2] = p2Drawing.dataRepresentation()
            doc.pagesData[3] = p3Drawing.dataRepresentation()
        }

        if let store {
            store.saveDrawing(notebookId: doc.id, pageIndex: 0, drawing: p0Drawing)
            store.saveDrawing(notebookId: doc.id, pageIndex: 1, drawing: p1Drawing)
            store.saveDrawing(notebookId: doc.id, pageIndex: 2, drawing: p2Drawing)
            store.saveDrawing(notebookId: doc.id, pageIndex: 3, drawing: p3Drawing)
        }
    }

    private static func cardShape(
        page: Int, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat,
        stroke: String, fill: String
    ) -> NoteShapeAttachment {
        NoteShapeAttachment(
            pageIndex: page,
            kindName: "rectangle",
            x: x,
            y: y,
            width: width,
            height: height,
            cornerRadius: 10,
            label: "",
            strokeColorHex: stroke,
            fillColorHex: fill,
            lineWidth: 1.5
        )
    }

    private static func subtitleBox(_ key: String, page: Int, y: CGFloat) -> NoteTextAttachment {
        NoteTextAttachment(
            pageIndex: page,
            text: l(key),
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
            y: y,
            width: contentWidth,
            height: 30
        )
    }

    private static func pillarTitle(_ text: String, page: Int, x: CGFloat, y: CGFloat, width: CGFloat, color: String) -> NoteTextAttachment {
        NoteTextAttachment(
            pageIndex: page,
            text: text,
            fontSize: 12.5,
            isBold: true,
            alignmentRaw: "left",
            textColorHex: color,
            backgroundColorHex: "clear",
            hasBorder: false,
            x: x,
            y: y,
            width: width,
            height: 20
        )
    }

    private static func pillarBody(_ text: String, page: Int, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> NoteTextAttachment {
        NoteTextAttachment(
            pageIndex: page,
            text: text,
            fontSize: 11,
            isBold: false,
            alignmentRaw: "left",
            textColorHex: "#4A5568",
            backgroundColorHex: "clear",
            hasBorder: false,
            x: x,
            y: y,
            width: width,
            height: height,
            lineSpacing: 2
        )
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
        spec.title = l("sample_showcase_chart_spec_title")
        spec.categories = (1...4).map { L10n.t("seed_chart_cat_\($0)") }
        var seriesKairumo = ChartSeries(
            name: "Kairumo (Padnote)",
            values: [98, 95, 96, 100],
            colorHex: "#3182CE"
        )
        var seriesTop3Avg = ChartSeries(
            name: l("sample_showcase_chart_series_top3"),
            values: [74, 52, 45, 38],
            colorHex: "#CBD5E0"
        )
        spec.series = [seriesKairumo, seriesTop3Avg]
        spec.legend = .bottom
        spec.yAxis.showGrid = true

        let size = CGSize(width: 650, height: 260)
        guard let image = ChartRenderer.image(spec: spec, size: size),
              let fileName = store.saveAttachmentImage(image) else {
            return nil
        }
        let renderWidth = contentWidth - 40
        return NoteImageAttachment(
            fileName: fileName,
            pageIndex: page,
            x: margin + 20,
            y: 476,
            width: renderWidth,
            height: renderWidth * (size.height / size.width),
            hasShadow: false,
            hasBorder: true,
            chartSpecJSON: spec.encodedJSON()
        )
    }

    // MARK: - 向量手繪產生器 (PKDrawing Builder)

    /// 第 1 頁手繪筆劃
    private static func buildShowcasePage0Drawing() -> PKDrawing {
        var strokes: [PKStroke] = []
        let decorInk = PKInk(.pen, color: UIColor(red: 0.19, green: 0.51, blue: 0.81, alpha: 0.8))
        let checkInk = PKInk(.pen, color: UIColor(red: 0.22, green: 0.63, blue: 0.41, alpha: 0.9))

        // 裝飾底線與側邊手繪幾何標章
        strokes.append(contentsOf: drawWavyUnderline(from: CGPoint(x: margin + 14, y: 140), to: CGPoint(x: margin + 260, y: 140), ink: decorInk, width: 1.8))
        strokes.append(contentsOf: drawHandCheckmark(origin: CGPoint(x: margin + contentWidth - 40, y: 122), size: 18, ink: checkInk, width: 2.5))

        // 鋼筆手繪插圖：放在評測表標題旁
        strokes.append(contentsOf: drawPenNibIllustration(origin: CGPoint(x: margin + contentWidth - 80, y: 440), ink: decorInk))

        var drawing = PKDrawing(strokes: strokes)
        // 豐富表格與頁面貼紙庫貼紙
        drawing = drawing.appending(StickerCatalogue.drawing(code: "badge", size: 30, origin: CGPoint(x: margin + contentWidth - 36, y: 32), color: .systemBlue))
        drawing = drawing.appending(StickerCatalogue.drawing(code: "star", size: 28, origin: CGPoint(x: margin + contentWidth - 45, y: 446), color: .systemOrange))
        drawing = drawing.appending(StickerCatalogue.drawing(code: "idea", size: 28, origin: CGPoint(x: margin + 140, y: 820), color: .systemPurple))
        return drawing
    }

    /// 第 2 頁手繪筆劃：16 種筆刷實作範例
    private static func buildShowcasePage1Drawing() -> PKDrawing {
        var strokes: [PKStroke] = []

        // 書寫家族 6 種筆刷實作
        let penInk = PKInk(.pen, color: UIColor(red: 0.12, green: 0.31, blue: 0.85, alpha: 1.0))
        let finelinerInk = PKInk(.pen, color: UIColor(red: 0.15, green: 0.20, blue: 0.30, alpha: 1.0))
        let ballpointInk = PKInk(.pen, color: UIColor(red: 0.10, green: 0.40, blue: 0.70, alpha: 0.9))
        let brushInk = PKInk(.pen, color: UIColor(red: 0.55, green: 0.12, blue: 0.12, alpha: 1.0))
        let calliInk = PKInk(.pen, color: UIColor(red: 0.40, green: 0.15, blue: 0.50, alpha: 1.0))
        let pencilInk = PKInk(.pencil, color: UIColor(red: 0.28, green: 0.32, blue: 0.38, alpha: 0.95))

        strokes.append(contentsOf: drawBrushSwatch(name: l("sample_showcase_tool_1_pen"), y: 148, ink: penInk, width: 3.2, isBrush: false, style: "wavy"))
        strokes.append(contentsOf: drawBrushSwatch(name: l("sample_showcase_tool_2_fineliner"), y: 176, ink: finelinerInk, width: 1.4, isBrush: false, style: "straight"))
        strokes.append(contentsOf: drawBrushSwatch(name: l("sample_showcase_tool_3_ballpoint"), y: 204, ink: ballpointInk, width: 2.0, isBrush: false, style: "wavy"))
        strokes.append(contentsOf: drawBrushSwatch(name: l("sample_showcase_tool_4_brush"), y: 232, ink: brushInk, width: 5.5, isBrush: true, style: "calli"))
        strokes.append(contentsOf: drawBrushSwatch(name: l("sample_showcase_tool_5_calligraphy"), y: 264, ink: calliInk, width: 5.0, isBrush: true, style: "calli"))
        strokes.append(contentsOf: drawBrushSwatch(name: l("sample_showcase_tool_6_pencil"), y: 296, ink: pencilInk, width: 2.2, isBrush: false, style: "wavy"))

        // 繪畫家族 5 種筆刷實作
        let charcoalInk = PKInk(.pencil, color: UIColor(red: 0.18, green: 0.18, blue: 0.22, alpha: 0.95))
        let crayonInk = PKInk(.pencil, color: UIColor(red: 0.85, green: 0.35, blue: 0.15, alpha: 0.95))
        let airbrushInk = PKInk(.marker, color: UIColor(red: 0.20, green: 0.65, blue: 0.85, alpha: 0.6))
        let oilpaintInk = PKInk(.pen, color: UIColor(red: 0.75, green: 0.20, blue: 0.20, alpha: 1.0))
        let watercolorInk = PKInk(.marker, color: UIColor(red: 0.15, green: 0.55, blue: 0.75, alpha: 0.55))

        strokes.append(contentsOf: drawBrushSwatch(name: l("sample_showcase_tool_7_charcoal"), y: 372, ink: charcoalInk, width: 3.8, isBrush: false, style: "wavy"))
        strokes.append(contentsOf: drawBrushSwatch(name: l("sample_showcase_tool_8_crayon"), y: 402, ink: crayonInk, width: 4.2, isBrush: false, style: "wavy"))
        strokes.append(contentsOf: drawBrushSwatch(name: l("sample_showcase_tool_9_airbrush"), y: 432, ink: airbrushInk, width: 7.0, isBrush: false, style: "wavy"))
        strokes.append(contentsOf: drawBrushSwatch(name: l("sample_showcase_tool_10_oilpaint"), y: 464, ink: oilpaintInk, width: 5.2, isBrush: true, style: "calli"))
        strokes.append(contentsOf: drawBrushSwatch(name: l("sample_showcase_tool_11_watercolor"), y: 496, ink: watercolorInk, width: 6.5, isBrush: false, style: "wavy"))

        // 標記與輔助家族 4 種工具實作
        let markerInk = PKInk(.marker, color: UIColor(red: 0.15, green: 0.45, blue: 0.85, alpha: 0.85))
        let highlightInk = PKInk(.marker, color: UIColor(red: 0.95, green: 0.85, blue: 0.15, alpha: 0.45))
        let rulerInk = PKInk(.pen, color: UIColor(red: 0.30, green: 0.50, blue: 0.75, alpha: 1.0))
        let lassoInk = PKInk(.pen, color: UIColor(red: 0.60, green: 0.30, blue: 0.85, alpha: 1.0))

        strokes.append(contentsOf: drawBrushSwatch(name: l("sample_showcase_tool_12_marker"), y: 576, ink: markerInk, width: 5.5, isBrush: false, style: "straight"))
        strokes.append(contentsOf: drawBrushSwatch(name: l("sample_showcase_tool_13_highlighter"), y: 604, ink: highlightInk, width: 12.0, isBrush: false, style: "straight"))
        strokes.append(contentsOf: drawBrushSwatch(name: l("sample_showcase_tool_14_ruler"), y: 634, ink: rulerInk, width: 2.0, isBrush: false, style: "straight"))
        strokes.append(contentsOf: drawBrushSwatch(name: l("sample_showcase_tool_15_lasso"), y: 662, ink: lassoInk, width: 1.8, isBrush: false, style: "dots"))

        var drawing = PKDrawing(strokes: strokes)
        drawing = drawing.appending(StickerCatalogue.drawing(code: "star", size: 28, origin: CGPoint(x: margin + contentWidth - 40, y: 120), color: .systemBlue))
        drawing = drawing.appending(StickerCatalogue.drawing(code: "idea", size: 28, origin: CGPoint(x: margin + contentWidth - 40, y: 344), color: .systemPurple))
        drawing = drawing.appending(StickerCatalogue.drawing(code: "check", size: 26, origin: CGPoint(x: margin + contentWidth - 40, y: 548), color: .systemOrange))
        return drawing
    }

    /// 第 3 頁手繪筆劃：流程圖與版面批註
    private static func buildShowcasePage2Drawing() -> PKDrawing {
        var strokes: [PKStroke] = []
        let penInk = PKInk(.pen, color: UIColor(red: 0.19, green: 0.51, blue: 0.81, alpha: 0.9))
        let accentInk = PKInk(.pen, color: UIColor(red: 0.85, green: 0.35, blue: 0.15, alpha: 0.9))

        // 在流程圖旁繪製手繪批註箭頭與確認徽章
        strokes.append(contentsOf: drawHandwrittenText(l("sample_showcase_flow_aligned"), origin: CGPoint(x: margin + 375, y: 495), ink: penInk, baseWidth: 2.0, spacing: 9))
        strokes.append(contentsOf: drawHandCheckmark(origin: CGPoint(x: margin + contentWidth - 30, y: 490), size: 16, ink: accentInk, width: 2.2))

        var drawing = PKDrawing(strokes: strokes)
        drawing = drawing.appending(StickerCatalogue.drawing(code: "check", size: 26, origin: CGPoint(x: margin + contentWidth - 45, y: 242), color: .systemGreen))
        drawing = drawing.appending(StickerCatalogue.drawing(code: "star", size: 26, origin: CGPoint(x: margin + contentWidth - 45, y: 540), color: .systemBlue))
        return drawing
    }

    /// 第 4 頁手繪筆劃：微積分算式真跡與圖釘導引批註
    private static func buildShowcasePage3Drawing() -> PKDrawing {
        var strokes: [PKStroke] = []
        let mathInk = PKInk(.pen, color: UIColor(red: 0.15, green: 0.20, blue: 0.35, alpha: 1.0))
        let stepInk = PKInk(.pen, color: UIColor(red: 0.35, green: 0.15, blue: 0.65, alpha: 1.0))
        let highlightInk = PKInk(.pen, color: UIColor(red: 0.85, green: 0.18, blue: 0.18, alpha: 1.0))
        let pinArrowInk = PKInk(.pen, color: UIColor(red: 0.12, green: 0.50, blue: 0.85, alpha: 1.0))

        // (A) 微積分方程真實手繪書寫（左側 x=margin+14 ~ margin+330, y=196 ~ 360）
        let mathX: CGFloat = margin + 14
        let mathY: CGFloat = 196

        strokes.append(contentsOf: drawHandwrittenText(l("sample_showcase_math_ink_title"), origin: CGPoint(x: mathX, y: mathY), ink: stepInk, baseWidth: 2.8, spacing: 13))
        strokes.append(contentsOf: drawIntegralSign(at: CGPoint(x: mathX + 8, y: mathY + 24), height: 38, ink: mathInk))
        strokes.append(contentsOf: drawHandwrittenText("0", origin: CGPoint(x: mathX + 6, y: mathY + 60), ink: mathInk, baseWidth: 1.8, spacing: 8))
        strokes.append(contentsOf: drawHandwrittenText("pi", origin: CGPoint(x: mathX + 14, y: mathY + 22), ink: mathInk, baseWidth: 1.8, spacing: 8))
        strokes.append(contentsOf: drawHandwrittenText("x sin(x) dx", origin: CGPoint(x: mathX + 28, y: mathY + 38), ink: mathInk, baseWidth: 2.4, spacing: 11))

        // Step 1: 分部積分公式
        strokes.append(contentsOf: drawHandwrittenText("Step 1:  u = x,  dv = sin(x)dx", origin: CGPoint(x: mathX + 6, y: mathY + 74), ink: stepInk, baseWidth: 2.2, spacing: 9.5))
        strokes.append(contentsOf: drawHandwrittenText("         du = dx, v = -cos(x)", origin: CGPoint(x: mathX + 6, y: mathY + 94), ink: stepInk, baseWidth: 2.2, spacing: 9.5))

        // Step 2: 代入展開
        strokes.append(contentsOf: drawHandwrittenText("Step 2:  = [ -x cos(x) ]_0^pi + int_0^pi cos(x)dx", origin: CGPoint(x: mathX + 6, y: mathY + 116), ink: mathInk, baseWidth: 2.1, spacing: 9.5))

        // Step 3: 邊界值代入
        strokes.append(contentsOf: drawHandwrittenText("Step 3:  = ( pi + 0 ) + ( 0 - 0 )", origin: CGPoint(x: mathX + 6, y: mathY + 136), ink: mathInk, baseWidth: 2.1, spacing: 9.5))

        // 結論：= pi （紅色雙圓圈手繪圈選 + 打勾）
        strokes.append(contentsOf: drawHandwrittenText("Ans =  pi", origin: CGPoint(x: mathX + 30, y: mathY + 158), ink: highlightInk, baseWidth: 3.2, spacing: 13))
        strokes.append(contentsOf: drawHandCircle(center: CGPoint(x: mathX + 90, y: mathY + 164), radius: 18, ink: highlightInk, width: 2.6))
        strokes.append(contentsOf: drawHandCheckmark(origin: CGPoint(x: mathX + 116, y: mathY + 154), size: 20, ink: highlightInk, width: 2.8))

        // 手繪引導箭頭：從微積分解答指向右側討論圖釘
        strokes.append(contentsOf: drawCurvedArrow(from: CGPoint(x: mathX + 150, y: mathY + 90), to: CGPoint(x: margin + 270, y: 245), ink: stepInk))

        // (B) 數字製圖與討論圖釘的手繪指引箭頭
        strokes.append(contentsOf: drawCurvedArrow(from: CGPoint(x: margin + 280, y: 460), to: CGPoint(x: margin + 405, y: 530), ink: pinArrowInk))
        strokes.append(contentsOf: drawHandwrittenText(l("sample_showcase_pin_hint"), origin: CGPoint(x: margin + 430, y: 530), ink: pinArrowInk, baseWidth: 2.0, spacing: 9))

        var drawing = PKDrawing(strokes: strokes)
        drawing = drawing.appending(StickerCatalogue.drawing(code: "star", size: 30, origin: CGPoint(x: margin + contentWidth - 45, y: 118), color: .systemOrange))
        drawing = drawing.appending(StickerCatalogue.drawing(code: "badge", size: 28, origin: CGPoint(x: margin + contentWidth - 45, y: 698), color: .systemGreen))
        return drawing
    }

    /// 繪製單個筆刷樣本：名稱標籤 + 手繪波浪筆跡
    private static func drawBrushSwatch(name: String, y: CGFloat, ink: PKInk, width: CGFloat, isBrush: Bool, style: String) -> [PKStroke] {
        var strokes: [PKStroke] = []
        strokes.append(contentsOf: drawHandwrittenText(name, origin: CGPoint(x: margin + 18, y: y), ink: ink, baseWidth: 2.2, isBrush: false, spacing: 10.5))

        let startX = margin + 180
        let endX = margin + contentWidth - 30
        var pts: [CGPoint] = []
        let steps = 28
        let dx = endX - startX
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let x = startX + dx * t
            let wave: CGFloat
            if style == "wavy" {
                wave = sin(t * .pi * 4) * 4.0
            } else if style == "calli" {
                wave = sin(t * .pi * 2) * 5.0 - (t * 2.0)
            } else if style == "dots" {
                wave = (i % 2 == 0) ? -2.5 : 2.5
            } else {
                wave = 0
            }
            pts.append(CGPoint(x: x, y: y + 8 + wave))
        }
        strokes.append(strokeFromPoints(pts, ink: ink, width: width, isBrush: isBrush))
        return strokes
    }


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

