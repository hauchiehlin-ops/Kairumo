//
//  NotebookSyncCoordinator.swift
//  Kairumo
//
//  把「A 裝置寫、B 裝置打開就有」這條路走完。
//
//  # 之前缺的是什麼
//
//  資料夾同步本身早就在了（`CloudSyncFolder`），但它只搬 `Packages/` 底下的
//  檔案。而使用者真正在編輯的筆記活在 `NotebookStore` 裡，套件只是按一個按鈕
//  才產生的衍生物 —— 而且**沒有回頭的路**。結果是：檔案同步得很成功，
//  另一台裝置上什麼也沒出現。
//
//  # 三步，順序不能顛倒
//
//  1. **先匯出**：把本機改過的筆記寫進套件。放到最後做的話，這一輪上傳的
//     就是上一輪的舊內容。
//  2. **再搬檔**：上傳與下載（聯集複製，策略在核心）。
//  3. **最後匯入**：把套件讀回筆記。這時套件裡已經含有雙方的操作，
//     讀回來的就是合併後的結果。
//
//  匯出走 `exportPreservingOtherDevices` —— 它只覆寫這台裝置自己的檔案。
//  用一般的匯出會把剛下載下來的對方編輯整個刪掉，而且不會有任何錯誤訊息。
//

import Foundation
import PencilKit

/// 同步需要用到的儲存能力。
///
/// 抽出這個協定，是為了讓同步流程**測得到**：`NotebookStore` 是單例又綁死
/// Documents 目錄，測試裡開不出兩台裝置。同步的錯誤（少匯出一步、順序顛倒、
/// 新筆記本被丟掉）只有在兩台裝置的情境下才看得出來，而那正是最該測的部分。
@MainActor
protocol SyncableNotebookStore: AnyObject {
    var syncNotebooks: [NotebookDocument] { get }
    var allNotebooks: [NotebookDocument] { get }
    var syncPackagesDirectory: URL { get }
    var syncAttachmentsDirectory: URL { get }
    /// **別台裝置**寫的那些筆畫。匯出時要扣掉它們，才不會複製一份掛在自己名下。
    var syncBaselineDirectory: URL { get }

    /// 讀一頁筆跡 —— **可以在任何執行緒上呼叫**。
    ///
    /// 為什麼是閉包而不是方法：`syncLoadDrawing` 本身沒有碰任何
    /// `@Published` 狀態（它只是把 URL 兜起來再讀檔），但它掛在
    /// `@MainActor` 的 store 上，於是整個匯出迴圈也被釘在主執行緒 ——
    /// 每本每頁讀一次檔、解一次 PKDrawing、寫一次 CRDT 套件，筆記本一多
    /// 就撞上 iOS 的 10 秒看門狗。把「讀圖」這件事提成一個只捕捉值型別的
    /// `@Sendable` 閉包，匯出就能整段搬到背景執行緒上。
    ///
    /// 實作這個協定的人有義務保證回傳的閉包真的不碰主執行緒狀態。
    var syncDrawingLoader: @Sendable (String, Int) -> PKDrawing { get }
    /// 目前正在編輯／檢視的作用中筆記本 ID（nil 表示在首頁或未指定）
    var activeNotebookId: String? { get }

    func syncLoadDrawing(notebookId: String, pageIndex: Int) -> PKDrawing
    func syncSaveDrawing(notebookId: String, pageIndex: Int, drawing: PKDrawing)
    func syncUpsert(_ document: NotebookDocument)
    func syncPurgeDeletedNotebooks(_ deletedIds: Set<String>)
    func syncRefreshRecordings()
}

extension SyncableNotebookStore {
    var activeNotebookId: String? {
        nil
    }

    func syncPurgeDeletedNotebooks(_: Set<String>) {}
    func syncRefreshRecordings() {}
}

extension NotebookStore: SyncableNotebookStore {
    var syncNotebooks: [NotebookDocument] {
        var list = visibleNotebooks
        let inboxId = recordingInboxNotebookId()
        if let inbox = notebooks.first(where: { $0.id.caseInsensitiveCompare(inboxId) == .orderedSame }),
           !list.contains(where: { $0.id.caseInsensitiveCompare(inboxId) == .orderedSame }) {
            list.append(inbox)
        }
        return list
    }

    func syncRefreshRecordings() {
        refreshRecordings()
    }

    var allNotebooks: [NotebookDocument] {
        notebooks
    }

    var syncPackagesDirectory: URL {
        corePackagesDirectory
    }

    /// 在主執行緒上把目錄抄成一個 URL，回傳的閉包只捕捉那個 URL ——
    /// 所以閉包帶到哪個執行緒都成立。
    var syncDrawingLoader: @Sendable (String, Int) -> PKDrawing {
        let dir = drawingsDirectory
        return { notebookId, pageIndex in
            let url = dir.appending(path: "\(notebookId)_p\(pageIndex).drawing")
            guard let data = try? Data(contentsOf: url),
                  let drawing = try? PKDrawing(data: data)
            else { return PKDrawing() }
            return drawing
        }
    }

    var syncAttachmentsDirectory: URL {
        attachmentsDirectory
    }

    // activeNotebookId 由 NotebookStore 本身的 @Published var 直接滿足協定，不需要在此重新宣告

    var syncBaselineDirectory: URL {
        let dir = documentsDirectory.appendingPathComponent("SyncBaseline", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func syncLoadDrawing(notebookId: String, pageIndex: Int) -> PKDrawing {
        loadDrawing(notebookId: notebookId, pageIndex: pageIndex)
    }

    func syncSaveDrawing(notebookId: String, pageIndex: Int, drawing: PKDrawing) {
        saveDrawing(notebookId: notebookId, pageIndex: pageIndex, drawing: drawing)
    }

    func syncUpsert(_ document: NotebookDocument) {
        upsertNotebook(document)
    }
}

@MainActor
enum NotebookSyncCoordinator {
    struct Report {
        var exported: Int = 0
        var uploaded: Int = 0
        var downloaded: Int = 0
        var imported: Int = 0
        /// 新出現在這台裝置上的筆記本數（另一台裝置建立的）。
        var newNotebooks: Int = 0
        var needsAttention: [String] = []
        var failures: [String: String] = [:]
        /// 這一輪**根本沒跑** —— 已經有另一輪在進行中。
        ///
        /// 跟「跑了但沒事做」要分得開：都回報「已是最新」的話，使用者按下
        /// 「立即同步」看到「已是最新」，會以為雲端真的比對過了。
        var wasSkipped: Bool = false

        var isNoOp: Bool {
            uploaded == 0 && downloaded == 0
        }
    }

    /// 這一輪各頁算出來的「自己的筆畫」。
    ///
    /// 匯出時算出來，匯入後要用它反推「別台裝置的部分」——
    /// `別人的 = 合併後的 − 自己的`。
    private typealias OwnStrokes = [String: PKDrawing]

    /// 閘用的時鐘。
    ///
    /// **要單調的。** 用牆上時鐘的話，時區或校時跳一下就會讓「拿著多久」
    /// 算出負數或幾小時 —— 前者永遠不接手，後者立刻把正在跑的那輪踢掉。
    private static func gateNowMs() -> UInt64 {
        UInt64(ProcessInfo.processInfo.systemUptime * 1000)
    }

    nonisolated static var isCancelled: Bool {
        DriveHttpClient.isCancellationRequested
    }

    nonisolated static func cancelSync() {
        DriveHttpClient.cancelAll()
        SyncLogger.logAsync("【同步中斷】已送出中斷要求，正在終止進行中的任務...", source: .general)
    }

    nonisolated static func resetCancellation() {
        DriveHttpClient.resetCancellation()
    }

    /// 跑完一輪同步。
    ///
    /// - Parameters:
    ///   - store: 筆記本的本機儲存。
    ///   - folder: 使用者選的雲端資料夾。呼叫端負責取得 security scope。
    static func run(store: SyncableNotebookStore, folder: URL, deviceId: UInt32) async -> Report {
        let grant = syncGateTryEnter(label: "folder", nowMs: gateNowMs())
        guard grant.granted else {
            SyncLogger.logAsync(
                "【資料夾同步】已有一輪在跑（\(grant.holder)，\(grant.heldMs / 1000) 秒）—— 這次跳過",
                source: .folder
            )
            var skipped = Report()
            skipped.wasSkipped = true
            return skipped
        }
        if grant.tookOver {
            SyncLogger.logAsync(
                "【資料夾同步】上一輪（\(grant.holder)）卡了 \(grant.heldMs / 1000) 秒沒收尾，接手",
                source: .folder
            )
        }
        defer { _ = syncGateLeave(ticket: grant.ticket) }
        resetCancellation()
        defer { resetCancellation() }
        SyncLogger.logAsync("【資料夾同步】開始執行，目標：\(folder.lastPathComponent)", source: .folder)
        var report = Report()
        let fm = FileManager.default
        let packagesDir = store.syncPackagesDirectory
        try? fm.createDirectory(at: packagesDir, withIntermediateDirectories: true)

        // ── 1. 匯出本機的筆記 ──────────────────────────────
        SyncLogger.logAsync("步驟 1：匯出本機筆記 (\(store.syncNotebooks.count) 本)...", source: .folder)
        // 匯出整段在背景執行緒上跑。
        //
        // 每一本每一頁要讀一次檔、解一次 `PKDrawing`、再寫一次 CRDT 套件，
        // 是整個同步最貴的一段。這段原本跟著 `NotebookSyncCoordinator` 的
        // `@MainActor` 標記留在主執行緒上，於是筆記本一多就被連續佔住十秒
        // 以上 —— iOS 的 scene-update 看門狗直接 SIGKILL（0x8BADF00D）。
        //
        // 先在 MainActor 上把每一本要用到的東西抄成值（便宜，只讀幾個 URL），
        // 之後整個迴圈都不再需要 `store`，就能整包交給背景執行緒。
        // Android 的 `CloudSync.runFull` 從第一天就包在
        // `withContext(Dispatchers.IO)` 裡，這裡是補上同一件事。
        let inputs = store.syncNotebooks.map {
            exportInputs(for: $0, store: store, packagesDir: packagesDir, deviceId: deviceId)
        }
        let exportOutcome = await Task.detached(priority: .utility) { () -> (OwnStrokes, Int, [String: String], Bool) in
            // **這一段不准回到主執行緒。**
            //
            // 不是效能建議，是硬性條件：這裡每本每頁要讀一次檔、解一次
            // PKDrawing、再寫一次 CRDT 套件。在主執行緒上做，筆記本一多就
            // 撞上 iOS 的 scene-update 看門狗 —— 實機上是 SIGKILL
            // 0x8BADF00D，使用者看到的是「按下同步之後整個 App 消失」。
            //
            // 有這一行，任何人把 Task.detached 拿掉的當下就會在開發／測試時
            // 立刻炸掉，而不是等到某台裝置上的筆記本夠多才發現。
            dispatchPrecondition(condition: .notOnQueue(.main))

            var own: OwnStrokes = [:]
            var exported = 0
            var failures = [String: String]()
            for input in inputs {
                if isCancelled || Task.isCancelled {
                    return (own, exported, failures, true)
                }
                do {
                    let mine = try exportOne(input)
                    own.merge(mine) { first, _ in first }
                    exported += 1
                } catch {
                    SyncLogger.logAsync(
                        "匯出失敗 (\(input.document.title))：\(error.localizedDescription)",
                        source: .folder
                    )
                    failures[input.document.title] = error.localizedDescription
                }
            }
            return (own, exported, failures, false)
        }.value
        let ownStrokes = exportOutcome.0
        report.exported = exportOutcome.1
        report.failures.merge(exportOutcome.2) { first, _ in first }
        if exportOutcome.3 {
            SyncLogger.logAsync("【資料夾同步】已手動中斷。", source: .folder)
            return report
        }
        SyncLogger.logAsync("步驟 1 完成，成功匯出 \(report.exported) 本", source: .folder)

        if isCancelled || Task.isCancelled {
            SyncLogger.logAsync("【資料夾同步】已手動中斷。", source: .folder)
            return report
        }

        // ── 2. 搬檔 (雙軌並行排程) ──────────────────────
        SyncLogger.logAsync("步驟 2：搬移雲端檔案 (雙軌並行排程)...", source: .folder)
        let activeLocalIds = Set(store.syncNotebooks.map { $0.id })
        let deletedNotebookIds = AccountSyncStore.shared.deletedNotebookIds
        let activeId = store.activeNotebookId ?? store.syncNotebooks.sorted { $0.lastModifiedDate > $1.lastModifiedDate }.first?.id
        let (syncUploaded, syncDownloaded, syncNeedsAttention, syncFailures, newNotebooks) = await Task.detached(priority: .utility) {
            var up = 0
            var down = 0
            var attention = [String]()
            var fails = [String: String]()
            var newBooks = 0

            // (1) 先清理雲端資料夾中屬於已刪除（帶墓碑）的套件，阻斷死灰復燃
            let remoteFolderItems = (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: [])) ?? []
            for item in remoteFolderItems {
                let actualName = ICloudSyncFolder.isPlaceholder(item) ? ICloudSyncFolder.logicalURL(of: item).lastPathComponent : item.lastPathComponent
                if actualName.hasSuffix(".padnote") {
                    let id = (actualName as NSString).deletingPathExtension
                    if deletedNotebookIds.contains(id) {
                        try? fm.removeItem(at: item)
                    }
                }
            }

            let allDiskPackages = (try? fm.contentsOfDirectory(at: packagesDir, includingPropertiesForKeys: nil))?
                .filter { $0.pathExtension == "padnote" } ?? []

            // (2) 清理本機已刪除殘留套件
            for diskPkg in allDiskPackages {
                let id = packageId(for: diskPkg)
                if deletedNotebookIds.contains(id) {
                    try? fm.removeItem(at: diskPkg)
                }
            }

            // 只同步本機活躍的套件
            let packages = allDiskPackages.filter { activeLocalIds.contains(packageId(for: $0)) && !deletedNotebookIds.contains(packageId(for: $0)) }
            SyncLogger.logAsync("📊【同步前核實】本機現存: \(activeLocalIds.count) 本，待同步活躍筆記: \(packages.count) 本", source: .folder)

            // 軌道一：前台作用中筆記優先極速同步
            var mutablePackages = packages
            if let activeId, let activeIdx = mutablePackages.firstIndex(where: { $0.deletingPathExtension().lastPathComponent == activeId }) {
                let activePkg = mutablePackages.remove(at: activeIdx)
                SyncLogger.logAsync("【前台極速軌】優先同步當前作用中筆記 (\(activeId.prefix(8))...)...", source: .folder)
                let res = CloudSyncFolder.sync(localPackage: activePkg, into: folder)
                up += res.uploaded.count
                down += res.downloaded.count
                attention.append(contentsOf: res.needsAttention)
                fails.merge(res.failures) { first, _ in first }
                SyncLogger.logAsync("【前台極速軌】當前筆記 (\(activeId.prefix(8))...) 完成（上傳: \(res.uploaded.count), 下載: \(res.downloaded.count)）", source: .folder)
            }

            // 軌道二：非作用中筆記背景佇列
            if !mutablePackages.isEmpty {
                SyncLogger.logAsync("【背景佇列】開始同步其餘 \(mutablePackages.count) 本非作用中筆記...", source: .folder)
                for package in mutablePackages {
                    if Task.isCancelled || DriveHttpClient.isCancellationRequested {
                        break
                    }
                    let pkgId = packageId(for: package)
                    SyncLogger.logAsync("【背景佇列】開始同步筆記本 (\(pkgId.prefix(8))...)...", source: .folder)
                    let result = CloudSyncFolder.sync(localPackage: package, into: folder)
                    up += result.uploaded.count
                    down += result.downloaded.count
                    attention.append(contentsOf: result.needsAttention)
                    fails.merge(result.failures) { first, _ in first }
                    SyncLogger.logAsync("【背景佇列】筆記本 (\(pkgId.prefix(8))...) 完成（上傳: \(result.uploaded.count), 下載: \(result.downloaded.count)）", source: .folder)
                }
            }

            // 另一台裝置建立的筆記本，本機還沒有對應的套件目錄 —— 要先整包抓下來（排除已刪除名單）。
            if !Task.isCancelled && !DriveHttpClient.isCancellationRequested {
                var tempReport = Report()
                newBooks = pullUnknownPackages(
                    into: packagesDir,
                    from: folder,
                    activeLocalIds: activeLocalIds,
                    deletedNotebookIds: deletedNotebookIds,
                    report: &tempReport
                )
                attention.append(contentsOf: tempReport.needsAttention)
                fails.merge(tempReport.failures) { first, _ in first }
            }

            return (up, down, attention, fails, newBooks)
        }.value

        report.uploaded += syncUploaded
        report.downloaded += syncDownloaded
        report.needsAttention.append(contentsOf: syncNeedsAttention)
        report.failures.merge(syncFailures) { first, _ in first }
        report.newNotebooks += newNotebooks
        SyncLogger.logAsync("步驟 2 完成。上傳: \(syncUploaded), 下載: \(syncDownloaded), 新增: \(newNotebooks), 失敗: \(syncFailures.count)", source: .folder)

        if isCancelled || Task.isCancelled {
            SyncLogger.logAsync("【資料夾同步】已手動中斷。", source: .folder)
            return report
        }

        // ── 3. 匯入回筆記 ─────────────────────────────────
        SyncLogger.logAsync("步驟 3：匯入套件回本機筆記...", source: .folder)
        await importPackagesForFolderSync(
            from: packagesDir,
            into: store,
            deviceId: deviceId,
            ownStrokes: ownStrokes,
            activeLocalIds: activeLocalIds,
            deletedNotebookIds: deletedNotebookIds,
            report: &report
        )
        store.syncPurgeDeletedNotebooks(deletedNotebookIds)
        store.syncRefreshRecordings()
        SyncLogger.logAsync("【資料夾同步】全部完成。", source: .folder)

        return report
    }

    /// 跑完一輪**Google Drive** 的同步。
    static func runDrive(store: SyncableNotebookStore, deviceId: UInt32) async -> Report? {
        guard await GoogleAuth.shared.isSignedIn else { return nil }
        // **整個行程同一時間只准跑一輪。**
        //
        // 每個入口原本各自帶一個旗標（首頁一顆、設定兩顆、自動同步一個），
        // 那些旗標彼此不認識 —— 自動同步在跑的時候按下「立即同步」，兩輪
        // 就並行了。而併發的症狀完全不像併發：
        //
        //   * 「找不到：/upload/drive/v3/files/…」——兩輪各自為同一本筆記
        //     開了可續傳上傳工作階段，先完成的那一輪把檔案換掉，另一輪
        //     手上的網址就失效了。看起來像 Drive 弄丟檔案。
        //   * 「blob … 下載後雜湊不符」—— 一輪在下載，另一輪同時把同名的
        //     blob 換掉。看起來像傳輸損毀。
        //
        // 鎖在核心（`sync_gate_*`），兩端共用同一把 —— 各寫一份的話，
        // 下一個新增的入口只會補上其中一邊。
        let grant = syncGateTryEnter(label: "google-drive", nowMs: gateNowMs())
        guard grant.granted else {
            SyncLogger.logAsync(
                "【Google Drive 同步】已有一輪在跑（\(grant.holder)，\(grant.heldMs / 1000) 秒）—— 這次跳過",
                source: .googleDrive
            )
            var skipped = Report()
            skipped.wasSkipped = true
            return skipped
        }
        if grant.tookOver {
            SyncLogger.logAsync(
                "【Google Drive 同步】上一輪（\(grant.holder)）卡了 \(grant.heldMs / 1000) 秒沒收尾，接手",
                source: .googleDrive
            )
        }
        defer { _ = syncGateLeave(ticket: grant.ticket) }
        resetCancellation()
        defer { resetCancellation() }
        SyncLogger.logAsync("【Google Drive 同步】開始執行", source: .googleDrive)
        var report = Report()
        let fm = FileManager.default
        let packagesDir = store.syncPackagesDirectory
        try? fm.createDirectory(at: packagesDir, withIntermediateDirectories: true)

        let localIndexJson = AccountSyncStore.shared.indexJSON
        let localLiveItems = syncLiveNotebooks(indexJson: localIndexJson)
        let localLiveById = Dictionary(localLiveItems.map { ($0.id.lowercased(), $0) }, uniquingKeysWith: { first, _ in first })

        // (A) 從 store.allNotebooks 全集確認未刪除的筆記本存在於 localIndexJson，且最新標題與資料夾一致
        for document in store.allNotebooks {
            let docId = document.id.lowercased()
            guard !AccountSyncStore.shared.isDeleted(id: document.id) else { continue }
            if let existing = localLiveById[docId] {
                // 如果本機標題或資料夾改過，記錄進同步索引以推進 Lamport 時戳
                if existing.title != document.title || (existing.parentId ?? "") != (document.folderId ?? "") {
                    AccountSyncStore.shared.record(
                        id: document.id,
                        title: document.title,
                        parentId: document.folderId,
                        isFolder: false
                    )
                }
            } else {
                AccountSyncStore.shared.record(
                    id: document.id,
                    title: document.title,
                    parentId: document.folderId,
                    isFolder: false
                )
            }
        }
        // (B) 清理磁碟套件目錄殘留的已刪除套件（防止墓碑被死灰復燃）
        let diskPackageUrls = (try? fm.contentsOfDirectory(at: packagesDir, includingPropertiesForKeys: nil))?
            .filter { $0.pathExtension == "padnote" } ?? []
        for diskUrl in diskPackageUrls {
            let diskId = packageId(for: diskUrl)
            if AccountSyncStore.shared.isDeleted(id: diskId) {
                try? fm.removeItem(at: diskUrl)
            }
        }

        SyncLogger.logAsync("步驟 1：匯出本機筆記 (\(store.syncNotebooks.count) 本)...", source: .googleDrive)
        // 匯出整段在背景執行緒上跑。
        //
        // 每一本每一頁要讀一次檔、解一次 `PKDrawing`、再寫一次 CRDT 套件，
        // 是整個同步最貴的一段。這段原本跟著 `NotebookSyncCoordinator` 的
        // `@MainActor` 標記留在主執行緒上，於是筆記本一多就被連續佔住十秒
        // 以上 —— iOS 的 scene-update 看門狗直接 SIGKILL（0x8BADF00D）。
        //
        // 先在 MainActor 上把每一本要用到的東西抄成值（便宜，只讀幾個 URL），
        // 之後整個迴圈都不再需要 `store`，就能整包交給背景執行緒。
        // Android 的 `CloudSync.runFull` 從第一天就包在
        // `withContext(Dispatchers.IO)` 裡，這裡是補上同一件事。
        let inputs = store.syncNotebooks.map {
            exportInputs(for: $0, store: store, packagesDir: packagesDir, deviceId: deviceId)
        }
        let exportOutcome = await Task.detached(priority: .utility) { () -> (OwnStrokes, Int, [String: String], Bool) in
            // **這一段不准回到主執行緒。**
            //
            // 不是效能建議，是硬性條件：這裡每本每頁要讀一次檔、解一次
            // PKDrawing、再寫一次 CRDT 套件。在主執行緒上做，筆記本一多就
            // 撞上 iOS 的 scene-update 看門狗 —— 實機上是 SIGKILL
            // 0x8BADF00D，使用者看到的是「按下同步之後整個 App 消失」。
            //
            // 有這一行，任何人把 Task.detached 拿掉的當下就會在開發／測試時
            // 立刻炸掉，而不是等到某台裝置上的筆記本夠多才發現。
            dispatchPrecondition(condition: .notOnQueue(.main))

            var own: OwnStrokes = [:]
            var exported = 0
            var failures = [String: String]()
            for input in inputs {
                if isCancelled || Task.isCancelled {
                    return (own, exported, failures, true)
                }
                do {
                    let mine = try exportOne(input)
                    own.merge(mine) { first, _ in first }
                    exported += 1
                } catch is CancellationError {
                    return (own, exported, failures, true)
                } catch {
                    SyncLogger.logAsync(
                        "匯出失敗 (\(input.document.title))：\(error.localizedDescription)",
                        source: .googleDrive
                    )
                    failures[input.document.title] = error.localizedDescription
                }
            }
            return (own, exported, failures, false)
        }.value
        let ownStrokes = exportOutcome.0
        report.exported = exportOutcome.1
        report.failures.merge(exportOutcome.2) { first, _ in first }
        if exportOutcome.3 {
            SyncLogger.logAsync("【Google Drive 同步】已手動中斷。", source: .googleDrive)
            return report
        }
        SyncLogger.logAsync("步驟 1 完成，成功匯出 \(report.exported) 本", source: .googleDrive)

        if isCancelled || Task.isCancelled {
            SyncLogger.logAsync("【Google Drive 同步】已手動中斷。", source: .googleDrive)
            return report
        }

        // ── 2. 一次 changes.list，然後只碰真的有差異的筆記本 ──────
        //
        // 舊流程是「每一本筆記都打一次 files.list」——20 本筆記 20 次往返，
        // 而其中 19 次的答案是「沒事」。使用者要的「沒變動的就不要花時間
        // 去動它」在那個結構下做不到：要知道有沒有變動就得先問，
        // 而問本身就是主要成本。
        //
        // 現在：一次 refresh() 把雲端變動拉進本機快照，之後
        // notebookNeedsSync() 完全在本機算，一個位元組都不傳。
        SyncLogger.logAsync("步驟 2：更新雲端快照（changes.list）...", source: .googleDrive)
        guard let session = await CloudSync.makeSession() else {
            SyncLogger.logAsync("無法取得 Google Drive 工作階段！", source: .googleDrive)
            return nil
        }

        let refreshed = await CloudSync.refresh(session)
        guard let refreshed, refreshed.ok else {
            let message = refreshed?.error ?? "雲端快照更新逾時"
            SyncLogger.logAsync("雲端快照更新失敗：\(message)", source: .googleDrive)
            report.failures["cloud"] = message
            if refreshed?.needsReauth == true {
                await GoogleAuth.shared.signOut()
            }
            return report
        }
        SyncLogger.logAsync(
            refreshed.fullRebuild
                ? "雲端快照重建完成（\(refreshed.trackedFiles) 個檔案）"
                : "雲端變動 \(refreshed.changed) 筆，快照共 \(refreshed.trackedFiles) 個檔案",
            source: .googleDrive
        )

        // 中繼資料（設定、筆記本清單、刪除墓碑）。
        guard let meta = await CloudSync.syncMetadata(session) else {
            SyncLogger.logAsync("無法取得 Google Drive 索引！", source: .googleDrive)
            await CloudSync.persist(session)
            return nil
        }
        guard meta.ok else {
            if isCancelled || Task.isCancelled {
                SyncLogger.logAsync("【Google Drive 同步】已手動中斷。", source: .googleDrive)
                return report
            }
            SyncLogger.logAsync("元資料同步失敗：\(meta.error)", source: .googleDrive)
            report.failures["cloud"] = meta.error
            if meta.needsReauth {
                await GoogleAuth.shared.signOut()
            }
            await CloudSync.persist(session)
            return report
        }

        if isCancelled || Task.isCancelled {
            await CloudSync.persist(session)
            SyncLogger.logAsync("【Google Drive 同步】已手動中斷。", source: .googleDrive)
            return report
        }

        // ── 同步前即時核實：本機現存 vs. 雲端索引差異樣態 ──────────────
        let activeLocalIds = Set(store.syncNotebooks.map { $0.id.lowercased() })
        var deletedNotebookIds = Set(AccountSyncStore.shared.deletedNotebookIds.map { $0.lowercased() })
        let cloudLiveIds = Set(syncLiveNotebooks(indexJson: meta.indexJson).map { $0.id.lowercased() })

        // 🌟 先拉取雲端上有、本機還沒有的新筆記本！
        // 原本放在所有既有筆記同步之後：如果前面任何一本現有筆記同步耗時（如巨量歷史或錄音）或中途失敗，
        // 新筆記本就永遠輪不到拉取，導致多裝置看到完全不同的筆記本清單。
        let (newBooks, pulledNewIds) = await pullNewNotebooks(
            session,
            into: packagesDir,
            index: meta.indexJson,
            activeLocalIds: activeLocalIds,
            deletedNotebookIds: deletedNotebookIds,
            report: &report
        )
        report.newNotebooks += newBooks

        var changedPackageIds = pulledNewIds

        let allDiskPackages = (try? fm.contentsOfDirectory(at: packagesDir, includingPropertiesForKeys: nil))?
            .filter { $0.pathExtension == "padnote" } ?? []

        var packages: [URL] = []
        var cleanedCount = 0

        for pkg in allDiskPackages {
            let id = packageId(for: pkg).lowercased()
            if activeLocalIds.contains(id) {
                deletedNotebookIds.remove(id)
                packages.append(pkg)
                continue
            }
            if deletedNotebookIds.contains(id) || !cloudLiveIds.contains(id) {
                try? fm.removeItem(at: pkg)
                cleanedCount += 1
            }
        }

        // 只碰真的有差異的那幾本。**這一行是整個改善的重點。**
        let activeId = store.activeNotebookId
        let pending = packages.filter {
            session.notebookNeedsSync(packagePath: $0.path, notebookId: packageId(for: $0))
        }
        SyncLogger.logAsync(
            "📊【同步前核實】本機 \(activeLocalIds.count) 本，清理 \(cleanedCount) 本，"
                + "有差異待同步 \(pending.count) 本（跳過 \(packages.count - pending.count) 本）",
            source: .googleDrive
        )

        // 前台作用中的那一本排最前面：使用者正在看的內容要先到。
        //
        // **原本這裡是壞的。** 寫的是
        // `pending.sorted { a, _ in packageId(for: a) == activeId }` ——
        // 它忽略第二個參數，所以不是合法的嚴格弱序；Swift 的 `sorted(by:)`
        // 對無效比較器的結果是**未定義**的。也就是說「前台優先」可能根本
        // 沒在運作，而症狀只是「有時候比較慢」，沒有人會去查。
        //
        // 規則改用核心那一份（`padnote_sync::order`），兩端同一套，
        // 而且有測試守著「不重複、不遺漏、其餘維持原序」。
        let orderedIds = syncOrderActiveFirst(
            ids: pending.map { packageId(for: $0) }, activeId: activeId
        )
        let byId = Dictionary(
            pending.map { (packageId(for: $0), $0) }, uniquingKeysWith: { first, _ in first }
        )
        let ordered = orderedIds.compactMap { byId[$0] }

        for package in ordered {
            if isCancelled || Task.isCancelled {
                break
            }
            let id = packageId(for: package)
            guard let result = await CloudSync.syncNotebook(
                session, packagePath: package.path, notebookId: id, deviceId: deviceId
            )
            else { continue }
            if result.ok {
                SyncLogger.logAsync(
                    "筆記本 \(id.prefix(8))… 完成（上傳 \(result.uploaded)、下載 \(result.downloaded)）",
                    source: .googleDrive
                )
                report.uploaded += Int(result.uploaded)
                report.downloaded += Int(result.downloaded)
                // 有下載就代表雲端有別台裝置的新內容。
                // 通知正在打開這本筆記的編輯器丟掉舊快取、重新讀取套件，
                // 讓使用者不需要關掉重開就能看到最新筆跡。
                if result.downloaded > 0 {
                    changedPackageIds.insert(id.lowercased())
                    NotificationCenter.default.post(
                        name: AppCommand.notebookPackageChanged,
                        object: id.lowercased()
                    )
                }
                // 不致命但要看得見：例如雲端上一個壞掉的 blob。
                // 悄悄吞掉的話，使用者會發現某張圖永遠出不來而查不出原因。
                for warning in result.warnings {
                    SyncLogger.logAsync("筆記本 \(id.prefix(8))… \(warning)", source: .googleDrive)
                    report.needsAttention.append("\(id.prefix(8))…：\(warning)")
                }
            } else {
                SyncLogger.logAsync("筆記本 \(id.prefix(8))… 同步失敗：\(result.error)", source: .googleDrive)
                report.failures[id] = result.error
                if result.needsReauth {
                    await GoogleAuth.shared.signOut()
                    break
                }
            }
        }

        for pkg in allDiskPackages {
            let id = packageId(for: pkg).lowercased()
            if !activeLocalIds.contains(id) {
                changedPackageIds.insert(id)
            }
        }

        if isCancelled || Task.isCancelled {
            await CloudSync.persist(session)
            // 即使被手動中斷，已經下載的套件也要匯入，不能丟掉！
            await importPackages(
                from: packagesDir,
                into: store,
                deviceId: deviceId,
                ownStrokes: ownStrokes,
                activeLocalIds: activeLocalIds,
                deletedNotebookIds: deletedNotebookIds,
                onlyNotebookIds: changedPackageIds,
                report: &report
            )
            store.syncPurgeDeletedNotebooks(deletedNotebookIds)
            SyncLogger.logAsync("【Google Drive 同步】已手動中斷。", source: .googleDrive)
            return report
        }

        // 快照要落地。不存的話，下次開 App 又要全量重建一次 ——
        // 那是唯一的慢路徑，不該每次啟動都走。
        await CloudSync.persist(session)
        SyncLogger.logAsync("步驟 2 完成。上傳: \(report.uploaded), 下載: \(report.downloaded), 新增: \(report.newNotebooks)", source: .googleDrive)

        if isCancelled || Task.isCancelled {
            SyncLogger.logAsync("【Google Drive 同步】已手動中斷。", source: .googleDrive)
            return report
        }

        // ── 3. 匯入回筆記 ─────────────────────────────────
        SyncLogger.logAsync("步驟 3：匯入套件回本機筆記...", source: .googleDrive)
        await importPackages(
            from: packagesDir,
            into: store,
            deviceId: deviceId,
            ownStrokes: ownStrokes,
            activeLocalIds: activeLocalIds,
            deletedNotebookIds: deletedNotebookIds,
            onlyNotebookIds: changedPackageIds,
            report: &report
        )
        // ── 4. 清理已被遠端刪除的本地殭屍筆記 ─────────────────
        store.syncPurgeDeletedNotebooks(deletedNotebookIds)
        store.syncRefreshRecordings()
        SyncLogger.logAsync("【Google Drive 同步】全部完成。", source: .googleDrive)

        return report
    }

    /// 把雲端有、本機還沒有的筆記本整本抓下來。回傳抓了幾本。
    ///
    /// 清單來自**合併後的索引**，不是本機那一份 —— 用本機的話，剛從雲端
    /// 收斂進來的那幾本還不在裡面，永遠差一輪。
    private static func pullNewNotebooks(
        _ session: FfiSyncSession,
        into packagesDir: URL,
        index: String,
        activeLocalIds: Set<String>,
        deletedNotebookIds: Set<String>,
        report: inout Report
    ) async -> (pulled: Int, pulledIds: Set<String>) {
        let fm = FileManager.default
        var pulled = 0
        var pulledIds = Set<String>()
        for item in syncLiveNotebooks(indexJson: index) {
            let normId = item.id.lowercased()
            guard !deletedNotebookIds.contains(normId) else { continue }
            let package = packagesDir.appending(path: "\(item.id).padnote")
            let lowerPackage = packagesDir.appending(path: "\(normId).padnote")
            let targetPackage = fm.fileExists(atPath: package.path) ? package : lowerPackage

            // 防禦性檢查：若本地存在該目錄，但本機 store 尚未載入該筆記本，
            // 檢查是否為無 ops 檔案的殘留空殼；若為空殼則移除，以便重新 clone
            if fm.fileExists(atPath: targetPackage.path), !activeLocalIds.contains(normId) {
                let opsDir = targetPackage.appending(path: "doc/ops")
                let opFiles = (try? fm.contentsOfDirectory(at: opsDir, includingPropertiesForKeys: nil))?
                    .filter { $0.pathExtension == "oplog" } ?? []
                if opFiles.isEmpty {
                    try? fm.removeItem(at: targetPackage)
                }
            }
            guard !fm.fileExists(atPath: targetPackage.path) else { continue }
            guard let result = await CloudSync.cloneNotebook(
                session, packagePath: targetPackage.path, notebookId: item.id, title: item.title
            )
            else { break }
            if result.ok {
                report.downloaded += Int(result.downloaded)
                pulled += 1
                pulledIds.insert(normId)
            } else {
                // 抓失敗時把空殼刪掉。留著的話，下一輪 `fileExists` 為真，
                // 這本就再也不會被重抓 —— 使用者會看到一本永遠打不開的空筆記。
                try? fm.removeItem(at: targetPackage)
                report.failures[item.title] = result.error
                if result.needsReauth {
                    break
                }
            }
        }
        return (pulled, pulledIds)
    }

    // MARK: - 里程碑（工作項 S-99）

    /// 把一本筆記目前的工作副本寫進它的 `.padnote` 套件，再從套件讀回來。
    ///
    /// # 為什麼里程碑要借用同步的這條路
    ///
    /// Apple 端的**工作副本**是 `Documents/notebooks_v1.json` 與
    /// `Drawings/*.drawing`，套件只是同步與匯出時才產生的衍生物
    /// （見 `docs/PLATFORM-PARITY.md` 第 2 層）。里程碑住在核心、記的是套件
    /// 歷史上的一刀 —— 所以建立之前必須先把工作副本推進套件，
    /// 還原之後必須再把套件讀回工作副本，否則使用者會看到
    /// 「按了還原，畫面沒變」。
    ///
    /// 這裡刻意重用 `exportOne` / `importOne` 而不是另寫一份：那兩個函式
    /// 裡有筆畫基準線的扣除邏輯（少扣一次，同一條線就會被複製成兩份、四份，
    /// 使用者看到的是筆跡愈來愈粗）。那段邏輯只該存在一處。
    @MainActor
    static func mirrorWorkingCopyIntoPackage(
        _ document: NotebookDocument, store: SyncableNotebookStore, deviceId: UInt32
    ) throws -> URL {
        let package = packageURL(for: document.id, in: store)
        // 這裡是單本、使用者剛按下某個動作的當下，量很小，就地跑完即可 ——
        // 會撞看門狗的是同步那條「一次幾十本」的迴圈，不是這裡。
        var inputs = exportInputs(
            for: document, store: store, packagesDir: store.syncPackagesDirectory,
            deviceId: deviceId
        )
        // packageURL 會把 id 轉小寫，exportInputs 不會 —— 以前者為準。
        inputs = ExportInputs(
            document: inputs.document, package: package,
            baselineDirectory: inputs.baselineDirectory,
            attachmentsDirectory: inputs.attachmentsDirectory,
            deviceId: inputs.deviceId, loadDrawing: inputs.loadDrawing
        )
        _ = try exportOne(inputs)
        return package
    }

    /// 把套件目前的內容寫回工作副本。還原之後一定要呼叫它。
    @MainActor
    static func applyPackageToWorkingCopy(
        notebookId: String, store: SyncableNotebookStore, deviceId: UInt32
    ) throws {
        // 還原是整份取代，這台裝置沒有「自己新增的那些」要保留 ——
        // 傳空的基準線，讓匯入把合併後的全部內容都算成別人的。
        let package = packageURL(for: notebookId, in: store)
        let documentId = package.deletingPathExtension().lastPathComponent
        let imported = try NotebookPackageBridge.importDocument(
            fromPackageAt: package, deviceId: deviceId, documentId: documentId
        )
        applyImported(imported, documentId: documentId, into: store, deviceId: deviceId, ownStrokes: [:])
    }

    @MainActor
    private static func packageURL(for notebookId: String, in store: SyncableNotebookStore) -> URL {
        try? FileManager.default.createDirectory(
            at: store.syncPackagesDirectory, withIntermediateDirectories: true
        )
        return store.syncPackagesDirectory
            .appending(path: "\(notebookId.lowercased()).padnote")
    }

    // MARK: - 單本

    /// 匯出一本筆記所需要的全部東西。
    ///
    /// 全是值型別與 `@Sendable` 閉包，所以整包可以帶到背景執行緒上 ——
    /// 這是把匯出搬離 MainActor 的關鍵：迴圈不再需要 `store`。
    struct ExportInputs: @unchecked Sendable {
        let document: NotebookDocument
        let package: URL
        let baselineDirectory: URL
        let attachmentsDirectory: URL
        let deviceId: UInt32
        let loadDrawing: @Sendable (String, Int) -> PKDrawing
    }

    /// 在 MainActor 上把一本筆記要用到的東西抄成值。**很便宜**：只讀
    /// 幾個 URL 與一份已經在記憶體裡的 document，不碰檔案系統。
    @MainActor
    private static func exportInputs(
        for document: NotebookDocument, store: SyncableNotebookStore,
        packagesDir: URL, deviceId: UInt32
    ) -> ExportInputs {
        ExportInputs(
            document: document,
            package: packagesDir.appending(path: "\(document.id).padnote"),
            baselineDirectory: store.syncBaselineDirectory,
            attachmentsDirectory: store.syncAttachmentsDirectory,
            deviceId: deviceId,
            loadDrawing: store.syncDrawingLoader
        )
    }

    /// 匯出一本，回傳這台裝置在各頁自己擁有的筆畫。
    ///
    /// `nonisolated`：這裡每頁要讀一次檔、解一次 `PKDrawing`、再寫一次
    /// CRDT 套件，是整個同步最貴的一段。留在 MainActor 上的話，筆記本一多
    /// 主執行緒就被連續佔住十秒以上 —— iOS 的 scene-update 看門狗會直接
    /// SIGKILL（0x8BADF00D），實機上就是「按下同步之後整個 App 消失」。
    @discardableResult
    private nonisolated static func exportOne(_ inputs: ExportInputs) throws -> OwnStrokes {
        let document = inputs.document
        let pageCount = max(document.pageCount, 1)
        // 只寫這台裝置自己新增的筆畫。
        //
        // 寫整份的話，等於把從別台裝置下載下來的筆畫複製一份掛在自己名下，
        // 下一次合併就會看到兩份、再下一次四份 —— 使用者看到的是筆跡愈來愈粗，
        // 因為同一條線被重複畫了好幾遍。
        //
        // 扣掉的是「別台裝置寫的那些」，不是「上次同步時的全部」——
        // 扣掉全部的話，這台裝置自己的筆畫在下一次匯出時會被扣成空的，
        // 而它的檔案又會被整個重寫，等於自己把自己的內容刪掉。
        var own: OwnStrokes = [:]
        var drawings = [PKDrawing]()
        drawings.reserveCapacity(pageCount)
        for page in 0 ..< pageCount {
            if NotebookSyncCoordinator.isCancelled || Task.isCancelled {
                throw CancellationError()
            }
            let current = inputs.loadDrawing(document.id, page)
            let others = loadBaseline(in: inputs.baselineDirectory, notebookId: document.id, pageIndex: page)
            let mine = PKDrawing(strokes: StrokeDelta.added(in: current, since: others))
            own[baselineKey(document.id, page)] = mine
            drawings.append(mine)
        }
        var images: [String: Data] = [:]
        for attachment in document.attachments ?? [] {
            let url = inputs.attachmentsDirectory.appending(path: attachment.fileName)
            if let bytes = try? Data(contentsOf: url) {
                images[attachment.fileName] = bytes
            }
        }
        try NotebookPackageBridge.exportPreservingOtherDevices(
            document: document, drawings: drawings, imageData: images,
            to: inputs.package, deviceId: inputs.deviceId
        )
        return own
    }

    private static func importOne(
        _ package: URL, into store: SyncableNotebookStore, deviceId: UInt32,
        ownStrokes: OwnStrokes
    ) async throws {
        let documentId = package.deletingPathExtension().lastPathComponent
        // 在背景執行緒解碼 PKDrawing 與套件物件，避免佔住主執行緒超過看門狗限制
        let imported = try await Task.detached(priority: .utility) {
            try NotebookPackageBridge.importDocument(
                fromPackageAt: package, deviceId: deviceId, documentId: documentId
            )
        }.value
        applyImported(imported, documentId: documentId, into: store, deviceId: deviceId, ownStrokes: ownStrokes)
    }

    private static func applyImported(
        _ imported: NotebookPackageBridge.ImportedNotebook,
        documentId: String,
        into store: SyncableNotebookStore,
        deviceId: UInt32,
        ownStrokes: OwnStrokes
    ) {
        // 圖片先落地：筆記本指到一個不存在的檔名時，畫面上會是一格空白。
        let attachmentsDir = store.syncAttachmentsDirectory
        let baselineDir = store.syncBaselineDirectory
        for (fileName, bytes) in imported.imageData {
            let url = attachmentsDir.appending(path: fileName)
            if !FileManager.default.fileExists(atPath: url.path) {
                try? bytes.write(to: url, options: .atomic)
            }
        }
        for (index, drawing) in imported.drawings.enumerated() {
            store.syncSaveDrawing(notebookId: documentId, pageIndex: index, drawing: drawing)
            // 別台裝置的部分 = 合併後的 − 自己的。下次匯出要扣掉它。
            let mine = ownStrokes[baselineKey(documentId, index)] ?? PKDrawing()
            let others = PKDrawing(strokes: StrokeDelta.added(in: drawing, since: mine))
            saveBaseline(others, in: baselineDir, notebookId: documentId, pageIndex: index)
        }
        store.syncUpsert(imported.document)
    }

    // MARK: - 基準線

    private nonisolated static func baselineKey(_ notebookId: String, _ pageIndex: Int) -> String {
        "\(notebookId)_p\(pageIndex)"
    }

    /// 這幾個取的是目錄而不是 `store`：匯出要在背景執行緒上跑，那裡碰不到
    /// `@MainActor` 的 store。目錄是一個 URL，值型別，帶到哪裡都成立。
    private nonisolated static func baselineURL(
        in directory: URL, notebookId: String, pageIndex: Int
    ) -> URL {
        directory.appending(path: "\(baselineKey(notebookId, pageIndex)).drawing")
    }

    private nonisolated static func loadBaseline(
        in directory: URL, notebookId: String, pageIndex: Int
    ) -> PKDrawing {
        let url = baselineURL(in: directory, notebookId: notebookId, pageIndex: pageIndex)
        guard let data = try? Data(contentsOf: url), let drawing = try? PKDrawing(data: data)
        else { return PKDrawing() }
        return drawing
    }

    private nonisolated static func saveBaseline(
        _ drawing: PKDrawing, in directory: URL, notebookId: String, pageIndex: Int
    ) {
        try? drawing.dataRepresentation().write(
            to: baselineURL(in: directory, notebookId: notebookId, pageIndex: pageIndex),
            options: .atomic
        )
    }

    /// 匯入套件目錄下的所有筆記本，具備破損目錄防禦與 iCloud 佔位檔處理。
    private static func importPackages(
        from packagesDir: URL,
        into store: SyncableNotebookStore,
        deviceId: UInt32,
        ownStrokes: OwnStrokes,
        activeLocalIds: Set<String>,
        deletedNotebookIds: Set<String>,
        onlyNotebookIds: Set<String>? = nil,
        report: inout Report
    ) async {
        let fm = FileManager.default
        let allPackages = (try? fm.contentsOfDirectory(at: packagesDir, includingPropertiesForKeys: nil))?
            .filter { $0.pathExtension == "padnote" } ?? []
        for package in allPackages {
            let notebookId = packageId(for: package)
            let normId = notebookId.lowercased()
            if deletedNotebookIds.contains(normId) {
                try? fm.removeItem(at: package)
                SyncLogger.logAsync("已清理已刪除筆記本殘留套件：\(notebookId)", source: .general)
                continue
            }

            // 如果指定了只匯入特定變更的筆記本，且此筆記本不在名單中，且本地已載入過，則跳過重算
            if let only = onlyNotebookIds, !only.contains(normId), activeLocalIds.contains(normId) {
                continue
            }

            var isDir: ObjCBool = false
            if fm.fileExists(atPath: package.path, isDirectory: &isDir), !isDir.boolValue {
                // 如果是 .padnote 單檔封裝（ZIP），先解壓縮成套件目錄
                let tempDir = fm.temporaryDirectory.appending(path: "import-\(UUID().uuidString)")
                do {
                    try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
                    try extractNotebook(archiveFile: package.path, outDir: tempDir.path)
                    try? fm.removeItem(at: package)
                    try fm.moveItem(at: tempDir, to: package)
                } catch {
                    try? fm.removeItem(at: tempDir)
                    report.failures[package.lastPathComponent] = "解開套件失敗：\(error.localizedDescription)"
                    continue
                }
            }

            // 檢查目錄內是否有 manifest.json
            let manifest = package.appending(path: "manifest.json")
            if !fm.fileExists(atPath: manifest.path) {
                let manifestPlaceholder = package.appending(path: ".manifest.json.icloud")
                if fm.fileExists(atPath: manifestPlaceholder.path) {
                    try? fm.startDownloadingUbiquitousItem(at: manifest)
                    report.failures[package.lastPathComponent] = "iCloud 雲端檔案下載中，請稍候重試"
                    continue
                }
                // 損毀的空目錄或非套件檔案，清理避免日後每次同步都重複報「不是 .padnote 套件」
                try? fm.removeItem(at: package)
                report.failures[package.lastPathComponent] = "套件缺少 manifest.json，已清理無效殘留目錄"
                continue
            }

            do {
                try await importOne(package, into: store, deviceId: deviceId, ownStrokes: ownStrokes)
                report.imported += 1
            } catch {
                report.failures[package.lastPathComponent] = error.localizedDescription
                // 匯入失敗（無論是沒有頁面、非套件、或是壞檔）：
                // 若這本筆記本尚未成功載入本機 store，必須把磁碟上的破損/空套件刪除。
                // 否則下次 pullNewNotebooks 會因為 fileExists(atPath:) 為真而跳過，
                // 導致筆記本永遠卡在無法匯入的死鎖狀態。
                if !activeLocalIds.contains(normId) {
                    try? fm.removeItem(at: package)
                }
            }
            // 每匯入完一本主動讓出時間片段給 RunLoop，防止連續解碼觸發 iOS 10秒看門狗 (0x8BADF00D)
            await Task.yield()
        }
    }

    /// 資料夾同步專用的匯入函式。
    ///
    /// 與 `importPackages` 的唯一差異：**完全不依賴 `deletedNotebookIds`**。
    /// 在雲端資料夾存在的套件就代表筆記本存在——不能因為某台裝置的 CRDT tombstone
    /// 就把它刪掉（tombstone 可能是歷史汙染資料）。
    private static func importPackagesForFolderSync(
        from packagesDir: URL,
        into store: SyncableNotebookStore,
        deviceId: UInt32,
        ownStrokes: OwnStrokes,
        activeLocalIds: Set<String>,
        deletedNotebookIds: Set<String>,
        report: inout Report
    ) async {
        let fm = FileManager.default
        let allPackages = (try? fm.contentsOfDirectory(at: packagesDir, includingPropertiesForKeys: nil))?
            .filter { $0.pathExtension == "padnote" } ?? []
        for package in allPackages {
            let notebookId = packageId(for: package)
            let normId = notebookId.lowercased()

            if deletedNotebookIds.contains(normId) {
                try? fm.removeItem(at: package)
                continue
            }

            var isDir: ObjCBool = false
            if fm.fileExists(atPath: package.path, isDirectory: &isDir), !isDir.boolValue {
                // 如果是 .padnote 單檔封裝（ZIP），先解壓縮成套件目錄
                let tempDir = fm.temporaryDirectory.appending(path: "import-\(UUID().uuidString)")
                do {
                    try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
                    try extractNotebook(archiveFile: package.path, outDir: tempDir.path)
                    try? fm.removeItem(at: package)
                    try fm.moveItem(at: tempDir, to: package)
                } catch {
                    try? fm.removeItem(at: tempDir)
                    report.failures[package.lastPathComponent] = "解開套件失敗：\(error.localizedDescription)"
                    continue
                }
            }

            // 檢查目錄內是否有 manifest.json
            let manifest = package.appending(path: "manifest.json")
            if !fm.fileExists(atPath: manifest.path) {
                let manifestPlaceholder = package.appending(path: ".manifest.json.icloud")
                if fm.fileExists(atPath: manifestPlaceholder.path) {
                    try? fm.startDownloadingUbiquitousItem(at: manifest)
                    report.failures[package.lastPathComponent] = "iCloud 雲端檔案下載中，請稍候重試"
                    continue
                }
                // 損毀的空目錄或非套件檔案，清理避免日後每次同步都重複報錯
                try? fm.removeItem(at: package)
                report.failures[package.lastPathComponent] = "套件缺少 manifest.json，已清理無效殘留目錄"
                continue
            }

            do {
                try await importOne(package, into: store, deviceId: deviceId, ownStrokes: ownStrokes)
                report.imported += 1
            } catch {
                report.failures[package.lastPathComponent] = error.localizedDescription
                if !activeLocalIds.contains(normId) {
                    try? fm.removeItem(at: package)
                }
            }
            await Task.yield()
        }
    }

    /// 把雲端資料夾裡本機還沒有的套件整包抓下來。
    ///
    /// `CloudSyncFolder.sync` 只處理「本機已經有這個套件目錄」的情況 ——
    /// 另一台裝置**新建**的筆記本在本機連目錄都沒有，不另外抓的話永遠不會出現。
    private nonisolated static func pullUnknownPackages(
        into packagesDir: URL,
        from folder: URL,
        activeLocalIds: Set<String>,
        deletedNotebookIds: Set<String>,
        report: inout Report
    ) -> Int {
        let fm = FileManager.default
        let remoteItems = (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: []))?
            .filter { $0.pathExtension == "padnote" || $0.lastPathComponent.hasSuffix(".padnote.icloud") } ?? []

        var pulled = 0
        for remoteItem in remoteItems {
            let actualName: String
            if ICloudSyncFolder.isPlaceholder(remoteItem) {
                let logical = ICloudSyncFolder.logicalURL(of: remoteItem)
                try? fm.startDownloadingUbiquitousItem(at: logical)
                actualName = logical.lastPathComponent
            } else {
                actualName = remoteItem.lastPathComponent
            }
            guard actualName.hasSuffix(".padnote") else { continue }

            let local = packagesDir.appending(path: actualName)
            let notebookId = packageId(for: local)

            // 若本機已有此筆記本（活躍），跳過——CloudSyncFolder.sync 已處理雙向同步。
            if activeLocalIds.contains(notebookId) {
                continue
            }
            // 若為已刪除的筆記本（帶墓碑），跳過並從雲端清除殘留，絕不重新拉取
            if deletedNotebookIds.contains(notebookId) {
                try? fm.removeItem(at: remoteItem)
                continue
            }
            guard !fm.fileExists(atPath: local.path) else { continue }

            var isDir: ObjCBool = false
            if fm.fileExists(atPath: remoteItem.path, isDirectory: &isDir), !isDir.boolValue {
                // 是單一 .padnote 壓縮檔，直接解壓至本機套件目錄
                let tempDir = fm.temporaryDirectory.appending(path: "pull-\(UUID().uuidString)")
                do {
                    try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
                    try extractNotebook(archiveFile: remoteItem.path, outDir: tempDir.path)
                    try fm.moveItem(at: tempDir, to: local)
                    pulled += 1
                    report.downloaded += 1
                } catch {
                    try? fm.removeItem(at: tempDir)
                    report.failures[actualName] = "解開雲端 .padnote 失敗：\(error.localizedDescription)"
                }
                continue
            }

            let result = CloudSyncFolder.sync(localPackage: local, into: folder)
            report.downloaded += result.downloaded.count
            report.failures.merge(result.failures) { first, _ in first }
            if !result.downloaded.isEmpty {
                pulled += 1
            }
        }
        return pulled
    }

    private nonisolated static func packageId(for package: URL) -> String {
        package.deletingPathExtension().lastPathComponent
    }
}

import Foundation

/// 同步來源識別（頂層型別，nonisolated 上下文可安全引用）
public enum SyncSource: String, Sendable, CaseIterable {
    case general = "系統"
    case googleDrive = "Google Drive"
    case folder = "iCloud / 資料夾"
}

@MainActor
public final class SyncLogger: ObservableObject {
    public static let shared = SyncLogger()

    public struct LogEntry: Identifiable, Sendable {
        public let id = UUID()
        public let timestamp = Date()
        public let source: SyncSource
        public let message: String
    }

    @Published public private(set) var entries: [LogEntry] = []

    public func log(_ message: String, source: SyncSource = .general) {
        let entry = LogEntry(source: source, message: message)
        entries.append(entry)
        if entries.count > 300 {
            entries.removeFirst(entries.count - 300)
        }
    }

    public func clear(for source: SyncSource? = nil) {
        if let source {
            entries.removeAll { $0.source == source }
        } else {
            entries.removeAll()
        }
    }
}

public extension SyncLogger {
    nonisolated static func logAsync(_ message: String, source: SyncSource = .general) {
        Task { @MainActor in
            SyncLogger.shared.log(message, source: source)
        }
    }
}
