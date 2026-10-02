package com.kairumo.padnote.shape

import org.json.JSONObject
import uniffi.padnote_core.FfiAnchor
import uniffi.padnote_core.FfiConnection
import uniffi.padnote_core.FfiEndCap
import uniffi.padnote_core.FfiPoint
import uniffi.padnote_core.FfiRect
import uniffi.padnote_core.FfiRouteStyle
import uniffi.padnote_core.FfiShape
import uniffi.padnote_core.FfiShapeKind
import uniffi.padnote_core.allShapeKinds
import uniffi.padnote_core.connectionArrowHead
import uniffi.padnote_core.connectionBetween
import uniffi.padnote_core.connectionPath
import uniffi.padnote_core.shapeAcceptsText
import uniffi.padnote_core.shapeAnchorPoint
import uniffi.padnote_core.shapeArrowHeads
import uniffi.padnote_core.shapeIsLinear
import uniffi.padnote_core.shapeOutline
import uniffi.padnote_core.shapeSemantic
import kotlin.math.PI
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.round
import kotlin.math.sin
import kotlin.math.sqrt

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
    // 插入尺寸刻意保守。太大的話，使用者拿到的第一件事是縮小它。
    // **必須與 Apple 端的預設一致**，否則同一個形狀在兩個平台大小不同。
    var width: Float = 120f,
    var height: Float = 60f,
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
    var groupId: String? = null,

    // ---- 進階樣式（全部可為 null：`null` ＝ 與以前一樣）----
    // 鍵名與 Apple 的 `NoteShapeAttachment` 一致。

    /** 線條樣式：`"solid"`（預設）、`"dashed"`、`"dotted"`。 */
    var dashStyle: String? = null,
    /** 形狀內文字大小。`null` 為 14。 */
    var fontSize: Float? = null,
    var textColorHex: String? = null,
    var isBold: Boolean? = null,
    var isItalic: Boolean? = null,
    /** 整個形狀的不透明度（0.1–1）。`null` 為 1。 */
    var opacity: Float? = null
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

    val centerX: Float get() = x + width / 2f
    val centerY: Float get() = y + height / 2f

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

    /** 線狀形狀的兩個端點（畫布座標，已套用旋轉）。核心的線是外框的對角線，旋轉由平台套。 */
    fun lineEndpoints(): Pair<FfiPoint, FfiPoint> {
        val deg = (rotationDegrees ?: 0f).toDouble()
        val c = FfiPoint(centerX, centerY)
        return ShapeFrameMath.rotate(FfiPoint(x, y), c, deg) to
            ShapeFrameMath.rotate(FfiPoint(x + width, y + height), c, deg)
    }

    /** 四個連接點的畫布座標（已套用旋轉）。 */
    fun anchorPoint(anchor: ShapeAnchor): FfiPoint = shapeAnchorPoint(ffiShape(), anchor.ffi)

    val dash: ShapeDash get() = ShapeDash.named(dashStyle)

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
        dashStyle?.let { put("dashStyle", it) }
        fontSize?.let { put("fontSize", it.toDouble()) }
        textColorHex?.let { put("textColorHex", it) }
        isBold?.let { put("isBold", it) }
        isItalic?.let { put("isItalic", it) }
        opacity?.let { put("opacity", it.toDouble()) }
    }.toString()

    companion object {
        fun nameOf(kind: FfiShapeKind): String = kind.name.lowercase()

        fun kindOf(name: String): FfiShapeKind? =
            allShapeKinds().firstOrNull { it.name.equals(name, ignoreCase = true) }

        fun decode(json: String): NoteShape? {
            val obj = runCatching { JSONObject(json) }.getOrNull() ?: return null
            fun str(key: String) = if (obj.has(key)) obj.optString(key) else null
            fun flt(key: String) = if (obj.has(key)) obj.optDouble(key).toFloat() else null
            return NoteShape(
                id = obj.optString("id", java.util.UUID.randomUUID().toString()),
                kindName = obj.optString("kindName", "process"),
                x = obj.optDouble("x", 80.0).toFloat(),
                y = obj.optDouble("y", 140.0).toFloat(),
                width = obj.optDouble("width", 160.0).toFloat(),
                height = obj.optDouble("height", 80.0).toFloat(),
                cornerRadius = obj.optDouble("cornerRadius", 8.0).toFloat(),
                label = obj.optString("label", ""),
                strokeColorHex = str("strokeColorHex"),
                fillColorHex = str("fillColorHex"),
                lineWidth = obj.optDouble("lineWidth", 2.0).toFloat(),
                rotationDegrees = flt("rotationDegrees"),
                groupId = str("groupId"),
                dashStyle = str("dashStyle"),
                fontSize = flt("fontSize"),
                textColorHex = str("textColorHex"),
                isBold = if (obj.has("isBold")) obj.optBoolean("isBold") else null,
                isItalic = if (obj.has("isItalic")) obj.optBoolean("isItalic") else null,
                opacity = flt("opacity")
            )
        }
    }
}

/** 線條樣式。名稱就是持久化的值，與 Apple 的 `ShapeDash` 一致。 */
enum class ShapeDash(val raw: String, val labelKey: String) {
    SOLID("solid", "dash_solid"),
    DASHED("dashed", "dash_dashed"),
    DOTTED("dotted", "dash_dotted");

    /** 虛線樣式要隨線寬縮放，細線配粗虛線段會看不出是虛線。單位：與線寬同單位。 */
    fun pattern(lineWidth: Float): FloatArray? {
        val w = max(1f, lineWidth)
        return when (this) {
            SOLID -> null
            DASHED -> floatArrayOf(w * 4f, w * 3f)
            DOTTED -> floatArrayOf(w * 0.1f, w * 2.2f)
        }
    }

    companion object {
        fun named(raw: String?): ShapeDash = entries.firstOrNull { it.raw == raw } ?: SOLID
    }
}

/** 連接點。名稱就是持久化的值。 */
enum class ShapeAnchor(val raw: String, val labelKey: String, val ffi: FfiAnchor) {
    TOP("top", "anchor_top", FfiAnchor.TOP),
    RIGHT("right", "anchor_right", FfiAnchor.RIGHT),
    BOTTOM("bottom", "anchor_bottom", FfiAnchor.BOTTOM),
    LEFT("left", "anchor_left", FfiAnchor.LEFT);

    companion object {
        fun named(raw: String?): ShapeAnchor? = entries.firstOrNull { it.raw == raw }
    }
}

enum class ConnectionRoute(val raw: String, val labelKey: String, val ffi: FfiRouteStyle) {
    STRAIGHT("straight", "route_straight", FfiRouteStyle.STRAIGHT),
    ORTHOGONAL("orthogonal", "route_elbow", FfiRouteStyle.ORTHOGONAL);

    companion object {
        fun named(raw: String?): ConnectionRoute? = entries.firstOrNull { it.raw == raw }
    }
}

enum class ConnectionCap(val raw: String, val labelKey: String, val ffi: FfiEndCap) {
    NONE("none", "cap_none", FfiEndCap.NONE),
    ARROW("arrow", "cap_arrow", FfiEndCap.ARROW),
    HOLLOW("hollow", "cap_hollow", FfiEndCap.HOLLOW_ARROW),
    CIRCLE("circle", "cap_circle", FfiEndCap.CIRCLE),
    DIAMOND("diamond", "cap_diamond", FfiEndCap.DIAMOND);

    companion object {
        fun named(raw: String?): ConnectionCap? = entries.firstOrNull { it.raw == raw }
        fun of(ffi: FfiEndCap): ConnectionCap = entries.first { it.ffi == ffi }
    }
}

/** 兩個形狀之間的連接線。欄位與 Apple 的 `NoteConnectionAttachment` 一對一。 */
data class NoteConnection(
    val id: String = java.util.UUID.randomUUID().toString(),
    var fromShapeId: String,
    var toShapeId: String,
    var label: String = "",
    var colorHex: String? = null,
    var lineWidth: Float = 2f,
    /** 出線／入線的連接點。`null` 由核心依兩個形狀的相對位置自動挑。 */
    var fromAnchor: String? = null,
    var toAnchor: String? = null,
    /** `"straight"` 或 `"orthogonal"`（核心的預設）。 */
    var route: String? = null,
    /** 起點預設 none、終點預設 arrow（與核心 `Connection::default` 相同）。 */
    var startCap: String? = null,
    var endCap: String? = null,
    var dashStyle: String? = null
) {
    val dash: ShapeDash get() = ShapeDash.named(dashStyle)
    val startCapName: ConnectionCap get() = ConnectionCap.named(startCap) ?: ConnectionCap.NONE
    val endCapName: ConnectionCap get() = ConnectionCap.named(endCap) ?: ConnectionCap.ARROW

    /**
     * 反轉方向：兩端的形狀、連接點、端點樣式一起對調。
     *
     * 兩端都沒設定時預設是「終點有箭頭」—— 對調之後箭頭要跟著到新的終點，
     * 光是交換兩個 null 會讓箭頭留在原本那一端。
     */
    fun reversed(): NoteConnection {
        var s = startCap
        var e = endCap
        if (s == null && e == null) { s = "arrow"; e = "none" } else { val t = s; s = e; e = t }
        return copy(
            fromShapeId = toShapeId, toShapeId = fromShapeId,
            fromAnchor = toAnchor, toAnchor = fromAnchor,
            startCap = s, endCap = e
        )
    }

    /**
     * 寫進核心連接線物件的欄位。`Center` 是「自動」的記號 —— 舊版一律寫
     * `Center/Center/Straight/None/Arrow` 而讀回時忽略，所以那個組合在檔案裡
     * 等於「沒有自訂」。明確選了直線卻沒指定連接點的線，會被解讀成那個舊組合
     * 而變回直角折線；這種情況把自動算出來的連接點一併寫進去。
     */
    fun coreFields(from: NoteShape?, to: NoteShape?): FfiConnection {
        var fa = ShapeAnchor.named(fromAnchor)?.ffi ?: FfiAnchor.CENTER
        var ta = ShapeAnchor.named(toAnchor)?.ffi ?: FfiAnchor.CENTER
        val r = ConnectionRoute.named(route) ?: ConnectionRoute.ORTHOGONAL
        val s = startCapName
        val e = endCapName
        val legacy = fa == FfiAnchor.CENTER && ta == FfiAnchor.CENTER &&
            r == ConnectionRoute.STRAIGHT && s == ConnectionCap.NONE && e == ConnectionCap.ARROW
        if (legacy && from != null && to != null) {
            val auto = connectionBetween(from.ffiShape(), to.ffiShape())
            fa = auto.fromAnchor
            ta = auto.toAnchor
        }
        return FfiConnection(fa, ta, r.ffi, s.ffi, e.ffi)
    }

    /** 從核心讀回的欄位套上來。舊版寫的那組固定值代表「沒有自訂」，維持 `null`。 */
    fun applyCore(
        fromAnchorCore: FfiAnchor, toAnchorCore: FfiAnchor, routeCore: FfiRouteStyle,
        startCapCore: FfiEndCap, endCapCore: FfiEndCap
    ): NoteConnection {
        val legacy = fromAnchorCore == FfiAnchor.CENTER && toAnchorCore == FfiAnchor.CENTER &&
            routeCore == FfiRouteStyle.STRAIGHT && startCapCore == FfiEndCap.NONE &&
            endCapCore == FfiEndCap.ARROW
        if (legacy) return this
        fun anchorName(a: FfiAnchor): String? =
            ShapeAnchor.entries.firstOrNull { it.ffi == a }?.raw
        val start = ConnectionCap.of(startCapCore)
        val end = ConnectionCap.of(endCapCore)
        return copy(
            fromAnchor = anchorName(fromAnchorCore),
            toAnchor = anchorName(toAnchorCore),
            route = if (routeCore == FfiRouteStyle.STRAIGHT) "straight" else null,
            startCap = if (start == ConnectionCap.NONE) null else start.raw,
            endCap = if (end == ConnectionCap.ARROW) null else end.raw
        )
    }
}

/**
 * 縮放與旋轉的算術（純函式，單元測試釘住）。與 Apple 的 `ShapeFrameMath` 逐項一致 ——
 * 兩邊的換算不同的話，同一個形狀在兩台裝置上拖出來的結果就不一樣。
 */
object ShapeFrameMath {
    /** 形狀的最小邊長。再小就抓不到把手了。 */
    const val MIN_SIDE = 16f

    data class Frame(val x: Float, val y: Float, val width: Float, val height: Float) {
        val centerX: Float get() = x + width / 2f
        val centerY: Float get() = y + height / 2f
    }

    fun rotate(p: FfiPoint, about: FfiPoint, degrees: Double): FfiPoint {
        if (kotlin.math.abs(degrees % 360.0) < 1e-9) return p
        val r = degrees * PI / 180.0
        val s = sin(r).toFloat()
        val c = cos(r).toFloat()
        val dx = p.x - about.x
        val dy = p.y - about.y
        return FfiPoint(about.x + dx * c - dy * s, about.y + dx * s + dy * c)
    }

    /**
     * 拖曳縮放把手之後的新外框。
     *
     * 位移是**形狀自己（旋轉前）座標軸**上的量 —— Compose 的指標座標已經落在旋轉後
     * 的子節點座標系裡，所以呼叫端直接給 drag 即可；而「對面那條邊在畫布上釘住」
     * 要成立，中心就得沿著旋轉後的軸平移。
     *
     * @param sx 把手的水平方向：-1 左、0 不動、1 右。
     * @param sy 把手的垂直方向：-1 上、0 不動、1 下。
     */
    fun resized(
        frame: Frame, rotationDegrees: Float,
        sx: Float, sy: Float, localDx: Float, localDy: Float,
        keepAspect: Boolean = false
    ): Frame {
        val r = rotationDegrees.toDouble() * PI / 180.0
        val s = sin(r).toFloat()
        val c = cos(r).toFloat()
        var w = max(MIN_SIDE, frame.width + sx * localDx)
        var h = max(MIN_SIDE, frame.height + sy * localDy)
        if (keepAspect && sx != 0f && sy != 0f && frame.width > 0f && frame.height > 0f) {
            val ratio = frame.width / frame.height
            if (kotlin.math.abs(w - frame.width) / frame.width >=
                kotlin.math.abs(h - frame.height) / frame.height) {
                h = max(MIN_SIDE, w / ratio); w = h * ratio
            } else {
                w = max(MIN_SIDE, h * ratio); h = w / ratio
            }
        }
        val dw = w - frame.width
        val dh = h - frame.height
        val lcx = sx * dw / 2f
        val lcy = sy * dh / 2f
        val cx = frame.centerX + lcx * c - lcy * s
        val cy = frame.centerY + lcx * s + lcy * c
        return Frame(cx - w / 2f, cy - h / 2f, w, h)
    }

    /**
     * 由兩個端點算出線狀形狀的外框與旋轉角。
     *
     * 核心的線是 bounds 的對角線，旋轉繞中心。要讓任意方向的線都能存進
     * 「外框＋旋轉」兩個既有欄位：外框取一個很扁的矩形（高 [thickness]），
     * 旋轉角補掉對角線與水平的那一點夾角。端點因此完全自由，不需要新增欄位，
     * 舊檔與另一個平台也讀得懂。
     */
    fun lineFrame(
        ax: Float, ay: Float, bx: Float, by: Float, thickness: Float = 2f
    ): Pair<Frame, Float> {
        val dx = bx - ax
        val dy = by - ay
        val length = max(thickness + 1f, hypot(dx, dy))
        val w = sqrt(max(1f, length * length - thickness * thickness))
        val diagonal = atan2(thickness, w)
        val phi = atan2(dy, dx)
        var degrees = ((phi - diagonal) * 180.0 / PI).toFloat() % 360f
        if (degrees < 0f) degrees += 360f
        val cx = (ax + bx) / 2f
        val cy = (ay + by) / 2f
        return Frame(cx - w / 2f, cy - thickness / 2f, w, thickness) to degrees
    }

    /** 吸附到 [step] 度的倍數（容差內才吸）。 */
    fun snapped(degrees: Float, step: Float = 15f, tolerance: Float = 4f): Float {
        val nearest = round(degrees / step) * step
        return if (kotlin.math.abs(degrees - nearest) <= tolerance) nearest else degrees
    }
}

/** 連接線的幾何。路徑與箭頭都由核心算。 */
object ShapeGeometry {

    /** 一個端點裝飾。圓點的 [points] 為空，用 [centerX]／[centerY]／[radius]。 */
    data class Cap(
        val kind: ConnectionCap,
        val points: List<FfiPoint>,
        val centerX: Float,
        val centerY: Float,
        val radius: Float
    )

    data class Connection(
        val path: List<FfiPoint>,
        /** 終點的箭頭三角形（舊欄位；等同 endCap 為 arrow 時的 points）。 */
        val arrowHead: List<FfiPoint>,
        val startCap: Cap?,
        val endCap: Cap?
    ) {
        /** 路徑的視覺中點（標籤與選取後的動作鈕放這裡）。依弧長找，不是取中間那個頂點。 */
        fun midpoint(): FfiPoint {
            if (path.size < 2) return path.firstOrNull() ?: FfiPoint(0f, 0f)
            var total = 0f
            for (i in 1 until path.size) total += hypot(path[i].x - path[i - 1].x, path[i].y - path[i - 1].y)
            var remaining = total / 2f
            for (i in 1 until path.size) {
                val seg = hypot(path[i].x - path[i - 1].x, path[i].y - path[i - 1].y)
                if (remaining <= seg && seg > 0f) {
                    val t = remaining / seg
                    return FfiPoint(
                        path[i - 1].x + (path[i].x - path[i - 1].x) * t,
                        path[i - 1].y + (path[i].y - path[i - 1].y) * t
                    )
                }
                remaining -= seg
            }
            return path.last()
        }

        /** 點到路徑的最短距離（頁面點）。選取連接線用。 */
        fun distanceTo(px: Float, py: Float): Float {
            var best = Float.MAX_VALUE
            for (i in 1 until path.size) {
                val ax = path[i - 1].x; val ay = path[i - 1].y
                val bx = path[i].x; val by = path[i].y
                val dx = bx - ax; val dy = by - ay
                val len2 = dx * dx + dy * dy
                val t = if (len2 <= 0f) 0f else (((px - ax) * dx + (py - ay) * dy) / len2).coerceIn(0f, 1f)
                best = minOf(best, hypot(px - (ax + dx * t), py - (ay + dy * t)))
            }
            return best
        }
    }

    /**
     * 算出一條連接線。
     *
     * 端點要落在形狀的**邊界**上，而邊界是形狀種類決定的（菱形的邊與方框的邊
     * 完全不同）。平台自己抓一個「大概的邊」，線就會穿進形狀裡或浮在外面。
     */
    fun connection(link: NoteConnection, from: NoteShape, to: NoteShape): Connection? {
        val a = from.ffiShape()
        val b = to.ffiShape()
        var spec = connectionBetween(a, b)
        ShapeAnchor.named(link.fromAnchor)?.let { spec = spec.copy(fromAnchor = it.ffi) }
        ShapeAnchor.named(link.toAnchor)?.let { spec = spec.copy(toAnchor = it.ffi) }
        ConnectionRoute.named(link.route)?.let { spec = spec.copy(route = it.ffi) }
        val path = connectionPath(spec, a, b)
        if (path.size < 2) return null

        val size = max(12f, link.lineWidth * 4.5f)
        val startCap = cap(link.startCapName, path[0], path[1], size)
        val endCap = cap(link.endCapName, path[path.size - 1], path[path.size - 2], size)
        return Connection(
            path = path,
            arrowHead = if (link.endCapName == ConnectionCap.ARROW) endCap?.points ?: emptyList() else emptyList(),
            startCap = startCap, endCap = endCap
        )
    }

    /** 舊的簽章（沒有自訂欄位的連接線）。 */
    fun connection(from: NoteShape, to: NoteShape): Connection? =
        connection(NoteConnection(fromShapeId = from.id, toShapeId = to.id), from, to)

    private fun cap(kind: ConnectionCap, tip: FfiPoint, from: FfiPoint, size: Float): Cap? {
        if (kind == ConnectionCap.NONE) return null
        val dx = tip.x - from.x
        val dy = tip.y - from.y
        val len = hypot(dx, dy)
        if (len <= 0.001f) return null
        val ux = dx / len
        val uy = dy / len
        return when (kind) {
            ConnectionCap.NONE -> null
            ConnectionCap.ARROW, ConnectionCap.HOLLOW ->
                Cap(kind, connectionArrowHead(tip, from, size), tip.x, tip.y, 0f)
            ConnectionCap.CIRCLE -> {
                val r = size * 0.38f
                Cap(kind, emptyList(), tip.x - ux * r, tip.y - uy * r, r)
            }
            ConnectionCap.DIAMOND -> {
                val half = size * 0.5f
                val mx = tip.x - ux * half
                val my = tip.y - uy * half
                val px = -uy * size * 0.32f
                val py = ux * size * 0.32f
                Cap(
                    kind,
                    listOf(
                        tip,
                        FfiPoint(mx + px, my + py),
                        FfiPoint(tip.x - ux * size, tip.y - uy * size),
                        FfiPoint(mx - px, my - py)
                    ),
                    mx, my, 0f
                )
            }
        }
    }
}
