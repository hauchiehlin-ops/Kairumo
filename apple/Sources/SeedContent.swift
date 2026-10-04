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

    // MARK: - 精選範例筆記：《Kairumo（精選實例）》
    public static func fillFeaturedBiologySample(_ doc: inout NotebookDocument) {
        ensurePages(&doc, count: 2)

        var texts: [NoteTextAttachment] = []
        var tables: [NoteTableAttachment] = []
        var shapes: [NoteShapeAttachment] = []
        var connections: [NoteConnectionAttachment] = []
        var tapes: [NoteTapeAttachment] = []

        // =========================================================================
        // 【第一頁：循環系統與氣體運輸】
        // =========================================================================

        // 1. 頁面大標題
        texts.append(NoteTextAttachment(
            pageIndex: 0,
            text: l("sample_bio_p1_title"),
            fontSize: 22,
            isBold: true,
            alignmentRaw: "left",
            textColorHex: "#C0392B",
            backgroundColorHex: "clear",
            hasBorder: false,
            cornerRadius: 0,
            x: margin,
            y: 40,
            width: contentWidth,
            height: 38
        ))

        // 2. 門脈循環區塊 (Portal Circulation)
        let portalBox = NoteShapeAttachment(
            pageIndex: 0,
            kindName: "rectangle",
            x: margin,
            y: 85,
            width: 250,
            height: 140,
            cornerRadius: 6,
            label: l("sample_bio_portal_shape"),
            strokeColorHex: "#D98880",
            fillColorHex: "#FDEDEC",
            lineWidth: 1.5
        )
        shapes.append(portalBox)

        texts.append(NoteTextAttachment(
            pageIndex: 0,
            text: l("sample_bio_portal_text"),
            fontSize: 13,
            isBold: false,
            alignmentRaw: "left",
            textColorHex: "#2C3E50",
            backgroundColorHex: "#FADBD8",
            hasBorder: true,
            cornerRadius: 6,
            borderColorHex: "#E6B0AA",
            borderWidth: 1.0,
            x: margin + 265,
            y: 85,
            width: contentWidth - 265,
            height: 140,
            lineSpacing: 4
        ))

        // 考點膠帶 1（覆蓋重要概念）
        tapes.append(NoteTapeAttachment(
            pageIndex: 0,
            rect: CGRect(x: margin + 275, y: 190, width: 200, height: 28),
            isRevealed: false,
            colorHex: "#FFD1DC" // 柔粉色
        ))

        // 3. 淋巴循環區塊 (Lymphatic System)
        let lymphBox = NoteShapeAttachment(
            pageIndex: 0,
            kindName: "rectangle",
            x: margin,
            y: 240,
            width: contentWidth,
            height: 180,
            cornerRadius: 8,
            label: "",
            strokeColorHex: "#52BE80",
            fillColorHex: "#EAFAF1",
            lineWidth: 1.5
        )
        shapes.append(lymphBox)

        texts.append(NoteTextAttachment(
            pageIndex: 0,
            text: l("sample_bio_lymph_path"),
            fontSize: 14,
            isBold: true,
            alignmentRaw: "left",
            textColorHex: "#1E8449",
            backgroundColorHex: "clear",
            hasBorder: false,
            x: margin + 15,
            y: 250,
            width: contentWidth - 30,
            height: 60,
            lineSpacing: 4
        ))

        texts.append(NoteTextAttachment(
            pageIndex: 0,
            text: l("sample_bio_lymph_funcs"),
            fontSize: 13,
            isBold: false,
            alignmentRaw: "left",
            textColorHex: "#273746",
            backgroundColorHex: "#D5F5E3",
            hasBorder: true,
            cornerRadius: 6,
            borderColorHex: "#A9DFBF",
            borderWidth: 1.0,
            x: margin + 15,
            y: 315,
            width: 440,
            height: 95,
            lineSpacing: 3
        ))

        // 塗鴉小貓咪文字框
        texts.append(NoteTextAttachment(
            pageIndex: 0,
            text: l("sample_bio_cat_memo"),
            fontSize: 12,
            isBold: true,
            alignmentRaw: "center",
            textColorHex: "#2C3E50",
            backgroundColorHex: "#FCF3CF",
            hasBorder: true,
            cornerRadius: 8,
            borderColorHex: "#F9E79F",
            borderWidth: 1.0,
            x: margin + 465,
            y: 315,
            width: contentWidth - 480,
            height: 95
        ))

        // 4. 氣體運輸機制 (Gas Transport)
        let gasBox = NoteShapeAttachment(
            pageIndex: 0,
            kindName: "rectangle",
            x: margin,
            y: 435,
            width: contentWidth,
            height: 250,
            cornerRadius: 8,
            label: "",
            strokeColorHex: "#85929E",
            fillColorHex: "#F2F4F4",
            lineWidth: 1.5
        )
        shapes.append(gasBox)

        texts.append(NoteTextAttachment(
            pageIndex: 0,
            text: l("sample_bio_gas_title"),
            fontSize: 15,
            isBold: true,
            alignmentRaw: "left",
            textColorHex: "#2C3E50",
            backgroundColorHex: "clear",
            hasBorder: false,
            x: margin + 15,
            y: 445,
            width: 300,
            height: 28
        ))

        // 氧氣運輸反應式
        texts.append(NoteTextAttachment(
            pageIndex: 0,
            text: l("sample_bio_o2_text"),
            fontSize: 13,
            isBold: false,
            alignmentRaw: "left",
            textColorHex: "#1B4F72",
            backgroundColorHex: "#EBF5FB",
            hasBorder: true,
            cornerRadius: 6,
            borderColorHex: "#AED6F1",
            borderWidth: 1.0,
            x: margin + 15,
            y: 478,
            width: contentWidth - 30,
            height: 75,
            lineSpacing: 3
        ))

        // 二氧化碳運輸反應式
        texts.append(NoteTextAttachment(
            pageIndex: 0,
            text: l("sample_bio_co2_text"),
            fontSize: 13,
            isBold: false,
            alignmentRaw: "left",
            textColorHex: "#641E16",
            backgroundColorHex: "#FADBD8",
            hasBorder: true,
            cornerRadius: 6,
            borderColorHex: "#F5B7B1",
            borderWidth: 1.0,
            x: margin + 15,
            y: 560,
            width: contentWidth - 30,
            height: 85,
            lineSpacing: 3
        ))

        // 考點膠帶 2 & 3（覆蓋重要百分比）
        tapes.append(NoteTapeAttachment(
            pageIndex: 0,
            rect: CGRect(x: margin + 35, y: 580, width: 140, height: 24),
            isRevealed: false,
            colorHex: "#FCEEAC" // 暖黃色
        ))
        tapes.append(NoteTapeAttachment(
            pageIndex: 0,
            rect: CGRect(x: margin + 35, y: 605, width: 140, height: 24),
            isRevealed: false,
            colorHex: "#C8E6C9" // 薄荷綠
        ))

        // =========================================================================
        // 【第二頁：泌尿系統與腎臟解剖】
        // =========================================================================

        // 1. 第二頁大標題
        texts.append(NoteTextAttachment(
            pageIndex: 1,
            text: l("sample_bio_p2_title"),
            fontSize: 22,
            isBold: true,
            alignmentRaw: "left",
            textColorHex: "#7D6608",
            backgroundColorHex: "clear",
            hasBorder: false,
            cornerRadius: 0,
            x: margin,
            y: 40,
            width: contentWidth,
            height: 38
        ))

        // 2. 解剖構造卡片
        let nephronBox = NoteShapeAttachment(
            pageIndex: 1,
            kindName: "rectangle",
            x: margin,
            y: 85,
            width: 320,
            height: 250,
            cornerRadius: 8,
            label: "",
            strokeColorHex: "#B7950B",
            fillColorHex: "#FEF9E7",
            lineWidth: 1.5
        )
        shapes.append(nephronBox)

        texts.append(NoteTextAttachment(
            pageIndex: 1,
            text: l("sample_bio_nephron_text"),
            fontSize: 13,
            isBold: false,
            alignmentRaw: "left",
            textColorHex: "#4D5656",
            backgroundColorHex: "clear",
            hasBorder: false,
            x: margin + 12,
            y: 95,
            width: 300,
            height: 230,
            lineSpacing: 4
        ))

        // 3. 腎臟生理功能總覽
        let funcBox = NoteShapeAttachment(
            pageIndex: 1,
            kindName: "rectangle",
            x: margin + 335,
            y: 85,
            width: contentWidth - 335,
            height: 250,
            cornerRadius: 8,
            label: "",
            strokeColorHex: "#2E86C1",
            fillColorHex: "#EBF5FB",
            lineWidth: 1.5
        )
        shapes.append(funcBox)

        texts.append(NoteTextAttachment(
            pageIndex: 1,
            text: l("sample_bio_renal_funcs"),
            fontSize: 13,
            isBold: false,
            alignmentRaw: "left",
            textColorHex: "#1B4F72",
            backgroundColorHex: "clear",
            hasBorder: false,
            x: margin + 347,
            y: 95,
            width: contentWidth - 360,
            height: 230,
            lineSpacing: 6
        ))

        // 考點膠帶 4（覆蓋荷爾蒙調節考點）
        tapes.append(NoteTapeAttachment(
            pageIndex: 1,
            rect: CGRect(x: margin + 347, y: 145, width: 180, height: 26),
            isRevealed: false,
            colorHex: "#BBDEFB" // 晴空藍
        ))

        // 4. 生理作用比較表（原生表格）
        texts.append(NoteTextAttachment(
            pageIndex: 1,
            text: l("sample_bio_table_title"),
            fontSize: 15,
            isBold: true,
            alignmentRaw: "left",
            textColorHex: "#2C3E50",
            backgroundColorHex: "clear",
            hasBorder: false,
            x: margin,
            y: 350,
            width: 350,
            height: 30
        ))

        let parsedTable = parseTable(l("sample_bio_tools_table"))
        tables.append(NoteTableAttachment(
            pageIndex: 1,
            x: margin,
            y: 385,
            width: contentWidth,
            rows: parsedTable.rows,
            cols: parsedTable.cols,
            cells: parsedTable.cells,
            headerRow: true,
            fontSize: 13,
            headerBackgroundHex: "#D4EFDF"
        ))

        // 5. 底部總結便簽
        texts.append(NoteTextAttachment(
            pageIndex: 1,
            text: l("sample_bio_summary_memo"),
            fontSize: 13,
            isBold: true,
            alignmentRaw: "left",
            textColorHex: "#922B21",
            backgroundColorHex: "#FADBD8",
            hasBorder: true,
            cornerRadius: 6,
            borderColorHex: "#E6B0AA",
            borderWidth: 1.0,
            x: margin,
            y: 560,
            width: contentWidth,
            height: 55,
            lineSpacing: 4
        ))

        // 組裝進 document
        doc.textAttachments = texts
        doc.tableAttachments = tables
        doc.shapeAttachments = shapes
        doc.connectionAttachments = connections
        doc.tapeAttachments = tapes
    }
}
