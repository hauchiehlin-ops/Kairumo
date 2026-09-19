//
//  GoogleAuth.swift
//  Kairumo
//
//  Google 授權（Apple，G-01 / ADR-0011）。
//
//  # 核心負責「送什麼」，這裡負責「怎麼送」
//
//  PKCE 怎麼算、redirect URI 長什麼樣、交換權杖要帶哪些欄位，全部在核心
//  （`ffi_oauth`）—— 任何一項兩邊寫得不一樣，Google 只會回一句
//  `invalid_grant`，而那句話對「哪裡不一樣」毫無提示。
//
//  這個檔案只做三件 Apple 非做不可的事：開系統瀏覽器、打 HTTP、
//  把權杖放進 Keychain。
//
//  # 為什麼是 ASWebAuthenticationSession
//
//  Google **會拒絕**在 WKWebView 裡完成的 OAuth（`disallowed_useragent`）。
//  `ASWebAuthenticationSession` 用的是 Safari 的 session，所以使用者已經登入
//  Google 的話不必再打一次密碼，而且憑證不會經過我們的程式碼。
//

import AuthenticationServices
import Foundation

@MainActor
public final class GoogleAuth: NSObject, ObservableObject {

    public static let shared = GoogleAuth()

    /// 有沒有可用的長期授權。
    @Published public private(set) var isSignedIn: Bool = false

    /// 這些筆記正在同步到**誰的** Drive。
    ///
    /// # 為什麼要顯示它
    ///
    /// 同步頁原本只有「已登入 / 尚未登入」兩種狀態 —— 使用者看不出來
    /// 資料進了哪一個帳號。一台裝置上有兩個 Google 帳號是常態，
    /// 而「同步好像沒作用」最常見的真正原因就是兩台連到了不同帳號。
    ///
    /// # 為什麼不必新增授權範圍
    ///
    /// Drive 的 `about.get` 在 `drive.appdata` 這個範圍底下就讀得到
    /// `user.emailAddress` —— **不需要 `openid email`**，也就不必讓使用者
    /// 重新同意一次。多要一個範圍只為了顯示一行字，與這個 App 的定位相反。
    @Published public private(set) var accountEmail: String?

    private let accountEmailKey = "kairumo.google.accountEmail"

    private var session: ASWebAuthenticationSession?
    /// 授權期間暫存的 PKCE。**不落盤** —— 它只在這一次授權裡有意義。
    private var pendingVerifier: String = ""
    private var pendingState: String = ""

    private override init() {
        super.init()
        isSignedIn = !KeychainTokens.load().refreshToken.isEmpty
        // 帳號只是顯示用的字串，放 UserDefaults 就好 —— 放 Keychain 的話
        // 登出時忘了清會留下一個「已登出但還顯示著帳號」的狀態。
        accountEmail = isSignedIn
            ? UserDefaults.standard.string(forKey: accountEmailKey)
            : nil
    }

    /// 向 Drive 問一次「這是誰的帳號」，並記下來。
    ///
    /// 失敗就靜靜放著：這是一行顯示用的字，拿不到不該讓同步失敗。
    public func refreshAccountEmail() async {
        guard isSignedIn, let token = await validAccessToken() else { return }
        var request = URLRequest(
            url: URL(string: "https://www.googleapis.com/drive/v3/about?fields=user")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let user = json["user"] as? [String: Any],
              let email = user["emailAddress"] as? String, !email.isEmpty
        else { return }
        accountEmail = email
        UserDefaults.standard.set(email, forKey: accountEmailKey)
    }

    public enum Failure: LocalizedError {
        /// 使用者自己取消，不是錯誤，但呼叫端要分得出來。
        case cancelled
        case stateMismatch
        case server(String)
        /// 需要重新登入（refresh token 失效）。
        case needsReauth

        public var errorDescription: String? {
            switch self {
            case .cancelled: return nil
            case .stateMismatch: return "state_mismatch"
            case .server(let code): return code
            case .needsReauth: return "needs_reauth"
            }
        }
    }

    // MARK: - 登入

    public func signIn(loginHint: String = "") async -> Result<Void, Failure> {
        let pkce = oauthNewPkce()
        guard !pkce.verifier.isEmpty else {
            return .failure(.server("random_unavailable"))
        }
        pendingVerifier = pkce.verifier
        pendingState = pkce.state

        let urlString = oauthAuthorizeUrl(
            platform: .apple,
            codeChallenge: pkce.challenge,
            state: pkce.state,
            loginHint: loginHint
        )
        guard let url = URL(string: urlString) else {
            return .failure(.server("bad_authorize_url"))
        }

        let callback: URL
        do {
            callback = try await present(url: url)
        } catch {
            // 使用者按取消也走這裡。那不是故障，不要跳錯誤對話框。
            return .failure(.cancelled)
        }

        let parsed = oauthParseCallback(url: callback.absoluteString)
        guard parsed.error.isEmpty else { return .failure(.server(parsed.error)) }
        // **一定要比對 state。** 不比對的話，別人可以誘導 App 去交換一個
        // 攻擊者取得的授權碼，結果是資料同步到攻擊者的雲端硬碟。
        guard !pendingState.isEmpty, parsed.state == pendingState else {
            return .failure(.stateMismatch)
        }
        guard !parsed.code.isEmpty else { return .failure(.server("missing_code")) }

        let body = oauthExchangeBody(
            platform: .apple,
            code: parsed.code,
            verifier: pendingVerifier
        )
        // 用完就清掉 —— 一組 PKCE 只能用一次。
        pendingVerifier = ""
        pendingState = ""

        switch await post(body) {
        case .failure(let error):
            return .failure(error)
        case .success(let json):
            let tokens = oauthParseTokenResponse(json: json, nowS: nowSeconds())
            guard tokens.error.isEmpty else { return .failure(.server(tokens.error)) }
            KeychainTokens.save(tokens, previousRefresh: "")
            isSignedIn = !tokens.refreshToken.isEmpty
            await refreshAccountEmail()
            return .success(())
        }
    }

    /// 開系統瀏覽器，等它跳回我們的 scheme。
    private func present(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let scheme = oauthUrlScheme(platform: .apple)
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: scheme) { callback, error in
                if let callback {
                    continuation.resume(returning: callback)
                } else {
                    continuation.resume(throwing: error ?? Failure.cancelled)
                }
            }
            session.presentationContextProvider = self
            // 不共用 Safari 的 cookie 的話，使用者每次都要重打 Google 密碼。
            session.prefersEphemeralWebBrowserSession = false
            self.session = session
            session.start()
        }
    }

    // MARK: - 取用與更新

    /// 拿一個能用的 access token，必要時先更新。
    ///
    /// 回 nil 代表**要請使用者重新登入**，不是「等一下再試」——
    /// 兩者混在一起會變成無限重試的背景迴圈，而使用者只看到「同步失敗」
    /// 卻不知道該去登入。專案還在 Testing 狀態時，refresh token 七天就會到這裡。
    public func validAccessToken(forceRefresh: Bool = false) async -> String? {
        let current = KeychainTokens.load()
        if !forceRefresh && oauthIsAccessValid(tokens: current, nowS: nowSeconds()) {
            return current.accessToken
        }
        guard !current.refreshToken.isEmpty else { return nil }

        let body = oauthRefreshBody(platform: .apple, refreshToken: current.refreshToken)
        guard case .success(let json) = await post(body) else { return nil }

        let refreshed = oauthParseTokenResponse(json: json, nowS: nowSeconds())
        if !refreshed.error.isEmpty {
            if oauthNeedsReauth(error: refreshed.error) || refreshed.error.contains("invalid_grant") {
                await markNeedsReauth()
            }
            return nil
        }
        // 更新回應通常**沒有** refresh_token，要沿用舊的 ——
        // 覆蓋成空字串的話下一次就再也更新不了。
        KeychainTokens.save(refreshed, previousRefresh: current.refreshToken)
        return refreshed.accessToken
    }

    /// 同步更新權杖（供背景 HTTP 執行緒在遇到 401 時自動重試換證）。
    public nonisolated func refreshTokenSync() -> String? {
        let current = KeychainTokens.load()
        guard !current.refreshToken.isEmpty else { return nil }

        let body = oauthRefreshBody(platform: .apple, refreshToken: current.refreshToken)
        guard let url = URL(string: oauthTokenEndpoint()) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = body.data(using: .utf8)

        let semaphore = DispatchSemaphore(value: 0)
        var responseData: Data?
        let task = URLSession.shared.dataTask(with: request) { data, _, _ in
            responseData = data
            semaphore.signal()
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + 15)

        guard let data = responseData, let json = String(data: data, encoding: .utf8) else {
            return nil
        }

        let nowS = UInt64(max(0, Date().timeIntervalSince1970))
        let refreshed = oauthParseTokenResponse(json: json, nowS: nowS)
        if !refreshed.error.isEmpty {
            if oauthNeedsReauth(error: refreshed.error) || refreshed.error.contains("invalid_grant") {
                markNeedsReauthSync()
            }
            return nil
        }

        KeychainTokens.save(refreshed, previousRefresh: current.refreshToken)
        return refreshed.accessToken
    }

    /// 標記為需要重新授權，清除死掉的憑證。
    @MainActor
    public func markNeedsReauth() {
        KeychainTokens.clear()
        isSignedIn = false
        accountEmail = nil
        UserDefaults.standard.removeObject(forKey: accountEmailKey)
    }

    public nonisolated func markNeedsReauthSync() {
        KeychainTokens.clear()
        UserDefaults.standard.removeObject(forKey: "kairumo.account.googleEmail")
        DispatchQueue.main.async {
            GoogleAuth.shared.isSignedIn = false
            GoogleAuth.shared.accountEmail = nil
        }
    }

    /// 登出並**撤銷**授權。
    ///
    /// 只清本機權杖是不夠的：授權還留在使用者的 Google 帳號裡，
    /// 他在帳號設定裡看得到一個「已授權但我明明登出了」的項目。
    public func signOut() async {
        let refresh = KeychainTokens.load().refreshToken
        if !refresh.isEmpty, let url = URL(string: oauthRevokeUrl(token: refresh)) {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            _ = try? await URLSession.shared.data(for: request)
        }
        KeychainTokens.clear()
        await MainActor.run {
            isSignedIn = false
            accountEmail = nil
            UserDefaults.standard.removeObject(forKey: accountEmailKey)
        }
    }

    private func post(_ body: String) async -> Result<String, Failure> {
        guard let url = URL(string: oauthTokenEndpoint()) else {
            return .failure(.server("bad_token_endpoint"))
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = body.data(using: .utf8)
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            // **錯誤回應的內容也要交給核心**：Google 把 `invalid_grant`
            // 放在 body 裡，只看 HTTP 狀態碼的話分不出「該重新登入」與
            // 「網路壞了」。
            return .success(String(data: data, encoding: .utf8) ?? "")
        } catch {
            return .failure(.server(error.localizedDescription))
        }
    }

    private func nowSeconds() -> UInt64 {
        UInt64(max(0, Date().timeIntervalSince1970))
    }
}

extension GoogleAuth: ASWebAuthenticationPresentationContextProviding {
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Catalyst 與 iPad 都走這一條。拿不到 key window 時給一個空的 ——
        // 系統會自己找，總比 crash 好。
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first ?? ASPresentationAnchor()
    }
}

/// 權杖存在 Keychain。
///
/// refresh token 等同「不必再問密碼就能存取使用者雲端硬碟」的長期憑證，
/// 不可以放在 `UserDefaults` —— 那是明文 plist，備份與檔案存取都讀得到。
///
/// `kSecAttrAccessibleAfterFirstUnlock`：背景同步要在使用者沒有解鎖的情況下
/// 也讀得到。用 `WhenUnlocked` 的話，鎖屏期間的同步會全部失敗。
enum KeychainTokens {

    private static let service = "com.kairumo.padnote.googleoauth"
    private static let account = "tokens"

    static func load() -> FfiTokenSet {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let stored = try? JSONDecoder().decode(StoredTokens.self, from: data)
        else {
            return FfiTokenSet(accessToken: "", refreshToken: "", expiresAtS: 0, error: "")
        }
        return FfiTokenSet(
            accessToken: stored.accessToken,
            refreshToken: stored.refreshToken,
            expiresAtS: stored.expiresAtS,
            error: ""
        )
    }

    static func save(_ tokens: FfiTokenSet, previousRefresh: String) {
        let stored = StoredTokens(
            accessToken: tokens.accessToken,
            refreshToken: tokens.refreshToken.isEmpty ? previousRefresh : tokens.refreshToken,
            expiresAtS: tokens.expiresAtS
        )
        guard let data = try? JSONEncoder().encode(stored) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        // 先刪再加。用 SecItemUpdate 的話，項目不存在時會失敗而且很容易
        // 被當成「存好了」——結果是使用者每次重開都要重新登入。
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }

    private struct StoredTokens: Codable {
        let accessToken: String
        let refreshToken: String
        let expiresAtS: UInt64
    }
}
