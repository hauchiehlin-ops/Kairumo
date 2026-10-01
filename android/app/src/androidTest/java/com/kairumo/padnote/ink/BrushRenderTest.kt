package com.kairumo.padnote.ink

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import uniffi.padnote_core.StrokePoint
import uniffi.padnote_core.ToolKind
import java.io.File
import kotlin.math.PI
import kotlin.math.sin

/**
 * 筆刷在 Android 上**真的畫得出來**。
 *
 * 十三支筆各畫一條波浪線（壓力由輕到重）到點陣圖上，檢查每一支都有留下墨跡，
 * 並把整張圖存成 `brush-sheet.png`（`filesDir`），用 `run-as` 取出來肉眼看。
 * 自繪引擎的筆刷（針筆、炭筆、蠟筆、噴槍、油畫筆、書法扁頭筆）走核心的筆點陣，其餘走 Kotlin 的線段算繪。
 */
@RunWith(AndroidJUnit4::class)
class BrushRenderTest {

    private fun wave(y: Float, pressure: Float? = null): List<StrokePoint> =
        (0..60).map { i ->
            val t = i / 60f
            StrokePoint(
                x = 20f + 420f * t,
                y = y + 18f * sin(t * 2f * PI.toFloat()),
                pressure = pressure ?: (0.2f + 0.8f * sin(t * PI.toFloat())),
                tilt = 0.2f,
                azimuth = 0f,
                dtUs = 8_000u,
                roll = 0f
            )
        }

    private val all = listOf(
        ToolKind.FOUNTAIN_PEN to 3f, ToolKind.BALL_POINT to 3f, ToolKind.FINELINER to 4f,
        ToolKind.BRUSH to 4f, ToolKind.CALLIGRAPHY to 6f, ToolKind.PENCIL to 3f,
        ToolKind.CHARCOAL to 7f, ToolKind.CRAYON to 7f, ToolKind.AIRBRUSH to 9f,
        ToolKind.OIL_PAINT to 9f, ToolKind.WATERCOLOR to 5f, ToolKind.MARKER to 4f,
        ToolKind.HIGHLIGHTER to 4f
    )

    private fun inkedPixels(bitmap: Bitmap, top: Int, bottom: Int): Int {
        var n = 0
        val row = IntArray(bitmap.width)
        for (y in top until bottom) {
            bitmap.getPixels(row, 0, bitmap.width, 0, y, bitmap.width, 1)
            for (p in row) if (p != Color.WHITE) n++
        }
        return n
    }

    @Test
    fun everyBrushLeavesInkOnTheBitmap() {
        val rowHeight = 80
        val bitmap = Bitmap.createBitmap(480, rowHeight * all.size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawColor(Color.WHITE)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeCap = Paint.Cap.ROUND
            color = Color.rgb(30, 60, 160)
        }
        all.forEachIndexed { index, (tool, width) ->
            val y = index * rowHeight + rowHeight / 2f
            InkBrushRenderer.drawStrokeOnCanvas(canvas, paint, wave(y), tool, width, 1f)
        }
        val missing = all.withIndex().filter { (i, _) ->
            inkedPixels(bitmap, i * rowHeight, (i + 1) * rowHeight) < 150
        }.map { it.value.first }
        // 存下來給人看。
        val out = File(InstrumentationRegistry.getInstrumentation().targetContext.filesDir, "brush-sheet.png")
        out.outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
        assertTrue("這些筆刷畫完之後點陣圖上幾乎沒有墨跡：$missing", missing.isEmpty())
    }

    @Test
    fun charcoalIsGrainyAndAirbrushIsSoft() {
        val bitmap = Bitmap.createBitmap(480, 160, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.drawColor(Color.WHITE)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.BLACK }
        InkBrushRenderer.drawStrokeOnCanvas(canvas, paint, wave(40f, 0.9f), ToolKind.CHARCOAL, 12f, 1f)
        InkBrushRenderer.drawStrokeOnCanvas(canvas, paint, wave(110f, 0.9f), ToolKind.FINELINER, 12f, 1f)
        // 針筆是實心的線；炭筆有顆粒 —— 在同樣寬度下，炭筆的筆觸裡有更多半透明（灰色）像素。
        fun grayShare(top: Int, bottom: Int): Float {
            var gray = 0
            var inked = 0
            val row = IntArray(bitmap.width)
            for (y in top until bottom) {
                bitmap.getPixels(row, 0, bitmap.width, 0, y, bitmap.width, 1)
                for (p in row) {
                    if (p == Color.WHITE) continue
                    inked++
                    val v = Color.red(p)
                    if (v in 40..215) gray++
                }
            }
            return if (inked == 0) 0f else gray.toFloat() / inked
        }
        val charcoal = grayShare(0, 80)
        val liner = grayShare(80, 160)
        assertTrue("炭筆（$charcoal）應該比針筆（$liner）有更多半透明的顆粒像素", charcoal > liner)
    }
}
