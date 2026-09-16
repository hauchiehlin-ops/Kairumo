//
//  NoteIntelligence.swift
//  Kairumo
//
//  摘要與待辦抽取的入口（工作項 S-20 收尾）。
//
//  # 在這之前的狀態
//
//  核心的 `llm_summarize` / `llm_extract_todos` 早就在 FFI 上，切塊、提示詞、
//  **解析**都做完了（`padnote-llm`，18 項測試）。缺的只有一件事：
//  **沒有任何畫面呼叫它們**。功能做完了，使用者按不到。
//
//  # 產生文字的那一段為什麼在平台層
//
//  核心的 `ffi_llm` 說得很清楚：把 llama.cpp 連進 `libpadnote_core` 會讓
//  每個使用者都多下載幾十 MB，不管他用不用得到摘要（與 reqwest 那次同一個
//  判斷）。所以核心只定義一個 `FfiLlm` 介面，後端由平台提供。
//
//  這一側用**系統內建的語言模型**：不必下載任何東西、不會讓 App 變大、
//  文字不離開裝置。沒有它的裝置就是沒有 —— 那時候誠實地說「這台裝置上
//  沒有可用的模型」，而不是丟一個「摘要失敗，請重試」讓使用者按一百次。
//
//  # 為什麼是同步橋接
//
//  `FfiLlm.generate` 是同步的（核心那邊刻意如此：解析那一段要逐次跑）。
//  系統模型的 API 是 async。中間用 semaphore 橋接，**因此絕對不能在主執行緒
//  呼叫** —— 在主執行緒上 semaphore 會把畫面整個鎖住，而模型一次要跑數秒。
//  呼叫端一律走 `Task.detached`。
//

import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

/// 這台裝置能不能做摘要。
enum NoteIntelligenceAvailability: Equatable {
    case available
    /// 這台裝置或這個系統版本沒有可用的模型。
    case unsupported
    /// 有模型但現在不能用（還在下載、或使用者關掉了）。
    case notReady
}

/// 把系統的語言模型包成核心看得懂的後端。
final class SystemLanguageBackend: FfiLlm, @unchecked Sendable {

    static var availability: NoteIntelligenceAvailability {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macCatalyst 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return .available
            case .unavailable(.deviceNotEligible):
                return .unsupported
            case .unavailable:
                // 還在下載、或使用者把它關掉了 —— 這兩種都是「等一下再來」，
                // 與「這台裝置永遠沒有」不是同一件事，訊息也不該一樣。
                return .notReady
            @unknown default:
                return .notReady
            }
        }
        return .unsupported
        #else
        return .unsupported
        #endif
    }

    /// **同步**跑一次生成。不要在主執行緒呼叫。
    func generate(prompt: String, maxTokens: UInt32) throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macCatalyst 26.0, *) {
            guard Self.availability == .available else {
                // 回 `ModelNotLoaded` 而不是 `Backend`：核心用這個區分
                // 「要引導使用者去處理」與「只能請他重試」。混成一種的話，
                // 沒有模型的人會看到「請再試一次」，而再試一百次也不會成功。
                throw FfiLlmError.ModelNotLoaded
            }

            let semaphore = DispatchSemaphore(value: 0)
            let box = ResultBox()

            Task.detached {
                do {
                    let session = LanguageModelSession()
                    let response = try await session.respond(to: prompt)
                    box.value = .success(response.content)
                } catch {
                    box.value = .failure(error)
                }
                semaphore.signal()
            }
            semaphore.wait()

            switch box.value {
            case .success(let text): return text
            case .failure(let error):
                throw FfiLlmError.Backend(detail: error.localizedDescription)
            case .none:
                throw FfiLlmError.Backend(detail: "沒有回應")
            }
        }
        throw FfiLlmError.ModelNotLoaded
        #else
        throw FfiLlmError.ModelNotLoaded
        #endif
    }

    /// 跨執行緒把結果帶回來。`Task` 裡不能直接寫外層的 `var`。
    private final class ResultBox: @unchecked Sendable {
        var value: Result<String, Error>?
    }
}

/// 摘要與待辦的畫面狀態。
@MainActor
final class NoteIntelligenceModel: ObservableObject {

    @Published private(set) var isRunning = false
    @Published private(set) var summary: String = ""
    @Published private(set) var todos: [FfiTodoItem] = []
    /// 出事了。`nil` 表示沒事。
    @Published private(set) var failure: String?
    /// true 表示要引導使用者去處理模型，而不是請他重試。
    @Published private(set) var needsModel = false

    var availability: NoteIntelligenceAvailability { SystemLanguageBackend.availability }

    /// 跑一次摘要與待辦抽取。
    ///
    /// - Parameters:
    ///   - text: 筆記的純文字（走 `export_markdown`）。
    ///   - locale: BCP-47。**一定要給** —— 不指定輸出語言的話，模型會跟著
    ///     輸入走，而一份中英夾雜的會議記錄會拿到一半中文、一半英文的摘要。
    func run(text: String, locale: String) {
        guard !isRunning else { return }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            failure = LocalizationManager.shared.localized("ai_nothing_to_summarize")
            return
        }

        isRunning = true
        failure = nil
        needsModel = false

        Task.detached(priority: .userInitiated) { [weak self] in
            // **一定要在背景。** `generate` 裡的 semaphore 在主執行緒上會把
            // 畫面整個鎖住，而模型一次要跑數秒到數十秒。
            let backend = SystemLanguageBackend()
            let summary = llmSummarize(
                engine: backend, text: text, locale: locale, maxTokens: 400)
            let todos = llmExtractTodos(
                engine: backend, text: text, locale: locale, maxTokens: 400)

            await MainActor.run {
                guard let self else { return }
                self.isRunning = false
                if summary.ok {
                    self.summary = summary.summary
                } else {
                    self.failure = summary.error
                    self.needsModel = summary.needsModel
                }
                // 待辦失敗不覆蓋摘要的錯誤訊息 —— 兩個都失敗時，先講摘要
                // 那一個就夠了，兩段紅字只會更難讀。
                if todos.ok {
                    self.todos = todos.todos
                } else if self.failure == nil {
                    self.failure = todos.error
                    self.needsModel = todos.needsModel
                }
            }
        }
    }

    func reset() {
        summary = ""
        todos = []
        failure = nil
        needsModel = false
    }
}
