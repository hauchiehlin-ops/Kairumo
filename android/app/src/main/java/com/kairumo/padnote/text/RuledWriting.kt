package com.kairumo.padnote.text

import uniffi.padnote_core.FfiGuide
import uniffi.padnote_core.FfiGuideKind
import uniffi.padnote_core.FfiTextureBand
import uniffi.padnote_core.FfiTextureKind
import uniffi.padnote_core.PageStyle
import uniffi.padnote_core.pageGuides
import uniffi.padnote_core.pageTexture
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.round

/**
 * 橫線紙上的「即點即書」擺放。與 Apple 端 `RuledWriting.swift` 是同一套規則：
 * 文字坐在格線上、一行一行對著格線寫；沒有格線的紙張則以點的位置為第一行的垂直中心。
 */
object RuledWriting {

    /** 方塊內距。固定為完整值，不隨方塊大小變。 */
    val padding: Float get() = TEXT_BOX_PADDING

    /** 方塊高度下限：不小於這個高度，內距才不會縮。 */
    const val FULL_PADDING_HEIGHT = 60f

    /** 可列印邊界（與 Apple `PageGeometry.printableInset` 相同）。 */
    const val PRINTABLE_INSET = 24f

    data class Placement(
        /** 方塊頂端 y。 */
        val top: Float,
        /** 字級（格線間距太小放不下原字級時會縮）。 */
        val fontSize: Float,
        /** 額外行距，讓每一行的基準線都落在格線上。 */
        val lineSpacing: Float,
        /** 這個位置的格線 y（第一行基準線所在）。 */
        val rule: Float,
        /** 格線間距。沒有格線時為字體行高。 */
        val step: Float
    )

    /** 這一頁所有水平格線的 y，由上到下、去掉重複。導引線與底紋都要收。 */
    fun horizontalRules(guides: List<FfiGuide>, bands: List<FfiTextureBand>): List<Float> {
        val ys = ArrayList<Float>()
        for (g in guides) {
            if (g.kind == FfiGuideKind.LINE && abs(g.h) < 1f && g.w > 50f) ys.add(g.y)
        }
        for (b in bands) {
            if (b.kind == FfiTextureKind.LINE && abs(b.h) < 1f && b.w > 50f) {
                for (i in 0 until b.count.toInt()) for (j in 0 until b.count2.toInt()) {
                    ys.add(b.y + b.stepY * i + b.step2Y * j)
                }
            }
        }
        return dedupe(ys)
    }

    /** 讀核心的版面與底紋，收出這一頁的水平格線。 */
    fun pageRules(paperId: String, style: PageStyle, pageWidth: Float, pageHeight: Float): List<Float> {
        val guides = runCatching { pageGuides(paperId, pageWidth, pageHeight) }.getOrNull() ?: emptyList()
        val bands = runCatching { pageTexture(paperId, style, pageWidth, pageHeight) }.getOrNull() ?: emptyList()
        return horizontalRules(guides, bands)
    }

    fun dedupe(values: List<Float>, tolerance: Float = 0.75f): List<Float> {
        val out = ArrayList<Float>()
        for (y in values.sorted()) if (out.isEmpty() || y - out.last() > tolerance) out.add(y)
        return out
    }

    /** 格線間距：相鄰間距的中位數。太少或太不規則（不像橫線紙）回 null。 */
    fun step(rules: List<Float>): Float? {
        if (rules.size < 3) return null
        val gaps = rules.zipWithNext { a, b -> b - a }.filter { it > 6f }.sorted()
        if (gaps.isEmpty()) return null
        val median = gaps[gaps.size / 2]
        return if (median in 14f..80f) median else null
    }

    fun lineHeight(fontSize: Float): Float = fontSize * 1.2f

    /** 第一行文字底部距方塊頂端的偏移量（內距 + 行高 + 2 微調底距）。 */
    fun textBottomOffset(fontSize: Float): Float = padding + lineHeight(fontSize) + 2f

    /** 點在兩條線之間就寫在下面那一條；剛好點在線下一點點（不到間距 30%）算那一條。 */
    fun ruleForTap(tapY: Float, rules: List<Float>, step: Float): Float? =
        rules.firstOrNull { it >= tapY - step * 0.3f } ?: rules.lastOrNull()

    /** 橫線紙上的擺放。不像橫線紙時回 null，由呼叫端改用自由擺放。 */
    fun placement(tapY: Float, rules: List<Float>, fontSize: Float, minTop: Float): Placement? {
        val step = step(rules) ?: return null
        var size = fontSize
        while (lineHeight(size) > step && size > 9f) size -= 1f
        val natural = lineHeight(size)
        val bottomOffset = textBottomOffset(size)
        var rule = ruleForTap(tapY, rules, step) ?: return null
        while (rule - bottomOffset < minTop) {
            rule = rules.firstOrNull { it > rule + 0.5f } ?: break
        }
        return Placement(rule - bottomOffset, size, max(0f, step - natural), rule, step)
    }

    /** 沒有格線（空白紙）的擺放：點的位置就是第一行文字的垂直中心。 */
    fun freePlacement(tapY: Float, fontSize: Float, minTop: Float): Placement {
        val natural = lineHeight(fontSize)
        val top = max(minTop, tapY - padding - natural / 2f)
        return Placement(top, fontSize, 0f, top + textBottomOffset(fontSize), natural)
    }

    /** 內容需要的方塊高度（含上下內距，不小於 [FULL_PADDING_HEIGHT]）。[contentHeight] 是文字本身的高度。 */
    fun boxHeight(contentHeight: Float): Float = max(FULL_PADDING_HEIGHT, kotlin.math.ceil(contentHeight) + 2f * padding + 8f)

    /** 拖曳／放置文字方塊時的 y 吸附：第一行底部坐在最近的格線上，沒有格線或離得遠就吸附 20 步進。 */
    fun snapY(y: Float, rules: List<Float>, fontSize: Float): Float {
        val offset = textBottomOffset(fontSize)
        val targetBottom = y + offset
        val nearest = rules.minByOrNull { abs(it - targetBottom) }
        if (nearest != null && abs(nearest - targetBottom) < 50f) {
            return max(PRINTABLE_INSET, nearest - offset)
        }
        return round(y / 20f) * 20f
    }

    /** 方塊可用寬度：左半邊以中線為界（要有像樣的寬度才成立），否則延伸到可列印右緣。 */
    fun availableWidth(startX: Float, pageWidth: Float, minWidth: Float): Float {
        val maxX = pageWidth - PRINTABLE_INSET
        val midX = pageWidth / 2f
        return if (startX < midX - 30f && maxX > midX && midX - startX - 12f >= 200f)
            max(minWidth, midX - startX - 12f) else max(minWidth, maxX - startX)
    }

    internal fun clampTop(top: Float, height: Float, pageHeight: Float, tapToWrite: Boolean): Float =
        if (tapToWrite) max(PRINTABLE_INSET - padding, min(top, pageHeight - PRINTABLE_INSET - height))
        else max(PRINTABLE_INSET, min(top, pageHeight - PRINTABLE_INSET - 40f))
}
