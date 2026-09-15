package com.kairumo.padnote.canvas

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * 堆疊順序的規則測試。
 *
 * **每一項都對應 Apple 端跑過的同一組案例** —— 兩邊的搬移規則差一點，
 * 同一份筆記在兩個平台的疊放結果就不同，而順序是會同步的。
 */
class ObjectStackingTest {

    private val order = listOf("a", "b", "c", "d")

    @Test fun bringForwardMovesOneUp() =
        assertEquals(listOf("a", "c", "b", "d"), ObjectStacking.bringForward(setOf("b"), order))

    @Test fun sendBackwardMovesOneDown() =
        assertEquals(listOf("a", "c", "b", "d"), ObjectStacking.sendBackward(setOf("c"), order))

    @Test fun bringToFrontGoesLast() =
        assertEquals(listOf("b", "c", "d", "a"), ObjectStacking.bringToFront(setOf("a"), order))

    @Test fun sendToBackGoesFirst() =
        assertEquals(listOf("d", "a", "b", "c"), ObjectStacking.sendToBack(setOf("d"), order))

    @Test fun topStaysPut() =
        assertEquals(order, ObjectStacking.bringForward(setOf("d"), order))

    @Test fun bottomStaysPut() =
        assertEquals(order, ObjectStacking.sendBackward(setOf("a"), order))

    /** 多選要保持彼此的相對順序，不能取決於集合的迭代順序。 */
    @Test fun multiSelectKeepsRelativeOrder() =
        assertEquals(listOf("b", "d", "a", "c"), ObjectStacking.bringToFront(setOf("c", "a"), order))

    @Test fun multiSelectMovesAsAGroup() =
        assertEquals(listOf("c", "a", "b", "d"), ObjectStacking.bringForward(setOf("a", "b"), order))

    /** 一整組一起往上，遇到頂就整組停 —— 不可以拆散。 */
    @Test fun groupStopsAtTop() =
        assertEquals(order, ObjectStacking.bringForward(setOf("c", "d"), order))

    @Test fun groupStopsAtBottom() =
        assertEquals(order, ObjectStacking.sendBackward(setOf("a", "b"), order))

    @Test fun selectingEverythingChangesNothing() =
        assertEquals(order, ObjectStacking.bringForward(setOf("a", "b", "c", "d"), order))

    /** 刪掉的物件要從順序裡剔除，否則清單會無限長大。 */
    @Test fun normalizedDropsMissingAndAppendsNew() {
        val items = listOf(
            ObjectStacking.Item("b", ObjectStacking.Kind.TEXT, ""),
            ObjectStacking.Item("z", ObjectStacking.Kind.IMAGE, "")
        )
        assertEquals(listOf("b", "z"), ObjectStacking.normalized(items, order))
    }

    /** 沒排過的物件排在排過的之上，並照型別預設分層（圖片在文字下面）。 */
    @Test fun unorderedFollowsTypeDefaults() {
        val items = listOf(
            ObjectStacking.Item("t", ObjectStacking.Kind.TEXT, ""),
            ObjectStacking.Item("i", ObjectStacking.Kind.IMAGE, "")
        )
        assertEquals(listOf("i", "t"), ObjectStacking.normalized(items, emptyList()))
    }
}
