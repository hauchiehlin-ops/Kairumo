package com.kairumo.padnote.library

import android.content.Context
import com.kairumo.padnote.table.NoteTable
import com.kairumo.padnote.table.TableStore
import com.kairumo.padnote.text.TextBoxStore
import org.json.JSONObject
import uniffi.padnote_core.PadnoteSession

/**
 * 文件範本目錄（工作項 S-61）。
 *
 * # 內容為什麼不寫在這個檔案裡
 *
 * 39 種文件、每種兩個版本 = 78 份。Swift 與 Kotlin 各手寫一份的話，兩邊必然
 * 漂移，而症狀是「同一份契約範本在 iPad 與 Android 上長得不一樣」。
 *
 * 所以內容寫在 `templates/src/` 底下的 JSON，版面由 `scripts/doc_templates_tool.py`
 * **算好之後**輸出成一份 `document-templates.json`，Gradle 在建置時複製進
 * assets。兩個平台載入同一份檔案，座標只算一次。
 *
 * # 與 Apple 端的對應
 *
 * `apple/Sources/DocumentTemplateCatalog.swift` 是同一組模型、同一份資料。
 * 改這裡之前先確認那邊要不要一起改。
 */
object DocumentTemplateCatalog {

    private const val ASSET = "templates/document-templates.json"

    data class Theme(
        val id: String,
        /**
         * `"document"`（文件範本）或 `"paper"`（紙張樣板）。
         *
         * 兩者的資料與排版完全一樣，差別只在介面上掛在哪裡：文件範本在
         * 收合的樹裡，紙張樣板掛在紙張清單底下。用 id 去猜的話，那張
         * 對照表遲早會跟 `templates/src/` 分岔。
         */
        val kind: String,
        val icon: String,
        val name: Map<String, String>,
        val categories: List<Category>
    )

    data class Category(
        val id: String,
        val name: Map<String, String>,
        val templates: List<Template>
    )

    data class Template(
        val id: String,
        val name: Map<String, String>,
        val description: Map<String, String>,
        val pageStyle: String,
        /** `example` / `blank` → 語言 → 內容。 */
        val variants: Map<String, Map<String, Variant>>
    )

    data class Variant(val pageCount: Int, val blocks: List<Block>)

    data class Block(
        val kind: String,
        val page: Int,
        val x: Float,
        val y: Float,
        val width: Float,
        val height: Float,
        val text: String,
        val fontSize: Float,
        val bold: Boolean,
        val lineSpacing: Float,
        val rows: Int,
        val cols: Int,
        val cells: List<String>,
        val headerRow: Boolean
    )

    /** 完整案例 / 空白範本。 */
    enum class VariantKind(val key: String, val labelKey: String) {
        EXAMPLE("example", "doc_variant_example"),
        BLANK("blank", "doc_variant_blank")
    }

    @Volatile
    private var cached: List<Theme>? = null

    /**
     * 讀目錄。讀不到回空清單 —— 範本是加分功能，不該讓首頁開不起來。
     */
    fun themes(context: Context): List<Theme> {
        cached?.let { return it }
        val parsed = runCatching {
            val raw = context.assets.open(ASSET).bufferedReader().use { it.readText() }
            parse(JSONObject(raw))
        }.getOrDefault(emptyList())
        cached = parsed
        return parsed
    }

    /** 文件範本（簽、契約、會議紀錄…）。收合的那棵樹用這一份。 */
    fun documentThemes(context: Context): List<Theme> =
        themes(context).filter { it.kind != "paper" }

    /** 紙張樣板自己的示範內容。用紙張的 id 就查得到。 */
    fun paperTemplate(context: Context, paperId: String): Template? =
        themes(context).asSequence()
            .filter { it.kind == "paper" }
            .flatMap { it.categories.asSequence() }
            .flatMap { it.templates.asSequence() }
            .firstOrNull { it.id == paperId }

    fun template(context: Context, id: String): Template? =
        themes(context).asSequence()
            .flatMap { it.categories.asSequence() }
            .flatMap { it.templates.asSequence() }
            .firstOrNull { it.id == id }

    /**
     * 依介面語言取字。沒有那個語系就退回繁體中文。
     *
     * 退而不是留白：範本名稱空白的話，使用者看到的是一列空清單。
     */
    fun localized(table: Map<String, String>, lang: String): String =
        table[lang] ?: table["zhHant"] ?: table.values.firstOrNull() ?: ""

    /**
     * 取某個版本在某個語言下的內容。
     *
     * 文件**內文**只有繁體中文與英文（公文、契約、訴狀綁的是特定法域的格式，
     * 逐字翻成其他語言不會變成當地可用的文件），其餘語言退回繁體中文。
     */
    fun variant(template: Template, kind: VariantKind, lang: String): Variant? {
        val byLang = template.variants[kind.key] ?: return null
        return byLang[lang] ?: byLang["zhHant"] ?: byLang.values.firstOrNull()
    }

    /**
     * 把範本內容鋪進一本已經建好的筆記。
     *
     * 座標已經算好，這裡只把區塊轉成對應的物件。**不要在這裡重算版面** ——
     * 一重算，Apple 與 Android 就各有一套版面邏輯，兩邊會慢慢分岔。
     *
     * @return 是否有鋪進任何東西。
     */
    fun apply(
        session: PadnoteSession,
        firstPageId: String,
        template: Template,
        kind: VariantKind,
        lang: String
    ): Boolean {
        val variant = variant(template, kind, lang) ?: return false
        val pages = ensurePages(session, firstPageId, variant.pageCount, paperOf(template))
        if (pages.isEmpty()) return false

        for (block in variant.blocks) {
            val pageId = pages.getOrNull(block.page) ?: continue
            if (block.kind == "table") {
                TableStore(session, pageId).create(
                    NoteTable(
                        x = block.x, y = block.y, width = block.width,
                        rows = block.rows, cols = block.cols,
                        cells = block.cells.toMutableList(),
                        headerRow = block.headerRow,
                        fontSize = 13f,
                        headerBackgroundHex = HEADER_FILL
                    )
                )
            } else {
                val store = TextBoxStore(session, pageId)
                val box = store.create(block.x, block.y)
                box.text = block.text
                box.fontSize = block.fontSize
                box.bold = block.bold
                box.width = block.width
                box.height = block.height
                box.textColorHex = inkColor(block.kind)
                box.lineSpacing = block.lineSpacing
                box.paragraphSpacing = 6f
                // 免責提示是唯一有底框的區塊 —— 要一眼看出「這段不是文件本文」，
                // 否則使用者會把它當成契約條款的一部分印出去。
                val notice = block.kind == "notice"
                box.hasBorder = notice
                box.backgroundColorHex = if (notice) NOTICE_FILL else "clear"
                if (notice) {
                    box.borderColorHex = NOTICE_BORDER
                    box.cornerRadius = 8f
                }
                store.persist(box)
            }
        }
        return true
    }

    /**
     * 這份文件範本要鋪在哪一種紙上。
     *
     * `pageStyle` 一直在 JSON 裡、兩端也都解析了，卻**沒有人用它** ——
     * 於是紙張與文件各選各的，實機上出現過一份公文「簽」鋪在行動端線框紙
     * 上：本文底下壓著兩個手機外框。對照表在核心，兩端才不會各給一個答案。
     */
    /** 核心的紙張 id → 核心的 `PageStyle`。 */
    fun paperStyle(paperId: String): uniffi.padnote_core.PageStyle =
        uniffi.padnote_core.paperTemplates()
            .firstOrNull { it.id == paperId }
            ?.pageStyle
            ?: uniffi.padnote_core.PageStyle.BLANK

    fun paperOf(template: Template): uniffi.padnote_core.PageStyle =
        when (uniffi.padnote_core.docTemplatePaperId(template.pageStyle)) {
            "lined" -> uniffi.padnote_core.PageStyle.LINED
            "grid" -> uniffi.padnote_core.PageStyle.GRID
            "dot_grid_fine" -> uniffi.padnote_core.PageStyle.DOTTED
            "cornell" -> uniffi.padnote_core.PageStyle.CORNELL
            else -> uniffi.padnote_core.PageStyle.BLANK
        }

    private fun ensurePages(
        session: PadnoteSession,
        firstPageId: String,
        count: Int,
        style: uniffi.padnote_core.PageStyle
    ): List<String> {
        val pages = mutableListOf(firstPageId)
        while (pages.size < count) {
            val next = runCatching { session.addPage(style) }.getOrNull() ?: break
            pages.add(next)
        }
        return pages
    }

    private fun inkColor(kind: String) = when (kind) {
        "title" -> "#141A22"
        "heading" -> "#1F2937"
        "notice" -> "#7A4A05"
        else -> "#26303C"
    }

    private const val HEADER_FILL = "#E9EEFC"
    private const val NOTICE_FILL = "#FDF4E3"
    private const val NOTICE_BORDER = "#E0A94A"

    // MARK: - 解析

    private fun parse(root: JSONObject): List<Theme> {
        val themes = mutableListOf<Theme>()
        val array = root.optJSONArray("themes") ?: return themes
        for (i in 0 until array.length()) {
            val theme = array.getJSONObject(i)
            val categories = mutableListOf<Category>()
            val catArray = theme.optJSONArray("categories")
            for (j in 0 until (catArray?.length() ?: 0)) {
                val category = catArray!!.getJSONObject(j)
                val templates = mutableListOf<Template>()
                val tmplArray = category.optJSONArray("templates")
                for (k in 0 until (tmplArray?.length() ?: 0)) {
                    templates.add(parseTemplate(tmplArray!!.getJSONObject(k)))
                }
                categories.add(
                    Category(
                        category.optString("id"),
                        strings(category.optJSONObject("name")),
                        templates
                    )
                )
            }
            themes.add(
                Theme(
                    theme.optString("id"),
                    theme.optString("kind", "document"),
                    theme.optJSONObject("icon")?.optString("android").orEmpty(),
                    strings(theme.optJSONObject("name")),
                    categories
                )
            )
        }
        return themes
    }

    private fun parseTemplate(raw: JSONObject): Template {
        val variants = mutableMapOf<String, Map<String, Variant>>()
        val variantRoot = raw.optJSONObject("variants")
        for (kind in variantRoot?.keys() ?: emptyList<String>().iterator()) {
            val byLang = variantRoot!!.getJSONObject(kind)
            val langs = mutableMapOf<String, Variant>()
            for (lang in byLang.keys()) {
                val body = byLang.getJSONObject(lang)
                val blocks = mutableListOf<Block>()
                val blockArray = body.optJSONArray("blocks")
                for (i in 0 until (blockArray?.length() ?: 0)) {
                    blocks.add(parseBlock(blockArray!!.getJSONObject(i)))
                }
                langs[lang] = Variant(body.optInt("pageCount", 1), blocks)
            }
            variants[kind] = langs
        }
        return Template(
            raw.optString("id"),
            strings(raw.optJSONObject("name")),
            strings(raw.optJSONObject("description")),
            raw.optString("pageStyle", "blank"),
            variants
        )
    }

    private fun parseBlock(raw: JSONObject): Block {
        val cells = mutableListOf<String>()
        val cellArray = raw.optJSONArray("cells")
        for (i in 0 until (cellArray?.length() ?: 0)) cells.add(cellArray!!.optString(i))
        return Block(
            kind = raw.optString("kind", "body"),
            page = raw.optInt("page"),
            x = raw.optDouble("x", 0.0).toFloat(),
            y = raw.optDouble("y", 0.0).toFloat(),
            width = raw.optDouble("width", 0.0).toFloat(),
            height = raw.optDouble("height", 0.0).toFloat(),
            text = raw.optString("text"),
            fontSize = raw.optDouble("fontSize", 15.0).toFloat(),
            bold = raw.optBoolean("bold"),
            lineSpacing = raw.optDouble("lineSpacing", 5.0).toFloat(),
            rows = raw.optInt("rows"),
            cols = raw.optInt("cols"),
            cells = cells,
            headerRow = raw.optBoolean("headerRow", true)
        )
    }

    private fun strings(raw: JSONObject?): Map<String, String> {
        if (raw == null) return emptyMap()
        val out = mutableMapOf<String, String>()
        for (key in raw.keys()) out[key] = raw.optString(key)
        return out
    }
}
