//
//  ProfileManager.swift
//  Kairumo
//
//  設定檔的管理與**切換引擎**。
//
//  # 切換最危險的是什麼
//
//  不是「讀到別人的資料」，而是**舊設定檔的寫入落到新設定檔的目錄**：
//  A 的編輯器在切換的那一刻還有一筆沒存、A 的同步還在跑第三本筆記、A 的背景寫檔佇列還排著一份快照。
//  這些工作的檔案路徑是「執行時才算」的（問 `ProfileContext` 現在是誰），切換之後它們就會寫進 B ——
//  範例筆記的 id 在每個設定檔都一樣，所以這種錯**不會報任何錯誤**，只是 B 的筆記悄悄變成 A 的內容。
//
//  所以順序是硬性的：
//
//  1. **先拆畫面**（`isSwitching`）：編輯器在舊設定檔還有效時存檔、消失。
//  2. **再停活動**：每個 `ProfileScoped` 的 `prepareForProfileSwitch()` 停掉該停的；接著取得全域同步閘門
//     （拿到就代表沒有任何一輪還在跑），最後才是 `finishPreparingForProfileSwitch()` 做最後的存檔。
//  3. **然後才切**：寫名單、改 `ProfileContext`。
//  4. **最後重載**：每個 `ProfileScoped` 的 `resetForProfileSwitch()` 丟掉舊的、讀新的；畫面整棵重建（`epoch`）。
//
//  步驟 3 之前任何一步失敗都**整個放棄**，使用者留在原本的設定檔，什麼都沒變。

import Foundation
import SwiftUI

/// 持有「屬於某個設定檔的狀態」的單例。切換設定檔時由 `ProfileManager` 依序呼叫。
///
/// `scripts/check-profile-scope.py` 保證：每個標成 `profile-scope: profile` 的單例都實作了
/// `resetForProfileSwitch()` —— 漏一個，切換之後下一個使用者就看得到上一個人的東西。
@MainActor
protocol ProfileScoped: AnyObject {
    /// 舊設定檔**還有效**時呼叫：停掉該停的（錄音、連線、計時器、進行中的工作）。
    /// 這時同步可能還在跑，所以**不要在這裡做最後的存檔** —— 見 `finishPreparingForProfileSwitch()`。
    func prepareForProfileSwitch() async
    /// 同步已經安靜下來（取得全域閘門）**之後**呼叫：做最後的存檔。
    /// 為什麼分兩段：同步的匯入會在跑的途中寫進筆記庫；在它結束前存檔，存完它又寫了一次，
    /// 切換之後那一筆就卡在舊設定檔的記憶體裡、或更糟 —— 落到新設定檔。
    func finishPreparingForProfileSwitch() async
    /// 新設定檔**已經生效**後呼叫：丟掉記憶體裡屬於舊設定檔的東西，從新設定檔重新載入。
    func resetForProfileSwitch()
}

extension ProfileScoped {
    func prepareForProfileSwitch() async {}
    func finishPreparingForProfileSwitch() async {}
}

extension Notification.Name {
    /// 設定檔**即將**切換。編輯器等持有未存內容的畫面收到就要立刻存檔 ——
    /// 這時 `ProfileContext` 還是舊的，存下去的位置才對。
    public static let kairumoProfileWillSwitch = Notification.Name("kairumo.profile.willSwitch")
    /// 設定檔已經切換完成（新的設定檔已載入）。
    public static let kairumoProfileDidSwitch = Notification.Name("kairumo.profile.didSwitch")
}

@MainActor
public final class ProfileManager: ObservableObject {
    // profile-scope: device 設定檔名單本身是整台裝置共用的
    public static let shared = ProfileManager()

    @Published public internal(set) var registry: ProfileRegistry
    /// 每次切換遞增。根畫面用它當 `.id`，整棵重建 —— 舊設定檔的畫面狀態一個都不留。
    @Published public private(set) var epoch = 0
    /// 切換進行中。根畫面此時只顯示一個中性的等待畫面，讓編輯器在舊設定檔還有效時存檔、消失。
    @Published public private(set) var isSwitching = false
    /// 使用中的設定檔需要解鎖。**只是畫面閘門**：資料已經在記憶體裡（見 `ProfileLockService` 的說明）。
    @Published public internal(set) var isLocked: Bool

    var storage: ProfileRegistryStorage
    let lockService: ProfileLockService
    /// 切換時依序處理的單例。順序有意義：下游依賴上游（`NotebookStore` 讀 `AccountSyncStore`，
    /// `LocalizationManager` 讀 `AccountSyncStore`，`AccountManager` 讀前兩者與 `GoogleAuth`）。
    ///
    /// 用閉包而不是陣列：單例是**用到才建立**的，`ProfileManager` 建立時不該把全部單例一次叫起來。
    var participantsProvider: () -> [ProfileScoped]
    /// 不是單例、但持有設定檔狀態的全域快取（`static var`）。切換後重設。
    var extraResetsProvider: () -> [() -> Void]
    /// 切換前讓同步安靜下來。預設實作是取得全域同步閘門；測試可以換掉。
    var quiesce: @MainActor () async -> SyncQuiesceToken?
    /// 切換完成之後重新啟動服務（同步、區網…）。
    var restart: @MainActor () async -> Void
    /// 上一次進背景的時間，用來決定回來時要不要重新上鎖。
    var backgroundedAt: Date?

    /// 離開 App 超過這麼久，回來要重新輸入 PIN。
    public static let relockAfterBackground: TimeInterval = 60

    public enum SwitchError: Error, Equatable {
        case alreadyActive
        case unknownProfile
        /// 同步還沒停下來（超時）。使用者留在原本的設定檔，稍後再試。
        case syncBusy
        case registryNotSaved
    }

    /// 同步閘門的憑證。放掉它之後才會有新的一輪同步開始。
    public struct SyncQuiesceToken {
        let release: () -> Void
        init(release: @escaping () -> Void) { self.release = release }
    }

    init(
        storage: ProfileRegistryStorage = ProfileRegistryStorage(fileURL: ProfileRegistryStorage.standardURL),
        lockService: ProfileLockService = .shared,
        participants: (() -> [ProfileScoped])? = nil,
        extraResets: (() -> [() -> Void])? = nil,
        quiesce: (@MainActor () async -> SyncQuiesceToken?)? = nil,
        restart: (@MainActor () async -> Void)? = nil
    ) {
        self.storage = storage
        self.lockService = lockService
        let loaded = Self.loadOrCreateRegistry(storage: storage)
        self.registry = loaded
        self.isLocked = loaded.active.lock.isEnabled
        self.participantsProvider = participants ?? { Self.defaultParticipants() }
        self.extraResetsProvider = extraResets ?? { Self.defaultExtraResets() }
        self.quiesce = quiesce ?? { await Self.defaultQuiesce() }
        self.restart = restart ?? { await Self.defaultRestart() }
        // `ProfileContext` 與名單必須一致。它們在切換時依「先名單、後 context」的順序寫，
        // 兩步之間若被中斷，以名單為準。
        if ProfileContext.activeId != loaded.activeId {
            ProfileContext.setActive(loaded.activeId)
        }
    }

    // MARK: - 載入

    /// 讀名單；沒有就建立只有預設設定檔的初始名單（對應升級前就存在的資料，什麼都不搬）。
    static func loadOrCreateRegistry(storage: ProfileRegistryStorage) -> ProfileRegistry {
        let fallbackName = ProfileDefaults(profileId: ProfileRecord.defaultId)
            .data(forKey: "kairumo.user.profile")
            .flatMap { try? JSONDecoder().decode(UserProfile.self, from: $0) }?
            .displayName ?? "Kairumo"
        let fallbackColor = IdentityPalette.defaultHex
        if let existing = storage.load() {
            let repaired = existing.repaired(fallbackName: fallbackName, fallbackColor: fallbackColor)
            if repaired != existing { try? storage.save(repaired) }
            return repaired
        }
        let initial = ProfileRegistry.initial(displayName: fallbackName, colorHex: fallbackColor)
        try? storage.save(initial)
        return initial
    }

    /// 在**任何單例被碰到之前**呼叫（`KairumoApp.init`）：讓 `ProfileContext` 對齊名單。
    /// 單例的 `init` 會依 `ProfileContext.activeId` 讀資料 —— 若它是舊的，整個 App 就載入錯的設定檔。
    public nonisolated static func reconcileContextBeforeLaunch() {
        let storage = ProfileRegistryStorage(fileURL: ProfileRegistryStorage.standardURL)
        guard let registry = storage.load(),
              registry.profile(id: registry.activeId) != nil,
              registry.activeId != ProfileContext.activeId
        else { return }
        ProfileContext.setActive(registry.activeId)
    }

    // MARK: - 查詢

    public var profiles: [ProfileRecord] { registry.profiles }
    public var active: ProfileRecord { registry.active }
    public var canAddProfile: Bool { registry.canAdd }

    // MARK: - 切換

    /// 切到另一個設定檔。**呼叫之前**，若那個設定檔有鎖，呼叫端要先讓使用者過關（`unlock`）。
    public func switchTo(_ id: String) async throws {
        guard !isSwitching else { throw SwitchError.syncBusy }
        guard id != registry.activeId else { throw SwitchError.alreadyActive }
        guard registry.profile(id: id) != nil else { throw SwitchError.unknownProfile }

        isSwitching = true
        defer { isSwitching = false }

        // 1. 先拆畫面。通知是同步送到的：編輯器在這一刻存檔，`ProfileContext` 還是舊的。
        NotificationCenter.default.post(name: .kairumoProfileWillSwitch, object: nil)
        // 讓 SwiftUI 把等待畫面換上去、舊畫面的 onDisappear 跑完。
        try? await Task.sleep(nanoseconds: 120_000_000)

        // 2. 停下所有活動（舊設定檔仍有效）。
        let participants = participantsProvider()
        for participant in participants {
            await participant.prepareForProfileSwitch()
        }
        guard let token = await quiesce() else {
            // 同步沒有停下來。什麼都還沒改：留在原本的設定檔。
            lastSwitchFailed()
            throw SwitchError.syncBusy
        }
        // 閘門在新設定檔載入完成之後、重啟服務之前放掉；中途失敗（`defer`）也一定放。
        var released = false
        func releaseGate() {
            guard !released else { return }
            released = true
            token.release()
        }
        defer { releaseGate() }
        for participant in participants {
            await participant.finishPreparingForProfileSwitch()
        }

        // 3. 切。先名單、後 context；名單寫不進去就放棄（還沒動任何東西）。
        var next = registry
        do {
            try next.activate(id: id)
            try storage.save(next)
        } catch {
            lastSwitchFailed()
            throw SwitchError.registryNotSaved
        }
        registry = next
        ProfileContext.setActive(id)

        // 4. 重載：丟舊的、讀新的。
        for participant in participants {
            participant.resetForProfileSwitch()
        }
        for reset in extraResetsProvider() { reset() }

        isLocked = false  // 呼叫端已經讓使用者過關。
        backgroundedAt = nil
        epoch += 1
        releaseGate()
        NotificationCenter.default.post(name: .kairumoProfileDidSwitch, object: nil)
        await restart()
    }

    private func lastSwitchFailed() {
        // 拆掉的畫面要還原：epoch 加一就會整棵重建，回到原本的設定檔。
        epoch += 1
    }

    // MARK: - 預設的收尾與重啟（正式環境用）

    /// 切換時依序處理的單例。**順序有意義**：先停活動（同步、錄音、連線），再換身分（登入、同步身分、語言），
    /// 然後才是筆記庫與其餘依賴它們的東西。`scripts/check-profile-scope.py` 保證標成 profile 的單例都有
    /// `resetForProfileSwitch`；新增單例時要同時加進這份清單（`ProfileManagerTests` 會核對）。
    static func defaultParticipants() -> [ProfileScoped] {
        [
            FocusSyncController.shared,
            AutoSyncController.shared,
            AudioRecorderManager.shared,
            CollaborationManager.shared,
            LocalRelayServer.shared,
            LocalSyncDiscovery.shared,
            GoogleAuth.shared,
            AccountSyncStore.shared,
            LocalizationManager.shared,
            AccountManager.shared,
            CloudSyncFolderMonitor.shared,
            NotebookStore.shared,
            ToolbarSettings.shared,
            NotebookSearchIndex.shared,
            StickerManager.shared,
            PenHardwareSettings.shared,
            GuidanceSuppressionManager.shared,
            DraftingState.shared,
            DraftToolController.shared,
            DraftEditController.shared,
            PracticeSession.shared,
            ExportPrintManager.shared,
            SheetCoordinator.shared,
            AudioTranscriber.shared,
            SyncLogger.shared,
        ]
    }

    /// 不是單例、但持有設定檔狀態的全域快取（`static var`）。
    static func defaultExtraResets() -> [() -> Void] {
        [
            { CloudSync.invalidateSession() },
            { ExportedObjectIds.shared.resetForProfileSwitch() },
            { PageThumbnailRenderer.invalidateAll() },
            { ImportedModelCache.resetForProfileSwitch() },
            { PageGeometry.use(format: nil) },
        ]
    }

    static func defaultQuiesce() async -> SyncQuiesceToken? {
        // 與 `NotebookStore.moveStorage` 同一個做法：先請進行中的同步中斷，再取得閘門。
        // 拿到閘門就代表沒有任何一輪還在讀寫套件目錄。
        NotebookSyncCoordinator.cancelSync()
        guard let grant = await SyncGateQueue.enter(label: "profile-switch") else { return nil }
        NotebookSyncCoordinator.resetCancellation()
        return SyncQuiesceToken { _ = syncGateLeave(ticket: grant.ticket) }
    }

    static func defaultRestart() async {
        // 與 App 啟動時做的事相同（見 `KairumoApp`）：搬舊錄音、重掃錄音、啟動同步。
        await RecordingMigration.runIfNeeded(store: NotebookStore.shared)
        NotebookStore.shared.refreshRecordings()
        AutoSyncController.shared.start(
            store: NotebookStore.shared, deviceId: NotebookMigration.deviceId
        )
        AutoSyncController.shared.request(.foreground)
    }

    // MARK: - 上鎖

    /// App 進背景。記下時間：回來時超過 `relockAfterBackground` 且這個設定檔有鎖，就重新上鎖。
    public func noteEnteredBackground(now: Date = Date()) {
        backgroundedAt = now
    }

    public func noteBecameActive(now: Date = Date()) {
        defer { backgroundedAt = nil }
        guard let left = backgroundedAt, registry.active.lock.isEnabled, !isLocked else { return }
        if now.timeIntervalSince(left) >= Self.relockAfterBackground { isLocked = true }
    }
}

/// 切換設定檔時的等待畫面。
struct ProfileSwitchingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text(LocalizationManager.shared.localized("profile_switching"))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .accessibilityIdentifier("profile.switching")
    }
}

/// 零尺寸的觀察者：設定檔即將切換時呼叫 `action`（編輯器在這裡存檔）。
struct ProfileWillSwitchSaver: View {
    let action: () -> Void

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .onReceive(NotificationCenter.default.publisher(for: .kairumoProfileWillSwitch)) { _ in action() }
    }
}
