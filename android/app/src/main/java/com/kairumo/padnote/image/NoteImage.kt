package com.kairumo.padnote.image

import org.json.JSONObject

/**
 * 圖片濾鏡。
 *
 * **`raw` 必須與 Apple 端 `ImageFilterStyle` 的 rawValue 逐字相同** ——
 * 那是持久化用的識別字，對不上的話同一本筆記換平台打開，濾鏡會全部變回原圖。
 * 顯示名稱走字串表，不可拿 rawValue 來顯示（那會讓濾鏡名稱永遠是中文）。
 */
enum class ImageFilterStyle(val raw: String, val labelKey: String) {
    ORIGINAL("原圖", "filter_original"),
    VINTAGE("復古", "filter_vintage"),
    MONO("黑白", "filter_mono"),
    CONTRAST("清晰", "filter_contrast"),
    WARM("柔光", "filter_warm");

    companion object {
        fun from(raw: String?): ImageFilterStyle =
            entries.firstOrNull { it.raw == raw } ?: ORIGINAL
    }
}

/**
 * 畫布上的一張圖片。
 *
 * 欄位與 Apple 端的 `NoteImageAttachment` 一對一。`null` 代表「沒設定」，
 * 與「設成 0」是兩回事 —— 編碼時不寫進 JSON。
 */
data class NoteImage(
    /** 核心的區塊 id。 */
    val id: String,
    /** blob id，圖片的位元組存在核心裡。 */
    var blobId: String,
    var x: Float = 60f,
    var y: Float = 80f,
    var width: Float = 240f,
    var height: Float = 180f,
    var rotationDegrees: Float = 0f,
    var cornerRadius: Float = 8f,
    var hasShadow: Boolean = true,
    var hasBorder: Boolean = false,
    var filterStyle: ImageFilterStyle = ImageFilterStyle.ORIGINAL,
    var borderColorHex: String? = null,
    var borderWidth: Float? = null,
    /** `"clear"` 為透明。哨符不是顏色，不可走顏色轉換。 */
    var backgroundColorHex: String? = null,
    /** 原始檔名。同步去重要用，不能每次重新產生。 */
    var fileName: String = ""
)

/**
 * 圖片區塊的外觀編碼（`format-spec.md` §6.2）。
 *
 * 核心的圖片區塊只記得「哪個 blob、多寬多高」。使用者調過的圓角、邊框、
 * 陰影、濾鏡、旋轉、底色全都沒有對應概念 —— 少了這一層，同一本筆記在另一台
 * 裝置上打開，每張圖都會變回一張沒有樣式的方形照片。那不是「還沒支援」，
 * 是資料遺失。
 *
 * **與 Apple 端的 `ImageAppearance.swift` 用同一組鍵。**
 */
object ImageAppearance {

    private const val OBJECT_KEY = "object"
    private const val IMAGE_KEY = "image"
    private const val CHART_KEY = "chart"

    /**
     * 由別種物件算繪出來的圖片區塊 —— 連結卡片與 3D 模型。
     *
     * 它們的真身跟著筆記本中繼資料走，所以這些衍生圖片必須認得出來並跳過，
     * 否則同一張卡片會變成兩份（真的一份、圖片一份），而且每同步一趟就多一份。
     */
    private val DERIVED = setOf("link", "model3d")

    /** 這個區塊是不是衍生圖片（載入時要跳過）。 */
    fun isDerived(json: String?): Boolean {
        val obj = runCatching { JSONObject(json ?: return false) }.getOrNull() ?: return false
        return obj.optString(OBJECT_KEY) in DERIVED
    }

    /** 這個區塊是不是圖表（圖表由 ChartStore 負責，不要當成普通圖片載入）。 */
    fun isChart(json: String?): Boolean {
        val obj = runCatching { JSONObject(json ?: return false) }.getOrNull() ?: return false
        return obj.optString(OBJECT_KEY) == CHART_KEY || obj.has(CHART_KEY)
    }

    fun encode(image: NoteImage): String {
        val style = JSONObject()
        style.put("rotationDegrees", image.rotationDegrees.toDouble())
        style.put("cornerRadius", image.cornerRadius.toDouble())
        style.put("hasShadow", image.hasShadow)
        style.put("hasBorder", image.hasBorder)
        style.put("filterStyle", image.filterStyle.raw)
        style.put("fileName", image.fileName)
        image.borderColorHex?.let { style.put("borderColorHex", it) }
        image.borderWidth?.let { style.put("borderWidth", it.toDouble()) }
        image.backgroundColorHex?.let { style.put("backgroundColorHex", it) }

        return JSONObject()
            .put(OBJECT_KEY, "image")
            .put(IMAGE_KEY, style)
            .toString()
    }

    /**
     * 把 JSON 套回圖片。認不得的鍵一律忽略。
     *
     * 忽略而不是報錯：另一個平台可能帶了我們還沒實作的欄位，那時該做的是
     * 保留其餘設定，不是整張圖都不套樣式。
     */
    fun apply(json: String?, image: NoteImage) {
        val root = runCatching { JSONObject(json ?: return) }.getOrNull() ?: return
        val style = root.optJSONObject(IMAGE_KEY) ?: return
        if (style.has("rotationDegrees")) {
            image.rotationDegrees = style.getDouble("rotationDegrees").toFloat()
        }
        if (style.has("cornerRadius")) {
            image.cornerRadius = style.getDouble("cornerRadius").toFloat()
        }
        if (style.has("hasShadow")) image.hasShadow = style.getBoolean("hasShadow")
        if (style.has("hasBorder")) image.hasBorder = style.getBoolean("hasBorder")
        if (style.has("filterStyle")) {
            image.filterStyle = ImageFilterStyle.from(style.getString("filterStyle"))
        }
        if (style.has("borderColorHex")) image.borderColorHex = style.getString("borderColorHex")
        if (style.has("borderWidth")) {
            image.borderWidth = style.getDouble("borderWidth").toFloat()
        }
        if (style.has("backgroundColorHex")) {
            image.backgroundColorHex = style.getString("backgroundColorHex")
        }
        if (style.has("fileName")) image.fileName = style.getString("fileName")
    }
}
