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
     * 筆記庫空的時候建立兩本範例筆記。已經有東西就什麼也不做 ——
     * 每次啟動都塞兩本進去的話，使用者刪掉之後它們會自己長回來。
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
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
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

    // MARK: - 歡迎使用 Kairumo

    private fun buildWelcome(context: Context, deviceId: UInt, l: (String) -> String): Boolean {
        val id = NotebookLibrary.create(context, l("seed_welcome_title"), deviceId) ?: return false
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
        val id = NotebookLibrary.create(context, l("seed_meeting_title"), deviceId) ?: return false
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
