package com.kairumo.padnote.ink

import android.view.MotionEvent
import uniffi.padnote_core.FfiPhase
import uniffi.padnote_core.FfiPointerEvent
import uniffi.padnote_core.FfiPointerKind
import uniffi.padnote_core.StrokePoint
import kotlin.math.PI

/**
 * `MotionEvent` → 核心輸入事件（工作包 WP5）。
 *
 * # 掌拒不在這裡
 *
 * 判斷「這是筆還是手掌」的邏輯在核心的 `InkArbiter`（`padnote-input`），
 * Apple 版與 Android 版共用同一份、同一組門檻。這個檔案只負責**如實轉換**：
 * 取到所有取樣點、把單位換對、把角度對到正確的語意。轉錯了，再好的仲裁
 * 也救不回來。
 *
 * # 三個很容易錯、而且錯了不會當掉的地方
 *
 * 1. **只讀 `getX()` 會掉點。** S Pen 的取樣率（240Hz 以上）遠高於畫面更新率，
 *    一個 `ACTION_MOVE` 事件裡通常塞著好幾個歷史取樣點。不讀
 *    `getHistorical*` 的話，快速書寫會變成折線。
 * 2. **接觸半徑要換成 dp。** 核心的手掌門檻是 22「點」。直接餵 px，
 *    在 3x 密度的螢幕上筆尖也會被當成手掌 —— 而在 1x 的模擬器上完全正常。
 * 3. **`AXIS_ORIENTATION` 是 -π..π，核心要 0..2π。** 負值會被核心夾成 0，
 *    於是扁筆頭的方向在螢幕左半邊全都錯，但不會有任何錯誤訊息。
 */
object InkInput {

    /** 一個轉換好的取樣點，含仲裁需要的欄位與筆跡需要的欄位。 */
    data class Sample(
        val event: FfiPointerEvent,
        /** 偏離垂直的角度（0–π/2），語意與核心 `StrokePoint.tilt` 相同。 */
        val tilt: Float,
        /** 0–2π。 */
        val azimuth: Float
    )

    /**
     * 把一個 `MotionEvent` 展開成所有取樣點（含歷史點）。
     *
     * @param density 螢幕密度（`resources.displayMetrics.density`）。px → dp 用。
     * @param zoom 畫布縮放比例（S-80）。預設 1.0。
     * @param offsetX 畫布水平位移（dp）。
     * @param offsetY 畫布垂直位移（dp）。
     */
    fun samples(
        event: MotionEvent,
        density: Float,
        zoom: Float = 1f,
        offsetX: Float = 0f,
        offsetY: Float = 0f
    ): List<Sample> {
        val phase = phaseOf(event) ?: return emptyList()
        val scale = if (density > 0f) density else 1f
        val out = ArrayList<Sample>()

        // ACTION_POINTER_DOWN / UP 只針對 actionIndex 那一根手指；
        // 其餘動作要走過所有指標，否則多指操作會漏掉。
        val indices: IntRange = when (event.actionMasked) {
            MotionEvent.ACTION_POINTER_DOWN, MotionEvent.ACTION_POINTER_UP ->
                event.actionIndex..event.actionIndex
            MotionEvent.ACTION_DOWN, MotionEvent.ACTION_UP -> 0..0
            else -> 0 until event.pointerCount
        }

        for (i in indices) {
            val id = event.getPointerId(i).toULong()
            val kind = kindOf(event.getToolType(i))

            // 歷史點先，目前點後 —— 順序就是實際書寫的順序。
            // 只有 MOVE 與 HOVER_MOVE 會帶歷史點。
            for (h in 0 until event.historySize) {
                out += sample(
                    id = id, kind = kind, phase = phase,
                    x = event.getHistoricalX(i, h), y = event.getHistoricalY(i, h),
                    pressure = event.getHistoricalPressure(i, h),
                    touchMajor = event.getHistoricalTouchMajor(i, h),
                    tiltRad = event.getHistoricalAxisValue(MotionEvent.AXIS_TILT, i, h),
                    orientationRad = event.getHistoricalOrientation(i, h),
                    timeMs = event.getHistoricalEventTime(h),
                    scale = scale,
                    zoom = zoom,
                    offsetX = offsetX,
                    offsetY = offsetY
                )
            }

            out += sample(
                id = id, kind = kind, phase = phase,
                x = event.getX(i), y = event.getY(i),
                pressure = event.getPressure(i),
                touchMajor = event.getTouchMajor(i),
                tiltRad = event.getAxisValue(MotionEvent.AXIS_TILT, i),
                orientationRad = event.getOrientation(i),
                timeMs = event.eventTime,
                scale = scale,
                zoom = zoom,
                offsetX = offsetX,
                offsetY = offsetY
            )
        }
        return out
    }

    private fun sample(
        id: ULong, kind: FfiPointerKind, phase: FfiPhase,
        x: Float, y: Float, pressure: Float, touchMajor: Float,
        tiltRad: Float, orientationRad: Float, timeMs: Long, scale: Float,
        zoom: Float = 1f, offsetX: Float = 0f, offsetY: Float = 0f
    ): Sample {
        val dpX = x / scale
        val dpY = y / scale
        val z = if (zoom > 0f) zoom else 1f
        val canvasX = (dpX - offsetX) / z
        val canvasY = (dpY - offsetY) / z

        return Sample(
            event = FfiPointerEvent(
                id = id,
                kind = kind,
                phase = phase,
                x = canvasX,
                y = canvasY,
                // 沒有壓感的裝置回傳 1.0；核心約定「沒有壓感時填 0.5」。
                pressure = pressure.coerceIn(0f, 1f),
                // touchMajor 是**直徑**，核心要的是長半徑；而且要換成 dp。
                contactRadius = (touchMajor / 2f) / scale / z,
                timestampUs = (timeMs * 1_000L).toULong()
            ),
            tilt = tiltRad.coerceIn(0f, (PI / 2).toFloat()),
            azimuth = normalizeAzimuth(orientationRad)
        )
    }

    /** `AXIS_ORIENTATION` 是 -π..π，核心的方位角是 0..2π。 */
    fun normalizeAzimuth(radians: Float): Float {
        val tau = (PI * 2).toFloat()
        val r = radians % tau
        return if (r < 0f) r + tau else r
    }

    fun kindOf(toolType: Int): FfiPointerKind = when (toolType) {
        MotionEvent.TOOL_TYPE_STYLUS -> FfiPointerKind.PEN
        MotionEvent.TOOL_TYPE_ERASER -> FfiPointerKind.ERASER
        MotionEvent.TOOL_TYPE_FINGER -> FfiPointerKind.FINGER
        MotionEvent.TOOL_TYPE_MOUSE -> FfiPointerKind.MOUSE
        else -> FfiPointerKind.UNKNOWN
    }

    /** 不需要處理的動作回傳 `null`（例如 ACTION_SCROLL）。 */
    fun phaseOf(event: MotionEvent): FfiPhase? = when (event.actionMasked) {
        MotionEvent.ACTION_DOWN, MotionEvent.ACTION_POINTER_DOWN -> FfiPhase.BEGAN
        MotionEvent.ACTION_MOVE -> FfiPhase.MOVED
        MotionEvent.ACTION_UP, MotionEvent.ACTION_POINTER_UP -> FfiPhase.ENDED
        MotionEvent.ACTION_CANCEL -> FfiPhase.CANCELLED
        MotionEvent.ACTION_HOVER_ENTER, MotionEvent.ACTION_HOVER_MOVE -> FfiPhase.HOVER
        MotionEvent.ACTION_HOVER_EXIT -> FfiPhase.HOVER_ENDED
        else -> null
    }

    /**
     * 取樣點序列 → 核心的 `StrokePoint`。
     *
     * `dtUs` 是距前一點的微秒差。格式規格 §5.4 用 u16 存它，上限 65535µs；
     * 超過代表使用者中途停筆，時間差本來就不具意義，夾住即可。
     */
    fun strokePoints(samples: List<Sample>): List<StrokePoint> {
        var previousUs: ULong? = null
        return samples.map { s ->
            val dt = previousUs?.let { prev ->
                val delta = if (s.event.timestampUs > prev) s.event.timestampUs - prev else 0uL
                delta.coerceAtMost(65_535uL)
            } ?: 0uL
            previousUs = s.event.timestampUs
            StrokePoint(
                x = s.event.x,
                y = s.event.y,
                pressure = s.event.pressure,
                tilt = s.tilt,
                azimuth = s.azimuth,
                dtUs = dt.toUInt()
            )
        }
    }

    const val MAX_DT_US: UInt = 65_535u
}
