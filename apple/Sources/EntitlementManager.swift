//
//  EntitlementManager.swift
//  Kairumo
//
//  職責：
//  1. 管理 Kairumo 免費基礎版（Free）與專業買斷版（Pro Non-Consumable IAP）之權限狀態。
//  2. 封裝 StoreKit 2 一次買斷交易驗證、購買恢復（AppStore.sync）與兌換碼入口。
//  3. 實作方法五（Serverless Ed25519 數位簽章 VIP 禮遇通行證）：
//     透過 `kairumo://vip?gift=<payload_b64url>.<sig_b64url>` 深層連結，
//     在裝置端離線以 `CryptoKit.Curve25519.Signing.PublicKey` 驗章並永久解鎖 Pro。
//  4. 提供 `PaywallSheet` 情境式升級面板，並透過 `EditorSubsystemCoordinator` 掛載，
//     確保主畫布 120Hz 手寫零常態開銷（遵守 Layer 5 守門機制）。
//

import CryptoKit
import Foundation
import os
import StoreKit
import SwiftUI

// MARK: - Pro Feature Gate Categories
enum ProFeatureGate: String, Identifiable, CaseIterable {
    case studios
    case draftingAndSolid
    case translationPen
    case proInk
    case audioTranscription
    case collabHost

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .studios:
            return "paywall_feature_studios_title"
        case .draftingAndSolid:
            return "paywall_feature_drafting_title"
        case .translationPen:
            return "paywall_feature_translation_pen_title"
        case .proInk:
            return "paywall_feature_pro_ink_title"
        case .audioTranscription:
            return "paywall_feature_audio_transcribe_title"
        case .collabHost:
            return "paywall_feature_collab_host_title"
        }
    }

    var descKey: String {
        switch self {
        case .studios:
            return "paywall_feature_studios_desc"
        case .draftingAndSolid:
            return "paywall_feature_drafting_desc"
        case .translationPen:
            return "paywall_feature_translation_pen_desc"
        case .proInk:
            return "paywall_feature_pro_ink_desc"
        case .audioTranscription:
            return "paywall_feature_audio_transcribe_desc"
        case .collabHost:
            return "paywall_feature_collab_host_desc"
        }
    }

    var iconName: String {
        switch self {
        case .studios:
            return "tablecells.badge.ellipsis"
        case .draftingAndSolid:
            return "compass.drawing"
        case .translationPen:
            return "character.bubble.fill"
        case .proInk:
            return "paintbrush.pointed.fill"
        case .audioTranscription:
            return "waveform.badge.magnifyingglass"
        case .collabHost:
            return "person.2.wave.2.fill"
        }
    }
}

// MARK: - Tool Pro Classification
extension EditorToolType {
    /// 基礎版提供 4 款日常筆刷（鋼筆、原子筆、鉛筆、螢光筆）＋橡皮擦＋套索＋遮蔽膠帶；
    /// 工程製圖筆、掃描翻譯筆與 9 款進階藝術筆刷列為 Pro 專屬。
    var isProRequired: Bool {
        switch self {
        case .pen, .ballpoint, .pencil, .highlighter, .eraser, .lasso, .maskingTape:
            return false
        case .drafting, .translationPen,
             .fineliner, .brush, .calligraphy, .charcoal, .crayon,
             .airbrush, .oilpaint, .watercolor, .marker:
            return true
        }
    }

    var proFeatureGate: ProFeatureGate {
        switch self {
        case .drafting:
            return .draftingAndSolid
        case .translationPen:
            return .translationPen
        default:
            return .proInk
        }
    }
}

// MARK: - VIP Gift Pass Payload (Method 5: Ed25519 Signed Token)
struct VIPGiftPayload: Codable, Equatable {
    let tier: String
    let id: String
    let to: String
    let iat: Int
    let exp: Int?
    let note: String?
}

// MARK: - License Tier
enum LicenseTier: Equatable {
    case basic
    case vipLimited(expiryDate: Date)
    case vip
    case pro
}

/// PRO 專屬鑽石星芒拱頂帝王冠（與 VIP 古典三尖平底金冠 crown.fill 形成鮮明外型差異）
struct ProDiamondCrownView: View {
    var size: CGFloat = 13

    var body: some View {
        ZStack {
            Image(systemName: "crown")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size * 0.78)
                .fontWeight(.heavy)
            Image(systemName: "sparkle")
                .resizable()
                .scaledToFit()
                .frame(width: size * 0.5, height: size * 0.5)
                .offset(y: -size * 0.44)
        }
        .frame(width: size, height: size)
        .foregroundStyle(
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.75, blue: 0.98),
                    Color(red: 0.78, green: 0.95, blue: 1.0)
                ],
                startPoint: .bottomLeading,
                endPoint: .topTrailing
            )
        )
    }
}

// MARK: - Two-Step Nudge Notice (方案 B：二段式無打擾輕提示)
struct ProNudgeNotice: Equatable {
    let id: UUID
    let feature: ProFeatureGate
    let itemName: String
    let timestamp: Date
}

// MARK: - Entitlement Manager
@MainActor
final class EntitlementManager: ObservableObject {
    // profile-scope: device Pro 買斷授權與 VIP 禮遇通行證屬於整台裝置共用
    static let shared = EntitlementManager()

    static let proLifetimeProductID = "com.kairumo.padnote.pro.lifetime"
    /// 對應 `scripts/issue-vip-gift.py` 的 Ed25519 驗證公鑰（32 bytes Base64）。
    /// App 僅內嵌公鑰，任何人均無法逆向偽造簽章。
    nonisolated static let vipPublicKeyBase64 = "F+SF0OIF+lUDASUaK4Hi3Iu1kYTUmDfbmF0kdOATeYc="

    private static let storeKitCacheKey = "kairumo.entitlement.storekitPro"
    private static let vipTokenStorageKey = "kairumo.entitlement.vipToken"
    private static let showLockedProBrushesKey = "kairumo.entitlement.showLockedProBrushes"

    @Published private(set) var isStoreKitPurchased: Bool = false
    @Published private(set) var isVIPUnlocked: Bool = false
    @Published private(set) var vipRecipientName: String?
    @Published private(set) var vipExpirationDate: Date?
    @Published private(set) var proProduct: Product?
    @Published private(set) var isPurchasing: Bool = false
    @Published var activePaywallFeature: ProFeatureGate?
    @Published var feedbackBannerText: String?
    /// 方案 B：第一次點到未解鎖工具時顯示的頂部輕量膠囊提示（不直接彈大視窗）
    @Published var activeNudge: ProNudgeNotice?
    /// 方案 C：基礎版是否展開工具列上的 11 款 Pro 進階筆刷（預設收合 false，保持工具列清爽）
    @Published var showLockedProBrushes: Bool = false

    private var updatesTask: Task<Void, Never>?
    private var nudgeDismissTask: Task<Void, Never>?

    var licenseTier: LicenseTier {
        if isStoreKitPurchased {
            return .pro
        }
        if isVIPUnlocked {
            if let exp = vipExpirationDate {
                return .vipLimited(expiryDate: exp)
            } else {
                return .vip
            }
        }
        return .basic
    }

    /// 授權日期格式化（如 2026/12/31）
    static func formatLicenseDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: date)
    }

    var isProUnlocked: Bool {
        let env = ProcessInfo.processInfo.environment
        if env["KAIRUMO_UITEST_FORCE_FREE"] == "1" {
            return isStoreKitPurchased || isVIPUnlocked
        }
        if env["KAIRUMO_UITEST"] == "1" {
            return true
        }
        return isStoreKitPurchased || isVIPUnlocked
    }

    private init() {
        let defaults = ProfileDefaults.device
        self.isStoreKitPurchased = defaults.bool(forKey: Self.storeKitCacheKey)
        self.showLockedProBrushes = defaults.bool(forKey: Self.showLockedProBrushesKey)
        if let savedToken = defaults.string(forKey: Self.vipTokenStorageKey),
           let payload = Self.verifyVIPToken(savedToken) {
            self.isVIPUnlocked = true
            self.vipRecipientName = payload.to
            if let exp = payload.exp {
                self.vipExpirationDate = Date(timeIntervalSince1970: TimeInterval(exp))
            } else {
                self.vipExpirationDate = nil
            }
        }

        updatesTask = Task { [weak self] in
            await self?.observeTransactionUpdates()
        }
        Task { [weak self] in
            await self?.refreshEntitlements()
            await self?.loadProducts()
        }
    }

    deinit {
        updatesTask?.cancel()
        nudgeDismissTask?.cancel()
    }

    // MARK: - 方案 C：Pro 筆刷收合與展開控制
    func toggleLockedProBrushes() {
        showLockedProBrushes.toggle()
        ProfileDefaults.device.set(showLockedProBrushes, forKey: Self.showLockedProBrushesKey)
    }

    /// 判斷特定工具是否應在當前工具列顯示（基礎版預設收合 Pro 筆刷，展開後或升級後顯示）
    func shouldDisplayToolInToolbar(_ tool: EditorToolType) -> Bool {
        if !tool.isProRequired || isProUnlocked {
            return true
        }
        return showLockedProBrushes
    }

    // MARK: - Gate Helper & 方案 B 二段式輕提示
    func requirePro(_ feature: ProFeatureGate, itemName: String? = nil, perform action: () -> Void) {
        if isProUnlocked {
            action()
        } else {
            nudgeOrPresentPaywall(focus: feature, itemName: itemName)
        }
    }

    /// 方案 B：第一次點擊未解鎖功能時僅彈出頂部輕量膠囊提示（3.2 秒自動消失）；
    /// 若使用者在 3.5 秒內連續點擊第二次同一個 Pro 功能，或主動點擊提示上的「了解詳情 ▸」，才開啟完整購買視窗。
    func nudgeOrPresentPaywall(focus feature: ProFeatureGate, itemName: String? = nil) {
        let resolvedName: String
        if let name = itemName, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            resolvedName = name
        } else {
            resolvedName = L10n.t(feature.titleKey)
        }

        let now = Date()
        if let current = activeNudge,
           current.feature == feature,
           current.itemName == resolvedName,
           now.timeIntervalSince(current.timestamp) < 3.5 {
            dismissNudge()
            activePaywallFeature = feature
            return
        }

        let notice = ProNudgeNotice(id: UUID(), feature: feature, itemName: resolvedName, timestamp: now)
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            activeNudge = notice
        }
        nudgeDismissTask?.cancel()
        nudgeDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_200_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self = self, self.activeNudge?.id == notice.id else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    self.activeNudge = nil
                }
            }
        }
    }

    func dismissNudge() {
        nudgeDismissTask?.cancel()
        withAnimation(.easeOut(duration: 0.18)) {
            activeNudge = nil
        }
    }

    // orphan-ok: 供首頁與輕提示膠囊主動開啟完整升級面板
    func presentPaywall(focus feature: ProFeatureGate = .studios) {
        dismissNudge()
        activePaywallFeature = feature
    }

    // MARK: - StoreKit 2 Operations

    /// 上一次向 App Store 取商品的結果。用來分辨「連不上 App Store」與「連得上但商品不存在」——
    /// 後者是內購項目未通過審核／未上架（實際發生過：App 已上架，內購仍在「準備提交」），
    /// 以前兩者都顯示「請檢查網路」，使用者與開發者都被誤導。
    enum ProductLoadState: Equatable {
        case notLoaded
        case loaded
        /// 請求成功，但 App Store 沒有回傳這個商品。
        case productMissing
        /// 請求本身失敗（離線、App Store 服務異常）。
        case requestFailed
    }

    @Published private(set) var productLoadState: ProductLoadState = .notLoaded
    private static let storeLog = Logger(subsystem: "com.kairumo", category: "storekit")

    func loadProducts() async {
        do {
            let fetched = try await Product.products(for: [Self.proLifetimeProductID])
            if let match = fetched.first(where: { $0.id == Self.proLifetimeProductID }) {
                self.proProduct = match
                productLoadState = .loaded
            } else {
                productLoadState = .productMissing
                Self.storeLog.error("App Store returned no product for \(Self.proLifetimeProductID, privacy: .public)")
            }
        } catch {
            productLoadState = .requestFailed
            Self.storeLog.error("Product request failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 購買面板打開時呼叫：清掉上一次留下的提示，商品還沒取到就再取一次。
    func preparePaywall() async {
        feedbackBannerText = nil
        if proProduct == nil {
            await loadProducts()
        }
    }

    /// 取不到商品時要顯示哪一句話。
    private var productUnavailableMessage: String {
        productLoadState == .productMissing
            ? L10n.t("paywall_product_unavailable")
            : L10n.t("paywall_store_unavailable")
    }

    func refreshEntitlements() async {
        var foundPro = false
        for await verificationResult in Transaction.currentEntitlements {
            if case .verified(let transaction) = verificationResult,
               transaction.productID == Self.proLifetimeProductID,
               transaction.revocationDate == nil {
                foundPro = true
                break
            }
        }
        if foundPro != isStoreKitPurchased {
            isStoreKitPurchased = foundPro
            ProfileDefaults.device.set(foundPro, forKey: Self.storeKitCacheKey)
        }
    }

    func purchaseLifetimePro() async {
        guard !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }

        if proProduct == nil {
            await loadProducts()
        }
        guard let product = proProduct else {
            feedbackBannerText = productUnavailableMessage
            return
        }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    markStoreKitUnlocked()
                    feedbackBannerText = L10n.t("pro_unlocked_toast")
                    activePaywallFeature = nil
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            Self.storeLog.error("Purchase failed: \(error.localizedDescription, privacy: .public)")
            feedbackBannerText = L10n.t("paywall_store_unavailable")
        }
    }

    func restorePurchases() async {
        guard !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
            if isProUnlocked {
                feedbackBannerText = L10n.t("pro_unlocked_toast")
                activePaywallFeature = nil
            } else {
                feedbackBannerText = L10n.t("paywall_restore_nothing")
            }
        } catch {
            feedbackBannerText = L10n.t("paywall_store_unavailable")
        }
    }

    private func observeTransactionUpdates() async {
        for await verificationResult in Transaction.updates {
            if case .verified(let transaction) = verificationResult {
                if transaction.productID == Self.proLifetimeProductID {
                    if transaction.revocationDate == nil {
                        markStoreKitUnlocked()
                    } else {
                        isStoreKitPurchased = false
                        ProfileDefaults.device.set(false, forKey: Self.storeKitCacheKey)
                    }
                }
                await transaction.finish()
            }
        }
    }

    private func markStoreKitUnlocked() {
        isStoreKitPurchased = true
        ProfileDefaults.device.set(true, forKey: Self.storeKitCacheKey)
    }

    // MARK: - Method 5: Ed25519 VIP Gift Pass Verification
    /// 處理 `kairumo://vip?gift=<payload_b64url>.<sig_b64url>` 深層連結
    @discardableResult
    func handleVIPUrl(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "kairumo",
              url.host?.lowercased() == "vip" else {
            return false
        }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let giftToken = components.queryItems?.first(where: { $0.name == "gift" })?.value,
              !giftToken.isEmpty else {
            feedbackBannerText = L10n.t("pro_vip_invalid_toast")
            return true
        }

        if let payload = Self.verifyVIPToken(giftToken) {
            ProfileDefaults.device.set(giftToken, forKey: Self.vipTokenStorageKey)
            isVIPUnlocked = true
            vipRecipientName = payload.to
            if let exp = payload.exp {
                vipExpirationDate = Date(timeIntervalSince1970: TimeInterval(exp))
            } else {
                vipExpirationDate = nil
            }
            feedbackBannerText = L10n.t("pro_unlocked_vip_toast")
            activePaywallFeature = nil
        } else {
            feedbackBannerText = L10n.t("pro_vip_invalid_toast")
        }
        return true
    }

    /// 純函式驗章：驗證 `<payload_b64url>.<sig_b64url>` 是否由開發者 Ed25519 私鑰簽發且未過期
    static func verifyVIPToken(
        _ rawToken: String,
        publicKeyBase64: String = EntitlementManager.vipPublicKeyBase64,
        nowTimestamp: Int = Int(Date().timeIntervalSince1970)
    ) -> VIPGiftPayload? {
        let trimmed = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }

        guard let payloadData = decodeBase64URL(String(parts[0])),
              let sigData = decodeBase64URL(String(parts[1])),
              let pubKeyData = Data(base64Encoded: publicKeyBase64) else {
            return nil
        }

        do {
            let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: pubKeyData)
            guard publicKey.isValidSignature(sigData, for: payloadData) else {
                return nil
            }
            let payload = try JSONDecoder().decode(VIPGiftPayload.self, from: payloadData)
            guard payload.tier == "pro_lifetime" else {
                return nil
            }
            if let exp = payload.exp, nowTimestamp > exp {
                return nil
            }
            return payload
        } catch {
            return nil
        }
    }

    private static func decodeBase64URL(_ input: String) -> Data? {
        var base64 = input
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }
        return Data(base64Encoded: base64)
    }

    #if DEBUG
    // orphan-ok: 供單元測試重置 VIP 狀態
    func resetVIPForTesting() {
        ProfileDefaults.device.removeObject(forKey: Self.vipTokenStorageKey)
        isVIPUnlocked = false
        vipRecipientName = nil
        vipExpirationDate = nil
    }
    #endif
}

// MARK: - Contextual Paywall Sheet
struct PaywallSheet: View {
    let highlightedFeature: ProFeatureGate
    @ObservedObject private var entitlement = EntitlementManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showOfferCodeRedemption = false

    private var orderedFeatures: [ProFeatureGate] {
        var list = ProFeatureGate.allCases
        if let idx = list.firstIndex(of: highlightedFeature) {
            list.remove(at: idx)
            list.insert(highlightedFeature, at: 0)
        }
        return list
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerCard
                    featureListSection
                    dataSafetyNotice
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .safeAreaInset(edge: .bottom) {
                bottomActionBar
            }
            .navigationTitle(L10n.t("paywall_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("close")) {
                        dismiss()
                    }
                }
            }
            #if !targetEnvironment(macCatalyst)
            .offerCodeRedemption(isPresented: $showOfferCodeRedemption)
            #endif
            .task {
                await entitlement.preparePaywall()
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Circle().fill(Color.accentColor))

                Text(L10n.t("paywall_lifetime_badge"))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.accentColor)

                Spacer()

                if entitlement.isProUnlocked {
                    Text(L10n.t("pro_status_unlocked"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.green)
                }
            }

            Text(L10n.t("paywall_title"))
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            Text(L10n.t("paywall_subtitle"))
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if case .vipLimited(let expiry) = entitlement.licenseTier {
                let dateStr = EntitlementManager.formatLicenseDate(expiry)
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "hourglass.badge.gearshape")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(red: 0.65, green: 0.38, blue: 0.15))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.t("paywall_vip_limited_notice").replacingOccurrences(of: "%@", with: dateStr))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color(red: 0.65, green: 0.38, blue: 0.15))
                        Text(L10n.t("paywall_vip_limited_desc").replacingOccurrences(of: "%@", with: dateStr))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 0.65, green: 0.38, blue: 0.15).opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(red: 0.65, green: 0.38, blue: 0.15).opacity(0.35), lineWidth: 1)
                        )
                )
            }

            if let feedback = entitlement.feedbackBannerText {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.accentColor)
                    Text(feedback)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.accentColor.opacity(0.12))
                )
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
    }

    private var featureListSection: some View {
        VStack(spacing: 12) {
            ForEach(orderedFeatures) { feature in
                let isHighlighted = (feature == highlightedFeature)
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: feature.iconName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(isHighlighted ? .white : .accentColor)
                        .frame(width: 42, height: 42)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isHighlighted ? Color.accentColor : Color.accentColor.opacity(0.12))
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(L10n.t(feature.titleKey))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.primary)
                            if isHighlighted {
                                Text(L10n.t("pro_badge"))
                                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.orange))
                            }
                        }
                        Text(L10n.t(feature.descKey))
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(UIColor.secondarySystemGroupedBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(isHighlighted ? Color.accentColor.opacity(0.55) : Color.clear, lineWidth: 1.5)
                        )
                )
            }
        }
    }

    private var dataSafetyNotice: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.shield.fill")
                .foregroundColor(.green)
                .font(.system(size: 16))
            Text(L10n.t("paywall_existing_data_safe"))
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
    }

    private var bottomActionBar: some View {
        VStack(spacing: 10) {
            Button {
                Task {
                    await entitlement.purchaseLifetimePro()
                }
            } label: {
                HStack(spacing: 8) {
                    if entitlement.isPurchasing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "lock.open.fill")
                    }
                    Text(L10n.t("paywall_buy_button"))
                        .fontWeight(.bold)
                    if let price = entitlement.proProduct?.displayPrice {
                        Text("· \(price)")
                            .fontWeight(.semibold)
                    }
                }
                .font(.system(size: 16))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(entitlement.isStoreKitPurchased ? Color.green : Color.accentColor)
                )
            }
            .disabled(entitlement.isPurchasing || entitlement.isStoreKitPurchased)

            HStack(spacing: 18) {
                Button {
                    Task {
                        await entitlement.restorePurchases()
                    }
                } label: {
                    Text(L10n.t("paywall_restore_button"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .disabled(entitlement.isPurchasing)

                #if !targetEnvironment(macCatalyst)
                Button {
                    showOfferCodeRedemption = true
                } label: {
                    Text(L10n.t("paywall_redeem_button"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
                #endif
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
    }
}

// MARK: - 方案 A：Pro 微徽章角標、半透明降飽和修飾器與選單標籤
struct ProMicroBadgeView: View {
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 1.5) {
            Image(systemName: "lock.fill")
                .font(.system(size: compact ? 6.5 : 7, weight: .bold))
            if !compact {
                Text(L10n.t("pro_badge"))
                    .font(.system(size: 7.5, weight: .heavy, design: .rounded))
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, compact ? 3.5 : 4.5)
        .padding(.vertical, 1.5)
        .background(
            Capsule().fill(
                LinearGradient(
                    colors: [Color.orange, Color(red: 0.92, green: 0.45, blue: 0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        )
        .shadow(color: Color.black.opacity(0.18), radius: 1.5, x: 0, y: 1)
        .allowsHitTesting(false)
    }
}

struct ProLockedToolbarItemModifier: ViewModifier {
    let isLocked: Bool
    var compactBadge: Bool = true

    func body(content: Content) -> some View {
        content
            .opacity(isLocked ? 0.48 : 1.0)
            .saturation(isLocked ? 0.45 : 1.0)
            .overlay(alignment: .topTrailing) {
                if isLocked {
                    ProMicroBadgeView(compact: compactBadge)
                        .offset(x: 3, y: -2)
                }
            }
    }
}

struct ProMenuItemLabel: View {
    let title: String
    let systemImage: String
    let isLocked: Bool

    var body: some View {
        Label(
            isLocked ? "\(title)  🔒 \(L10n.t("pro_badge"))" : title,
            systemImage: systemImage
        )
    }
}

// MARK: - 方案 C：工具列「展開／收合 Pro 進階筆組」按鈕
struct ProBrushesCollapseButton: View {
    let showLabels: Bool
    let proToolCount: Int
    @ObservedObject private var entitlement = EntitlementManager.shared

    var body: some View {
        if !entitlement.isProUnlocked && proToolCount > 0 {
            let expanded = entitlement.showLockedProBrushes
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                    entitlement.toggleLockedProBrushes()
                }
            } label: {
                VStack(spacing: 2) {
                    HStack(spacing: 3) {
                        Image(systemName: expanded ? "chevron.left.circle.fill" : "sparkles")
                            .font(.system(size: 11, weight: .bold))
                        if !expanded {
                            Text("\(L10n.t("pro_badge")) \(proToolCount)")
                                .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                        }
                        Image(systemName: expanded ? "chevron.left" : "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.orange.opacity(expanded ? 0.18 : 0.11))
                            .overlay(
                                Capsule()
                                    .stroke(Color.orange.opacity(0.38), lineWidth: 1)
                            )
                    )

                    if showLabels {
                        Text(L10n.t(expanded ? "pro_brushes_collapse_btn" : "pro_brushes_expand_btn"))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(L10n.t("pro_brushes_toggle_hint"))
            .accessibilityLabel(L10n.t(expanded ? "pro_brushes_collapse_btn" : "pro_brushes_expand_btn"))
            .accessibilityIdentifier("editor.ink.pro_brushes_toggle")
        }
    }
}

// MARK: - 方案 B：頂部二段式無打擾輕提示膠囊（Pro Nudge Banner）
struct ProNudgeBannerView: View {
    let nudge: ProNudgeNotice
    @ObservedObject private var entitlement = EntitlementManager.shared

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 3) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 9, weight: .bold))
                Text(L10n.t("pro_badge"))
                    .font(.system(size: 9.5, weight: .heavy, design: .rounded))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.orange))

            Text(String(format: L10n.t("pro_nudge_toast_format"), nudge.itemName))
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)

            Button {
                entitlement.presentPaywall(focus: nudge.feature)
            } label: {
                Text(L10n.t("pro_nudge_learn_more"))
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.accentColor))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("paywall.nudge.learn_more")

            Button {
                entitlement.dismissNudge()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(4)
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 10)
        .padding(.trailing, 8)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(.regularMaterial)
                .overlay(
                    Capsule()
                        .stroke(Color.orange.opacity(0.45), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.16), radius: 8, x: 0, y: 3)
        .padding(.top, 52)
        .padding(.horizontal, 16)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - Paywall Subsystem Modifier
struct PaywallSubsystemModifier: ViewModifier {
    @ObservedObject private var entitlement = EntitlementManager.shared

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let nudge = entitlement.activeNudge {
                    ProNudgeBannerView(nudge: nudge)
                        .zIndex(999)
                }
            }
            .sheet(item: $entitlement.activePaywallFeature) { feature in
                PaywallSheet(highlightedFeature: feature)
            }
    }
}

extension View {
    /// 掛載 Pro 升級面板與二段式輕提示膠囊（支援從編輯器或首頁隨需喚起）
    func paywallSubsystem() -> some View {
        self.modifier(PaywallSubsystemModifier())
    }

    /// 方案 A：為工具列上的未解鎖 Pro 按鈕套用降飽和半透明與微型鎖頭角標
    func proLockedToolbarItem(_ isLocked: Bool, compactBadge: Bool = true) -> some View {
        self.modifier(ProLockedToolbarItemModifier(isLocked: isLocked, compactBadge: compactBadge))
    }
}
