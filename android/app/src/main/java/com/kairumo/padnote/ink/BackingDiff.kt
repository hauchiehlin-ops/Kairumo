package com.kairumo.padnote.ink

/**
 * 已烘焙的筆畫序列與目前序列的差異（對應 Apple `ProInkLayerView.patchRegion` 的判斷）。
 *
 * 擦掉一筆或把一筆放回來時，序列只差「被拿掉／插進來」的幾筆、其餘相對順序不變 ——
 * 這時只需要重畫那幾筆的範圍，不必把整頁幾百筆重貼一遍。其餘情況（換序、替換、差太多）回 `null`，整頁重建。
 */
internal object BackingDiff {
    class Diff<T>(val removed: List<T>, val inserted: List<T>)

    fun <T> diff(baked: List<T>, current: List<T>, maxChanges: Int = 8, same: (T, T) -> Boolean): Diff<T>? {
        if (baked.size == current.size) return null
        val removal = current.size < baked.size
        val longer = if (removal) baked else current
        val shorter = if (removal) current else baked
        var j = 0
        val differing = ArrayList<T>()
        for (item in longer) {
            if (j < shorter.size && same(shorter[j], item)) j++ else differing.add(item)
        }
        if (j != shorter.size || differing.isEmpty() || differing.size > maxChanges) return null
        return if (removal) Diff(removed = differing, inserted = emptyList())
        else Diff(removed = emptyList(), inserted = differing)
    }
}
