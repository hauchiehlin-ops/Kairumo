package com.kairumo.padnote.shape

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import uniffi.padnote_core.PadnoteSession
import java.io.File

/**
 * 形狀編修之後的持久化：縮放、旋轉、樣式、任意角度的線、連接線設定、拉線連接。
 *
 * 在此之前 Android 只把「建立時的外框」寫進核心 —— 縮放、旋轉、改色之後重開 App
 * 全部回到插入時的樣子，同步到 Apple 也一樣。對照 `apple/Tests/ShapeEditingTests.swift`。
 */
@RunWith(AndroidJUnit4::class)
class ShapeEditingTest {

    private val context = InstrumentationRegistry.getInstrumentation().targetContext

    private fun session(name: String): Pair<PadnoteSession, String> {
        val dir = File(context.cacheDir, "shape-edit-$name-${System.nanoTime()}")
        val s = PadnoteSession.create(dir.absolutePath, "形狀", 1_757_635_200_000uL, 0xF5u)
        return s to s.firstPageId()!!
    }

    private fun shape(kind: String = "process") =
        NoteShape(kindName = kind, x = 100f, y = 200f, width = 160f, height = 80f)

    // ── 編修之後的持久化（縮放、旋轉、樣式、線段、連接線設定）──────────

    @Test
    fun oldFilesWithoutNewKeysStillDecode() {
        val s = NoteShape.decode(
            """{"id":"s","kindName":"process","x":1,"y":2,"width":3,"height":4,"label":"","lineWidth":2}""")!!
        assertNull(s.dashStyle)
        assertEquals(ShapeDash.SOLID, s.dash)
    }

    @Test
    fun styleJsonUsesTheSameKeysAsApple() {
        val s = NoteShape(
            kindName = "decision", label = "是否", strokeColorHex = "#FF0000", fillColorHex = "clear",
            lineWidth = 4f, dashStyle = "dashed", fontSize = 20f, isBold = true, opacity = 0.5f)
        val json = ShapeStyleMeta.encode(s)
        // 鍵名是 Apple 端 `ShapeStyleMeta` 的屬性名，改了就是改檔案格式。
        for (key in listOf("kind", "label", "stroke", "fill", "lineWidth", "dash", "fontSize", "bold", "opacity")) {
            assertTrue("缺少鍵 $key", json.has(key))
        }
        val back = NoteShape(id = s.id)
        ShapeStyleMeta.apply(json, back)
        assertEquals("decision", back.kindName)
        assertEquals("#FF0000", back.strokeColorHex)
        assertEquals("clear", back.fillColorHex)
        assertEquals("dashed", back.dashStyle)
        assertEquals(20f, back.fontSize!!, 0f)
        assertEquals(true, back.isBold)
    }

    @Test
    fun connectionStyleJsonUsesTheSameKeysAsApple() {
        val c = NoteConnection(
            fromShapeId = "a", toShapeId = "b", label = "是", colorHex = "#0000FF", lineWidth = 3f,
            fromAnchor = "bottom", toAnchor = "top", route = "straight",
            startCap = "circle", endCap = "hollow", dashStyle = "dotted")
        val json = ShapeStyleMeta.encode(c)
        for (key in listOf("fromAnchor", "toAnchor", "route", "startCap", "endCap", "label", "color", "lineWidth", "dash")) {
            assertTrue("缺少鍵 $key", json.has(key))
        }
        val back = NoteConnection(fromShapeId = "a", toShapeId = "b")
        ShapeStyleMeta.apply(json, back)
        assertEquals("straight", back.route)
        assertEquals("hollow", back.endCap)
        assertEquals("#0000FF", back.colorHex)
    }

    @Test
    fun resizeRotateAndStyleSurviveTheNotebook() {
        // 在此之前 Android 只把「建立時的外框」寫進核心：縮放、旋轉、改色之後重開
        // 全部回到插入時的樣子，而且同步到 Apple 也一樣。
        val (s, page) = session("edit-roundtrip")
        val store = ShapeStore(s, page)
        val created = store.create(shape("decision").apply { label = "原本" })

        store.persist(created.copyShape().apply {
            x = 150f; y = 260f; width = 240f; height = 120f
            rotationDegrees = 30f
            label = "改過"
            strokeColorHex = "#FF0000"; fillColorHex = "#00FF00"
            lineWidth = 4f; dashStyle = "dashed"; fontSize = 20f; isBold = true; opacity = 0.5f
        })

        val back = ShapeStore(s, page).apply { load() }.all.single()
        assertEquals(created.id, back.id)
        assertEquals(150f, back.x, 0.6f)
        assertEquals(260f, back.y, 0.6f)
        assertEquals(240f, back.width, 0.6f)
        assertEquals(120f, back.height, 0.6f)
        assertEquals(30f, back.rotationDegrees!!, 0.1f)
        assertEquals("改過", back.label)
        assertEquals("#FF0000", back.strokeColorHex)
        assertEquals("#00FF00", back.fillColorHex)
        assertEquals("dashed", back.dashStyle)
        assertEquals(20f, back.fontSize!!, 0f)
        assertEquals(0.5f, back.opacity!!, 0.001f)
    }

    @Test
    fun resizingARotatedShapeKeepsItsRotationAndCentreMath() {
        // 轉過的形狀縮放要在**自己的軸**上做：直接在轉過的狀態下縮放會把形狀剪成平行四邊形。
        val (s, page) = session("rotated-resize")
        val store = ShapeStore(s, page)
        val created = store.create(shape().apply { rotationDegrees = 45f })
        store.persist(created.copyShape().apply { width = 240f })   // 只拉寬

        val back = ShapeStore(s, page).apply { load() }.all.single()
        assertEquals(240f, back.width, 0.6f)
        assertEquals(80f, back.height, 0.6f)
        assertEquals(45f, back.rotationDegrees!!, 0.1f)
    }

    @Test
    fun anArbitraryLineSurvivesTheNotebook() {
        val (s, page) = session("line")
        val store = ShapeStore(s, page)
        val (f, deg) = ShapeFrameMath.lineFrame(300f, 600f, 500f, 500f)
        val created = store.create(
            NoteShape(kindName = "arrow", x = f.x, y = f.y, width = f.width, height = f.height,
                rotationDegrees = deg))

        val ends = ShapeStore(s, page).apply { load() }.all.single().lineEndpoints()
        assertEquals(300f, ends.first.x, 0.3f)
        assertEquals(600f, ends.first.y, 0.3f)
        assertEquals(500f, ends.second.x, 0.3f)
        assertEquals(500f, ends.second.y, 0.3f)
        assertEquals(created.id, ShapeStore(s, page).apply { load() }.all.single().id)
    }

    @Test
    fun connectionSettingsSurviveTheNotebook() {
        val (s, page) = session("connection-settings")
        val store = ShapeStore(s, page)
        val a = store.create(shape("process"))
        val b = store.create(shape("process").apply { y = 400f })
        val link = store.connect(
            NoteConnection(
                fromShapeId = a.id, toShapeId = b.id, label = "是",
                fromAnchor = "bottom", toAnchor = "top", route = "straight",
                startCap = "circle", endCap = "hollow", colorHex = "#0000FF",
                lineWidth = 3f, dashStyle = "dotted"),
            a, b)!!

        val back = ShapeStore(s, page).apply { load() }.allConnections.single { it.id == link.id }
        assertEquals("bottom", back.fromAnchor)
        assertEquals("top", back.toAnchor)
        assertEquals("straight", back.route)
        assertEquals("circle", back.startCap)
        assertEquals("hollow", back.endCap)
        assertEquals("#0000FF", back.colorHex)
        assertEquals(3f, back.lineWidth, 0f)
        assertEquals("dotted", back.dashStyle)
    }

    @Test
    fun editingAConnectionAfterCreationIsPersisted() {
        // 核心的連接線物件建立之後不能改 —— 改動走中繼資料。
        val (s, page) = session("connection-edit")
        val store = ShapeStore(s, page)
        val a = store.create(shape("process"))
        val b = store.create(shape("process").apply { y = 400f })
        val link = store.connect(a, b)!!
        store.persist(link.copy(route = "straight", endCap = "diamond", colorHex = "#FF0000"))

        val back = ShapeStore(s, page).apply { load() }.allConnections.single()
        assertEquals("straight", back.route)
        assertEquals("diamond", back.endCap)
        assertEquals("#FF0000", back.colorHex)
    }

    @Test
    fun draggingFromAnAnchorOntoAnotherShapeConnectsThem() {
        val (s, page) = session("connect-drag")
        val store = ShapeStore(s, page)
        val a = store.create(shape("process"))
        val b = store.create(shape("process").apply { y = 400f })
        // 放在 b 的內部、靠近它的上緣。
        val link = store.connectByDrag(a, ShapeAnchor.BOTTOM, b.x + b.width / 2f, b.y + 6f)!!
        assertEquals(a.id, link.fromShapeId)
        assertEquals(b.id, link.toShapeId)
        assertEquals("bottom", link.fromAnchor)
        assertEquals("top", link.toAnchor)
        // 放在空白處不連。
        assertNull(store.connectByDrag(a, ShapeAnchor.RIGHT, 700f, 900f))
    }

    @Test
    fun removingAShapeRemovesItsStyleAndItsLines() {
        val (s, page) = session("remove-style")
        val store = ShapeStore(s, page)
        val a = store.create(shape("process").apply { strokeColorHex = "#FF0000" })
        val b = store.create(shape("process").apply { y = 400f })
        store.connect(a, b)
        store.remove(a)

        val back = ShapeStore(s, page).apply { load() }
        assertEquals(1, back.all.size)
        assertTrue("連著它的線也要走", back.allConnections.isEmpty())
    }

    @Test
    fun twoStoresEditingDifferentShapesDoNotOverwriteEachOther() {
        // 樣式以前放在筆記本中繼資料（整本一個暫存器）：各自載入、各改一個形狀，
        // 後寫的整包蓋掉先寫的。現在每個形狀一個信封區塊，兩個都在。
        val (s, page) = session("envelopes")
        val seed = ShapeStore(s, page)
        val a = seed.create(shape("process"))
        val b = seed.create(shape("process").apply { y = 400f })

        val deviceOne = ShapeStore(s, page).apply { load() }
        val deviceTwo = ShapeStore(s, page).apply { load() }
        deviceOne.persist(deviceOne.all.first { it.id == a.id }.copyShape().apply { strokeColorHex = "#FF0000" })
        deviceTwo.persist(deviceTwo.all.first { it.id == b.id }.copyShape().apply { fillColorHex = "#00FF00" })

        val back = ShapeStore(s, page).apply { load() }.all.associateBy { it.id }
        assertEquals("#FF0000", back.getValue(a.id).strokeColorHex)
        assertEquals("#00FF00", back.getValue(b.id).fillColorHex)
    }

    @Test
    fun styleEnvelopesAreNotLoadedAsImages() {
        val (s, page) = session("envelope-not-image")
        ShapeStore(s, page).create(shape("process").apply { strokeColorHex = "#FF0000" })
        assertTrue(com.kairumo.padnote.image.ImageStore(s, page).apply { load() }.all.isEmpty())
    }
}
