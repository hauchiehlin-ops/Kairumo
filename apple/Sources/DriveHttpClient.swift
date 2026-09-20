//
//  DriveHttpClient.swift
//  Kairumo
//
//  Google Drive 的 HTTP（Apple）。
//
//  核心負責**送什麼**（查詢字串、分頁、合併規則），這裡只負責**怎麼送**：
//  帶上權杖、送出去、把回應原樣交回去。
//
//  # 不要在這裡判斷 Drive 的語意
//
//  唯一的例外是**狀態碼的分類**，而那一項非常重要：
//  - 401/403 → `PermissionDenied`，上層據此要求重新登入
//  - 404 → `NotFound`，第一次同步時檔案本來就不存在，那不是錯誤
//  - 其餘 → `Backend`，重試即可
//
//  混成同一種的話，使用者會在「該重新登入」時看到一句沒有用的「同步失敗」，
//  而背景會無限重試一個永遠不會成功的請求。
//
//  # 為什麼不讓核心自己用 reqwest
//
//  試過，`libpadnote_core.so` 從 8.1 MB 變成 13 MB —— 整個 rustls 堆疊被連進來。
//  而且 URLSession 帶著系統的 Proxy、VPN 與 ATS 設定，那些 reqwest 拿不到。
//

import Foundation

/// 核心會從背景執行緒同步呼叫這些方法，所以裡面用 semaphore 把
/// `URLSession` 的非同步 API 轉成同步。
///
/// **絕對不要從主執行緒呼叫。** 在主執行緒等 semaphore 會直接卡死 UI，
/// 而且畫面完全沒有反應 —— 看起來像 App 當掉而不是網路慢。
final class DriveHttpClient: FfiDriveHttp {

    private var accessToken: String
    private let session: URLSession
    private let ownsSession: Bool

    init(accessToken: String, session: URLSession? = nil) {
        self.accessToken = accessToken
        if let s = session {
            self.session = s
            self.ownsSession = false
        } else {
            let q = OperationQueue()
            q.name = "DriveHttpClientQueue"
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 30
            config.timeoutIntervalForResource = 60
            self.session = URLSession(configuration: config, delegate: nil, delegateQueue: q)
            self.ownsSession = true
        }
    }

    deinit {
        if ownsSession {
            session.finishTasksAndInvalidate()
        }
    }

    func updateAccessToken(_ token: String) {
        self.accessToken = token
    }
    func getJson(url: String, query: [FfiQueryParam]) throws -> String {
        guard var components = URLComponents(string: url) else {
            throw FfiDriveError.Backend(detail: "bad_url")
        }
        // 交給 URLComponents 做百分號編碼 —— Drive 的 `q=` 裡有空格、
        // 單引號與括號，自己拼字串很容易漏掉其中一種。
        components.queryItems = query.map { URLQueryItem(name: $0.name, value: $0.value) }
        guard let built = components.url else {
            throw FfiDriveError.Backend(detail: "bad_query")
        }
        let data = try send(URLRequest(url: built))
        return String(data: data, encoding: .utf8) ?? ""
    }

    func getBytes(url: String, range: FfiByteRange?) throws -> Data {
        guard let target = URL(string: url) else {
            throw FfiDriveError.Backend(detail: "bad_url")
        }
        var request = URLRequest(url: target)
        if let range {
            // 核心給的是半開區間 [start, end)，HTTP 的 Range 是**閉區間** ——
            // 尾端要減一。少減那個 1 會每次多拉一個位元組。
            request.setValue("bytes=\(range.start)-\(range.end - 1)", forHTTPHeaderField: "Range")
        }
        return try send(request)
    }

    func postJson(url: String, bodyJson: String) throws -> String {
        guard let target = URL(string: url) else {
            throw FfiDriveError.Backend(detail: "bad_url")
        }
        var request = URLRequest(url: target)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyJson.data(using: .utf8)
        let data = try send(request)
        return String(data: data, encoding: .utf8) ?? ""
    }

    func patchBytes(url: String, data: Data) throws {
        guard let target = URL(string: url) else {
            throw FfiDriveError.Backend(detail: "bad_url")
        }
        var request = URLRequest(url: target)
        request.httpMethod = "PATCH"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        _ = try send(request)
    }

    /// 開一個可續傳上傳的工作階段。
    ///
    /// Drive 把工作階段 URI 放在**回應標頭 `Location`** 裡，不是 body ——
    /// 這就是為什麼這一步必須由平台做，核心看不到標頭。
    func startResumable(url: String, bodyJson: String) throws -> String {
        guard let target = URL(string: url) else {
            throw FfiDriveError.Backend(detail: "bad_url")
        }
        var request = URLRequest(url: target)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyJson.data(using: .utf8)
        let (_, headers) = try sendWithHeaders(request)
        guard let location = headers["Location"] as? String
            ?? headers["location"] as? String
        else {
            throw FfiDriveError.Backend(detail: "可續傳上傳沒有回傳 Location")
        }
        return location
    }

    func putBytes(url: String, data: Data) throws {
        guard let target = URL(string: url) else {
            throw FfiDriveError.Backend(detail: "bad_url")
        }
        var request = URLRequest(url: target)
        request.httpMethod = "PUT"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        _ = try send(request)
    }

    // MARK: - 內部

    private func send(_ base: URLRequest) throws -> Data {
        try sendWithHeaders(base).0
    }

    private func sendWithHeaders(_ base: URLRequest) throws -> (Data, [AnyHashable: Any]) {
        var request = base
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let semaphore = DispatchSemaphore(value: 0)
        var payload = Data()
        var response: HTTPURLResponse?
        var transportError: Error?

        let task = session.dataTask(with: request) { data, urlResponse, error in
            payload = data ?? Data()
            response = urlResponse as? HTTPURLResponse
            transportError = error
            semaphore.signal()
        }
        task.resume()
        let waitResult = semaphore.wait(timeout: .now() + 35)
        if waitResult == .timedOut {
            task.cancel()
            throw FfiDriveError.Backend(detail: "request_timeout")
        }

        if let transportError {
            // 連不上：網路問題，重試會好。
            throw FfiDriveError.Backend(detail: transportError.localizedDescription)
        }
        if let response {
            if (200..<300).contains(response.statusCode) {
                return (payload, response.allHeaderFields)
            }
            if response.statusCode == 401 {
                // 嘗試自動換證並重試一次
                if let newToken = GoogleAuth.shared.refreshTokenSync() {
                    self.accessToken = newToken
                    var retryRequest = base
                    retryRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")

                    let retrySem = DispatchSemaphore(value: 0)
                    var retryPayload = Data()
                    var retryResponse: HTTPURLResponse?
                    var retryErr: Error?
                    let retryTask = session.dataTask(with: retryRequest) { d, r, e in
                        retryPayload = d ?? Data()
                        retryResponse = r as? HTTPURLResponse
                        retryErr = e
                        retrySem.signal()
                    }
                    retryTask.resume()
                    let retryWait = retrySem.wait(timeout: .now() + 35)
                    if retryWait != .timedOut, retryErr == nil, let resp = retryResponse, (200..<300).contains(resp.statusCode) {
                        return (retryPayload, resp.allHeaderFields)
                    }
                }
                GoogleAuth.shared.markNeedsReauthSync()
                throw FfiDriveError.PermissionDenied(detail: "Google 帳號憑證已失效或過期，請重新登入 (HTTP 401)")
            }
        }

        guard let response else {
            throw FfiDriveError.Backend(detail: "no_response")
        }
        throw Self.classify(
            status: response.statusCode,
            path: request.url?.path ?? "",
            detail: String(data: payload, encoding: .utf8) ?? ""
        )
    }

    private static func classify(status: Int, path: String, detail: String) -> FfiDriveError {
        switch status {
        case 401: return .PermissionDenied(detail: "Google 帳號憑證已失效或過期，請重新登入 (HTTP 401)")
        case 403: return .PermissionDenied(detail: "Google 帳號權限不足 (HTTP 403)")
        case 404: return .NotFound(path: path)
        default: return .Backend(detail: "HTTP \(status) \(detail)")
        }
    }
}

/// 跑一輪雲端同步（Apple）。
///
/// 把三塊接起來：`GoogleAuth` 的權杖、`DriveHttpClient` 的 HTTP、
/// 以及核心的合併規則。合併之後的結果寫回 `AccountSyncStore` ——
/// **雲端那邊可能有別台裝置的改動**，不寫回去的話這次同步等於白做。
///
/// 兩層都同步：中繼資料（設定、筆記本清單、刪除墓碑）與**內容**
/// （每一本筆記的 oplog 檔）。
public enum CloudSync {

    /// 同步一輪。回傳 nil 表示沒登入。
    @discardableResult
    public static func runOnce() async -> FfiCloudSyncResult? {
        guard let token = await GoogleAuth.shared.validAccessToken() else { return nil }

        let settings = await AccountSyncStore.shared.settingsJSON
        let index = await AccountSyncStore.shared.indexJSON

        // 核心會同步地等 HTTP，所以整段丟到背景執行緒。在主執行緒跑會卡死 UI。
        // 整體加 120 秒上限：Rust 端若進入重試迴圈（每次 HTTP 最多 35s），
        // 沒有這一層的話，整個同步會永遠掛著，UI 卡在「同步中…」。
        let detached = Task.detached(priority: .utility) {
            gdriveSyncMetadata(
                http: DriveHttpClient(accessToken: token),
                localSettingsJson: settings,
                localIndexJson: index
            )
        }
        let result: FfiCloudSyncResult
        do {
            result = try await withTimeout(seconds: 120) { await detached.value }
        } catch {
            detached.cancel()
            return FfiCloudSyncResult(
                ok: false,
                settingsJson: settings,
                indexJson: index,
                error: "同步逾時（超過 120 秒），請檢查網路連線後重試",
                needsReauth: false
            )
        }

        if result.ok {
            // 合併結果要落地。只更新畫面不寫檔的話，重開 App 就回到同步前。
            await AccountSyncStore.shared.mergeSettings(result.settingsJson)
            await AccountSyncStore.shared.mergeIndex(result.indexJson)
        } else if result.needsReauth {
            // 權杖救不回來了 —— 留著一個死權杖的話，背景會一直重試，
            // 而使用者不知道要去登入。
            await GoogleAuth.shared.signOut()
        }
        return result
    }

    /// 把一本**只存在於雲端**的筆記本整本抓下來。
    ///
    /// 另一台裝置新建的筆記本在本機連套件目錄都沒有，`syncNotebook` 會以
    /// 「開不了套件」失敗。少了這條路，症狀是：索引同步成功、清單上出現了
    /// 標題，點進去卻是空的，而且每一輪都重複同樣的失敗。
    public static func cloneNotebook(
        packagePath: String,
        notebookId: String,
        title: String
    ) async -> FfiNotebookSyncResult? {
        guard let token = await GoogleAuth.shared.validAccessToken() else { return nil }
        let now = UInt64(max(0, Date().timeIntervalSince1970 * 1000))
        let detached = Task.detached(priority: .utility) {
            gdriveCloneNotebook(
                http: DriveHttpClient(accessToken: token),
                packagePath: packagePath,
                notebookId: notebookId,
                title: title,
                nowUnixMs: now
            )
        }
        let result: FfiNotebookSyncResult
        do {
            result = try await withTimeout(seconds: 90) { await detached.value }
        } catch {
            detached.cancel()
            return FfiNotebookSyncResult(ok: false, uploaded: 0, downloaded: 0,
                error: "下載逾時（超過 90 秒）", needsReauth: false)
        }

        if result.needsReauth {
            await GoogleAuth.shared.signOut()
        }
        return result
    }

    /// 同步一本筆記本的內容。
    ///
    /// 回傳 `downloaded > 0` 時，**呼叫端必須重新載入這本筆記** ——
    /// oplog 檔已經寫進套件，但記憶體裡那份還是同步前的狀態，
    /// 畫面上看不到任何變化，使用者會以為同步沒作用。
    public static func syncNotebook(
        packagePath: String,
        notebookId: String
    ) async -> FfiNotebookSyncResult? {
        guard let token = await GoogleAuth.shared.validAccessToken() else { return nil }

        // 動態計算逾時時間：根據套件內待同步的 oplog 數量自適應調整，避免巨量歷史筆跡或弱網時超時
        let opsDir = (packagePath as NSString).appendingPathComponent("doc/ops")
        let opsCount = (try? FileManager.default.contentsOfDirectory(atPath: opsDir).count) ?? 0
        let timeoutSeconds = max(120.0, min(600.0, 60.0 + Double(opsCount) * 1.5))

        let detached = Task.detached(priority: .utility) {
            let http = DriveHttpClient(accessToken: token)
            let ops = gdriveSyncNotebook(
                http: http,
                packagePath: packagePath,
                notebookId: notebookId
            )
            guard ops.ok else { return ops }

            // 媒體接在 oplog 之後。順序很重要：oplog 裡的 AddImage 會指向一個
            // blob id，媒體還沒到的話，那一頁會有一個指向不存在檔案的圖片區塊。
            // 反過來先傳媒體只是多佔一點空間，不會讓畫面壞掉。
            let media = gdriveSyncMedia(
                http: http,
                packagePath: packagePath,
                notebookId: notebookId
            )
            return FfiNotebookSyncResult(
                ok: media.ok,
                uploaded: ops.uploaded + media.uploaded,
                downloaded: ops.downloaded + media.downloaded,
                error: media.error,
                needsReauth: media.needsReauth
            )
        }
        let result: FfiNotebookSyncResult
        do {
            result = try await withTimeout(seconds: timeoutSeconds) { await detached.value }
        } catch {
            detached.cancel()
            return FfiNotebookSyncResult(ok: false, uploaded: 0, downloaded: 0,
                error: "同步逾時（超過 \(Int(timeoutSeconds)) 秒）", needsReauth: false)
        }

        if result.needsReauth {
            await GoogleAuth.shared.signOut()
        }
        return result
    }
}

/// 指定秒數內未完成就拋出 `CancellationError`。
private func withTimeout<T: Sendable>(
    seconds: Double,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw CancellationError()
        }
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}
