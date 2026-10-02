package com.kairumo.padnote.canvas

import androidx.compose.ui.geometry.Offset
import kotlin.math.*

/**
 * 磁吸對齊結果
 */
data class MagneticSnapResult(
    val snappedPoint: Offset,
    val snappedAngleDegrees: Double?,
    val didSnap: Boolean
)

/**
 * 次世代筆跡磁吸對齊與幾何角度引導 (Smart Magnetic Snap & Ruler - Android 版)。
 * 當筆畫接近水平、垂直、45° 或紙張格線時，自動磁吸吸附並給予觸覺反饋與光導引。
 */
object SmartMagneticSnap {
    private val canonicalAngles = doubleArrayOf(0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0)
    private const val angleToleranceDegrees = 6.0
    private const val gridStep = 20f

    fun snap(start: Offset, current: Offset, enableGrid: Boolean = true): MagneticSnapResult {
        val dx = current.x - start.x
        val dy = current.y - start.y
        val distance = hypot(dx, dy)
        if (distance < 18f) {
            return MagneticSnapResult(current, null, false)
        }

        var angleDeg = Math.toDegrees(atan2(dy.toDouble(), dx.toDouble()))
        if (angleDeg < 0) angleDeg += 360.0

        var bestAngle: Double? = null
        for (canonical in canonicalAngles) {
            val diff = abs(angleDeg - canonical)
            val wrapDiff = min(diff, 360.0 - diff)
            if (wrapDiff <= angleToleranceDegrees) {
                bestAngle = canonical
                break
            }
        }

        if (bestAngle != null) {
            val rad = bestAngle * (Math.PI / 180.0)
            var snappedX = (start.x + cos(rad) * distance).toFloat()
            var snappedY = (start.y + sin(rad) * distance).toFloat()
            if (enableGrid) {
                snappedX = round(snappedX / gridStep) * gridStep
                snappedY = round(snappedY / gridStep) * gridStep
            }
            return MagneticSnapResult(
                Offset(snappedX, snappedY),
                bestAngle,
                true
            )
        }

        if (enableGrid) {
            val snappedX = round(current.x / gridStep) * gridStep
            val snappedY = round(current.y / gridStep) * gridStep
            if (abs(snappedX - current.x) < 5f && abs(snappedY - current.y) < 5f) {
                return MagneticSnapResult(Offset(snappedX, snappedY), null, true)
            }
        }

        return MagneticSnapResult(current, null, false)
    }

    /**
     * 這一筆是不是「刻意畫的直線」。與 Apple 的 `isNearlyStraight` 同一條規則。
     *
     * 磁吸原本對每一筆都生效：寫字的最後一筆只要起訖連線碰巧接近水平，或終點離
     * 格點不到 5 單位，終點就被拉去對齊，字會莫名其妙歪掉。磁吸是畫圖時把直線扶正
     * 用的，不該碰手寫的字。每個中間點離起訖連線不超過線長的 8%（至少 3）才算直線。
     */
    fun isNearlyStraight(points: List<Offset>): Boolean {
        if (points.size < 2) return false
        val first = points.first()
        val last = points.last()
        val length = hypot(last.x - first.x, last.y - first.y)
        if (length <= 18f) return false
        val tolerance = max(3f, length * 0.08f)
        return points.all { p ->
            val d = abs((last.x - first.x) * (first.y - p.y) - (first.x - p.x) * (last.y - first.y)) / length
            d <= tolerance
        }
    }
}
