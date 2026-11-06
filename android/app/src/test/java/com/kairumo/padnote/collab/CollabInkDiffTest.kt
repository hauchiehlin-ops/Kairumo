package com.kairumo.padnote.collab

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 回報：Android 加入房主的房間後，房主兩頁的筆跡瞬間被清空。原因是換頁／加頁時新引擎還沒從套件讀完，
 * 比對把「已知但引擎上沒有」的整頁筆畫當成擦除送出。這裡鎖住修正後的規則。
 */
class CollabInkDiffTest {
    private val hostStrokes = setOf("a", "b", "c")

    @Test
    fun freshEngineNeverErases() {
        // 新引擎第一次比對（還沒有上一次）：手上是空的也不算擦掉任何東西。
        assertTrue(CollabInkDiff.removed(hostStrokes, emptySet(), previous = null).isEmpty())
        // 已知的筆畫留著（不重送、也不擦）。
        assertEquals(hostStrokes, CollabInkDiff.nextKnown(hostStrokes, emptySet(), emptySet()))
    }

    @Test
    fun strokesTheEngineNeverHadAreNotErased() {
        // 引擎只讀到 a（其餘因競態沒進來）：b、c 不是這台擦的。
        val removed = CollabInkDiff.removed(hostStrokes, setOf("a"), previous = setOf("a"))
        assertTrue(removed.isEmpty())
    }

    @Test
    fun realEraseIsReported() {
        // 上一次引擎上有 a、b，現在 b 沒了：這才是擦除。
        val removed = CollabInkDiff.removed(hostStrokes, setOf("a"), previous = setOf("a", "b"))
        assertEquals(setOf("b"), removed)
        assertEquals(setOf("a", "c"), CollabInkDiff.nextKnown(hostStrokes, setOf("a"), removed))
    }

    @Test
    fun newStrokesBecomeKnown() {
        val next = CollabInkDiff.nextKnown(hostStrokes, setOf("a", "b", "c", "d"), emptySet())
        assertEquals(setOf("a", "b", "c", "d"), next)
    }
}
