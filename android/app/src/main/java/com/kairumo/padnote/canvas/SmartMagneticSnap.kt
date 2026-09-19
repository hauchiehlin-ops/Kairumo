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
    private val canonicalAngles = listOf(0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0)
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
            val rad = Math.toRadians(bestAngle)
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
}
