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

    /** 點在尺的身體上（外框內）。 */
    fun containsBody(x: Float, y: Float): Boolean {
        val l = toLocal(x, y)
        return l.x in 0f..geometry.width && l.y in 0f..geometry.height
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
