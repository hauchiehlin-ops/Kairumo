import SwiftUI
import UIKit

/// 練習題（對應 Android 的 `PracticeSession`）：出題、批改、標記、看答案。
///
/// 題目與標準答案全在核心（`draft_problem`、`draft_grade`）—— 同一個種子在兩個平台產生同一題、
/// 同一份答案批出同一個分數。這裡只管把題目線放進頁面、把學生畫的線交給核心批改、把結果標在畫面上。
@MainActor
final class PracticeSession: ObservableObject {
    static let shared = PracticeSession()

    /// 批改摘要：各種問題的條數與分數。
    struct Summary: Equatable {
        var score = 0
        var missing = 0
        var extra = 0
        var wrongType = 0
        var misaligned = 0
        var hatchMissing = false
        var hatchAngle = false
        var perfect: Bool { missing + extra + wrongType + misaligned == 0 && !hatchMissing && !hatchAngle }
    }

    @Published private(set) var problem: FfiProblem?
    @Published private(set) var summary: Summary?
    /// 選擇題／挑錯題的回饋（已翻成使用者語言）。
    @Published private(set) var feedback: String?
    /// 挑錯題：已選的錯誤種類（選完要再點位置）。
    @Published private(set) var pickedKind: Int?
    @Published private(set) var answerShown = false

    private var pageSize = CGSize(width: 1600, height: 1132)

    private func l(_ key: String) -> String { LocalizationManager.shared.localized(key) }

    var isActive: Bool { problem != nil }
    var isDrawing: Bool { problem.map { draftProblemIsDrawing(kind: $0.kind) } ?? false }

    /// 隨機的種子（時間＋亂數；記在題目裡，同一題可重現）。
    private func freshSeed() -> UInt64 { UInt64.random(in: 1 ... 999_999) }

    // MARK: 出題

    /// 出一題（`seed` 為 `nil` 就隨機），把題目線放進頁面。回傳有沒有成功。
    @discardableResult
    func start(kind: String, seed: UInt64? = nil, layer: ProInkLayerView, pageSize: CGSize) -> Bool {
        self.pageSize = pageSize
        let s = seed ?? freshSeed()
        guard let p = draftProblem(kind: kind, seed: s, pageWidth: Float(pageSize.width), pageHeight: Float(pageSize.height)) else {
            return false
        }
        clearMarks(layer: layer)
        problem = p
        summary = nil
        feedback = nil
        pickedKind = nil
        answerShown = false
        let items = p.given.map { Self.sheetStroke($0, color: "#374151", width: nil, layerId: 1) }
        for item in items { DraftingState.shared.ensureVisible(layer: item.layer, notebookId: layer.notebookId) }
        layer.insertDrafted(items, origin: .zero)
        DraftingState.shared.toolHint = l("draft_prob_prompt_\(kind)")
        if kind == "spot_error" { DraftingState.shared.toolHint = l("draft_prob_prompt_spot_error") }
        return true
    }

    func end(layer: ProInkLayerView?) {
        layer?.clearOverlay()
        problem = nil
        summary = nil
        feedback = nil
        pickedKind = nil
        answerShown = false
        if DraftingState.shared.tool == .problemSpot { DraftingState.shared.tool = .none }
    }

    /// 核心的線 → 頁面筆畫。`layerId` 1 = 底層（題目）；`width` 為 `nil` 用該線型的標準寬。
    static func sheetStroke(_ line: FfiProblemLine, color: String, width: Float?, layerId: UInt8, dashed: Bool = false) -> FfiSheetStroke {
        let w: Float = width ?? (line.lineType == 1 ? 1.4 : (line.thin ? 1.2 : 1.8))
        return FfiSheetStroke(
            points: [line.a, line.b], layer: layerId, lineType: dashed ? 1 : line.lineType, width: w, colorHex: color)
    }

    // MARK: 批改（畫題）

    /// 把頁面上學生畫的線交給核心批改，並把問題標在畫面上。
    @discardableResult
    func grade(layer: ProInkLayerView) -> Summary? {
        guard let p = problem, isDrawing else { return nil }
        let strokes = layer.ownStrokes.map { s in
            FfiDrawnStroke(
                layer: s.layerId, lineType: s.lineTypeId, width: s.baseWidth,
                points: s.points.map { FfiPoint(x: $0.x, y: $0.y) })
        }
        guard let g = draftGrade(
            kind: p.kind, seed: p.seed, pageWidth: Float(pageSize.width), pageHeight: Float(pageSize.height),
            strokes: strokes)
        else { return nil }
        var sum = Summary(score: Int(g.score))
        var marks: [FfiSheetStroke] = []
        for issue in g.issues {
            switch issue.kind {
            case .missing:
                sum.missing += 1
                if let line = issue.line { marks.append(Self.sheetStroke(line, color: "#F97316", width: 2.6, layerId: 3, dashed: true)) }
            case .extra:
                sum.extra += 1
                if let line = issue.line { marks.append(Self.sheetStroke(line, color: "#DC2626", width: 5, layerId: 3)) }
            case .wrongType:
                sum.wrongType += 1
                if let line = issue.line { marks.append(Self.sheetStroke(line, color: "#EAB308", width: 5, layerId: 3)) }
            case .misaligned:
                sum.misaligned += 1
                if let line = issue.line { marks.append(Self.sheetStroke(line, color: "#2563EB", width: 2.6, layerId: 3, dashed: true)) }
            case .hatchMissing: sum.hatchMissing = true
            case .hatchAngle: sum.hatchAngle = true
            }
        }
        summary = sum
        answerShown = false
        layer.setOverlay(strokes: marks, marks: [])
        UINotificationFeedbackGenerator().notificationOccurred(sum.perfect ? .success : .warning)
        return sum
    }

    /// 標準答案畫成綠色疊層（不存檔、不進復原）。
    func showAnswer(layer: ProInkLayerView) {
        guard let p = problem, isDrawing else { return }
        let items = p.answer.map { Self.sheetStroke($0, color: "#16A34A", width: 2.2, layerId: 3) }
        layer.setOverlay(strokes: items, marks: [])
        answerShown = true
    }

    func clearMarks(layer: ProInkLayerView?) {
        layer?.clearOverlay()
        answerShown = false
    }

    // MARK: 選擇題與挑錯題

    /// 選了第 `index` 個選項。判斷題直接給結果；挑錯題先記下種類，接著要點位置。
    func choose(_ index: Int) {
        guard let p = problem else { return }
        if p.kind == "spot_error" {
            pickedKind = index
            feedback = l("draft_prob_spot_tap")
            DraftingState.shared.tool = .problemSpot
            DraftingState.shared.toolHint = l("draft_prob_spot_tap")
            return
        }
        let ok = draftCheckChoice(
            kind: p.kind, seed: p.seed, pageWidth: Float(pageSize.width), pageHeight: Float(pageSize.height),
            picked: UInt32(index))
        feedback = l(ok ? "draft_prob_choice_right" : "draft_prob_choice_wrong")
        UINotificationFeedbackGenerator().notificationOccurred(ok ? .success : .warning)
    }

    /// 挑錯題：在 `point` 點了一下。種類與位置都對才算對；不對就把正確的地方圈出來。
    func spot(at point: CGPoint, layer: ProInkLayerView) {
        guard let p = problem, p.kind == "spot_error", let picked = pickedKind else { return }
        let ok = draftCheckError(
            seed: p.seed, pageWidth: Float(pageSize.width), pageHeight: Float(pageSize.height),
            picked: UInt32(picked), at: FfiPoint(x: Float(point.x), y: Float(point.y)), radius: 40)
        feedback = l(ok ? "draft_prob_spot_right" : "draft_prob_spot_wrong")
        if let at = p.errorAt {
            let ring = (0 ... 32).map { i -> FfiPoint in
                let a = Float(i) / 32 * 2 * .pi
                return FfiPoint(x: at.x + 28 * cos(a), y: at.y + 28 * sin(a))
            }
            layer.setOverlay(strokes: [FfiSheetStroke(points: ring, layer: 3, lineType: 0, width: 3, colorHex: ok ? "#16A34A" : "#DC2626")], marks: [])
        }
        UINotificationFeedbackGenerator().notificationOccurred(ok ? .success : .warning)
        DraftingState.shared.tool = .none
    }
}

// MARK: - 練習卡

/// 練習進行中浮在畫布上的小卡：題目提示、選項、批改結果與動作。
struct PracticeCard: View {
    @ObservedObject private var session = PracticeSession.shared
    @ObservedObject private var localizationManager = LocalizationManager.shared
    var layer: () -> ProInkLayerView?
    var onNew: () -> Void

    private func t(_ key: String) -> String { localizationManager.localized(key) }

    private func fill(_ key: String, _ values: String...) -> String {
        var text = t(key)
        for (i, v) in values.enumerated() { text = text.replacingOccurrences(of: "%\(i + 1)@", with: v) }
        return text
    }

    var body: some View {
        if let p = session.problem {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(t("draft_prob_kind_\(p.kind)")).font(.subheadline.bold())
                    Spacer()
                    Button(role: .destructive) { session.end(layer: layer()) } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .accessibilityLabel(t("draft_prob_close"))
                    .accessibilityIdentifier("draft.practice.close")
                }
                Text(t("draft_prob_prompt_\(p.kind)")).font(.footnote)
                Text(fill("draft_prob_hint_dims", "\(Int(p.widthMm))", "\(Int(p.heightMm))", "\(Int(p.depthMm))"))
                    .font(.caption).foregroundColor(.secondary)
                if !p.choices.isEmpty { choices(p) }
                if let feedback = session.feedback {
                    Text(feedback).font(.footnote.bold())
                        .accessibilityIdentifier("draft.practice.feedback")
                }
                if session.isDrawing { drawingActions }
                if let s = session.summary { result(s) }
                Button(action: onNew) { Label(t("draft_prob_new"), systemImage: "arrow.clockwise") }
                    .buttonStyle(.bordered).controlSize(.small)
                    .accessibilityIdentifier("draft.practice.new")
            }
            .padding(12)
            .frame(maxWidth: 420, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("draft.practice.card")
        }
    }

    @ViewBuilder private func choices(_ p: FfiProblem) -> some View {
        HStack(spacing: 6) {
            ForEach(Array(p.choices.enumerated()), id: \.offset) { i, key in
                Button(t(key)) { session.choose(i) }
                    .buttonStyle(.bordered).controlSize(.small)
                    .tint(session.pickedKind == i ? .accentColor : .secondary)
                    .accessibilityIdentifier("draft.practice.choice.\(i)")
            }
        }
    }

    private var drawingActions: some View {
        HStack(spacing: 6) {
            Button { if let l = layer() { session.grade(layer: l) } } label: {
                Label(t("draft_prob_grade"), systemImage: "checkmark.seal")
            }
            .buttonStyle(.borderedProminent).controlSize(.small)
            .accessibilityIdentifier("draft.practice.grade")
            Button { if let l = layer() { session.showAnswer(layer: l) } } label: {
                Label(t("draft_prob_show_answer"), systemImage: "eye")
            }
            .buttonStyle(.bordered).controlSize(.small)
            .accessibilityIdentifier("draft.practice.answer")
            Button { session.clearMarks(layer: layer()) } label: { Text(t("draft_prob_clear")) }
                .buttonStyle(.bordered).controlSize(.small)
                .accessibilityIdentifier("draft.practice.clear")
        }
    }

    @ViewBuilder private func result(_ s: PracticeSession.Summary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(fill("draft_prob_score", "\(s.score)")).font(.footnote.bold())
                .accessibilityIdentifier("draft.practice.score")
            if s.perfect {
                Text(t("draft_prob_perfect")).font(.caption)
            } else {
                if s.missing > 0 { Text(fill("draft_prob_issue_missing", "\(s.missing)")).font(.caption) }
                if s.extra > 0 { Text(fill("draft_prob_issue_extra", "\(s.extra)")).font(.caption) }
                if s.wrongType > 0 { Text(fill("draft_prob_issue_type", "\(s.wrongType)")).font(.caption) }
                if s.misaligned > 0 { Text(fill("draft_prob_issue_align", "\(s.misaligned)")).font(.caption) }
                if s.hatchMissing { Text(t("draft_prob_issue_hatch_missing")).font(.caption) }
                if s.hatchAngle { Text(t("draft_prob_issue_hatch_angle")).font(.caption) }
            }
            if session.answerShown { Text(t("draft_prob_answer_shown")).font(.caption) }
        }
    }
}
