package com.kairumo.padnote.collab

import com.kairumo.padnote.ink.InkEngine
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import uniffi.padnote_core.StrokePoint
import uniffi.padnote_core.ToolKind

/** 筆畫的線上格式（設計 §8.1）—— Apple 端 `CollabStroke` 讀寫的是同一份 JSON。 */
class CollabStrokeTest {

    private val stroke = InkEngine.CompletedStroke(
        pointerId = 1uL, coreStrokeId = "s1",
        points = listOf(StrokePoint(1f, 2f, 0.5f, 0.1f, 0.2f, 1000u, 0f), StrokePoint(3f, 4f, 0.6f, 0f, 0f, 8000u, 0f)),
        tool = ToolKind.FOUNTAIN_PEN, startedAtMs = 0L,
        colorRgba = byteArrayOf(0x12, 0x34, 0x56, -1), baseWidth = 2.5f
    )

    @Test fun encodesTheSharedFormat() {
        val json = CollabStroke.encode(stroke, "w1")
        assertEquals("w1", json.getString("id"))
        assertEquals("fountain_pen", json.getString("tool")) // 與 Apple 的 toolNames 表同名
        assertEquals("#123456FF", json.getString("rgba"))
        assertEquals(14, json.getJSONArray("points").length()) // 每點 7 個數字
    }

    @Test fun roundTripsThroughJson() {
        val (id, back) = CollabStroke.decode(JSONObject(CollabStroke.encode(stroke, "w1").toString()), 0L)!!
        assertEquals("w1", id)
        assertEquals(stroke.points, back.points)
        assertEquals(ToolKind.FOUNTAIN_PEN, back.tool)
        assertEquals(stroke.colorRgba.toList(), back.colorRgba.toList())
        assertEquals(2.5f, back.baseWidth)
    }

    @Test fun readsWhatAppleWrites() {
        // Apple 送來的數字是 Double、工具名是 snake_case。
        val apple = JSONObject("""{"id":"abc","tool":"oil_paint","rgba":"#FF000080","width":4,"points":[1,2,0.5,0,0,0,0]}""")
        val (_, s) = CollabStroke.decode(apple, 0L)!!
        assertEquals(ToolKind.OIL_PAINT, s.tool)
        assertEquals(listOf(-1, 0, 0, -128).map { it.toByte() }, s.colorRgba.toList())
    }

    @Test fun carriesThePackageIdSoEveryDeviceWritesTheSameOne() {
        // Android 的線上 id 就是核心 id；Apple 的是內容雜湊，另外附 `cid`。收到的人照它寫進自己的套件。
        val core = "0f8e3c3a-2b1d-4c5e-9a7b-6d5c4b3a2f10"
        val android = CollabStroke.encode(stroke.copy(coreStrokeId = core), core)
        assertEquals(core, CollabStroke.coreId(JSONObject(android.toString())))
        val apple = JSONObject("""{"id":"ab12cd34ef56ab12cd34ef56","cid":"${core.uppercase()}","tool":"pencil","rgba":"#000000FF","width":1,"points":[0,0,0,0,0,0,0]}""")
        assertEquals(core, CollabStroke.coreId(apple))
        // 舊版 Apple：只有內容雜湊，沒有能寫進核心的 id → 由這台發新的。
        val old = JSONObject("""{"id":"ab12cd34ef56ab12cd34ef56","tool":"pencil","rgba":"#000000FF","width":1,"points":[0,0,0,0,0,0,0]}""")
        assertNull(CollabStroke.coreId(old))
    }

    @Test fun rejectsAnUnknownTool() {
        assertNull(CollabStroke.decode(JSONObject("""{"id":"x","tool":"laser","rgba":"#000000FF","width":1,"points":[0,0,0,0,0,0,0]}"""), 0L))
    }
}
