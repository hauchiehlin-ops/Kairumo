package com.kairumo.padnote.ink

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kairumo.padnote.L10n
import uniffi.padnote_core.FfiDrawnStroke
import uniffi.padnote_core.FfiIssueKind
import uniffi.padnote_core.FfiPoint
import uniffi.padnote_core.FfiProblem
import uniffi.padnote_core.FfiProblemLine
import uniffi.padnote_core.FfiSheetStroke
import uniffi.padnote_core.draftCheckChoice
import uniffi.padnote_core.draftCheckError
import uniffi.padnote_core.draftGrade
import uniffi.padnote_core.draftProblem
import uniffi.padnote_core.draftProblemIsDrawing

/**
 * 練習題（對應 Apple 的 `PracticeSession`）：出題、批改、標記、看答案。
 *
 * 題目與標準答案全在核心（`draft_problem`、`draft_grade`）—— 同一個種子在兩個平台產生同一題、
 * 同一份答案批出同一個分數。這裡只管把題目線放進頁面、把學生畫的線交給核心批改、把結果標在畫面上。
 */
object PracticeSession {
    /** 批改摘要：各種問題的條數與分數。 */
    data class Summary(
        val score: Int = 0,
        val missing: Int = 0,
        val extra: Int = 0,
        val wrongType: Int = 0,
        val misaligned: Int = 0,
        val hatchMissing: Boolean = false,
        val hatchAngle: Boolean = false
    ) {
        val perfect: Boolean get() = missing + extra + wrongType + misaligned == 0 && !hatchMissing && !hatchAngle
    }

    var problem by mutableStateOf<FfiProblem?>(null)
        private set
    var summary by mutableStateOf<Summary?>(null)
        private set
    /** 選擇題／挑錯題的回饋（已翻成使用者語言）。 */
    var feedback by mutableStateOf<String?>(null)
        private set
    /** 挑錯題：已選的錯誤種類（選完要再點位置）。 */
    var pickedKind by mutableStateOf<Int?>(null)
        private set
    var answerShown by mutableStateOf(false)
        private set

    private var pageW = 1600f
    private var pageH = 1132f

    val isActive: Boolean get() = problem != null
    val isDrawing: Boolean get() = problem?.let { draftProblemIsDrawing(it.kind) } ?: false

    /** 核心的線 → 頁面筆畫。`width` 為 null 用該線型的標準寬。 */
    private fun sheet(line: FfiProblemLine, color: String, width: Float?, layer: Int, dashed: Boolean = false): FfiSheetStroke {
        val w = width ?: if (line.lineType.toInt() == 1) 1.4f else if (line.thin) 1.2f else 1.8f
        return FfiSheetStroke(
            listOf(line.a, line.b), layer.toUByte(), (if (dashed) 1 else line.lineType.toInt()).toUByte(), w, color)
    }

    /** 出一題（[seed] 為 null 就隨機），把題目線放進頁面。回傳有沒有成功。 */
    fun start(kind: String, seed: ULong?, engine: InkEngine, pageWidth: Float, pageHeight: Float): Boolean {
        pageW = pageWidth
        pageH = pageHeight
        val s = seed ?: (1..999_999).random().toULong()
        val p = draftProblem(kind, s, pageWidth, pageHeight) ?: return false
        engine.clearOverlay()
        problem = p
        summary = null
        feedback = null
        pickedKind = null
        answerShown = false
        DraftingState.ensureVisible(1)
        engine.insertDrafted(p.given.map { sheet(it, "#374151", null, 1) }, 0f, 0f)
        DraftingState.toolHint = L10n.t("draft_prob_prompt_$kind")
        return true
    }

    fun end(engine: InkEngine?) {
        engine?.clearOverlay()
        problem = null
        summary = null
        feedback = null
        pickedKind = null
        answerShown = false
        if (DraftingState.tool == DraftTool.PROBLEM_SPOT) DraftingState.selectTool(DraftTool.NONE)
    }

    /** 把頁面上學生畫的線交給核心批改，並把問題標在畫面上。 */
    fun grade(engine: InkEngine): Summary? {
        val p = problem ?: return null
        if (!isDrawing) return null
        val strokes = engine.strokes.map { s ->
            FfiDrawnStroke(s.layer.toUByte(), s.lineType.toUByte(), s.baseWidth, s.points.map { FfiPoint(it.x, it.y) })
        }
        val g = draftGrade(p.kind, p.seed, pageW, pageH, strokes) ?: return null
        var sum = Summary(score = g.score.toInt())
        val marks = mutableListOf<FfiSheetStroke>()
        for (issue in g.issues) {
            val line = issue.line
            when (issue.kind) {
                FfiIssueKind.MISSING -> {
                    sum = sum.copy(missing = sum.missing + 1)
                    if (line != null) marks += sheet(line, "#F97316", 2.6f, 3, dashed = true)
                }
                FfiIssueKind.EXTRA -> {
                    sum = sum.copy(extra = sum.extra + 1)
                    if (line != null) marks += sheet(line, "#DC2626", 5f, 3)
                }
                FfiIssueKind.WRONG_TYPE -> {
                    sum = sum.copy(wrongType = sum.wrongType + 1)
                    if (line != null) marks += sheet(line, "#EAB308", 5f, 3)
                }
                FfiIssueKind.MISALIGNED -> {
                    sum = sum.copy(misaligned = sum.misaligned + 1)
                    if (line != null) marks += sheet(line, "#2563EB", 2.6f, 3, dashed = true)
                }
                FfiIssueKind.HATCH_MISSING -> sum = sum.copy(hatchMissing = true)
                FfiIssueKind.HATCH_ANGLE -> sum = sum.copy(hatchAngle = true)
            }
        }
        summary = sum
        answerShown = false
        engine.setOverlay(marks, emptyList())
        return sum
    }

    /** 標準答案畫成綠色疊層（不存檔、不進復原）。 */
    fun showAnswer(engine: InkEngine) {
        val p = problem ?: return
        if (!isDrawing) return
        engine.setOverlay(p.answer.map { sheet(it, "#16A34A", 2.2f, 3) }, emptyList())
        answerShown = true
    }

    fun clearMarks(engine: InkEngine?) {
        engine?.clearOverlay()
        answerShown = false
    }

    /** 選了第 [index] 個選項。判斷題直接給結果；挑錯題先記下種類，接著要點位置。 */
    fun choose(index: Int) {
        val p = problem ?: return
        if (p.kind == "spot_error") {
            pickedKind = index
            feedback = L10n.t("draft_prob_spot_tap")
            DraftingState.selectTool(DraftTool.PROBLEM_SPOT)
            DraftingState.toolHint = L10n.t("draft_prob_spot_tap")
            return
        }
        val ok = draftCheckChoice(p.kind, p.seed, pageW, pageH, index.toUInt())
        feedback = L10n.t(if (ok) "draft_prob_choice_right" else "draft_prob_choice_wrong")
    }

    /** 挑錯題：在 (x, y) 點了一下。種類與位置都對才算對；不對就把正確的地方圈出來。 */
    fun spot(x: Float, y: Float, engine: InkEngine) {
        val p = problem ?: return
        val picked = pickedKind ?: return
        if (p.kind != "spot_error") return
        val ok = draftCheckError(p.seed, pageW, pageH, picked.toUInt(), FfiPoint(x, y), 40f)
        feedback = L10n.t(if (ok) "draft_prob_spot_right" else "draft_prob_spot_wrong")
        p.errorAt?.let { at ->
            val ring = (0..32).map { i ->
                val a = i.toFloat() / 32 * 2 * Math.PI.toFloat()
                FfiPoint(at.x + 28f * kotlin.math.cos(a), at.y + 28f * kotlin.math.sin(a))
            }
            engine.setOverlay(
                listOf(FfiSheetStroke(ring, 3u, 0u, 3f, if (ok) "#16A34A" else "#DC2626")), emptyList())
        }
        DraftingState.selectTool(DraftTool.NONE)
    }
}

/** 練習進行中浮在畫布上的小卡：題目提示、選項、批改結果與動作。 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun PracticeCard(engine: InkEngine, onNew: () -> Unit, modifier: Modifier = Modifier) {
    val p = PracticeSession.problem ?: return
    fun t(key: String) = L10n.t(key)
    fun fill(key: String, vararg values: String): String {
        var text = t(key)
        values.forEachIndexed { i, v -> text = text.replace("%${i + 1}@", v) }
        return text
    }
    Column(
        modifier
            .widthIn(max = 420.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.96f))
            .padding(12.dp)
            .testTag("draft.practice.card"),
        verticalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        Row(horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.padding(0.dp)) {
            Text(t("draft_prob_kind_${p.kind}"), fontSize = 14.sp, style = MaterialTheme.typography.titleSmall)
            TextButton(
                onClick = { PracticeSession.end(engine) },
                modifier = Modifier.testTag("draft.practice.close").semantics { contentDescription = t("draft_prob_close") }
            ) { Text("✕") }
        }
        Text(t("draft_prob_prompt_${p.kind}"), fontSize = 12.sp)
        Text(
            fill("draft_prob_hint_dims", "${p.widthMm.toInt()}", "${p.heightMm.toInt()}", "${p.depthMm.toInt()}"),
            fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        if (p.choices.isNotEmpty()) {
            FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                p.choices.forEachIndexed { i, key ->
                    FilterChip(
                        selected = PracticeSession.pickedKind == i,
                        onClick = { PracticeSession.choose(i) },
                        label = { Text(t(key), fontSize = 12.sp) },
                        modifier = Modifier.testTag("draft.practice.choice.$i")
                    )
                }
            }
        }
        PracticeSession.feedback?.let {
            Text(it, fontSize = 12.sp, style = MaterialTheme.typography.labelLarge, modifier = Modifier.testTag("draft.practice.feedback"))
        }
        if (PracticeSession.isDrawing) {
            FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                FilterChip(selected = true, onClick = { PracticeSession.grade(engine) },
                    label = { Text("✔ " + t("draft_prob_grade"), fontSize = 12.sp) }, modifier = Modifier.testTag("draft.practice.grade"))
                FilterChip(selected = false, onClick = { PracticeSession.showAnswer(engine) },
                    label = { Text("👁 " + t("draft_prob_show_answer"), fontSize = 12.sp) }, modifier = Modifier.testTag("draft.practice.answer"))
                FilterChip(selected = false, onClick = { PracticeSession.clearMarks(engine) },
                    label = { Text(t("draft_prob_clear"), fontSize = 12.sp) }, modifier = Modifier.testTag("draft.practice.clear"))
            }
        }
        PracticeSession.summary?.let { s ->
            Text(fill("draft_prob_score", "${s.score}"), fontSize = 12.sp, style = MaterialTheme.typography.labelLarge,
                modifier = Modifier.testTag("draft.practice.score"))
            if (s.perfect) {
                Text(t("draft_prob_perfect"), fontSize = 11.sp)
            } else {
                if (s.missing > 0) Text(fill("draft_prob_issue_missing", "${s.missing}"), fontSize = 11.sp)
                if (s.extra > 0) Text(fill("draft_prob_issue_extra", "${s.extra}"), fontSize = 11.sp)
                if (s.wrongType > 0) Text(fill("draft_prob_issue_type", "${s.wrongType}"), fontSize = 11.sp)
                if (s.misaligned > 0) Text(fill("draft_prob_issue_align", "${s.misaligned}"), fontSize = 11.sp)
                if (s.hatchMissing) Text(t("draft_prob_issue_hatch_missing"), fontSize = 11.sp)
                if (s.hatchAngle) Text(t("draft_prob_issue_hatch_angle"), fontSize = 11.sp)
            }
            if (PracticeSession.answerShown) Text(t("draft_prob_answer_shown"), fontSize = 11.sp)
        }
        FilterChip(selected = false, onClick = onNew, label = { Text("↻ " + t("draft_prob_new"), fontSize = 12.sp) },
            modifier = Modifier.testTag("draft.practice.new"))
    }
}
