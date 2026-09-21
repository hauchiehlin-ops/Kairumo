//
//  ModelDownloadManager.swift
//  Kairumo
//
//  按需下載端側模型（A2，決策 D4）。
//
//  # 為什麼這個檔案之前不存在
//
//  核心的 `padnote-models` 早就把清單、SHA-256 驗證、斷點續傳、刪除都寫完了，
//  但**沒有任何下載入口** —— 於是需要模型的功能永遠走降級路徑：
//  轉錄一律退回系統聽寫，而使用者不會知道還有更好的選項，
//  也沒有辦法把它打開。
//
//  # 續傳與驗證都不在這裡
//
//  這一層只做一件事：**從第 N 個位元組開始拿一段回來**。
//  進度怎麼保、雜湊怎麼驗、驗完怎麼改名，全部在核心 —— 那些正是最容易
//  寫錯、又最難在真機上重現的地方，兩個平台各寫一份遲早會分岔。
//

import Foundation

/// 平台端的 Range 下載器。
///
/// 一次最多拿 8 MiB。整包拿的話，一個 574 MB 的模型會一次配置 574 MB，
/// 而手機會在那之前就把 App 收掉。
final class ModelRangeFetcher: FfiModelFetcher {

    /// 單次請求的上限。
    private static let chunkBytes = 8 * 1024 * 1024

    private let session: URLSession
    /// 每拿完一段回報一次「總共拿到第幾個位元組」。
    ///
    /// 進度只有這裡知道：核心的 `model_download` 是一個會跑很久的同步呼叫，
    /// 它不會中途回報。少了這個回呼，畫面上就是一顆轉不動的圈圈，
    /// 而使用者無法分辨「在下載」與「卡住了」。
    private let onProgress: (@Sendable (UInt64) -> Void)?

    init(onProgress: (@Sendable (UInt64) -> Void)? = nil) {
        self.onProgress = onProgress
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 600
        config.waitsForConnectivity = true
        session = URLSession(configuration: config)
    }

    func supportsRange() -> Bool { true }

    /// **會阻塞**：核心是同步呼叫它的，所以這裡用 semaphore 把 URLSession
    /// 轉成同步。絕對不要從主執行緒進來。
    func fetch(url: String, from: UInt64) throws -> Data {
        guard let target = URL(string: url) else {
            throw FfiModelError.Network(detail: "網址無效：\(url)")
        }
        var request = URLRequest(url: target)
        let upper = from + UInt64(Self.chunkBytes) - 1
        request.setValue("bytes=\(from)-\(upper)", forHTTPHeaderField: "Range")

        var payload: Data?
        var failure: Error?
        let done = DispatchSemaphore(value: 0)
        session.dataTask(with: request) { data, response, error in
            defer { done.signal() }
            if let error {
                failure = error
                return
            }
            guard let http = response as? HTTPURLResponse else {
                failure = FfiModelError.Network(detail: "沒有 HTTP 回應")
                return
            }
            // 206 是我們要的（部分內容）；200 表示伺服器忽略了 Range，
            // 那時整包都在 data 裡，核心會照長度自己往前推。
            guard (200..<300).contains(http.statusCode) else {
                failure = FfiModelError.Network(detail: "HTTP \(http.statusCode)")
                return
            }
            payload = data
        }.resume()
        done.wait()

        if let failure {
            throw FfiModelError.Network(detail: failure.localizedDescription)
        }
        let data = payload ?? Data()
        if !data.isEmpty {
            onProgress?(from + UInt64(data.count))
        }
        // 回空的不是錯誤：核心會保住進度，稍後再試。
        return data
    }
}

/// 模型下載的畫面狀態。
@MainActor
public final class ModelDownloadManager: ObservableObject {

    public static let shared = ModelDownloadManager()

    @Published public private(set) var models: [FfiModelInfo] = []
    /// 正在下載的模型 id。
    @Published public private(set) var downloading: String?
    @Published public private(set) var lastError: String = ""
    /// 0…1。只有下載中有意義。
    @Published public private(set) var progress: Double = 0

    private var task: Task<Void, Never>?

    private init() {}

    /// 模型放哪裡。
    ///
    /// Application Support 而不是 Documents：這些是**可重新下載的衍生資料**，
    /// 不該出現在使用者的「檔案」App 裡，也不該被備份上 iCloud
    /// （一個 574 MB 的模型會把使用者的免費空間吃掉）。
    public var modelsRoot: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Kairumo/models", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        var url = base
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
        return base
    }

    public func refresh() {
        models = modelCatalog(root: modelsRoot.path)
    }

    /// 某一項能力現在有沒有模型可用（例如 `asr.zh`）。
    public func isCapabilityReady(_ capability: String) -> Bool {
        modelCapabilityReady(root: modelsRoot.path, capability: capability)
    }

    public func path(of id: String) -> String {
        modelPath(root: modelsRoot.path, id: id)
    }

    /// 開始（或續傳）下載。
    public func download(_ id: String) {
        guard downloading == nil else { return }
        downloading = id
        lastError = ""
        let root = modelsRoot.path
        let total = models.first { $0.id == id }?.sizeBytes ?? 0
        progress = 0
        task = Task { @MainActor in
            defer {
                self.downloading = nil
                self.progress = 0
                self.refresh()
            }
            let result = await Task.detached(priority: .utility) {
                let fetcher = ModelRangeFetcher { done in
                    guard total > 0 else { return }
                    let fraction = min(1, Double(done) / Double(total))
                    Task { @MainActor in
                        ModelDownloadManager.shared.progress = fraction
                    }
                }
                return modelDownload(root: root, id: id, fetcher: fetcher)
            }.value
            if !result.ok && !result.incomplete {
                self.lastError = result.error
            }
            // 沒下載完但進度保住了：再叫一次就從斷點接下去。
            if result.incomplete {
                self.lastError = LocalizationManager.shared.localized("model_download_paused")
            }
        }
    }

    public func cancel() {
        task?.cancel()
        task = nil
        downloading = nil
    }

    public func remove(_ id: String) {
        _ = modelRemove(root: modelsRoot.path, id: id)
        refresh()
    }

    public var diskUsage: UInt64 {
        modelDiskUsage(root: modelsRoot.path)
    }
}
