package com.kairumo.padnote.shape

import org.json.JSONObject
import uniffi.padnote_core.FfiPoint
import uniffi.padnote_core.FfiRect
import uniffi.padnote_core.FfiShape
import uniffi.padnote_core.FfiShapeKind
import uniffi.padnote_core.allShapeKinds
import uniffi.padnote_core.connectionArrowHead
import uniffi.padnote_core.connectionBetween
import uniffi.padnote_core.connectionPath
import uniffi.padnote_core.shapeAcceptsText
import uniffi.padnote_core.shapeArrowHeads
import uniffi.padnote_core.shapeIsLinear
import uniffi.padnote_core.shapeOutline
import uniffi.padnote_core.shapeSemantic

/**
 * 畫布上的形狀與流程圖（Android）。
 *
 * 幾何全部來自核心（`shapeOutline` / `connectionPath` / `connectionArrowHead`）。
 * ISO 5807 的符號有明確的比例 —— 判斷菱形的頂點位置、資料平行四邊形的斜度 ——
 * 各平台各畫一份的話，同一張流程圖在兩台裝置上會長得不一樣，連接線的落點
 * 也就跟著錯。
 *
 * 與 Apple 的 `NoteShapeAttachment` 一對一對應。
 */
data class NoteShape(
    val id: String = java.util.UUID.randomUUID().toString(),
    /**
     * `FfiShapeKind` 的名稱。
     *
     * 存名稱而不是列舉序號：序號會隨核心新增種類而位移，那會讓舊筆記裡的
     * 「判斷」變成「資料」，而且不會有任何錯誤訊息。
     */
    var kindName: String = "process",
    var x: Float = 80f,
    var y: Float = 140f,
    var width: Float = 160f,
    var height: Float = 80f,
    var cornerRadius: Float = 8f,
    var label: String = "",
    var strokeColorHex: String? = null,
    /** `"clear"` 為透明。 */
    var fillColorHex: String? = null,
    var lineWidth: Float = 2f,
    /**
     * 繞自身中心的旋轉角度（度，順時針）。`null` = 沒設定（等同 0）。
     *
     * 與 Apple 端 `NoteShapeAttachment.rotationDegrees` 同一個鍵、同一個語意。
     */
    var rotationDegrees: Float? = null,
    /**
     * 所屬群組的 id。`null` 代表這個形狀在最上層。
     *
     * 群組是核心物件樹裡真正的節點（`Group`），不是平台自己畫出來的框 ——
     * 所以它跨得過平台：在一台裝置上群組起來，另一台打開仍然是一組。
     */
    var groupId: String? = null
) {
    /** 核心認得的種類。對不上時退回方框 —— 使用者至少看得到一個形狀。 */
    val kind: FfiShapeKind get() = kindOf(kindName) ?: FfiShapeKind.PROCESS

    /** 核心算出來的外框頂點（畫布座標）。 */
    fun outline(segments: UInt = 48u): List<FfiPoint> = shapeOutline(ffiShape(), segments)

    /** 這個形狀在 ISO 5807 裡代表什麼。 */
    val semantic: String? get() = shapeSemantic(kind)

    /** 這種形狀能不能放字。連接線與箭頭不能。 */
    val acceptsText: Boolean get() = shapeAcceptsText(kind)

    /** 線狀形狀（線／箭頭／雙箭頭）。路徑不能收尾，也沒有可填色的內部。 */
    val isLinear: Boolean get() = shapeIsLinear(kind)

    /**
     * 兩端的箭頭三角形（畫布座標）。非線狀形狀回傳空清單。
     *
     * 箭頭大小跟著線寬走：粗線配小三角形看不出是箭頭。
     */
    fun arrowHeads(): List<List<FfiPoint>> {
        if (!isLinear) return emptyList()
        val heads = shapeArrowHeads(ffiShape(), maxOf(10f, lineWidth * 5f))
        return listOf(heads.start, heads.end).filter { it.size >= 3 }
    }

    fun ffiShape(): FfiShape = FfiShape(
        kind = kind,
        bounds = FfiRect(minX = x, minY = y, maxX = x + width, maxY = y + height),
        cornerRadius = cornerRadius,
        // 核心據此把連接點與輪廓轉到旋轉後的位置 ——
        // 不帶過去的話，線會接在圖形外面的空氣中。
        rotationDegrees = rotationDegrees ?: 0f
    )

    fun copyShape(): NoteShape = decode(encodedJson()) ?: NoteShape()

    fun encodedJson(): String = JSONObject().apply {
        put("id", id)
        put("kindName", kindName)
        put("x", x.toDouble()); put("y", y.toDouble())
        put("width", width.toDouble()); put("height", height.toDouble())
        put("cornerRadius", cornerRadius.toDouble())
        put("label", label)
        put("lineWidth", lineWidth.toDouble())
        rotationDegrees?.let { put("rotationDegrees", it.toDouble()) }
        groupId?.let { put("groupId", it) }
        strokeColorHex?.let { put("strokeColorHex", it) }
        fillColorHex?.let { put("fillColorHex", it) }
    }.toString()

    companion object {
        fun nameOf(kind: FfiShapeKind): String = kind.name.lowercase()

        fun kindOf(name: String): FfiShapeKind? =
            allShapeKinds().firstOrNull { it.name.equals(name, ignoreCase = true) }

        fun decode(json: String): NoteShape? {
            val obj = runCatching { JSONObject(json) }.getOrNull() ?: return null
            return NoteShape(
                id = obj.optString("id", java.util.UUID.randomUUID().toString()),
                kindName = obj.optString("kindName", "process"),
                x = obj.optDouble("x", 80.0).toFloat(),
                y = obj.optDouble("y", 140.0).toFloat(),
                width = obj.optDouble("width", 160.0).toFloat(),
                height = obj.optDouble("height", 80.0).toFloat(),
                cornerRadius = obj.optDouble("cornerRadius", 8.0).toFloat(),
                label = obj.optString("label", ""),
                strokeColorHex = if (obj.has("strokeColorHex")) obj.optString("strokeColorHex") else null,
                fillColorHex = if (obj.has("fillColorHex")) obj.optString("fillColorHex") else null,
                lineWidth = obj.optDouble("lineWidth", 2.0).toFloat(),
                rotationDegrees = if (obj.has("rotationDegrees"))
                    obj.optDouble("rotationDegrees").toFloat() else null,
                groupId = if (obj.has("groupId")) obj.optString("groupId") else null
            )
        }
    }
}

/** 兩個形狀之間的連接線。 */
data class NoteConnection(
    val id: String = java.util.UUID.randomUUID().toString(),
    var fromShapeId: String,
    var toShapeId: String,
    var label: String = "",
    var colorHex: String? = null,
    var lineWidth: Float = 2f
)

/** 連接線的幾何。路徑與箭頭都由核心算。 */
object ShapeGeometry {

    data class Connection(val path: List<FfiPoint>, val arrowHead: List<FfiPoint>)

    /**
     * 算出一條連接線。
     *
     * 端點要落在形狀的**邊界**上，而邊界是形狀種類決定的（菱形的邊與方框的邊
     * 完全不同）。平台自己抓一個「大概的邊」，線就會穿進形狀裡或浮在外面。
     */
    fun connection(from: NoteShape, to: NoteShape): Connection? {
        val a = from.ffiShape()
        val b = to.ffiShape()
        val path = connectionPath(connectionBetween(a, b), a, b)
        if (path.size < 2) return null
        val head = connectionArrowHead(path[path.size - 1], path[path.size - 2], 12f)
        return Connection(path, head)
    }
}
