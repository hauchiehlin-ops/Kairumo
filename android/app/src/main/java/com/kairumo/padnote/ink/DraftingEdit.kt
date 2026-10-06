package com.kairumo.padnote.ink

import uniffi.padnote_core.FfiPhase
import uniffi.padnote_core.FfiPoint
import uniffi.padnote_core.FfiPolyline
import uniffi.padnote_core.FfiSheetStroke
import uniffi.padnote_core.draftArrayPolar
import uniffi.padnote_core.draftArrayRect
import uniffi.padnote_core.draftExtend
import uniffi.padnote_core.draftFillet
import uniffi.padnote_core.draftMirror
import uniffi.padnote_core.draftOffset
import uniffi.padnote_core.draftTrim
import uniffi.padnote_core.draftUnitsPerMm
import com.kairumo.padnote.L10n
import kotlin.math.hypot

/**
 * 編輯工具的觸控流程：修剪、延伸、圓角、偏移、鏡射、環形陣列（對應 Apple 的 `DraftEditController`）。
 *
 * 幾何全在核心（`draft_trim`…），這裡只管「點了哪一筆、現在第幾步」，並把結果換成筆畫
 * （沿用原筆畫的筆、顏色、圖層與線型）。每個動作都是**一次復原**。
 */
object DraftEditController {
    private var first: InkEngine.CompletedStroke? = null
    private var firstClick = InkEngine.Offset2(0f, 0f)
    private var axisStart: InkEngine.Offset2? = null

    /** 內容改了，要重畫。 */
    var onChanged: () -> Unit = {}

    fun reset(engine: InkEngine?) {
        first = null
        axisStart = null
        engine?.clearOverlay()
    }

    /** 這一步在等什麼（語系鍵）。 */
    fun hintKey(tool: DraftTool): String? = when (tool) {
        DraftTool.TRIM -> "draft_hint_trim"
        DraftTool.EXTEND -> "draft_hint_extend"
        DraftTool.FILLET -> if (first == null) "draft_hint_fillet_first" else "draft_hint_fillet_second"
        DraftTool.OFFSET -> if (first == null) "draft_hint_offset_first" else "draft_hint_offset_side"
        DraftTool.MIRROR -> if (axisStart == null) "draft_hint_mirror_first" else "draft_hint_mirror_second"
        DraftTool.ARRAY_POLAR -> "draft_hint_polar_center"
        else -> null
    }

    private fun pt(p: InkEngine.Offset2) = FfiPoint(p.x, p.y)
    private fun pts(s: InkEngine.CompletedStroke) = s.points.map { FfiPoint(it.x, it.y) }

    /** 這一次觸控有沒有出提示（出了就不要被「下一步在等什麼」蓋掉）。 */
    private var noticed = false

    private fun notice(key: String) {
        DraftingState.toolHint = L10n.t(key)
        noticed = true
    }

    private fun done(engine: InkEngine) {
        reset(engine)
        onChanged()
    }

    fun handle(phase: FfiPhase, x: Float, y: Float, tool: DraftTool, engine: InkEngine) {
        if (phase == FfiPhase.CANCELLED) {
            engine.clearOverlay()
            return
        }
        val radius = 14f / engine.toolZoom.coerceAtLeast(0.25f)
        val raw = InkEngine.Offset2(x, y)
        when (tool) {
            DraftTool.TRIM -> if (phase == FfiPhase.ENDED) trim(raw, radius, engine)
            DraftTool.EXTEND -> if (phase == FfiPhase.ENDED) extend(raw, radius, engine)
            DraftTool.FILLET -> if (phase == FfiPhase.ENDED) fillet(raw, radius, engine)
            DraftTool.OFFSET -> if (phase == FfiPhase.ENDED) offset(raw, radius, engine)
            DraftTool.MIRROR -> mirror(phase, raw, radius, engine)
            DraftTool.ARRAY_POLAR -> if (phase == FfiPhase.ENDED) polar(raw, radius, engine)
            else -> Unit
        }
        if (!noticed) DraftToolController.refreshHint()
        noticed = false
    }

    // ── 修剪 ──

    private fun trim(click: InkEngine.Offset2, radius: Float, engine: InkEngine) {
        val hit = engine.strokeNear(click.x, click.y, radius) ?: return notice("draft_edit_nothing")
        val cutters = engine.polylinesExcluding(listOf(hit))
        val pieces = draftTrim(pts(hit), cutters, pt(click)) ?: return notice("draft_edit_no_crossing")
        engine.replaceStrokes(listOf(hit), pieces.map { engine.derive(hit, it.points) })
        done(engine)
    }

    // ── 延伸 ──

    private fun extend(click: InkEngine.Offset2, radius: Float, engine: InkEngine) {
        // 點的是「端點附近」：命中半徑比一般大一點，端點好點。
        val hit = engine.strokeNear(click.x, click.y, radius * 2.2f) ?: return notice("draft_edit_nothing")
        val boundaries = engine.polylinesExcluding(listOf(hit))
        val longer = draftExtend(pts(hit), pt(click), boundaries) ?: return notice("draft_edit_no_boundary")
        engine.replaceStrokes(listOf(hit), listOf(engine.derive(hit, longer)))
        done(engine)
    }

    // ── 圓角 ──

    private fun fillet(click: InkEngine.Offset2, radius: Float, engine: InkEngine) {
        val hit = engine.strokeNear(click.x, click.y, radius) ?: return notice("draft_edit_nothing")
        val one = first
        if (one == null) {
            first = hit
            firstClick = click
            engine.setOverlay(emptyList(), listOf(click))
            return
        }
        if (hit === one) return
        val r = DraftingState.filletRadiusMm.toFloat() * draftUnitsPerMm()
        val f = draftFillet(pts(one), pts(hit), r, pt(firstClick), pt(click))
        if (f == null) {
            reset(engine)
            return notice("draft_edit_fillet_fail")
        }
        engine.replaceStrokes(
            listOf(one, hit),
            listOf(engine.derive(one, f.a), engine.derive(hit, f.b), engine.derive(one, f.arc)))
        done(engine)
    }

    // ── 偏移 ──

    private fun offset(click: InkEngine.Offset2, radius: Float, engine: InkEngine) {
        val one = first
        if (one == null) {
            val hit = engine.strokeNear(click.x, click.y, radius) ?: return notice("draft_edit_nothing")
            first = hit
            firstClick = click
            engine.setOverlay(emptyList(), listOf(click))
            return
        }
        val distance = DraftingState.offsetDistanceMm.toFloat() * draftUnitsPerMm()
        val moved = draftOffset(pts(one), distance, pt(click))
        if (moved == null) {
            reset(engine)
            return notice("draft_edit_offset_fail")
        }
        // 偏移是**多一條**平行線，原來那條留著。
        engine.insertCopies(listOf(engine.derive(one, moved)))
        done(engine)
    }

    // ── 鏡射 ──

    private fun mirrored(chosen: List<InkEngine.CompletedStroke>, a: InkEngine.Offset2, b: InkEngine.Offset2, engine: InkEngine) =
        chosen.map { engine.moved(it, draftMirror(pts(it), pt(a), pt(b))) }

    private fun preview(strokes: List<InkEngine.CompletedStroke>, marks: List<InkEngine.Offset2>, engine: InkEngine) {
        engine.setOverlay(
            strokes.map { s ->
                FfiSheetStroke(
                    s.points.map { FfiPoint(it.x, it.y) }, s.layer.toUByte(), s.lineType.toUByte(), s.baseWidth,
                    hex(s.colorRgba))
            }, marks)
    }

    private fun hex(rgba: ByteArray): String =
        if (rgba.size < 3) "#000000"
        else "#%02X%02X%02X".format(rgba[0].toInt() and 0xFF, rgba[1].toInt() and 0xFF, rgba[2].toInt() and 0xFF)

    private fun mirror(phase: FfiPhase, raw: InkEngine.Offset2, radius: Float, engine: InkEngine) {
        val chosen = engine.strokesByCoreIds(DraftingState.editSelection)
        if (chosen.isEmpty()) {
            if (phase == FfiPhase.ENDED) notice("draft_edit_need_selection")
            return
        }
        val a = axisStart
        if (a == null) {
            if (phase != FfiPhase.ENDED) return
            val start = engine.snapAnchor(raw.x, raw.y, radius) ?: raw
            axisStart = start
            engine.setOverlay(emptyList(), listOf(start))
            return
        }
        val b = engine.snapAnchor(raw.x, raw.y, radius) ?: raw
        if (hypot(b.x - a.x, b.y - a.y) <= 2f) {
            if (phase == FfiPhase.ENDED) reset(engine)
            return
        }
        when (phase) {
            FfiPhase.BEGAN, FfiPhase.MOVED -> preview(mirrored(chosen, a, b, engine), listOf(a, b), engine)
            FfiPhase.ENDED -> {
                engine.insertCopies(mirrored(chosen, a, b, engine))
                done(engine)
            }
            else -> Unit
        }
    }

    // ── 陣列 ──

    /** 矩形陣列：直接套用在選取的筆畫上。回傳做出幾份複本（0 = 沒東西可做）。 */
    fun applyRectArray(rows: Int, cols: Int, dxMm: Double, dyMm: Double, engine: InkEngine): Int {
        val chosen = engine.strokesByCoreIds(DraftingState.editSelection)
        if (chosen.isEmpty()) return 0
        val unit = draftUnitsPerMm()
        val made = chosen.flatMap { s ->
            draftArrayRect(pts(s), rows.coerceAtLeast(1).toUInt(), cols.coerceAtLeast(1).toUInt(),
                (dxMm * unit).toFloat(), (dyMm * unit).toFloat()).map { engine.moved(s, it.points) }
        }
        val n = engine.insertCopies(made)
        onChanged()
        return n
    }

    private fun polar(click: InkEngine.Offset2, radius: Float, engine: InkEngine) {
        val chosen = engine.strokesByCoreIds(DraftingState.editSelection)
        if (chosen.isEmpty()) return notice("draft_edit_need_selection")
        val center = engine.snapAnchor(click.x, click.y, radius) ?: click
        val made = chosen.flatMap { s ->
            draftArrayPolar(pts(s), pt(center), DraftingState.polarCount.coerceAtLeast(1).toUInt(),
                DraftingState.polarTotalDeg.toFloat()).map { engine.moved(s, it.points) }
        }
        engine.insertCopies(made)
        done(engine)
    }
}
