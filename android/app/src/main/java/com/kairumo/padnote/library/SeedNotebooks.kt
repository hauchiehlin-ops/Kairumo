package com.kairumo.padnote.library

import android.content.Context
import com.kairumo.padnote.LocalizationStrings
import com.kairumo.padnote.chart.ChartSeries
import com.kairumo.padnote.chart.ChartSpec
import com.kairumo.padnote.chart.ChartStore
import com.kairumo.padnote.shape.NoteShape
import com.kairumo.padnote.shape.ShapeStore
import com.kairumo.padnote.table.NoteTable
import com.kairumo.padnote.table.TableStore
import com.kairumo.padnote.text.TextBoxStore
import uniffi.padnote_core.PadnoteSession
import uniffi.padnote_core.PageStyle

/**
 * 兩本內建範例筆記的內容（Android）。
 *
 * # 為什麼要有內容
 *
 * Android 在此之前只會建一本叫「Kairumo」的**空白**筆記本。使用者第一次
 * 打開看到的是一片白 —— 那比沒有範例還糟，因為他會以為這個 App 只能手寫。
 *
 * # 與 Apple 端的關係
 *
 * 版面、文案、配色與 `apple/Sources/SeedContent.swift` **是同一組**：
 * 同樣三頁、同樣的標題與段落、同樣的表格內容（來自同一批 `sample_*` 語系
 * 字串）。兩邊各寫一套的話，同一本「範例筆記」在兩個平台會長得不一樣，
 * 而那正是範例最不該出現的事。
 *
 * 文字在建立當下用當時的介面語言取一次就夠 —— 種子只跑一次，跑完那些字
 * 就是**使用者自己的內容**，跟著語言變的話他改過的字會被翻譯蓋掉。
 */
object SeedNotebooks {

    /** 與 Apple 端同一組版面常數。 */
    private const val MARGIN = 56f
    private const val PAGE_WIDTH = 800f
    private const val CONTENT_WIDTH = PAGE_WIDTH - MARGIN * 2

    /**
     * 筆記庫空的時候建立範例筆記。已經有東西就什麼也不做 ——
     * 每次啟動都塞進去的話，使用者刪掉之後它們會自己長回來。
     *
     * @return 建立的筆記本數（0 表示本來就有東西）。
     */
    fun seedIfEmpty(context: Context, deviceId: UInt, languageTag: String): Int {
        fun l(key: String) = LocalizationStrings.localized(key, languageTag)

        val existing = NotebookLibrary.all(context, deviceId)
        if (existing.isNotEmpty()) return backfill(context, deviceId, existing, ::l)

        var created = 0
        if (buildWelcome(context, deviceId, ::l)) created++
        if (buildMeeting(context, deviceId, ::l)) created++
        if (buildFeatureShowcase(context, deviceId, ::l)) created++
        if (buildKairumoManual(context, deviceId)) created++
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putBoolean(KEY_MANUAL, true).apply()
        return created
    }

    /**
     * 補上「有名字、沒內容」的範例筆記。
     *
     * # 為什麼需要這一步
     *
     * 上面那段只在筆記庫**空的時候**跑。而範例筆記的內容是後來才加的 ——
     * 在那之前裝過這個 App 的人，庫裡早就有東西（Android 舊版會自動建一本
     * 叫 Kairumo 的空白筆記），於是那個補內容的分支一輩子不會執行。
     * 使用者看到的是：範例筆記打開來一片白，而它的名字承諾的是說明。
     *
     * # 為什麼不直接重建
     *
     * 種子跑完，那些字就是**使用者自己的內容**了。所以只在「整個筆記庫
     * 沒有任何一筆內容」時才補 —— 只要他寫過一個字、畫過一筆，就一律不動。
     * 補內容補掉使用者的筆記，比一片空白嚴重得多。
     *
     * 補過就記一個旗標。沒有它的話，使用者把範例刪掉（庫裡剩下的仍然是
     * 空的），下次開 App 它們就自己長回來。
     */
    private fun backfill(
        context: Context,
        deviceId: UInt,
        existing: List<NotebookLibrary.Entry>,
        l: (String) -> String
    ): Int {
        // 主動清理廢除的舊版《Kairumo（精選實例）》
        NotebookLibrary.delete(context, LEGACY_FEATURED_ID)

        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val showcaseTitle = l("seed_feature_showcase_title")
        val hasShowcase = existing.any { it.title == showcaseTitle || it.id == SHOWCASE_ID }
        if (!hasShowcase) {
            buildFeatureShowcase(context, deviceId, l)
        }

        // 《Kairumo手冊》：舊使用者只補一次（旗標），之後刪掉就不再長回來。
        if (!prefs.getBoolean(KEY_MANUAL, false)) {
            prefs.edit().putBoolean(KEY_MANUAL, true).apply()
            if (existing.none { it.id == MANUAL_ID || it.title == MANUAL_TITLE }) {
                buildKairumoManual(context, deviceId)
            }
        }

        if (prefs.getBoolean(KEY_BACKFILLED, false)) return 0

        val welcomeTitle = l("seed_welcome_title")
        val meetingTitle = l("seed_meeting_title")
        val hasSamples = existing.any { it.title == welcomeTitle || it.title == meetingTitle }
        if (hasSamples) return 0
        if (!existing.all { isBlank(context, it.id, deviceId) }) return 0

        var created = 0
        if (buildWelcome(context, deviceId, l)) created++
        if (buildMeeting(context, deviceId, l)) created++
        prefs.edit().putBoolean(KEY_BACKFILLED, true).apply()
        return created
    }

    /** 這本筆記有沒有任何內容 —— 筆跡與插入的物件都算。 */
    private fun isBlank(context: Context, id: String, deviceId: UInt): Boolean {
        val session = NotebookLibrary.open(context, id, deviceId)?.first ?: return false
        val pages = runCatching { session.pageCount().toInt() }.getOrDefault(0)
        for (index in 0 until pages) {
            val page = runCatching { session.pageIdAt(index.toUInt()) }.getOrNull() ?: continue
            val empty = runCatching { session.drawOrder(page).isEmpty() }.getOrDefault(false) &&
                runCatching { session.textBlockIds(page).isEmpty() }.getOrDefault(false) &&
                runCatching { session.tableBlockIds(page).isEmpty() }.getOrDefault(false) &&
                runCatching { session.imageBlockIds(page).isEmpty() }.getOrDefault(false)
            // 讀不出來就當成「有東西」。判斷不出來就不要動它。
            if (!empty) return false
        }
        return true
    }

    private const val PREFS = "kairumo.seed"
    private const val KEY_MANUAL = "kairumo_manual_added"
    private const val MANUAL_ID = "seed-kairumo-manual-v1"
    /** 名稱是固定的，不走語系表。 */
    private const val MANUAL_TITLE = "Kairumo手冊"
    private const val KEY_BACKFILLED = "samples_backfilled"
    private const val WELCOME_ID = "seed-welcome-notebook-v1"
    private const val MEETING_ID = "seed-meeting-notebook-v1"
    private const val SHOWCASE_ID = "seed-feature-showcase-v1"
    private const val LEGACY_FEATURED_ID = "seed-featured-biology-v1"

    // MARK: - 功能實戰範例筆記：《Kairumo(功能範例)》

private fun buildFeatureShowcase(context: Context, deviceId: UInt, l: (String) -> String): Boolean {
        // 主動清理舊版《Kairumo（精選實例）》
        NotebookLibrary.delete(context, LEGACY_FEATURED_ID)

        val id = NotebookLibrary.create(
            context, l("seed_feature_showcase_title"), deviceId, id = SHOWCASE_ID
        ) ?: return false
        val opened = NotebookLibrary.open(context, id, deviceId) ?: return false
        val (session, firstPage) = opened
        val pages = ensurePages(session, firstPage, 4)

        // 設定為方格點陣 (grid) 樣板
        val meta = NotebookMeta.load(session)
        meta.setPaperId(session, "grid")

        // =========================================================================
        // 【第 1 頁：應用程式用途說明 ＆ 市面主流軟體深度全景評測】
        // =========================================================================

        title(session, pages[0], l("sample_showcase_p1_title"), 32f)

        val textStore0 = TextBoxStore(session, pages[0])
        val subBox0 = textStore0.create(MARGIN, 76f)
        subBox0.width = CONTENT_WIDTH
        subBox0.height = 30f
        subBox0.text = l("sample_showcase_p1_subtitle")
        subBox0.fontSize = 13f
        subBox0.bold = true
        subBox0.textColorHex = "#2B6CB0"
        subBox0.backgroundColorHex = "#EBF8FF"
        subBox0.hasBorder = true
        subBox0.borderColorHex = "#BEE3F8"
        subBox0.borderWidth = 1.0f
        subBox0.cornerRadius = 6f
        textStore0.persist(subBox0)

        // 應用程式核心使命卡片
        val shapes0 = ShapeStore(session, pages[0])
        shapes0.create(card(MARGIN, 114f, CONTENT_WIDTH, 118f, "#3182CE", "#EBF8FF"))

        val misTitle0 = textStore0.create(MARGIN + 14f, 122f)
        misTitle0.width = CONTENT_WIDTH - 28f
        misTitle0.height = 22f
        misTitle0.text = l("sample_showcase_p1_mission_title")
        misTitle0.fontSize = 14f
        misTitle0.bold = true
        misTitle0.textColorHex = "#2B6CB0"
        misTitle0.backgroundColorHex = "clear"
        misTitle0.hasBorder = false
        textStore0.persist(misTitle0)

        val misBody0 = textStore0.create(MARGIN + 14f, 146f)
        misBody0.width = CONTENT_WIDTH - 28f
        misBody0.height = 80f
        misBody0.text = l("sample_showcase_p1_mission_body")
        misBody0.fontSize = 11.5f
        misBody0.textColorHex = "#2D3748"
        misBody0.backgroundColorHex = "clear"
        misBody0.hasBorder = false
        misBody0.lineSpacing = 3f
        textStore0.persist(misBody0)

        // 四大核心支柱 (2x2 矩陣)
        val p1PillarsY = 242f
        val colW = (CONTENT_WIDTH - 14f) / 2f
        val rowH = 92f

        shapes0.create(card(MARGIN, p1PillarsY, colW, rowH, "#38A169", "#F0FFF4"))
        addPillarText(textStore0, l("sample_showcase_p1_pillar1_title"), l("sample_showcase_p1_pillar1_body"), MARGIN + 10f, p1PillarsY, colW - 20f, "#22543D")

        shapes0.create(card(MARGIN + colW + 14f, p1PillarsY, colW, rowH, "#805AD5", "#FAF5FF"))
        addPillarText(textStore0, l("sample_showcase_p1_pillar2_title"), l("sample_showcase_p1_pillar2_body"), MARGIN + colW + 24f, p1PillarsY, colW - 20f, "#44337A")

        shapes0.create(card(MARGIN, p1PillarsY + rowH + 10f, colW, rowH, "#DD6B20", "#FFFAF0"))
        addPillarText(textStore0, l("sample_showcase_p1_pillar3_title"), l("sample_showcase_p1_pillar3_body"), MARGIN + 10f, p1PillarsY + rowH + 10f, colW - 20f, "#7B341E")

        shapes0.create(card(MARGIN + colW + 14f, p1PillarsY + rowH + 10f, colW, rowH, "#D69E2E", "#FFFFF0"))
        addPillarText(textStore0, l("sample_showcase_p1_pillar4_title"), l("sample_showcase_p1_pillar4_body"), MARGIN + colW + 24f, p1PillarsY + rowH + 10f, colW - 20f, "#744210")

        // 全景深度評測表
        val p1TableY = 450f
        val tblTitle0 = textStore0.create(MARGIN, p1TableY)
        tblTitle0.width = CONTENT_WIDTH
        tblTitle0.height = 24f
        tblTitle0.text = l("sample_showcase_p1_table_title")
        tblTitle0.fontSize = 14f
        tblTitle0.bold = true
        tblTitle0.textColorHex = "#1A365D"
        tblTitle0.backgroundColorHex = "clear"
        tblTitle0.hasBorder = false
        textStore0.persist(tblTitle0)

        val tableStore0 = TableStore(session, pages[0])
        val parsedMatrix = parseTable(l("sample_showcase_comparison_table"))
        val matrixTable = NoteTable(
            x = MARGIN, y = p1TableY + 28f, width = CONTENT_WIDTH,
            rows = parsedMatrix.rows, cols = parsedMatrix.cols,
            cells = parsedMatrix.cells.toMutableList(),
            headerRow = true, fontSize = 10f, headerBackgroundHex = "#EBF8FF"
        )
        tableStore0.create(matrixTable)

        // 底部亮點膠囊
        val pillY0 = 825f
        shapes0.create(pill("100% 完全開源免費", MARGIN, pillY0, "#EBF8FF"))
        shapes0.create(pill("零廣告無廠商鎖定", MARGIN + 175f, pillY0, "#F0FFF4"))
        shapes0.create(pill("次世代多維思考架構", MARGIN + 350f, pillY0, "#FAF5FF"))
        shapes0.create(pill("原生高效向量核心", MARGIN + 525f, pillY0, "#FFFAF0"))


        // =========================================================================
        // 【第 2 頁：「手繪模式」下所有工具用法與實作範例】
        // =========================================================================

        title(session, pages[1], l("sample_showcase_p2_title"), 32f)

        val textStore1 = TextBoxStore(session, pages[1])
        val subBox1 = textStore1.create(MARGIN, 76f)
        subBox1.width = CONTENT_WIDTH
        subBox1.height = 30f
        subBox1.text = l("sample_showcase_p2_subtitle")
        subBox1.fontSize = 13f
        subBox1.bold = true
        subBox1.textColorHex = "#2B6CB0"
        subBox1.backgroundColorHex = "#EBF8FF"
        subBox1.hasBorder = true
        subBox1.borderColorHex = "#BEE3F8"
        subBox1.borderWidth = 1.0f
        subBox1.cornerRadius = 6f
        textStore1.persist(subBox1)

        val shapes1 = ShapeStore(session, pages[1])
        // 家族 1 背景卡片 (書寫)
        shapes1.create(card(MARGIN, 114f, CONTENT_WIDTH, 216f, "#2B6CB0", "#F7FAFC"))
        addSectionHeader(textStore1, l("sample_showcase_p2_family_write"), MARGIN + 12f, 122f, "#2B6CB0")

        // 家族 2 背景卡片 (彩繪)
        shapes1.create(card(MARGIN, 338f, CONTENT_WIDTH, 196f, "#9F7AEA", "#FAF5FF"))
        addSectionHeader(textStore1, l("sample_showcase_p2_family_paint"), MARGIN + 12f, 346f, "#6B46C1")

        // 家族 3 背景卡片 (標記與工具)
        shapes1.create(card(MARGIN, 542f, CONTENT_WIDTH, 236f, "#DD6B20", "#FFFAF0"))
        addSectionHeader(textStore1, l("sample_showcase_p2_family_mark"), MARGIN + 12f, 550f, "#C05621")

        // 書寫筆刷實體筆劃 (鋼筆、原子筆、毛筆、鉛筆)
        val penColor = byteArrayOf(30, 80, 215.toByte(), -1)
        val ballColor = byteArrayOf(25, 100, 180.toByte(), -1)
        val brushColor = byteArrayOf(140.toByte(), 30, 30, -1)
        val pencilColor = byteArrayOf(70, 80, 95, -1)

        addStrokeSwatch(session, pages[1], MARGIN + 180f, 156f, uniffi.padnote_core.ToolKind.FOUNTAIN_PEN, penColor, 3.2f)
        addStrokeSwatch(session, pages[1], MARGIN + 180f, 212f, uniffi.padnote_core.ToolKind.BALL_POINT, ballColor, 2.0f)
        addStrokeSwatch(session, pages[1], MARGIN + 180f, 240f, uniffi.padnote_core.ToolKind.CALLIGRAPHY, brushColor, 5.5f)
        addStrokeSwatch(session, pages[1], MARGIN + 180f, 304f, uniffi.padnote_core.ToolKind.PENCIL, pencilColor, 2.2f)

        // 彩繪筆刷實體筆劃 (炭筆、蠟筆、油畫、水彩)
        val charcoalColor = byteArrayOf(45, 45, 55, -1)
        val crayonColor = byteArrayOf(215.toByte(), 90, 40, -1)
        val oilColor = byteArrayOf(190.toByte(), 50, 50, -1)
        val waterColor = byteArrayOf(40, 140.toByte(), 190.toByte(), -1)

        addStrokeSwatch(session, pages[1], MARGIN + 180f, 380f, uniffi.padnote_core.ToolKind.CHARCOAL, charcoalColor, 3.8f)
        addStrokeSwatch(session, pages[1], MARGIN + 180f, 410f, uniffi.padnote_core.ToolKind.CRAYON, crayonColor, 4.2f)
        addStrokeSwatch(session, pages[1], MARGIN + 180f, 472f, uniffi.padnote_core.ToolKind.OIL_PAINT, oilColor, 5.2f)
        addStrokeSwatch(session, pages[1], MARGIN + 180f, 504f, uniffi.padnote_core.ToolKind.WATERCOLOR, waterColor, 6.5f)

        // 標記工具筆劃 (記號筆、螢光筆)
        val markerColor = byteArrayOf(40, 115.toByte(), 215.toByte(), -1)
        val highColor = byteArrayOf(240.toByte(), 215.toByte(), 40, -1)
        addStrokeSwatch(session, pages[1], MARGIN + 180f, 584f, uniffi.padnote_core.ToolKind.MARKER, markerColor, 5.5f)
        addStrokeSwatch(session, pages[1], MARGIN + 180f, 612f, uniffi.padnote_core.ToolKind.HIGHLIGHTER, highColor, 10.0f)

        // 遮蔽膠帶說明卡片
        val tapeDescBox = textStore1.create(MARGIN + 14f, 692f)
        tapeDescBox.width = CONTENT_WIDTH - 28f
        tapeDescBox.height = 40f
        tapeDescBox.text = l("sample_showcase_p2_tape_desc")
        tapeDescBox.fontSize = 11f
        tapeDescBox.textColorHex = "#744210"
        tapeDescBox.backgroundColorHex = "#FEFCBF"
        tapeDescBox.hasBorder = true
        tapeDescBox.borderColorHex = "#ECC94B"
        tapeDescBox.borderWidth = 1.0f
        tapeDescBox.cornerRadius = 6f
        tapeDescBox.lineSpacing = 2f
        textStore1.persist(tapeDescBox)

        // 膠帶背後的答案文字
        val tapeAnsBox = textStore1.create(MARGIN + 20f, 738f)
        tapeAnsBox.width = CONTENT_WIDTH - 40f
        tapeAnsBox.height = 32f
        tapeAnsBox.text = l("sample_showcase_tape_answer")
        tapeAnsBox.fontSize = 12f
        tapeAnsBox.bold = true
        tapeAnsBox.textColorHex = "#2D3748"
        tapeAnsBox.backgroundColorHex = "#FFFFFF"
        tapeAnsBox.hasBorder = true
        tapeAnsBox.borderColorHex = "#E2E8F0"
        tapeAnsBox.borderWidth = 1.0f
        tapeAnsBox.cornerRadius = 4f
        textStore1.persist(tapeAnsBox)

        // 底部筆刷徽章
        val pillY1 = 825f
        shapes1.create(pill("16 種物理級筆刷", MARGIN, pillY1, "#EBF8FF"))
        shapes1.create(pill("真實壓感與毛筆提按", MARGIN + 175f, pillY1, "#F0FFF4"))
        shapes1.create(pill("互動考點遮蔽膠帶", MARGIN + 350f, pillY1, "#FFFFF0"))
        shapes1.create(pill("尺規與套索精準幾何", MARGIN + 525f, pillY1, "#FAF5FF"))


        // =========================================================================
        // 【第 3 頁：「文字模式」下所有工具用法與實作範例】
        // =========================================================================

        title(session, pages[2], l("sample_showcase_p3_title"), 32f)

        val textStore2 = TextBoxStore(session, pages[2])
        val subBox2 = textStore2.create(MARGIN, 76f)
        subBox2.width = CONTENT_WIDTH
        subBox2.height = 30f
        subBox2.text = l("sample_showcase_p3_subtitle")
        subBox2.fontSize = 13f
        subBox2.bold = true
        subBox2.textColorHex = "#2B6CB0"
        subBox2.backgroundColorHex = "#EBF8FF"
        subBox2.hasBorder = true
        subBox2.borderColorHex = "#BEE3F8"
        subBox2.borderWidth = 1.0f
        subBox2.cornerRadius = 6f
        textStore2.persist(subBox2)

        val shapes2 = ShapeStore(session, pages[2])
        // 1. 富文本文字卡片
        shapes2.create(card(MARGIN, 114f, CONTENT_WIDTH, 116f, "#3182CE", "#EBF8FF"))
        val richTitle2 = textStore2.create(MARGIN + 14f, 122f)
        richTitle2.width = CONTENT_WIDTH - 28f
        richTitle2.height = 22f
        richTitle2.text = l("sample_showcase_p3_richtext_title")
        richTitle2.fontSize = 14f
        richTitle2.bold = true
        richTitle2.textColorHex = "#2B6CB0"
        richTitle2.backgroundColorHex = "clear"
        richTitle2.hasBorder = false
        textStore2.persist(richTitle2)

        val richBody2 = textStore2.create(MARGIN + 14f, 146f)
        richBody2.width = CONTENT_WIDTH - 28f
        richBody2.height = 76f
        richBody2.text = l("sample_showcase_p3_richtext_body")
        richBody2.fontSize = 11.5f
        richBody2.textColorHex = "#2D3748"
        richBody2.backgroundColorHex = "#FFFFFF"
        richBody2.hasBorder = true
        richBody2.borderColorHex = "#BEE3F8"
        richBody2.borderWidth = 1.0f
        richBody2.cornerRadius = 6f
        richBody2.lineSpacing = 3f
        textStore2.persist(richBody2)

        // 2. 原生數據表格
        val p3TableY = 240f
        val tblTitle2 = textStore2.create(MARGIN, p3TableY)
        tblTitle2.width = CONTENT_WIDTH
        tblTitle2.height = 22f
        tblTitle2.text = l("sample_showcase_p3_table_title")
        tblTitle2.fontSize = 13f
        tblTitle2.bold = true
        tblTitle2.textColorHex = "#1A365D"
        tblTitle2.backgroundColorHex = "clear"
        tblTitle2.hasBorder = false
        textStore2.persist(tblTitle2)

        val tableStore2 = TableStore(session, pages[2])
        val parsedP3Table = parseTable(l("sample_showcase_p3_table_data"))
        val p3Table = NoteTable(
            x = MARGIN, y = p3TableY + 26f, width = CONTENT_WIDTH,
            rows = parsedP3Table.rows, cols = parsedP3Table.cols,
            cells = parsedP3Table.cells.toMutableList(),
            headerRow = true, fontSize = 11f, headerBackgroundHex = "#EDF2F7"
        )
        tableStore2.create(p3Table)

        // 3. 幾何圖形庫與智慧流程圖
        val flowY = 430f
        val flowTitle2 = textStore2.create(MARGIN, flowY)
        flowTitle2.width = CONTENT_WIDTH
        flowTitle2.height = 22f
        flowTitle2.text = l("sample_showcase_p3_flow_title")
        flowTitle2.fontSize = 13f
        flowTitle2.bold = true
        flowTitle2.textColorHex = "#2C5282"
        flowTitle2.backgroundColorHex = "clear"
        flowTitle2.hasBorder = false
        textStore2.persist(flowTitle2)

        val flowBoxY = flowY + 30f
        shapes2.create(
            NoteShape(
                kindName = "terminator", x = MARGIN, y = flowBoxY, width = 140f, height = 50f,
                cornerRadius = 25f, label = l("sample_showcase_p3_flow_start"),
                strokeColorHex = "#38A169", fillColorHex = "#F0FFF4", lineWidth = 1.5f
            )
        )
        shapes2.create(
            NoteShape(
                kindName = "process", x = MARGIN + 175f, y = flowBoxY, width = 155f, height = 50f,
                cornerRadius = 8f, label = l("sample_showcase_p3_flow_process"),
                strokeColorHex = "#3182CE", fillColorHex = "#EBF8FF", lineWidth = 1.5f
            )
        )
        shapes2.create(
            NoteShape(
                kindName = "decision", x = MARGIN + 365f, y = flowBoxY - 8f, width = 150f, height = 66f,
                cornerRadius = 0f, label = l("sample_showcase_p3_flow_decision"),
                strokeColorHex = "#805AD5", fillColorHex = "#FAF5FF", lineWidth = 1.5f
            )
        )
        shapes2.create(
            NoteShape(
                kindName = "terminator", x = MARGIN + 550f, y = flowBoxY, width = 138f, height = 50f,
                cornerRadius = 25f, label = l("sample_showcase_p3_flow_end"),
                strokeColorHex = "#DD6B20", fillColorHex = "#FFFAF0", lineWidth = 1.5f
            )
        )

        // 4. 多媒體區塊標題
        val mediaY = 540f
        val mediaTitle2 = textStore2.create(MARGIN, mediaY)
        mediaTitle2.width = CONTENT_WIDTH
        mediaTitle2.height = 22f
        mediaTitle2.text = l("sample_showcase_p3_media_title")
        mediaTitle2.fontSize = 13f
        mediaTitle2.bold = true
        mediaTitle2.textColorHex = "#1A365D"
        mediaTitle2.backgroundColorHex = "clear"
        mediaTitle2.hasBorder = false
        textStore2.persist(mediaTitle2)

        val cardW = (CONTENT_WIDTH - 24f) / 3f
        val cardH = 190f
        val cardRowY = mediaY + 30f

        // 4a. 網頁預覽卡片
        shapes2.create(card(MARGIN, cardRowY, cardW, cardH, "#3182CE", "#FFFFFF"))
        val linkText = textStore2.create(MARGIN + 10f, cardRowY + 12f)
        linkText.width = cardW - 20f
        linkText.height = cardH - 24f
        linkText.text = l("sample_showcase_card_link_body")
        linkText.fontSize = 11f
        linkText.textColorHex = "#2B6CB0"
        linkText.backgroundColorHex = "clear"
        linkText.hasBorder = false
        textStore2.persist(linkText)

        // 4b. 錄音時間軸卡片
        shapes2.create(card(MARGIN + cardW + 12f, cardRowY, cardW, cardH, "#805AD5", "#FFFFFF"))
        val audioText = textStore2.create(MARGIN + cardW + 22f, cardRowY + 12f)
        audioText.width = cardW - 20f
        audioText.height = cardH - 24f
        audioText.text = l("sample_showcase_card_audio_body")
        audioText.fontSize = 11f
        audioText.textColorHex = "#6B46C1"
        audioText.backgroundColorHex = "clear"
        audioText.hasBorder = false
        textStore2.persist(audioText)

        // 4c. 3D 空間幾何模型卡片
        shapes2.create(card(MARGIN + (cardW + 12f) * 2f, cardRowY, cardW, cardH, "#DD6B20", "#FFFFFF"))
        val modelText = textStore2.create(MARGIN + (cardW + 12f) * 2f + 10f, cardRowY + 12f)
        modelText.width = cardW - 20f
        modelText.height = cardH - 24f
        modelText.text = l("sample_showcase_card_model_body")
        modelText.fontSize = 11f
        modelText.textColorHex = "#C05621"
        modelText.backgroundColorHex = "clear"
        modelText.hasBorder = false
        textStore2.persist(modelText)

        // 底部文字模式徽章
        val pillY2 = 825f
        shapes2.create(pill("桌面級專業排版", MARGIN, pillY2, "#EBF8FF"))
        shapes2.create(pill("原生高格自適應表", MARGIN + 175f, pillY2, "#F0FFF4"))
        shapes2.create(pill("智慧拓撲流程圖", MARGIN + 350f, pillY2, "#FAF5FF"))
        shapes2.create(pill("3D 與音訊多媒體", MARGIN + 525f, pillY2, "#FFFAF0"))


        // =========================================================================
        // 【第 4 頁：「手繪＋文字」終極交響樂：說明 Kairumo 最大優勢】
        // =========================================================================

        title(session, pages[3], l("sample_showcase_p4_title"), 32f)

        val textStore3 = TextBoxStore(session, pages[3])
        val subBox3 = textStore3.create(MARGIN, 76f)
        subBox3.width = CONTENT_WIDTH
        subBox3.height = 30f
        subBox3.text = l("sample_showcase_p4_subtitle")
        subBox3.fontSize = 13f
        subBox3.bold = true
        subBox3.textColorHex = "#2B6CB0"
        subBox3.backgroundColorHex = "#EBF8FF"
        subBox3.hasBorder = true
        subBox3.borderColorHex = "#BEE3F8"
        subBox3.borderWidth = 1.0f
        subBox3.cornerRadius = 6f
        textStore3.persist(subBox3)

        val shapes3 = ShapeStore(session, pages[3])
        // 旗艦金色橫幅標章
        shapes3.create(
            NoteShape(
                kindName = "roundedrectangle", x = MARGIN, y = 114f, width = CONTENT_WIDTH, height = 38f,
                cornerRadius = 8f, label = l("sample_showcase_p4_hero_badge"),
                strokeColorHex = "#D69E2E", fillColorHex = "#FEFCBF", lineWidth = 1.5f
            )
        )

        // 1. 微積分方程融合卡片
        shapes3.create(card(MARGIN, 160f, CONTENT_WIDTH, 215f, "#805AD5", "#FAF5FF"))

        val calcTitle4 = textStore3.create(MARGIN + 14f, 168f)
        calcTitle4.width = CONTENT_WIDTH - 28f
        calcTitle4.height = 22f
        calcTitle4.text = l("sample_showcase_p4_math_card_title")
        calcTitle4.fontSize = 13f
        calcTitle4.bold = true
        calcTitle4.textColorHex = "#553C9A"
        calcTitle4.backgroundColorHex = "clear"
        calcTitle4.hasBorder = false
        textStore3.persist(calcTitle4)

        // 右側 LaTeX 步驟解析說明卡
        val calcDesc4 = textStore3.create(MARGIN + 340f, 196f)
        calcDesc4.width = CONTENT_WIDTH - 354f
        calcDesc4.height = 168f
        calcDesc4.text = l("sample_showcase_p4_math_card_desc")
        calcDesc4.fontSize = 11f
        calcDesc4.textColorHex = "#4A5568"
        calcDesc4.backgroundColorHex = "#FFFFFF"
        calcDesc4.hasBorder = true
        calcDesc4.borderColorHex = "#E9D8FD"
        calcDesc4.borderWidth = 1.0f
        calcDesc4.cornerRadius = 6f
        calcDesc4.lineSpacing = 3f
        textStore3.persist(calcDesc4)

        // 左側真實微積分手寫筆劃
        val mathInkColor = byteArrayOf(38, 50, 90, -1)
        val mathPoints1 = (0..20).map { i ->
            uniffi.padnote_core.StrokePoint(
                x = MARGIN + 20f + i * 14f,
                y = 220f + kotlin.math.sin(i * 0.4f) * 3f,
                pressure = 0.6f, tilt = 0.2f, azimuth = 0f, dtUs = (i * 10_000).toUInt()
            )
        }
        session.addStroke(pages[3], uniffi.padnote_core.ToolKind.FOUNTAIN_PEN, mathInkColor, 2.8f, mathPoints1)

        val mathPoints2 = (0..24).map { i ->
            uniffi.padnote_core.StrokePoint(
                x = MARGIN + 20f + i * 13f,
                y = 265f + kotlin.math.cos(i * 0.4f) * 2f,
                pressure = 0.65f, tilt = 0.2f, azimuth = 0f, dtUs = (i * 9_000).toUInt()
            )
        }
        session.addStroke(pages[3], uniffi.padnote_core.ToolKind.FOUNTAIN_PEN, mathInkColor, 2.4f, mathPoints2)

        // 紅色圓圈重點圈選
        val redCircleColor = byteArrayOf(215.toByte(), 45, 45, -1)
        val circlePoints = (0..24).map { i ->
            val angle = (i / 24f) * kotlin.math.PI.toFloat() * 2f
            uniffi.padnote_core.StrokePoint(
                x = MARGIN + 120f + kotlin.math.cos(angle) * 18f,
                y = 345f + kotlin.math.sin(angle) * 18f,
                pressure = 0.7f, tilt = 0.2f, azimuth = 0f, dtUs = (i * 8_000).toUInt()
            )
        }
        session.addStroke(pages[3], uniffi.padnote_core.ToolKind.FOUNTAIN_PEN, redCircleColor, 3.0f, circlePoints)

        // 2. 數字製圖（Chart Studio）與討論圖釘（Comment Pins）
        shapes3.create(card(MARGIN, 386f, CONTENT_WIDTH, 300f, "#3182CE", "#F7FAFC"))

        val chartTitle4 = textStore3.create(MARGIN + 14f, 394f)
        chartTitle4.width = CONTENT_WIDTH - 28f
        chartTitle4.height = 22f
        chartTitle4.text = l("sample_showcase_p4_chart_card_title")
        chartTitle4.fontSize = 13f
        chartTitle4.bold = true
        chartTitle4.textColorHex = "#2B6CB0"
        chartTitle4.backgroundColorHex = "clear"
        chartTitle4.hasBorder = false
        textStore3.persist(chartTitle4)

        val chartDesc4 = textStore3.create(MARGIN + 14f, 418f)
        chartDesc4.width = CONTENT_WIDTH - 28f
        chartDesc4.height = 48f
        chartDesc4.text = l("sample_showcase_p4_chart_card_desc")
        chartDesc4.fontSize = 11f
        chartDesc4.textColorHex = "#2D3748"
        chartDesc4.backgroundColorHex = "#EDF2F7"
        chartDesc4.hasBorder = true
        chartDesc4.borderColorHex = "#CBD5E0"
        chartDesc4.borderWidth = 1.0f
        chartDesc4.cornerRadius = 6f
        chartDesc4.lineSpacing = 2f
        textStore3.persist(chartDesc4)

        // 插入動態可編輯長條圖
        val chartSpec = ChartSpec(
            title = l("sample_showcase_chart_spec_title"),
            categories = mutableListOf("向量書寫延遲", "圖表動態可編修", "空間圖釘協作", "開源與無訂閱限制"),
            series = mutableListOf(
                ChartSeries(
                    name = "Kairumo (Padnote)",
                    values = mutableListOf(98.0, 95.0, 96.0, 100.0),
                    colorHex = "#3182CE"
                ),
                ChartSeries(
                    name = l("sample_showcase_chart_series_top3"),
                    values = mutableListOf(74.0, 52.0, 45.0, 38.0),
                    colorHex = "#CBD5E0"
                )
            )
        )
        ChartStore(session, pages[3]).create(chartSpec, x = MARGIN + 20f, y = 476f)

        // 插入討論圖釘（CommentPin）
        val pin1 = com.kairumo.padnote.comment.CommentPin(
            id = "seed-pin-showcase-chart-p4",
            pageIndex = 3,
            x = MARGIN + 415f,
            y = 535f,
            authorId = "kairumo-reviewer",
            authorName = "Kairumo Architect",
            authorColor = "#3182CE",
            createdAt = java.util.Date(System.currentTimeMillis() - 7200_000L),
            isResolved = false,
            messages = mutableListOf(
                com.kairumo.padnote.comment.CommentMessage(
                    id = "msg-p4-q3",
                    authorId = "kairumo-reviewer",
                    authorName = "Kairumo Architect",
                    authorColor = "#3182CE",
                    text = l("sample_showcase_pin1_msg"),
                    createdAt = java.util.Date(System.currentTimeMillis() - 7200_000L)
                )
            )
        )

        val pin2 = com.kairumo.padnote.comment.CommentPin(
            id = "seed-pin-showcase-math-p4",
            pageIndex = 3,
            x = MARGIN + 280f,
            y = 250f,
            authorId = "math-evaluator",
            authorName = "Prof. Euler",
            authorColor = "#805AD5",
            createdAt = java.util.Date(System.currentTimeMillis() - 3600_000L),
            isResolved = false,
            messages = mutableListOf(
                com.kairumo.padnote.comment.CommentMessage(
                    id = "msg-p4-euler",
                    authorId = "math-evaluator",
                    authorName = "Prof. Euler",
                    authorColor = "#805AD5",
                    text = l("sample_showcase_pin2_msg"),
                    createdAt = java.util.Date(System.currentTimeMillis() - 3600_000L)
                )
            )
        )
        meta.setCommentPins(session, listOf(pin1, pin2))

        // 3. 底部總結：為什麼全球創作者與工程師讚嘆 Kairumo
        shapes3.create(card(MARGIN, 694f, CONTENT_WIDTH, 118f, "#38A169", "#F0FFF4"))
        val conclTitle = textStore3.create(MARGIN + 14f, 702f)
        conclTitle.width = CONTENT_WIDTH - 28f
        conclTitle.height = 22f
        conclTitle.text = l("sample_showcase_p4_conclusion_title")
        conclTitle.fontSize = 13f
        conclTitle.bold = true
        conclTitle.textColorHex = "#22543D"
        conclTitle.backgroundColorHex = "clear"
        conclTitle.hasBorder = false
        textStore3.persist(conclTitle)

        val conclBody = textStore3.create(MARGIN + 14f, 726f)
        conclBody.width = CONTENT_WIDTH - 28f
        conclBody.height = 78f
        conclBody.text = l("sample_showcase_p4_conclusion_body")
        conclBody.fontSize = 11f
        conclBody.textColorHex = "#276749"
        conclBody.backgroundColorHex = "clear"
        conclBody.hasBorder = false
        conclBody.lineSpacing = 3f
        textStore3.persist(conclBody)

        // 底部亮點膠囊
        val pillY3 = 825f
        shapes3.create(pill("STEM 微積分深度解析", MARGIN, pillY3, "#FAF5FF"))
        shapes3.create(pill("動態可編修圖表工坊", MARGIN + 175f, pillY3, "#EBF8FF"))
        shapes3.create(pill("空間討論圖釘協作", MARGIN + 350f, pillY3, "#F0FFF4"))
        shapes3.create(pill("終極無界數位紙張", MARGIN + 525f, pillY3, "#FFFAF0"))

        return true
    }

    private fun card(x: Float, y: Float, width: Float, height: Float, stroke: String, fill: String) = NoteShape(
        kindName = "rectangle", x = x, y = y, width = width, height = height,
        cornerRadius = 10f, label = "", strokeColorHex = stroke, fillColorHex = fill, lineWidth = 1.5f
    )

    private fun addPillarText(store: TextBoxStore, title: String, body: String, x: Float, y: Float, width: Float, color: String) {
        val t = store.create(x, y + 8f)
        t.width = width
        t.height = 20f
        t.text = title
        t.fontSize = 12.5f
        t.bold = true
        t.textColorHex = color
        t.backgroundColorHex = "clear"
        t.hasBorder = false
        store.persist(t)

        val b = store.create(x, y + 30f)
        b.width = width
        b.height = 56f
        b.text = body
        b.fontSize = 11f
        b.textColorHex = "#4A5568"
        b.backgroundColorHex = "clear"
        b.hasBorder = false
        b.lineSpacing = 2f
        store.persist(b)
    }

    private fun addSectionHeader(store: TextBoxStore, title: String, x: Float, y: Float, color: String) {
        val t = store.create(x, y)
        t.width = CONTENT_WIDTH - 24f
        t.height = 22f
        t.text = title
        t.fontSize = 13f
        t.bold = true
        t.textColorHex = color
        t.backgroundColorHex = "clear"
        t.hasBorder = false
        store.persist(t)
    }

    private fun addStrokeSwatch(
        session: PadnoteSession, pageId: String,
        startX: Float, y: Float,
        tool: uniffi.padnote_core.ToolKind, color: ByteArray, baseWidth: Float
    ) {
        val points = (0..24).map { i ->
            val press = 0.4f + kotlin.math.sin(i * 0.35f) * 0.5f
            uniffi.padnote_core.StrokePoint(
                x = startX + i * 18f,
                y = y + kotlin.math.sin(i * 0.45f) * 4f,
                pressure = press, tilt = 0.2f, azimuth = 0f, dtUs = (i * 9_000).toUInt()
            )
        }
        session.addStroke(pageId, tool, color, baseWidth, points)
    }

    // MARK: - 歡迎使用 Kairumo

    private fun buildWelcome(context: Context, deviceId: UInt, l: (String) -> String): Boolean {
        val id = NotebookLibrary.create(
            context, l("seed_welcome_title"), deviceId, id = WELCOME_ID
        ) ?: return false
        val opened = NotebookLibrary.open(context, id, deviceId) ?: return false
        val (session, firstPage) = opened
        val pages = ensurePages(session, firstPage, 3)

        // 第 1 頁：這個 App 是什麼
        title(session, pages[0], l("sample_welcome_p1_title"), 72f)
        body(session, pages[0], l("sample_welcome_p1_body"), 132f, 300f)
        val shapes0 = ShapeStore(session, pages[0])
        shapes0.create(pill(l("sample_welcome_pill_write"), MARGIN, 470f, "#E9EEFC"))
        shapes0.create(pill(l("sample_welcome_pill_type"), MARGIN + 168f, 470f, "#E4F3EC"))
        shapes0.create(pill(l("sample_welcome_pill_record"), MARGIN + 336f, 470f, "#FDECEC"))

        // 第 2 頁：工具列
        title(session, pages[1], l("sample_welcome_p2_title"), 72f)
        TableStore(session, pages[1]).create(table(l("sample_welcome_tools_table"), 136f))
        body(session, pages[1], l("sample_welcome_p2_body"), 470f, 60f)

        // 第 3 頁：備份、同步、隱私
        title(session, pages[2], l("sample_welcome_p3_title"), 72f)
        body(session, pages[2], l("sample_welcome_p3_body"), 132f, 330f)
        return true
    }

    // MARK: - 課堂與會議記錄

    private fun buildMeeting(context: Context, deviceId: UInt, l: (String) -> String): Boolean {
        val id = NotebookLibrary.create(
            context, l("seed_meeting_title"), deviceId, id = MEETING_ID
        ) ?: return false
        val opened = NotebookLibrary.open(context, id, deviceId) ?: return false
        val (session, firstPage) = opened
        val pages = ensurePages(session, firstPage, 3)

        // 第 1 頁：議程 + 重點
        title(session, pages[0], l("sample_meeting_p1_title"), 72f)
        TableStore(session, pages[0]).create(table(l("sample_meeting_agenda_table"), 136f))
        body(session, pages[0], l("sample_meeting_p1_body"), 420f, 240f)

        // 第 2 頁：數字製圖。圖表帶著規格走，所以它**改得動** ——
        // 只存一張點陣圖的話，示範不了「圖表可編修」這件事。
        title(session, pages[1], l("sample_meeting_p2_title"), 72f)
        val spec = ChartSpec(
            title = l("sample_meeting_chart_title"),
            categories = splitList(l("sample_meeting_chart_categories")).toMutableList(),
            series = mutableListOf(
                ChartSeries(
                    name = l("sample_meeting_chart_series"),
                    values = mutableListOf(6.0, 9.0, 7.0, 12.0),
                    colorHex = "#1F4FD8"
                )
            )
        )
        ChartStore(session, pages[1]).create(spec, x = MARGIN, y = 150f)
        body(session, pages[1], l("sample_meeting_p2_body"), 560f, 90f)

        // 第 3 頁：決議 + 流程圖
        title(session, pages[2], l("sample_meeting_p3_title"), 72f)
        TableStore(session, pages[2]).create(table(l("sample_meeting_todo_table"), 136f))
        body(session, pages[2], l("sample_meeting_p3_body"), 380f, 70f)
        val shapes2 = ShapeStore(session, pages[2])
        shapes2.create(
            NoteShape(
                kindName = "terminator", x = MARGIN, y = 480f, width = 170f, height = 62f,
                cornerRadius = 26f, label = l("sample_meeting_flow_start"),
                strokeColorHex = "#0E7C53", fillColorHex = "#E4F3EC", lineWidth = 1.5f
            )
        )
        shapes2.create(
            NoteShape(
                kindName = "decision", x = MARGIN + 230f, y = 466f, width = 180f, height = 90f,
                cornerRadius = 0f, label = l("sample_meeting_flow_decide"),
                strokeColorHex = "#1F4FD8", fillColorHex = "#E9EEFC", lineWidth = 1.5f
            )
        )
        shapes2.create(
            NoteShape(
                kindName = "process", x = MARGIN + 440f, y = 480f, width = 180f, height = 62f,
                cornerRadius = 8f, label = l("sample_meeting_flow_end"),
                strokeColorHex = "#1F4FD8", fillColorHex = "#FFFFFF", lineWidth = 1.5f
            )
        )
        return true
    }

    // MARK: - 共用建構子

    private fun title(session: PadnoteSession, pageId: String, text: String, y: Float) {
        val store = TextBoxStore(session, pageId)
        val box = store.create(MARGIN, y)
        box.text = text
        box.fontSize = 26f
        box.bold = true
        box.width = CONTENT_WIDTH
        box.height = 46f
        box.textColorHex = "#141A22"
        box.backgroundColorHex = "clear"
        box.hasBorder = false
        box.cornerRadius = 0f
        store.persist(box)
    }

    private fun body(
        session: PadnoteSession, pageId: String, text: String, y: Float, height: Float
    ) {
        val store = TextBoxStore(session, pageId)
        val box = store.create(MARGIN, y)
        box.text = text
        box.fontSize = 15f
        box.width = CONTENT_WIDTH
        box.height = height
        box.textColorHex = "#26303C"
        box.backgroundColorHex = "clear"
        box.hasBorder = false
        box.cornerRadius = 0f
        box.lineSpacing = 5f
        box.paragraphSpacing = 6f
        store.persist(box)
    }

    private fun pill(label: String, x: Float, y: Float, fill: String) = NoteShape(
        kindName = "roundedrectangle", x = x, y = y, width = 150f, height = 46f,
        cornerRadius = 23f, label = label,
        strokeColorHex = "#1F4FD8", fillColorHex = fill, lineWidth = 1.5f
    )

    private fun table(raw: String, y: Float): NoteTable {
        val parsed = parseTable(raw)
        return NoteTable(
            x = MARGIN, y = y, width = CONTENT_WIDTH,
            rows = parsed.rows, cols = parsed.cols,
            cells = parsed.cells.toMutableList(),
            headerRow = true, fontSize = 14f, headerBackgroundHex = "#E9EEFC"
        )
    }

    /**
     * 把 `a|b\nc|d` 解析成逐列展開的表格內容。
     *
     * 一張 3×5 的表若在 catalog 裡拆成 15 條字串，譯者看不到上下文，
     * 而且新增一列要改六個語系的鍵名。所以整張表是一條字串 ——
     * 與 Apple 的 `SeedContent.parseTable` 同一個格式與同一份字串。
     *
     * 短列補空字串而不是丟掉：`cells` 的長度必須剛好是 `rows * cols`。
     */
    data class ParsedTable(val rows: Int, val cols: Int, val cells: List<String>)

    fun parseTable(raw: String): ParsedTable {
        val lines = raw.split("\n").map { it.split("|") }
        if (lines.isEmpty()) return ParsedTable(1, 1, listOf(""))
        val cols = lines.maxOf { it.size }
        val cells = mutableListOf<String>()
        for (line in lines) {
            for (column in 0 until cols) cells += line.getOrElse(column) { "" }
        }
        return ParsedTable(lines.size, cols, cells)
    }

    private fun splitList(raw: String): List<String> =
        raw.split("|").filter { it.isNotEmpty() }

    /** 補足空白頁，回傳前 [count] 頁的 id。 */
    // MARK: - 《Kairumo手冊》：全部用手繪筆畫完成
    //
    // 沒有任何文字方塊或形狀物件：標題是逐字手寫、插圖是一筆一筆畫的。筆畫來自
    // `assets/seed/kairumo-manual-ink.json`（Apple 讀同一份），所以兩個平台畫出來是同一本。

    private fun buildKairumoManual(context: Context, deviceId: UInt): Boolean {
        val root = runCatching {
            org.json.JSONObject(context.assets.open("seed/kairumo-manual-ink.json").bufferedReader().use { it.readText() })
        }.getOrNull() ?: return false
        val pagesJson = root.optJSONArray("pages") ?: return false

        val id = NotebookLibrary.create(context, MANUAL_TITLE, deviceId, id = MANUAL_ID) ?: return false
        val (session, firstPage) = NotebookLibrary.open(context, id, deviceId) ?: return false
        val pages = ensurePages(session, firstPage, maxOf(2, pagesJson.length()))

        for (index in 0 until pagesJson.length()) {
            val strokes = pagesJson.getJSONObject(index).optJSONArray("strokes") ?: continue
            for (k in 0 until strokes.length()) {
                val s = strokes.getJSONObject(k)
                val pts = s.getJSONArray("points")
                if (pts.length() < 2) continue
                val hex = s.getString("color").removePrefix("#")
                val rgba = byteArrayOf(
                    hex.substring(0, 2).toInt(16).toByte(), hex.substring(2, 4).toInt(16).toByte(),
                    hex.substring(4, 6).toInt(16).toByte(), -1
                )
                val n = pts.length()
                val points = (0 until n).map { i ->
                    val xy = pts.getJSONArray(i)
                    // 起筆與收筆輕、中段重 —— 手寫的筆壓，不是等粗的線。
                    val edge = minOf(i, n - 1 - i).coerceAtMost(7) / 4f
                    uniffi.padnote_core.StrokePoint(
                        x = xy.getDouble(0).toFloat(), y = xy.getDouble(1).toFloat(),
                        pressure = 0.55f + 0.3f * minOf(1f, edge), tilt = 0.2f, azimuth = 0f,
                        dtUs = (i * 12_000).toUInt()
                    )
                }
                runCatching {
                    session.addStroke(
                        pages[index], uniffi.padnote_core.ToolKind.FOUNTAIN_PEN, rgba,
                        s.getDouble("width").toFloat(), points
                    )
                }.onFailure { android.util.Log.w("KairumoManual", "stroke $index/$k: $it") }
            }
        }
        return true
    }

    private fun ensurePages(session: PadnoteSession, firstPage: String, count: Int): List<String> {
        val ids = mutableListOf(firstPage)
        while (ids.size < count) {
            val next = runCatching { session.addPage(PageStyle.BLANK) }.getOrNull() ?: break
            ids += next
        }
        return ids
    }
}
