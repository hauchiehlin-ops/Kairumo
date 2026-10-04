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
        if (buildFeaturedBiology(context, deviceId, ::l)) created++
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
    private const val WELCOME_ID = "seed-welcome-notebook-v1"
    private const val MEETING_ID = "seed-meeting-notebook-v1"
    private const val FEATURED_ID = "seed-featured-biology-v1"

    // MARK: - 精選範例筆記：《Kairumo（精選實例）》

    private fun buildFeaturedBiology(context: Context, deviceId: UInt, l: (String) -> String): Boolean {
        val id = NotebookLibrary.create(
            context, l("seed_featured_biology_title"), deviceId, id = FEATURED_ID
        ) ?: return false
        val opened = NotebookLibrary.open(context, id, deviceId) ?: return false
        val (session, firstPage) = opened
        val pages = ensurePages(session, firstPage, 2)

        // 設定為方格點陣 (grid) 樣板
        val meta = NotebookMeta.load(session)
        meta.setPaperId(session, "grid")

        // =========================================================================
        // 【第一頁：循環系統與氣體運輸】
        // =========================================================================

        // 1. 大標題
        title(session, pages[0], "生物學重點筆記：人體循環系統與氣體運輸機制", 40f)

        // 2. 門脈循環區塊
        val shapes0 = ShapeStore(session, pages[0])
        val portalShape = NoteShape(
            kindName = "rectangle", x = MARGIN, y = 85f, width = 250f, height = 140f,
            cornerRadius = 6f, label = "【肝門靜脈循環】\n消化道微血管 → 肝門靜脈\n→ 肝臟微血管竇 → 肝靜脈",
            strokeColorHex = "#D98880", fillColorHex = "#FDEDEC", lineWidth = 1.5f
        )
        shapes0.create(portalShape)

        val textStore0 = TextBoxStore(session, pages[0])
        val portalText = textStore0.create(MARGIN + 265f, 85f)
        portalText.width = CONTENT_WIDTH - 265f
        portalText.height = 140f
        portalText.text = "腸靜脈 → 肝門靜脈\n  ↓ (養分儲存 / 肝臟解毒)\n肝微血管 → 肝靜脈 → 下腔靜脈 → 右心房"
        portalText.fontSize = 13f
        portalText.textColorHex = "#2C3E50"
        portalText.backgroundColorHex = "#FADBD8"
        portalText.hasBorder = true
        portalText.borderColorHex = "#E6B0AA"
        portalText.borderWidth = 1.0f
        portalText.cornerRadius = 6f
        portalText.lineSpacing = 4f
        textStore0.persist(portalText)

        // 3. 淋巴循環區塊
        val lymphShape = NoteShape(
            kindName = "rectangle", x = MARGIN, y = 240f, width = CONTENT_WIDTH, height = 180f,
            cornerRadius = 8f, label = "",
            strokeColorHex = "#52BE80", fillColorHex = "#EAFAF1", lineWidth = 1.5f
        )
        shapes0.create(lymphShape)

        val lymphHeader = textStore0.create(MARGIN + 15f, 250f)
        lymphHeader.width = CONTENT_WIDTH - 30f
        lymphHeader.height = 60f
        lymphHeader.text = "【淋巴循環路徑 (Lymphatic Circulation)】\n組織微淋巴管 → 小淋巴管 → 大淋巴管 → 胸導管 / 右淋巴總管\n→ 左右鎖骨下靜脈 → 上腔靜脈 → 右心房注入血液循環"
        lymphHeader.fontSize = 14f
        lymphHeader.textColorHex = "#1E8449"
        lymphHeader.backgroundColorHex = "clear"
        lymphHeader.hasBorder = false
        lymphHeader.lineSpacing = 4f
        textStore0.persist(lymphHeader)

        val lymphBody = textStore0.create(MARGIN + 15f, 315f)
        lymphBody.width = 440f
        lymphBody.height = 95f
        lymphBody.text = "★ 淋巴系統生理功能：\n1. 體液回收：回收組織液多餘水分，維持恆定血容量\n2. 運送養分：乳糜管吸收脂溶性養分 (維生素 A, D, E, K)\n3. 免疫防禦：運送病原體進入淋巴結，活化 B/T 淋巴球進行濾清"
        lymphBody.fontSize = 13f
        lymphBody.textColorHex = "#273746"
        lymphBody.backgroundColorHex = "#D5F5E3"
        lymphBody.hasBorder = true
        lymphBody.borderColorHex = "#A9DFBF"
        lymphBody.borderWidth = 1.0f
        lymphBody.cornerRadius = 6f
        lymphBody.lineSpacing = 3f
        textStore0.persist(lymphBody)

        val catBox = textStore0.create(MARGIN + 465f, 315f)
        catBox.width = CONTENT_WIDTH - 480f
        catBox.height = 95f
        catBox.text = "  /\\_/\\\n ( o.o )\n  > ^ <\n(吸收好脂肪~)"
        catBox.fontSize = 12f
        catBox.textColorHex = "#2C3E50"
        catBox.backgroundColorHex = "#FCF3CF"
        catBox.hasBorder = true
        catBox.borderColorHex = "#F9E79F"
        catBox.borderWidth = 1.0f
        catBox.cornerRadius = 8f
        catBox.alignment = "center"
        textStore0.persist(catBox)

        // 4. 氣體運輸機制
        val gasShape = NoteShape(
            kindName = "rectangle", x = MARGIN, y = 435f, width = CONTENT_WIDTH, height = 250f,
            cornerRadius = 8f, label = "",
            strokeColorHex = "#85929E", fillColorHex = "#F2F4F4", lineWidth = 1.5f
        )
        shapes0.create(gasShape)

        val o2Box = textStore0.create(MARGIN + 15f, 478f)
        o2Box.width = CONTENT_WIDTH - 30f
        o2Box.height = 75f
        o2Box.text = "1. 氧氣 (O₂) 運輸：\n   • 98% 與血紅素結合： Hb + O₂ ⇄ HbO₂ (氧合血紅素)\n     [肺泡氧分壓高，向右反應；組織氧分壓低，向左釋放]\n   • 2% 物理溶解於血漿中"
        o2Box.fontSize = 13f
        o2Box.textColorHex = "#1B4F72"
        o2Box.backgroundColorHex = "#EBF5FB"
        o2Box.hasBorder = true
        o2Box.borderColorHex = "#AED6F1"
        o2Box.borderWidth = 1.0f
        o2Box.cornerRadius = 6f
        o2Box.lineSpacing = 3f
        textStore0.persist(o2Box)

        val co2Box = textStore0.create(MARGIN + 15f, 560f)
        co2Box.width = CONTENT_WIDTH - 30f
        co2Box.height = 85f
        co2Box.text = "2. 二氧化碳 (CO₂) 運輸：\n   • 70% 碳酸氫根 (HCO₃⁻)： CO₂ + H₂O ⇄ H₂CO₃ ⇄ HCO₃⁻ + H⁺ (紅血球碳酸酐酶催化)\n   • 23% 與血紅素結合： Hb + CO₂ ⇄ HbCO₂ (氨基甲酸血紅素)\n   • 7%  物理溶解於血漿中"
        co2Box.fontSize = 13f
        co2Box.textColorHex = "#641E16"
        co2Box.backgroundColorHex = "#FADBD8"
        co2Box.hasBorder = true
        co2Box.borderColorHex = "#F5B7B1"
        co2Box.borderWidth = 1.0f
        co2Box.cornerRadius = 6f
        co2Box.lineSpacing = 3f
        textStore0.persist(co2Box)

        // 5. 第一頁背誦考點膠帶
        val page0Tapes = listOf(
            com.kairumo.padnote.canvas.NoteTape(
                pageIndex = 0, x = MARGIN + 275f, y = 190f, width = 200f, height = 28f,
                isRevealed = false, colorHex = "#FFD1DC"
            ),
            com.kairumo.padnote.canvas.NoteTape(
                pageIndex = 0, x = MARGIN + 35f, y = 580f, width = 140f, height = 24f,
                isRevealed = false, colorHex = "#FCEEAC"
            ),
            com.kairumo.padnote.canvas.NoteTape(
                pageIndex = 0, x = MARGIN + 35f, y = 605f, width = 140f, height = 24f,
                isRevealed = false, colorHex = "#C8E6C9"
            )
        )

        // =========================================================================
        // 【第二頁：泌尿系統與腎臟解剖】
        // =========================================================================

        title(session, pages[1], "泌尿生理學：腎單元構造與尿液形成機制", 40f)

        val shapes1 = ShapeStore(session, pages[1])
        val nephronShape = NoteShape(
            kindName = "rectangle", x = MARGIN, y = 85f, width = 320f, height = 250f,
            cornerRadius = 8f, label = "",
            strokeColorHex = "#B7950B", fillColorHex = "#FEF9E7", lineWidth = 1.5f
        )
        shapes1.create(nephronShape)

        val textStore1 = TextBoxStore(session, pages[1])
        val nephronText = textStore1.create(MARGIN + 12f, 95f)
        nephronText.width = 300f
        nephronText.height = 230f
        nephronText.text = "【腎單元解剖層次 (The Nephron)】\n• 腎臟巨觀：皮質 (Cortex) + 髓質 (Medulla) + 腎盂\n• 腎小體 (Renal Corpuscle)：\n   - 入球小動脈 (管徑大) → 腎絲球 (微血管團)\n   - 鮑氏囊 (雙層杯狀構造，承接濾液)\n   - 出球小動脈 (管徑小，形成高壓過濾)\n• 腎小管 (Renal Tubule)：\n   - 近曲小管 → 亨利氏環 (U型) → 遠曲小管\n   - 匯入集尿管 (Collecting Duct) → 腎乳頭"
        nephronText.fontSize = 13f
        nephronText.textColorHex = "#4D5656"
        nephronText.backgroundColorHex = "clear"
        nephronText.hasBorder = false
        nephronText.lineSpacing = 4f
        textStore1.persist(nephronText)

        val funcShape = NoteShape(
            kindName = "rectangle", x = MARGIN + 335f, y = 85f, width = CONTENT_WIDTH - 335f, height = 250f,
            cornerRadius = 8f, label = "",
            strokeColorHex = "#2E86C1", fillColorHex = "#EBF5FB", lineWidth = 1.5f
        )
        shapes1.create(funcShape)

        val funcText = textStore1.create(MARGIN + 347f, 95f)
        funcText.width = CONTENT_WIDTH - 360f
        funcText.height = 230f
        funcText.text = "【腎臟生理功能清單】\n1. 形成尿液，排出含氮廢物 (尿素、尿酸、肌酸酐)\n2. 調控體液滲透壓與水分恆定 (受抗利尿激素 ADH 調控)\n3. 酸鹼平衡調節 (保留 HCO₃⁻，主動分泌 H⁺/NH₄⁺)\n4. 維持血壓恆定 (分泌腎素 Renin 啟動 RAAS 系統)\n5. 分泌紅血球生成素 (EPO，刺激骨髓造血)"
        funcText.fontSize = 13f
        funcText.textColorHex = "#1B4F72"
        funcText.backgroundColorHex = "clear"
        funcText.hasBorder = false
        funcText.lineSpacing = 6f
        textStore1.persist(funcText)

        // 原生表格：生理作用比較
        val table1 = table(l("sample_bio_tools_table"), 385f)
        TableStore(session, pages[1]).create(table1)

        val summaryText = textStore1.create(MARGIN, 560f)
        summaryText.width = CONTENT_WIDTH
        summaryText.height = 55f
        summaryText.text = "★ 考題速記口訣：\n『過濾不選大（無血球、大蛋白），再吸收要主動（葡萄糖全收，水跟著走），分泌作用排廢物（氫離子藥物走）』"
        summaryText.fontSize = 13f
        summaryText.textColorHex = "#922B21"
        summaryText.backgroundColorHex = "#FADBD8"
        summaryText.hasBorder = true
        summaryText.borderColorHex = "#E6B0AA"
        summaryText.borderWidth = 1.0f
        summaryText.cornerRadius = 6f
        summaryText.lineSpacing = 4f
        textStore1.persist(summaryText)

        // 第二頁考點膠帶
        val page1Tapes = listOf(
            com.kairumo.padnote.canvas.NoteTape(
                pageIndex = 1, x = MARGIN + 347f, y = 145f, width = 180f, height = 26f,
                isRevealed = false, colorHex = "#BBDEFB"
            )
        )

        // 寫入膠帶至中繼資料與持久化
        meta.setTapes(session, page0Tapes + page1Tapes)
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
