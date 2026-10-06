package com.kairumo.padnote.ink

import uniffi.padnote_core.FfiInstrumentGeometry
import uniffi.padnote_core.FfiPoint
import uniffi.padnote_core.draftInstrumentGeometry
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.sin

/**
 * 頁面上的一把虛擬尺規（對應 Apple 的 `InstrumentModel`）：形狀由核心給（`draft_instrument_geometry`），
 * 這裡存位置與轉角。座標：核心給的幾何以尺的左上角為原點；用 [originX]/[originY] 加繞幾何中心的 [angle]（弧度）變到頁面上。
 */
class InstrumentModel private constructor(
    val kind: String,
    val geometry: FfiInstrumentGeometry,
    var originX: Float,
    var originY: Float
) {
    var angle = 0f
        private set

    /** 量角器的讀數點（尺自己的座標，所以尺移動、轉動時讀數跟著走）。沒讀過是 null。 */
    var readingLocal: Pair<Float, Float>? = null
        private set

    val verticalOnly: Boolean get() = geometry.verticalOnly
    val angleDegrees: Double get() = Math.toDegrees(angle.toDouble())

    private val pivotX get() = geometry.width / 2f
    private val pivotY get() = geometry.height / 2f

    /** 尺本身的座標 → 頁面座標。 */
    fun toPage(p: FfiPoint): InkEngine.Offset2 {
        val dx = p.x - pivotX
        val dy = p.y - pivotY
        val c = cos(angle)
        val s = sin(angle)
        return InkEngine.Offset2(originX + pivotX + dx * c - dy * s, originY + pivotY + dx * s + dy * c)
    }

    fun toLocal(x: Float, y: Float): InkEngine.Offset2 {
        val dx = x - originX - pivotX
        val dy = y - originY - pivotY
        val c = cos(angle)
        val s = sin(angle)
        return InkEngine.Offset2(pivotX + dx * c + dy * s, pivotY - dx * s + dy * c)
    }

    /** 靠著畫線的邊（頁面座標）。 */
    val pageEdges: List<Pair<InkEngine.Offset2, InkEngine.Offset2>>
        get() = geometry.edges.map { toPage(it.a) to toPage(it.b) }

    val pageOutline: List<List<InkEngine.Offset2>>
        get() = geometry.outline.map { ring -> ring.map(::toPage) }

    fun move(dx: Float, dy: Float) {
        originY += dy
        if (!verticalOnly) originX += dx
    }

    fun rotate(degrees: Double) {
        if (verticalOnly) return
        angle += Math.toRadians(degrees).toFloat()
    }

    /** 點在尺的身體上（外框內）。量角器是半圓，其他是包圍盒。 */
    fun containsBody(x: Float, y: Float): Boolean {
        val l = toLocal(x, y)
        val c = geometry.readingCenter
        if (c != null) return hypot(l.x - c.x, l.y - c.y) <= geometry.width / 2f && l.y <= c.y + 0.5f
        return l.x in 0f..geometry.width && l.y in 0f..geometry.height
    }

    // ── 量角器讀角度 ──

    /** 在量角器外圈的刻度帶（半徑的 55% 以外）：按住是讀角度，不是搬尺。 */
    fun isReadingZone(x: Float, y: Float): Boolean {
        val c = geometry.readingCenter ?: return false
        if (!containsBody(x, y)) return false
        val l = toLocal(x, y)
        return hypot(l.x - c.x, l.y - c.y) >= geometry.width / 2f * 0.55f
    }

    /** 把讀數點設在頁面上的 (x, y)；null 清掉。 */
    fun setReading(at: Pair<Float, Float>?) {
        readingLocal = at?.let { val l = toLocal(it.first, it.second); l.x to l.y }
    }

    /** 目前讀到的角度（度；0° 在量角器右端、逆時針到 180°）。沒讀過或讀不到回 null。 */
    val readingDegrees: Float?
        get() {
            val c = geometry.readingCenter ?: return null
            val r = readingLocal ?: return null
            return uniffi.padnote_core.draftProtractorAngle(c, FfiPoint(r.first, r.second))
        }

    /** 讀數線：從圓心沿讀到的方向到外緣（頁面座標）。沒讀數回 null。 */
    val readingRay: Pair<InkEngine.Offset2, InkEngine.Offset2>?
        get() {
            val c = geometry.readingCenter ?: return null
            val r = readingLocal ?: return null
            if (readingDegrees == null) return null
            val dx = r.first - c.x
            val dy = r.second - c.y
            val len = hypot(dx, dy)
            if (len < 0.001f) return null
            val radius = geometry.width / 2f
            return toPage(c) to toPage(FfiPoint(c.x + dx / len * radius, c.y + dy / len * radius))
        }

    /** 讀數的顯示字：「37.5° / 142.5°」（量角器兩邊的刻度）。 */
    val readingText: String?
        get() {
            val a = readingDegrees ?: return null
            return "%.1f° / %.1f°".format(a, 180f - a)
        }

    /** 離哪一條邊最近（[band] 之內）：回邊的起點、終點與 (x, y) 投影在那條邊所在直線上的點。 */
    fun nearestEdge(x: Float, y: Float, band: Float): Edge? {
        var best: Edge? = null
        var bestD = Float.MAX_VALUE
        for ((a, b) in pageEdges) {
            val foot = footOnLine(x, y, a, b)
            val d = hypot(foot.x - x, foot.y - y)
            val along = alongFraction(x, y, a, b)
            if (d > band || along < -0.05f || along > 1.05f) continue
            if (d < bestD) { best = Edge(a, b, foot); bestD = d }
        }
        return best
    }

    data class Edge(val a: InkEngine.Offset2, val b: InkEngine.Offset2, val foot: InkEngine.Offset2)

    /** 包含整把尺的範圍（頁面座標）。 */
    fun bounds(): FloatArray {
        val pts = pageOutline.flatten()
        return floatArrayOf(
            pts.minOf { it.x } - 24f, pts.minOf { it.y } - 24f,
            pts.maxOf { it.x } + 24f, pts.maxOf { it.y } + 24f
        )
    }

    companion object {
        fun create(kind: String, sizeMm: Double, pageWidth: Float, cx: Float, cy: Float): InstrumentModel? {
            val g = draftInstrumentGeometry(kind, sizeMm.toFloat(), pageWidth) ?: return null
            // 丁字尺貼著頁面左緣，只能上下滑。
            val ox = if (g.verticalOnly) 0f else cx - g.width / 2f
            return InstrumentModel(kind, g, ox, cy - g.height / 2f)
        }

        fun footOnLine(px: Float, py: Float, a: InkEngine.Offset2, b: InkEngine.Offset2): InkEngine.Offset2 {
            val vx = b.x - a.x
            val vy = b.y - a.y
            val len2 = vx * vx + vy * vy
            if (len2 < 1e-9f) return a
            val t = ((px - a.x) * vx + (py - a.y) * vy) / len2
            return InkEngine.Offset2(a.x + vx * t, a.y + vy * t)
        }

        private fun alongFraction(px: Float, py: Float, a: InkEngine.Offset2, b: InkEngine.Offset2): Float {
            val vx = b.x - a.x
            val vy = b.y - a.y
            val len2 = vx * vx + vy * vy
            return if (len2 > 1e-9f) ((px - a.x) * vx + (py - a.y) * vy) / len2 else 0f
        }
    }
}
