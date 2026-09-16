//
//  NoteIntelligenceSheet.swift
//  Kairumo
//
//  「摘要與待辦」的畫面（工作項 S-20 收尾）。
//
//  # 三種狀態要分開講
//
//  這個畫面最容易做錯的地方不是版面，是**把三種不同的失敗混成一種**：
//
//  | 狀態 | 使用者該做什麼 |
//  |---|---|
//  | 這台裝置沒有模型 | 什麼也不用做，這裡就是沒有這個功能 |
//  | 模型還沒準備好 | 等一下再來 |
//  | 這則筆記沒有文字 | 先辨識手寫，或先打一些字 |
//
//  全部寫成「摘要失敗，請重試」的話，前兩種的人會一直按，而第三種的人
//  永遠不知道自己缺的是什麼。
//
//  Android 端是同一套畫面與同一組語系鍵（見 `ai/NoteIntelligenceSheet.kt`）。
//

import SwiftUI

struct NoteIntelligenceSheet: View {

    /// 要整理的文字。由呼叫端提供（走核心的 `export_markdown`）。
    let text: String
    /// 把整理結果插進筆記。
    let onInsert: (String) -> Void

    @StateObject private var model = NoteIntelligenceModel()
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss

    private func l(_ key: String) -> String { localizationManager.localized(key) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.m) {
                    Text(l("ai_summary_desc"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    switch model.availability {
                    case .unsupported:
                        notice(l("ai_unsupported"), systemImage: "cpu")
                    case .notReady:
                        notice(l("ai_not_ready"), systemImage: "clock")
                    case .available:
                        runnable
                    }
                }
                .frame(maxWidth: DS.Content.readableMaxWidth, alignment: .leading)
                .frame(maxWidth: .infinity)
                .padding(DS.Space.l)
            }
            .navigationTitle(l("ai_summary"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l("close")) { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var runnable: some View {
        Button {
            model.run(text: text, locale: localizationManager.currentLanguage.rawValue)
        } label: {
            HStack(spacing: DS.Space.s) {
                if model.isRunning { ProgressView() }
                Text(model.isRunning ? l("ai_running") : l("ai_run"))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(model.isRunning)

        // 隱私這一句放在按鈕旁邊，不是藏在說明頁裡 —— 使用者猶豫的那一刻
        // 就是按下去之前。
        Label(l("ai_on_device_note"), systemImage: "lock")
            .font(.footnote)
            .foregroundStyle(.secondary)

        if let failure = model.failure {
            notice(
                model.needsModel ? l("ai_not_ready") : failure,
                systemImage: "exclamationmark.triangle")
        }

        if !model.summary.isEmpty {
            section(l("ai_key_points")) {
                Text(model.summary)
                    .textSelection(.enabled)
            }
        }

        if !model.summary.isEmpty || !model.todos.isEmpty {
            section(l("ai_todos")) {
                if model.todos.isEmpty {
                    // **沒有待辦是正常的答案**，不是錯誤。當成錯誤的話，
                    // 使用者每次對一段沒有待辦的筆記按下去都會看到紅字。
                    Text(l("ai_no_todos"))
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: DS.Space.xs) {
                        ForEach(Array(model.todos.enumerated()), id: \.offset) { _, todo in
                            Label(todo.text, systemImage: todo.done ? "checkmark.square" : "square")
                                .labelStyle(.titleAndIcon)
                        }
                    }
                }
            }

            Button {
                onInsert(insertableText)
                dismiss()
            } label: {
                Text(l("ai_insert")).frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }

    /// 插進筆記的樣子。
    ///
    /// 用 Markdown 的清單語法而不是純文字：這段會變成筆記裡的一個文字方塊，
    /// 而使用者接下來多半會勾掉其中幾條。
    private var insertableText: String {
        var parts: [String] = []
        if !model.summary.isEmpty {
            parts.append("## \(l("ai_key_points"))\n\n\(model.summary)")
        }
        if !model.todos.isEmpty {
            let lines = model.todos
                .map { "- [\($0.done ? "x" : " ")] \($0.text)" }
                .joined(separator: "\n")
            parts.append("## \(l("ai_todos"))\n\n\(lines)")
        }
        return parts.joined(separator: "\n\n")
    }

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            Text(title).font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func notice(_ message: String, systemImage: String) -> some View {
        Label {
            Text(message)
        } icon: {
            Image(systemName: systemImage)
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .padding(DS.Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
