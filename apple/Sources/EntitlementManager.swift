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

    @Published private(set) var isStoreKitPurchased: Bool = false
    @Published private(set) var isVIPUnlocked: Bool = false
    @Published private(set) var vipRecipientName: String?
    @Published private(set) var proProduct: Product?
    @Published private(set) var isPurchasing: Bool = false
    @Published var activePaywallFeature: ProFeatureGate?
    @Published var feedbackBannerText: String?

    private var updatesTask: Task<Void, Never>?

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
        if let savedToken = defaults.string(forKey: Self.vipTokenStorageKey),
           let payload = Self.verifyVIPToken(savedToken) {
            self.isVIPUnlocked = true
            self.vipRecipientName = payload.to
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
    }

    // MARK: - Gate Helper
    func requirePro(_ feature: ProFeatureGate, perform action: () -> Void) {
        if isProUnlocked {
            action()
        } else {
            activePaywallFeature = feature
        }
    }

    // orphan-ok: 供首頁與工具列開啟升級面板
    func presentPaywall(focus feature: ProFeatureGate = .studios) {
        activePaywallFeature = feature
    }

    // MARK: - StoreKit 2 Operations
    func loadProducts() async {
        do {
            let fetched = try await Product.products(for: [Self.proLifetimeProductID])
            if let match = fetched.first(where: { $0.id == Self.proLifetimeProductID }) {
                self.proProduct = match
            }
        } catch {
            // 離線或沙盒未配置時靜默降級，保留靜態價格展示
        }
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
            feedbackBannerText = L10n.t("paywall_store_unavailable")
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
                        .fill(entitlement.isProUnlocked ? Color.green : Color.accentColor)
                )
            }
            .disabled(entitlement.isPurchasing || entitlement.isProUnlocked)

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

// MARK: - Paywall Subsystem Modifier
struct PaywallSubsystemModifier: ViewModifier {
    @ObservedObject private var entitlement = EntitlementManager.shared

    func body(content: Content) -> some View {
        content
            .sheet(item: $entitlement.activePaywallFeature) { feature in
                PaywallSheet(highlightedFeature: feature)
            }
    }
}

extension View {
    /// 掛載 Pro 升級面板（支援從編輯器或首頁隨需喚起）
    func paywallSubsystem() -> some View {
        self.modifier(PaywallSubsystemModifier())
    }
}
