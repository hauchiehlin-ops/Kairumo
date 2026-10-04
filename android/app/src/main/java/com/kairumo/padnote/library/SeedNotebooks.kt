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
        val pages = ensurePages(session, firstPage, 2)

        // 設定為方格點陣 (grid) 樣板
        val meta = NotebookMeta.load(session)
        meta.setPaperId(session, "grid")

        // =========================================================================
        // 【第一頁：手繪（鉛筆／鋼筆／毛筆）＋ 打字（主流應用優缺點比較表）】
        // =========================================================================

        // 1. 頁面大標題與副標（打字）
        title(session, pages[0], l("sample_showcase_p1_title"), 38f)

        val textStore0 = TextBoxStore(session, pages[0])
        val subBox = textStore0.create(MARGIN, 84f)
        subBox.width = CONTENT_WIDTH
        subBox.height = 32f
        subBox.text = l("sample_showcase_p1_subtitle")
        subBox.fontSize = 13f
        subBox.bold = true
        subBox.textColorHex = "#2B6CB0"
        subBox.backgroundColorHex = "#EBF8FF"
        subBox.hasBorder = true
        subBox.borderColorHex = "#BEE3F8"
        subBox.borderWidth = 1.0f
        subBox.cornerRadius = 6f
        textStore0.persist(subBox)

        val noteBox = textStore0.create(MARGIN, 124f)
        noteBox.width = CONTENT_WIDTH
        noteBox.height = 52f
        noteBox.text = l("sample_showcase_handwriting_note")
        noteBox.fontSize = 12f
        noteBox.textColorHex = "#2D3748"
        noteBox.backgroundColorHex = "#F7FAFC"
        noteBox.hasBorder = true
        noteBox.borderColorHex = "#E2E8F0"
        noteBox.borderWidth = 1.0f
        noteBox.cornerRadius = 8f
        noteBox.lineSpacing = 3f
        textStore0.persist(noteBox)

        // 2. 「手繪」：分別用鉛筆、鋼筆、毛筆表列真實手寫筆劃 (addStroke)
        // 鉛筆 (Pencil)：灰色系顆粒感
        val pencilColor = byteArrayOf(70, 80, 95, -1) // #46505F
        val pPoints1 = (0..20).map { i ->
            uniffi.padnote_core.StrokePoint(
                x = MARGIN + 20f + i * 14f,
                y = 205f + kotlin.math.sin(i * 0.5f) * 2f,
                pressure = 0.5f, tilt = 0.2f, azimuth = 0f, dtUs = (i * 10_000).toUInt()
            )
        }
        session.addStroke(pages[0], uniffi.padnote_core.ToolKind.PENCIL, pencilColor, 2.2f, pPoints1)

        val pPoints2 = (0..35).map { i ->
            uniffi.padnote_core.StrokePoint(
                x = MARGIN + 30f + i * 12f,
                y = 235f + kotlin.math.sin(i * 0.7f) * 1.5f,
                pressure = 0.55f, tilt = 0.2f, azimuth = 0f, dtUs = (i * 8_000).toUInt()
            )
        }
        session.addStroke(pages[0], uniffi.padnote_core.ToolKind.PENCIL, pencilColor, 1.9f, pPoints2)

        // 鋼筆 (Fountain Pen)：藍色流暢壓感
        val penColor = byteArrayOf(30, 80, 215.toByte(), -1) // #1E50D7
        val penPoints1 = (0..22).map { i ->
            val press = 0.4f + kotlin.math.sin(i * 0.3f) * 0.5f
            uniffi.padnote_core.StrokePoint(
                x = MARGIN + 20f + i * 15f,
                y = 280f + kotlin.math.cos(i * 0.4f) * 2.5f,
                pressure = press, tilt = 0.1f, azimuth = 0f, dtUs = (i * 9_000).toUInt()
            )
        }
        session.addStroke(pages[0], uniffi.padnote_core.ToolKind.FOUNTAIN_PEN, penColor, 3.2f, penPoints1)

        val penPoints2 = (0..38).map { i ->
            val press = 0.5f + kotlin.math.sin(i * 0.5f) * 0.4f
            uniffi.padnote_core.StrokePoint(
                x = MARGIN + 30f + i * 12f,
                y = 310f + kotlin.math.sin(i * 0.6f) * 2f,
                pressure = press, tilt = 0.1f, azimuth = 0f, dtUs = (i * 7_000).toUInt()
            )
        }
        session.addStroke(pages[0], uniffi.padnote_core.ToolKind.FOUNTAIN_PEN, penColor, 2.6f, penPoints2)

        // 毛筆 (Calligraphy / Brush)：深紅濃墨大幅提按起伏
        val brushColor = byteArrayOf(140.toByte(), 30, 30, -1) // #8C1E1E
        val brushPoints1 = (0..24).map { i ->
            val press = 0.3f + kotlin.math.sin(i * 0.25f) * 0.7f
            uniffi.padnote_core.StrokePoint(
                x = MARGIN + 20f + i * 16f,
                y = 355f + kotlin.math.sin(i * 0.3f) * 4f,
                pressure = press, tilt = 0.3f, azimuth = 0f, dtUs = (i * 12_000).toUInt()
            )
        }
        session.addStroke(pages[0], uniffi.padnote_core.ToolKind.CALLIGRAPHY, brushColor, 5.5f, brushPoints1)

        val brushPoints2 = (0..36).map { i ->
            val press = 0.35f + kotlin.math.sin(i * 0.35f) * 0.65f
            uniffi.padnote_core.StrokePoint(
                x = MARGIN + 30f + i * 13f,
                y = 385f + kotlin.math.cos(i * 0.4f) * 3f,
                pressure = press, tilt = 0.3f, azimuth = 0f, dtUs = (i * 10_000).toUInt()
            )
        }
        session.addStroke(pages[0], uniffi.padnote_core.ToolKind.CALLIGRAPHY, brushColor, 4.2f, brushPoints2)

        // 3. 「打字」：市面前 3 大主流應用對比表格
        val tblTitle = textStore0.create(MARGIN, 405f)
        tblTitle.width = CONTENT_WIDTH
        tblTitle.height = 28f
        tblTitle.text = l("sample_showcase_table_title")
        tblTitle.fontSize = 15f
        tblTitle.bold = true
        tblTitle.textColorHex = "#1A365D"
        tblTitle.backgroundColorHex = "clear"
        tblTitle.hasBorder = false
        textStore0.persist(tblTitle)

        val tableStore0 = TableStore(session, pages[0])
        val parsedMatrix = parseTable(l("sample_showcase_comparison_table"))
        val matrixTable = NoteTable(
            x = MARGIN, y = 438f, width = CONTENT_WIDTH,
            rows = parsedMatrix.rows, cols = parsedMatrix.cols,
            cells = parsedMatrix.cells.toMutableList(),
            headerRow = true, fontSize = 11f, headerBackgroundHex = "#EBF8FF"
        )
        tableStore0.create(matrixTable)

        // 底部亮點膠囊
        val shapes0 = ShapeStore(session, pages[0])
        shapes0.create(pill("100% 開源無廣告", MARGIN, 825f, "#EBF8FF"))
        shapes0.create(pill("超低延遲向量筆跡", MARGIN + 175f, 825f, "#F0FFF4"))
        shapes0.create(pill("微積分公式深度融合", MARGIN + 350f, 825f, "#FAF5FF"))
        shapes0.create(pill("數字製圖＋討論圖釘", MARGIN + 525f, 825f, "#FFFAF0"))

        // =========================================================================
        // 【第二頁：手繪＋打字融合微積分方程 ＆ 數字製圖＋討論圖釘用法】
        // =========================================================================

        title(session, pages[1], l("sample_showcase_p2_title"), 38f)

        // 1. 微積分方程融合：打字解析卡片
        val shapes1 = ShapeStore(session, pages[1])
        shapes1.create(
            NoteShape(
                kindName = "rectangle", x = MARGIN, y = 84f, width = CONTENT_WIDTH, height = 250f,
                cornerRadius = 10f, label = "",
                strokeColorHex = "#9F7AEA", fillColorHex = "#FAF5FF", lineWidth = 1.5f
            )
        )

        val textStore1 = TextBoxStore(session, pages[1])
        val calcTitle = textStore1.create(MARGIN + 16f, 94f)
        calcTitle.width = CONTENT_WIDTH - 32f
        calcTitle.height = 24f
        calcTitle.text = l("sample_showcase_calc_typed_title")
        calcTitle.fontSize = 14f
        calcTitle.bold = true
        calcTitle.textColorHex = "#553C9A"
        calcTitle.backgroundColorHex = "clear"
        calcTitle.hasBorder = false
        textStore1.persist(calcTitle)

        val calcDesc = textStore1.create(MARGIN + 16f, 122f)
        calcDesc.width = 320f
        calcDesc.height = 195f
        calcDesc.text = l("sample_showcase_calc_typed_desc")
        calcDesc.fontSize = 11f
        calcDesc.textColorHex = "#4A5568"
        calcDesc.backgroundColorHex = "#FFFFFF"
        calcDesc.hasBorder = true
        calcDesc.borderColorHex = "#E9D8FD"
        calcDesc.borderWidth = 1.0f
        calcDesc.cornerRadius = 6f
        calcDesc.lineSpacing = 3f
        textStore1.persist(calcDesc)

        // 微積分手繪算式筆劃 (∫ x sin(x) dx = π, 分部積分推導與圈選)
        val mathInkColor = byteArrayOf(38, 50, 90, -1)
        val mathPoints1 = (0..20).map { i ->
            uniffi.padnote_core.StrokePoint(
                x = MARGIN + 360f + i * 16f,
                y = 145f + kotlin.math.sin(i * 0.4f) * 3f,
                pressure = 0.6f, tilt = 0.2f, azimuth = 0f, dtUs = (i * 10_000).toUInt()
            )
        }
        session.addStroke(pages[1], uniffi.padnote_core.ToolKind.FOUNTAIN_PEN, mathInkColor, 3.0f, mathPoints1)

        val mathPoints2 = (0..24).map { i ->
            uniffi.padnote_core.StrokePoint(
                x = MARGIN + 360f + i * 14f,
                y = 195f + kotlin.math.cos(i * 0.4f) * 2f,
                pressure = 0.65f, tilt = 0.2f, azimuth = 0f, dtUs = (i * 9_000).toUInt()
            )
        }
        session.addStroke(pages[1], uniffi.padnote_core.ToolKind.FOUNTAIN_PEN, mathInkColor, 2.5f, mathPoints2)

        // 紅色圓圈重點圈選
        val redCircleColor = byteArrayOf(215.toByte(), 45, 45, -1)
        val circlePoints = (0..24).map { i ->
            val angle = (i / 24f) * kotlin.math.PI.toFloat() * 2f
            uniffi.padnote_core.StrokePoint(
                x = MARGIN + 520f + kotlin.math.cos(angle) * 22f,
                y = 265f + kotlin.math.sin(angle) * 22f,
                pressure = 0.7f, tilt = 0.2f, azimuth = 0f, dtUs = (i * 8_000).toUInt()
            )
        }
        session.addStroke(pages[1], uniffi.padnote_core.ToolKind.FOUNTAIN_PEN, redCircleColor, 3.2f, circlePoints)

        // 2. 數字製圖（Chart Studio）與討論圖釘（Comment Pins）
        shapes1.create(
            NoteShape(
                kindName = "rectangle", x = MARGIN, y = 350f, width = CONTENT_WIDTH, height = 485f,
                cornerRadius = 10f, label = "",
                strokeColorHex = "#3182CE", fillColorHex = "#F7FAFC", lineWidth = 1.5f
            )
        )

        val chartTitle = textStore1.create(MARGIN + 16f, 360f)
        chartTitle.width = CONTENT_WIDTH - 32f
        chartTitle.height = 24f
        chartTitle.text = l("sample_showcase_chart_typed_title")
        chartTitle.fontSize = 14f
        chartTitle.bold = true
        chartTitle.textColorHex = "#2B6CB0"
        chartTitle.backgroundColorHex = "clear"
        chartTitle.hasBorder = false
        textStore1.persist(chartTitle)

        val chartDesc = textStore1.create(MARGIN + 16f, 390f)
        chartDesc.width = CONTENT_WIDTH - 32f
        chartDesc.height = 80f
        chartDesc.text = l("sample_showcase_chart_typed_desc")
        chartDesc.fontSize = 11f
        chartDesc.textColorHex = "#2D3748"
        chartDesc.backgroundColorHex = "#EDF2F7"
        chartDesc.hasBorder = true
        chartDesc.borderColorHex = "#CBD5E0"
        chartDesc.borderWidth = 1.0f
        chartDesc.cornerRadius = 6f
        chartDesc.lineSpacing = 3f
        textStore1.persist(chartDesc)

        // 插入動態可編輯長條圖
        val chartSpec = ChartSpec(
            title = "2026 手寫繪圖效能與自由度指標對比 (滿分 100)",
            categories = mutableListOf("向量書寫延遲", "圖表動態可編修", "空間圖釘協作", "開源與無訂閱限制"),
            series = mutableListOf(
                ChartSeries(
                    name = "Kairumo (Padnote)",
                    values = mutableListOf(98.0, 95.0, 96.0, 100.0),
                    colorHex = "#3182CE"
                ),
                ChartSeries(
                    name = "商業付費競品平均",
                    values = mutableListOf(74.0, 52.0, 45.0, 38.0),
                    colorHex = "#CBD5E0"
                )
            )
        )
        ChartStore(session, pages[1]).create(chartSpec, x = MARGIN + 20f, y = 480f)

        // 插入討論圖釘（CommentPin）
        val pin1 = com.kairumo.padnote.comment.CommentPin(
            id = "seed-pin-showcase-chart-q3",
            pageIndex = 1,
            x = MARGIN + 415f,
            y = 535f,
            authorId = "kairumo-reviewer",
            authorName = "Kairumo Architect",
            authorColor = "#3182CE",
            createdAt = java.util.Date(System.currentTimeMillis() - 7200_000L),
            isResolved = false,
            messages = mutableListOf(
                com.kairumo.padnote.comment.CommentMessage(
                    id = "msg-q3-surge",
                    authorId = "kairumo-reviewer",
                    authorName = "Kairumo Architect",
                    authorColor = "#3182CE",
                    text = l("sample_showcase_pin1_msg"),
                    createdAt = java.util.Date(System.currentTimeMillis() - 7200_000L)
                )
            )
        )

        val pin2 = com.kairumo.padnote.comment.CommentPin(
            id = "seed-pin-showcase-math-bound",
            pageIndex = 1,
            x = MARGIN + 630f,
            y = 205f,
            authorId = "math-evaluator",
            authorName = "Prof. Euler",
            authorColor = "#805AD5",
            createdAt = java.util.Date(System.currentTimeMillis() - 3600_000L),
            isResolved = false,
            messages = mutableListOf(
                com.kairumo.padnote.comment.CommentMessage(
                    id = "msg-euler-bound",
                    authorId = "math-evaluator",
                    authorName = "Prof. Euler",
                    authorColor = "#805AD5",
                    text = l("sample_showcase_pin2_msg"),
                    createdAt = java.util.Date(System.currentTimeMillis() - 3600_000L)
                )
            )
        )
        meta.setCommentPins(session, listOf(pin1, pin2))

        return true
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
    private fun ensurePages(session: PadnoteSession, firstPage: String, count: Int): List<String> {
        val ids = mutableListOf(firstPage)
        while (ids.size < count) {
            val next = runCatching { session.addPage(PageStyle.BLANK) }.getOrNull() ?: break
            ids += next
        }
        return ids
    }
}
