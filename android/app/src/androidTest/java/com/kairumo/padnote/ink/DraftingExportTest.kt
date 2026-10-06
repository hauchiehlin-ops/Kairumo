package com.kairumo.padnote.ink

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import uniffi.padnote_core.FfiGlassKind
import uniffi.padnote_core.FfiPoint
import uniffi.padnote_core.FfiSheetStroke
import uniffi.padnote_core.draftUnitsPerMm
import uniffi.padnote_core.solidGlassBounds
import uniffi.padnote_core.solidGlassFrame
import uniffi.padnote_core.solidPresetProfile
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder

/** 匯出：SVG、DXF、STL、OBJ、GLB、USDZ 與玻璃盒展開。對應 Apple 的 `DraftingExportTests`。 */
@RunWith(AndroidJUnit4::class)
class DraftingExportTest {
    private val u = draftUnitsPerMm()

    @Before
    fun setUp() {
        DraftingState.attach(InstrumentationRegistry.getInstrumentation().targetContext)
        DraftingState.use("export-test-${System.nanoTime()}")
    }

    private fun line(engine: InkEngine, layer: Int, type: Int, y: Float) {
        engine.insertDrafted(
            listOf(FfiSheetStroke(listOf(FfiPoint(0f, y), FfiPoint(100f * u, y)), layer.toUByte(), type.toUByte(), 2.6f, "#111827")),
            0f, 0f)
    }

    private fun box() = solidPresetProfile("rect", 50f * u, 40f * u)!! to 30f * u

    @Test
    fun thePageExportsAsSvgAndDxfInMillimetres() {
        val engine = InkEngine()
        line(engine, 3, 0, 0f)
        line(engine, 3, 1, 10f * u)
        val svg = DraftingExport.pageText(engine, "svg", 800f, 1132f)!!
        assertTrue(svg.contains("width=\"210mm\""))
        assertTrue(svg.contains("points=\"0,0 100,0\""))
        assertEquals("只有隱藏線有虛線圖樣", 1, svg.split("stroke-dasharray").size - 1)
        val dxf = DraftingExport.pageText(engine, "dxf", 800f, 1132f)!!
        assertTrue(dxf.contains("AC1009"))
        assertEquals(2, dxf.split("0\nPOLYLINE\n").size - 1)
        assertTrue(dxf.endsWith("0\nEOF\n"))
    }

    @Test
    fun hiddenLayersAreNotExportedAndAnEmptyPageGivesNothing() {
        val engine = InkEngine()
        assertNull("沒有任何線", DraftingExport.pageText(engine, "svg", 800f, 1132f))
        line(engine, 3, 0, 0f)
        line(engine, 2, 0, 20f)
        DraftingState.setHidden(2, true)
        try {
            val svg = DraftingExport.pageText(engine, "svg", 800f, 1132f)!!
            assertEquals("中層隱藏了就不輸出", 1, svg.split("<polyline").size - 1)
            assertFalse(svg.contains("layer-aux"))
        } finally {
            DraftingState.setHidden(2, false)
        }
    }

    @Test
    fun everySolidFormatHasValidContentAndTheRightSize() {
        val (profile, depth) = box()
        // STL：二進位，12 個三角形、毫米。
        val stl = DraftingExport.solidBytes(profile, depth, "stl")!!
        val bb = ByteBuffer.wrap(stl).order(ByteOrder.LITTLE_ENDIAN)
        val n = bb.getInt(80)
        assertEquals(12, n)
        assertEquals(84 + n * 50, stl.size)
        var maxX = Float.MIN_VALUE
        for (t in 0 until n) for (v in 0 until 3) maxX = maxOf(maxX, bb.getFloat(84 + t * 50 + 12 + v * 12))
        assertEquals(50f, maxX, 0.01f)
        // OBJ：文字，36 個頂點、12 個面。
        val obj = String(DraftingExport.solidBytes(profile, depth, "obj")!!)
        assertEquals(36, obj.lines().count { it.startsWith("v ") })
        assertEquals(12, obj.lines().count { it.startsWith("f ") })
        // GLB：魔術字、版本 2、長度一致；單位是公尺。
        val glb = DraftingExport.solidBytes(profile, depth, "glb")!!
        val g = ByteBuffer.wrap(glb).order(ByteOrder.LITTLE_ENDIAN)
        assertEquals("glTF", String(glb, 0, 4))
        assertEquals(2, g.getInt(4))
        assertEquals(glb.size, g.getInt(8))
        val json = String(glb, 20, g.getInt(12))
        assertTrue(json.contains("\"max\":[0.05"))
        // USDZ：zip，資料起點對齊 64，usda 內容在裡面。
        val usdz = DraftingExport.solidBytes(profile, depth, "usdz")!!
        assertEquals(0x50, usdz[0].toInt()); assertEquals(0x4b, usdz[1].toInt())
        val z = ByteBuffer.wrap(usdz).order(ByteOrder.LITTLE_ENDIAN)
        val dataAt = 30 + (z.getShort(26).toInt() and 0xFFFF) + (z.getShort(28).toInt() and 0xFFFF)
        assertEquals("USDZ 的資料起點要對齊 64", 0, dataAt % 64)
        assertTrue(String(usdz, dataAt, 9).startsWith("#usda 1.0"))
    }

    @Test
    fun aShapeWithHolesExportsAndBadInputIsRefused() {
        val plate = solidPresetProfile("plate_holes", 80f * u, 60f * u)!!
        for (f in uniffi.padnote_core.solidExportFormats()) {
            assertNotNull(f, DraftingExport.solidBytes(plate, 10f * u, f))
        }
        val (profile, depth) = box()
        assertNull(DraftingExport.solidBytes(profile, depth, "step"))
        assertNull(DraftingExport.solidBytes(profile, 0f, "stl"))
    }

    @Test
    fun theSharedFileLandsInTheExportsFolder() {
        val ctx = InstrumentationRegistry.getInstrumentation().targetContext
        val (profile, depth) = box()
        val bytes = DraftingExport.solidBytes(profile, depth, "stl")!!
        // 不真的開分享表（測試裡沒有可以接的 Activity）：只驗證檔案寫到 cache/exports/ 底下。
        val file = File(File(ctx.cacheDir, "exports").also { it.mkdirs() }, "solid-test.stl")
        file.writeBytes(bytes)
        assertTrue(file.exists() && file.length() == bytes.size.toLong())
        file.delete()
    }

    @Test
    fun theGlassBoxFramesUnfoldShareOneBoundsAndHaveEveryLineKind() {
        val (profile, depth) = box()
        val state = GlassState()
        val bounds = state.boundsFor(profile, depth)
        assertEquals(4, bounds.size)
        assertEquals("同樣的條件不重算", bounds, state.boundsFor(profile, depth))
        val closed = solidGlassFrame(profile, depth, true, 0f, state.yaw, state.pitch)!!
        val flat = solidGlassFrame(profile, depth, true, 1f, state.yaw, state.pitch)!!
        assertEquals(closed.lines.size, flat.lines.size)
        assertTrue(closed.lines.zip(flat.lines).any { (a, b) -> kotlin.math.abs(a.ax - b.ax) > 1f })
        // 長方體沒有隱藏線；U 形有（右視圖裡凹槽的底看不到）。
        val u = solidPresetProfile("u_shape", 50f * this.u, 40f * this.u)!!
        val uFlat = solidGlassFrame(u, depth, true, 1f, state.yaw, state.pitch)!!
        for (kind in FfiGlassKind.values()) assertTrue("$kind", uFlat.lines.any { it.kind == kind })
        // 視角或投影法一變，範圍就重算。
        state.third = false
        assertNotNull(solidGlassBounds(profile, depth, false, state.yaw, state.pitch))
        assertEquals(4, state.boundsFor(profile, depth).size)
    }

    @Test
    fun playingPausingAndScrubbingKeepTheProgressInRange() {
        val state = GlassState()
        assertEquals(0f, state.t, 0f)
        state.playing = true
        state.t = 0.5f
        state.playing = false
        assertTrue(state.t in 0f..1f)
    }
}
