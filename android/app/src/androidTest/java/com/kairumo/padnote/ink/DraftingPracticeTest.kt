package com.kairumo.padnote.ink

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.kairumo.padnote.L10n
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import uniffi.padnote_core.FfiPoint
import uniffi.padnote_core.FfiProblemLine
import uniffi.padnote_core.FfiSheetStroke

/**
 * 練習題：出題、批改、標記、看答案。走真正的核心題庫與批改，對應 Apple 的 `DraftingPracticeTests`。
 */
@RunWith(AndroidJUnit4::class)
class DraftingPracticeTest {
    private lateinit var engine: InkEngine
    private val pageW = 1600f
    private val pageH = 1132f

    @Before
    fun setUp() {
        val ctx = InstrumentationRegistry.getInstrumentation().targetContext
        DraftingState.attach(ctx)
        DraftingState.use("practice-test-${System.nanoTime()}")
        DraftingState.selectTool(DraftTool.NONE)
        engine = InkEngine()
        PracticeSession.end(null)
    }

    @After
    fun tearDown() {
        PracticeSession.end(engine)
        DraftingState.selectTool(DraftTool.NONE)
    }

    /** 學生用製圖筆（頂層）把這些線畫上去：粗實線 2.6、隱藏線 1.4、細線 1.2、中心線 1.1。 */
    private fun draw(lines: List<FfiProblemLine>, mutate: (Int, FfiProblemLine) -> FfiProblemLine = { _, l -> l }) {
        val items = lines.mapIndexed { i, raw ->
            val l = mutate(i, raw)
            val type = l.lineType.toInt()
            val width = when {
                type == 1 -> 1.4f
                type == 2 -> 1.1f
                l.thin -> 1.2f
                else -> 2.6f
            }
            FfiSheetStroke(listOf(l.a, l.b), 3u, type.toUByte(), width, "#111827")
        }
        engine.insertDrafted(items, 0f, 0f)
    }

    private fun start(kind: String, seed: ULong = 7uL) =
        PracticeSession.start(kind, seed, engine, pageW, pageH)

    @Test
    fun startingAProblemPutsTheGivenLinesOnTheBottomLayerAndShowsThePrompt() {
        for (kind in listOf("complete_view", "iso_to_views", "section", "angle_judgement", "spot_error")) {
            engine = InkEngine()
            assertTrue(kind, start(kind))
            val p = PracticeSession.problem!!
            assertEquals(kind, p.kind)
            assertEquals("題目線都在底層", p.given.size, engine.strokes.size)
            assertTrue(engine.strokes.all { it.layer == 1 })
            assertEquals(L10n.t("draft_prob_prompt_$kind"), DraftingState.toolHint)
            assertTrue(PracticeSession.isActive)
        }
        assertFalse("認不得的題型不開始", PracticeSession.start("nope", 1uL, engine, pageW, pageH))
    }

    @Test
    fun theSameSeedGivesTheSameProblemOnEveryDevice() {
        start("complete_view", 99uL)
        val first = PracticeSession.problem!!.given.map { it.a.x to it.a.y }
        PracticeSession.end(engine)
        engine = InkEngine()
        start("complete_view", 99uL)
        assertEquals(first, PracticeSession.problem!!.given.map { it.a.x to it.a.y })
    }

    @Test
    fun drawingTheModelAnswerScoresAHundredAndMarksNothing() {
        for (kind in listOf("complete_view", "iso_to_views", "section")) {
            engine = InkEngine()
            start(kind)
            draw(PracticeSession.problem!!.answer)
            val s = PracticeSession.grade(engine)!!
            assertEquals("$kind 標準答案要滿分", 100, s.score)
            assertTrue(kind, s.perfect)
            assertTrue("沒有問題就沒有標記", engine.overlayStrokes.isEmpty())
        }
    }

    @Test
    fun anEmptyPageScoresLowAndMarksEveryMissingLine() {
        start("complete_view")
        val s = PracticeSession.grade(engine)!!
        assertTrue(s.score < 50)
        assertTrue(s.missing > 0)
        assertEquals("每條缺的線都標出來", s.missing, engine.overlayStrokes.size)
        assertFalse(s.perfect)
    }

    @Test
    fun aMissingLineAWrongTypeAndAnExtraLineAreEachReported() {
        // 少一條。
        start("complete_view")
        var answer = PracticeSession.problem!!.answer
        draw(answer.drop(1))
        assertEquals(1, PracticeSession.grade(engine)!!.missing)

        // 線型錯：把一條實線畫成隱藏線。
        engine = InkEngine()
        start("complete_view")
        answer = PracticeSession.problem!!.answer
        val solid = answer.indexOfFirst { it.lineType.toInt() == 0 && !it.thin }
        draw(answer) { i, l -> if (i == solid) FfiProblemLine(l.a, l.b, 1u, false) else l }
        val t = PracticeSession.grade(engine)!!
        assertEquals(1, t.wrongType)
        assertEquals(0, t.missing)

        // 多一條。
        engine = InkEngine()
        start("complete_view")
        draw(PracticeSession.problem!!.answer)
        val area = PracticeSession.problem!!.answerArea!!
        draw(listOf(FfiProblemLine(FfiPoint(area.x + 10f, area.y + 12f), FfiPoint(area.x + area.w - 10f, area.y + area.h - 12f), 0u, false)))
        val e = PracticeSession.grade(engine)!!
        assertEquals(1, e.extra)
        assertEquals(1, engine.overlayStrokes.size)
    }

    @Test
    fun aShiftedAnswerIsMisalignedNotMissingAndExtra() {
        start("complete_view")
        val shifted = PracticeSession.problem!!.answer.map { FfiProblemLine(FfiPoint(it.a.x + 9f, it.a.y), FfiPoint(it.b.x + 9f, it.b.y), it.lineType, it.thin) }
        draw(shifted)
        val s = PracticeSession.grade(engine)!!
        assertTrue("垂直的邊要報沒對齊：$s", s.misaligned >= 2)
        assertEquals(0, s.extra)
    }

    @Test
    fun theSectionNeedsHatchingAtTheRightAngle() {
        start("section")
        val answer = PracticeSession.problem!!.answer
        // 沒畫剖面線。
        draw(answer.filter { !it.thin })
        assertTrue(PracticeSession.grade(engine)!!.hatchMissing)
        // 畫了但轉 90°：每條剖面線換成垂直的。
        engine = InkEngine()
        start("section")
        val a2 = PracticeSession.problem!!.answer
        draw(a2) { _, l ->
            if (l.thin) {
                // 轉成垂直、從原線中點上下各半個 0.35 倍長度：還在作答範圍內，長度也夠，
                // 所以報的是「角度不對」而不是「畫太少」。
                val len = kotlin.math.hypot(l.b.x - l.a.x, l.b.y - l.a.y) * 0.35f
                val mx = (l.a.x + l.b.x) / 2f
                val my = (l.a.y + l.b.y) / 2f
                FfiProblemLine(FfiPoint(mx, my - len), FfiPoint(mx, my + len), l.lineType, true)
            } else l
        }
        assertTrue(PracticeSession.grade(engine)!!.hatchAngle)
    }

    @Test
    fun linesOutsideTheAnswerAreaAndOnOtherLayersAreIgnored() {
        start("complete_view")
        val answer = PracticeSession.problem!!.answer
        draw(answer)
        // 在作答範圍外多畫一條：不算。
        draw(listOf(FfiProblemLine(FfiPoint(30f, 30f), FfiPoint(300f, 30f), 0u, false)))
        assertEquals(100, PracticeSession.grade(engine)!!.score)
    }

    @Test
    fun showAnswerDrawsTheModelAnswerAsAnOverlayOnly() {
        start("complete_view")
        val before = engine.strokes.size
        PracticeSession.showAnswer(engine)
        assertEquals(PracticeSession.problem!!.answer.size, engine.overlayStrokes.size)
        assertTrue(PracticeSession.answerShown)
        assertEquals("看答案不改內容", before, engine.strokes.size)
        PracticeSession.clearMarks(engine)
        assertTrue(engine.overlayStrokes.isEmpty())
    }

    @Test
    fun theAngleQuestionAcceptsOnlyTheRightChoice() {
        for (seed in 1uL..6uL) {
            engine = InkEngine()
            start("angle_judgement", seed)
            val p = PracticeSession.problem!!
            val right = p.correct!!.toInt()
            PracticeSession.choose(1 - right)
            assertEquals(L10n.t("draft_prob_choice_wrong"), PracticeSession.feedback)
            PracticeSession.choose(right)
            assertEquals(L10n.t("draft_prob_choice_right"), PracticeSession.feedback)
        }
    }

    @Test
    fun spotTheErrorNeedsTheKindAndThePlace() {
        start("spot_error", 5uL)
        val p = PracticeSession.problem!!
        val at = p.errorAt!!
        val right = p.correct!!.toInt()
        // 選對種類之後進入「點位置」。
        PracticeSession.choose(right)
        assertEquals(DraftTool.PROBLEM_SPOT, DraftingState.tool)
        assertEquals(L10n.t("draft_prob_spot_tap"), PracticeSession.feedback)
        // 點得很遠：不對，並圈出正確的位置。
        PracticeSession.spot(at.x + 400f, at.y, engine)
        assertEquals(L10n.t("draft_prob_spot_wrong"), PracticeSession.feedback)
        assertEquals(1, engine.overlayStrokes.size)
        assertEquals(DraftTool.NONE, DraftingState.tool)
        // 再選一次、點對。
        PracticeSession.choose(right)
        PracticeSession.spot(at.x + 10f, at.y - 8f, engine)
        assertEquals(L10n.t("draft_prob_spot_right"), PracticeSession.feedback)
        // 位置對、種類錯：不算對。
        PracticeSession.choose((right + 1) % 4)
        PracticeSession.spot(at.x, at.y, engine)
        assertEquals(L10n.t("draft_prob_spot_wrong"), PracticeSession.feedback)
    }

    @Test
    fun theSpotToolRoutesTapsThroughTheToolController() {
        start("spot_error", 5uL)
        val p = PracticeSession.problem!!
        PracticeSession.choose(p.correct!!.toInt())
        engine.onToolTouch = { phase, x, y -> DraftToolController.handle(phase, x, y, engine) }
        DraftToolController.handle(uniffi.padnote_core.FfiPhase.BEGAN, p.errorAt!!.x, p.errorAt!!.y, engine)
        DraftToolController.handle(uniffi.padnote_core.FfiPhase.ENDED, p.errorAt!!.x, p.errorAt!!.y, engine)
        assertEquals(L10n.t("draft_prob_spot_right"), PracticeSession.feedback)
    }

    @Test
    fun endingThePracticeClearsEverything() {
        start("complete_view")
        PracticeSession.grade(engine)
        PracticeSession.end(engine)
        assertFalse(PracticeSession.isActive)
        assertEquals(null, PracticeSession.summary)
        assertTrue(engine.overlayStrokes.isEmpty())
        assertNotNull(engine.strokes.firstOrNull { it.layer == 1 })   // 題目線是頁面內容，留著
    }

    @Test
    fun theGivenLinesUndoAsOneAction() {
        start("complete_view")
        assertTrue(engine.strokes.isNotEmpty())
        assertTrue(engine.undo())
        assertEquals(0, engine.strokes.size)
    }
}
