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
    /// 目前正在編輯／檢視的作用中筆記本 ID（nil 表示在首頁或未指定）
    var activeNotebookId: String? { get }

    func syncLoadDrawing(notebookId: String, pageIndex: Int) -> PKDrawing
    func syncSaveDrawing(notebookId: String, pageIndex: Int, drawing: PKDrawing)
    func syncUpsert(_ document: NotebookDocument)
    func syncPurgeDeletedNotebooks(_ deletedIds: Set<String>)
}

extension SyncableNotebookStore {
    var activeNotebookId: String? { nil }
    func syncPurgeDeletedNotebooks(_ deletedIds: Set<String>) {}
}

extension NotebookStore: SyncableNotebookStore {
    var syncNotebooks: [NotebookDocument] { visibleNotebooks }
    var allNotebooks: [NotebookDocument] { notebooks }
    var syncPackagesDirectory: URL { corePackagesDirectory }
    var syncAttachmentsDirectory: URL { attachmentsDirectory }
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

        var isNoOp: Bool { uploaded == 0 && downloaded == 0 }
    }

    /// 這一輪各頁算出來的「自己的筆畫」。
    ///
    /// 匯出時算出來，匯入後要用它反推「別台裝置的部分」——
    /// `別人的 = 合併後的 − 自己的`。
    private typealias OwnStrokes = [String: PKDrawing]

    public nonisolated static var isCancelled: Bool {
        DriveHttpClient.isCancellationRequested
    }

    public nonisolated static func cancelSync() {
        DriveHttpClient.cancelAll()
        SyncLogger.logAsync("【同步中斷】已送出中斷要求，正在終止進行中的任務...", source: .general)
    }

    public nonisolated static func resetCancellation() {
        DriveHttpClient.resetCancellation()
    }

    /// 跑完一輪同步。
    ///
    /// - Parameters:
    ///   - store: 筆記本的本機儲存。
    ///   - folder: 使用者選的雲端資料夾。呼叫端負責取得 security scope。
    static func run(store: SyncableNotebookStore, folder: URL, deviceId: UInt32) async -> Report {
        resetCancellation()
        defer { resetCancellation() }
        SyncLogger.logAsync("【資料夾同步】開始執行，目標：\(folder.lastPathComponent)", source: .folder)
        var report = Report()
        let fm = FileManager.default
        let packagesDir = store.syncPackagesDirectory
        try? fm.createDirectory(at: packagesDir, withIntermediateDirectories: true)

        // ── 1. 匯出本機的筆記 ──────────────────────────────
        SyncLogger.logAsync("步驟 1：匯出本機筆記 (\(store.syncNotebooks.count) 本)...", source: .folder)
        var ownStrokes: OwnStrokes = [:]
        for document in store.syncNotebooks {
            if isCancelled || Task.isCancelled {
                SyncLogger.logAsync("【資料夾同步】已手動中斷。", source: .folder)
                return report
            }
            let package = packagesDir.appendingPathComponent("\(document.id).padnote")
            do {
                let own = try exportOne(document, from: store, to: package, deviceId: deviceId)
                ownStrokes.merge(own) { first, _ in first }
                report.exported += 1
            } catch {
                SyncLogger.logAsync("匯出失敗 (\(document.title))：\(error.localizedDescription)", source: .folder)
                report.failures[document.title] = error.localizedDescription
            }
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
                    if Task.isCancelled || DriveHttpClient.isCancellationRequested { break }
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
        importPackagesForFolderSync(
            from: packagesDir,
            into: store,
            deviceId: deviceId,
            ownStrokes: ownStrokes,
            activeLocalIds: activeLocalIds,
            deletedNotebookIds: deletedNotebookIds,
            report: &report
        )
        store.syncPurgeDeletedNotebooks(deletedNotebookIds)
        SyncLogger.logAsync("【資料夾同步】全部完成。", source: .folder)

        return report
    }


    /// 跑完一輪**Google Drive** 的同步。
    static func runDrive(store: SyncableNotebookStore, deviceId: UInt32) async -> Report? {
        guard await GoogleAuth.shared.isSignedIn else { return nil }
        resetCancellation()
        defer { resetCancellation() }
        SyncLogger.logAsync("【Google Drive 同步】開始執行", source: .googleDrive)
        var report = Report()
        let fm = FileManager.default
        let packagesDir = store.syncPackagesDirectory
        try? fm.createDirectory(at: packagesDir, withIntermediateDirectories: true)

        let localIndexJson = AccountSyncStore.shared.indexJSON
        let localLiveSet = Set(syncLiveNotebooks(indexJson: localIndexJson).map { $0.id })

        // (A) 從 store.allNotebooks 全集確認未刪除的筆記本存在於 localIndexJson
        for document in store.allNotebooks {
            if !AccountSyncStore.shared.isDeleted(id: document.id) && !localLiveSet.contains(document.id) {
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
        var ownStrokes: OwnStrokes = [:]
        for document in store.syncNotebooks {
            if isCancelled || Task.isCancelled {
                SyncLogger.logAsync("【Google Drive 同步】已手動中斷。", source: .googleDrive)
                return report
            }
            let package = packagesDir.appendingPathComponent("\(document.id).padnote")
            do {
                let own = try exportOne(document, from: store, to: package, deviceId: deviceId)
                ownStrokes.merge(own) { first, _ in first }
                report.exported += 1
            } catch {
                SyncLogger.logAsync("匯出失敗 (\(document.title))：\(error.localizedDescription)", source: .googleDrive)
                report.failures[document.title] = error.localizedDescription
            }
        }
        SyncLogger.logAsync("步驟 1 完成，成功匯出 \(report.exported) 本", source: .googleDrive)

        if isCancelled || Task.isCancelled {
            SyncLogger.logAsync("【Google Drive 同步】已手動中斷。", source: .googleDrive)
            return report
        }

        // ── 2. 中繼資料，再逐本搬內容 ───────────────────────
        SyncLogger.logAsync("步驟 2：同步元資料與檔案 (連線中)...", source: .googleDrive)
        guard let meta = await CloudSync.runOnce() else {
            SyncLogger.logAsync("無法取得 Google Drive 索引！", source: .googleDrive)
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
            return report
        }

        if isCancelled || Task.isCancelled {
            SyncLogger.logAsync("【Google Drive 同步】已手動中斷。", source: .googleDrive)
            return report
        }

        // ── 同步前即時核實：本機現存 vs. 雲端索引差異樣態 ──────────────
        let activeLocalIds = Set(store.syncNotebooks.map { $0.id.lowercased() })
        var deletedNotebookIds = Set(AccountSyncStore.shared.deletedNotebookIds.map { $0.lowercased() })
        let cloudLiveIds = Set(syncLiveNotebooks(indexJson: meta.indexJson).map { $0.id.lowercased() })
        
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
            if deletedNotebookIds.contains(id) {
                try? fm.removeItem(at: pkg)
                cleanedCount += 1
                continue
            }
            if !cloudLiveIds.contains(id) {
                try? fm.removeItem(at: pkg)
                cleanedCount += 1
                continue
            }
        }

        SyncLogger.logAsync("📊【同步前核實】本機現存: \(activeLocalIds.count) 本，清理/排除無效套件: \(cleanedCount) 本，待同步活躍筆記: \(packages.count) 本", source: .googleDrive)
        SyncLogger.logAsync("雲端元資料同步完成，開始逐本比對套件檔案...", source: .googleDrive)

        // ── 雙軌排程：前台極速軌 + 背景並行佇列 ──────────────
        let activeId = store.activeNotebookId

        let foreground = packages.filter { $0.deletingPathExtension().lastPathComponent == activeId }
        let background = packages.filter { $0.deletingPathExtension().lastPathComponent != activeId }

        // 前台極速軌：優先、立即執行
        for package in foreground {
            if isCancelled || Task.isCancelled { break }
            let id = package.deletingPathExtension().lastPathComponent
            SyncLogger.logAsync("⚡ 前台極速同步：\(id.prefix(8))...", source: .googleDrive)
            guard let result = await CloudSync.syncNotebook(
                packagePath: package.path, notebookId: id) else { continue }
            if result.ok {
                SyncLogger.logAsync("筆記本 \(id.prefix(8))... 同步完成（上傳: \(result.uploaded), 下載: \(result.downloaded)）", source: .googleDrive)
                report.uploaded += Int(result.uploaded)
                report.downloaded += Int(result.downloaded)
            } else {
                let err = result.error
                SyncLogger.logAsync("筆記本 \(id.prefix(8))... 同步失敗：\(err)", source: .googleDrive)
                report.failures[id] = err
                if result.needsReauth {
                    await GoogleAuth.shared.signOut()
                    break
                }
            }
        }

        // 背景並行佇列：2 路並發，兼顧速度與連線穩定度（防 Google 限流）
        let concurrencyLimit = 2
        var backgroundQueue = background
        while !backgroundQueue.isEmpty {
            if isCancelled || Task.isCancelled { break }
            let batch = Array(backgroundQueue.prefix(concurrencyLimit))
            backgroundQueue.removeFirst(min(concurrencyLimit, backgroundQueue.count))

            for package in batch {
                let id = package.deletingPathExtension().lastPathComponent
                SyncLogger.logAsync("開始同步筆記本 \(id.prefix(8))...", source: .googleDrive)
            }

            let batchResults: [(uploaded: Int, downloaded: Int, id: String, error: String?, needsReauth: Bool)] =
                await withTaskGroup(
                    of: (uploaded: Int, downloaded: Int, id: String, error: String?, needsReauth: Bool).self
                ) { group in
                    for package in batch {
                        let id = package.deletingPathExtension().lastPathComponent
                        let path = package.path
                        group.addTask {
                            if Task.isCancelled || NotebookSyncCoordinator.isCancelled {
                                return (0, 0, id, "已中斷同步", false)
                            }
                            guard let result = await CloudSync.syncNotebook(
                                packagePath: path, notebookId: id) else {
                                return (0, 0, id, nil, false)
                            }
                            if result.ok {
                                return (Int(result.uploaded), Int(result.downloaded), id, nil, false)
                            } else {
                                return (0, 0, id, result.error, result.needsReauth)
                            }
                        }
                    }
                    var collected: [(Int, Int, String, String?, Bool)] = []
                    for await r in group { collected.append(r) }
                    return collected
                }

            var shouldBreak = false
            for r in batchResults {
                if let err = r.error {
                    SyncLogger.logAsync("筆記本 \(r.id.prefix(8))... 背景同步失敗：\(err)", source: .googleDrive)
                    report.failures[r.id] = err
                    if r.needsReauth {
                        await GoogleAuth.shared.signOut()
                        shouldBreak = true
                    }
                } else {
                    SyncLogger.logAsync("筆記本 \(r.id.prefix(8))... 背景同步完成（上傳: \(r.uploaded), 下載: \(r.downloaded)）", source: .googleDrive)
                    report.uploaded += r.uploaded
                    report.downloaded += r.downloaded
                }
            }
            if shouldBreak { break }
        }

        if isCancelled || Task.isCancelled {
            SyncLogger.logAsync("【Google Drive 同步】已手動中斷。", source: .googleDrive)
            return report
        }

        // 別台裝置新建的筆記本
        let newBooks = await pullNewNotebooks(
            into: packagesDir,
            index: meta.indexJson,
            activeLocalIds: activeLocalIds,
            deletedNotebookIds: deletedNotebookIds,
            report: &report
        )
        report.newNotebooks += newBooks
        SyncLogger.logAsync("步驟 2 完成。上傳: \(report.uploaded), 下載: \(report.downloaded), 新增: \(report.newNotebooks)", source: .googleDrive)

        if isCancelled || Task.isCancelled {
            SyncLogger.logAsync("【Google Drive 同步】已手動中斷。", source: .googleDrive)
            return report
        }

        // ── 3. 匯入回筆記 ─────────────────────────────────
        SyncLogger.logAsync("步驟 3：匯入套件回本機筆記...", source: .googleDrive)
        importPackages(
            from: packagesDir,
            into: store,
            deviceId: deviceId,
            ownStrokes: ownStrokes,
            activeLocalIds: activeLocalIds,
            deletedNotebookIds: deletedNotebookIds,
            report: &report
        )
        // ── 4. 清理已被遠端刪除的本地殭屍筆記 ─────────────────
        store.syncPurgeDeletedNotebooks(deletedNotebookIds)
        SyncLogger.logAsync("【Google Drive 同步】全部完成。", source: .googleDrive)

        return report
    }

    /// 把雲端有、本機還沒有的筆記本整本抓下來。回傳抓了幾本。
    ///
    /// 清單來自**合併後的索引**，不是本機那一份 —— 用本機的話，剛從雲端
    /// 收斂進來的那幾本還不在裡面，永遠差一輪。
    private static func pullNewNotebooks(
        into packagesDir: URL,
        index: String,
        activeLocalIds: Set<String>,
        deletedNotebookIds: Set<String>,
        report: inout Report
    ) async -> Int {
        let fm = FileManager.default
        var pulled = 0
        for item in syncLiveNotebooks(indexJson: index) {
            let normId = item.id.lowercased()
            guard !deletedNotebookIds.contains(normId) else { continue }
            let package = packagesDir.appendingPathComponent("\(item.id).padnote")
            let lowerPackage = packagesDir.appendingPathComponent("\(normId).padnote")
            let targetPackage = fm.fileExists(atPath: package.path) ? package : lowerPackage

            // 防禦性檢查：若本地存在該目錄，但本機 store 尚未載入該筆記本，
            // 檢查是否為無 ops 檔案的殘留空殼；若為空殼則移除，以便重新 clone
            if fm.fileExists(atPath: targetPackage.path) && !activeLocalIds.contains(normId) {
                let opsDir = targetPackage.appendingPathComponent("doc/ops")
                let opFiles = (try? fm.contentsOfDirectory(at: opsDir, includingPropertiesForKeys: nil))?
                    .filter { $0.pathExtension == "oplog" } ?? []
                if opFiles.isEmpty {
                    try? fm.removeItem(at: targetPackage)
                }
            }
            guard !fm.fileExists(atPath: targetPackage.path) else { continue }
            guard let result = await CloudSync.cloneNotebook(
                packagePath: targetPackage.path, notebookId: item.id, title: item.title)
            else { break }
            if result.ok {
                report.downloaded += Int(result.downloaded)
                pulled += 1
            } else {
                // 抓失敗時把空殼刪掉。留著的話，下一輪 `fileExists` 為真，
                // 這本就再也不會被重抓 —— 使用者會看到一本永遠打不開的空筆記。
                try? fm.removeItem(at: targetPackage)
                report.failures[item.title] = result.error
                if result.needsReauth { break }
            }
        }
        return pulled
    }

    // MARK: - 單本

    /// 匯出一本，回傳這台裝置在各頁自己擁有的筆畫。
    @discardableResult
    private static func exportOne(
        _ document: NotebookDocument, from store: SyncableNotebookStore,
        to package: URL, deviceId: UInt32
    ) throws -> OwnStrokes {
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
        let drawings = (0..<pageCount).map { page -> PKDrawing in
            let current = store.syncLoadDrawing(notebookId: document.id, pageIndex: page)
            let others = loadBaseline(store: store, notebookId: document.id, pageIndex: page)
            let mine = PKDrawing(strokes: StrokeDelta.added(in: current, since: others))
            own[baselineKey(document.id, page)] = mine
            return mine
        }
        var images: [String: Data] = [:]
        for attachment in document.attachments ?? [] {
            let url = store.syncAttachmentsDirectory.appendingPathComponent(attachment.fileName)
            if let bytes = try? Data(contentsOf: url) { images[attachment.fileName] = bytes }
        }
        try NotebookPackageBridge.exportPreservingOtherDevices(
            document: document, drawings: drawings, imageData: images,
            to: package, deviceId: deviceId)
        return own
    }

    private static func importOne(
        _ package: URL, into store: SyncableNotebookStore, deviceId: UInt32,
        ownStrokes: OwnStrokes
    ) throws {
        let documentId = package.deletingPathExtension().lastPathComponent
        let imported = try NotebookPackageBridge.importDocument(
            fromPackageAt: package, deviceId: deviceId, documentId: documentId)

        // 圖片先落地：筆記本指到一個不存在的檔名時，畫面上會是一格空白。
        for (fileName, bytes) in imported.imageData {
            let url = store.syncAttachmentsDirectory.appendingPathComponent(fileName)
            if !FileManager.default.fileExists(atPath: url.path) {
                try? bytes.write(to: url, options: .atomic)
            }
        }
        for (index, drawing) in imported.drawings.enumerated() {
            store.syncSaveDrawing(notebookId: documentId, pageIndex: index, drawing: drawing)
            // 別台裝置的部分 = 合併後的 − 自己的。下次匯出要扣掉它。
            let mine = ownStrokes[baselineKey(documentId, index)] ?? PKDrawing()
            let others = PKDrawing(strokes: StrokeDelta.added(in: drawing, since: mine))
            saveBaseline(others, store: store, notebookId: documentId, pageIndex: index)
        }
        store.syncUpsert(imported.document)
    }

    // MARK: - 基準線

    private static func baselineKey(_ notebookId: String, _ pageIndex: Int) -> String {
        "\(notebookId)_p\(pageIndex)"
    }

    private static func baselineURL(
        store: SyncableNotebookStore, notebookId: String, pageIndex: Int
    ) -> URL {
        store.syncBaselineDirectory
            .appendingPathComponent("\(baselineKey(notebookId, pageIndex)).drawing")
    }

    private static func loadBaseline(
        store: SyncableNotebookStore, notebookId: String, pageIndex: Int
    ) -> PKDrawing {
        let url = baselineURL(store: store, notebookId: notebookId, pageIndex: pageIndex)
        guard let data = try? Data(contentsOf: url), let drawing = try? PKDrawing(data: data)
        else { return PKDrawing() }
        return drawing
    }

    private static func saveBaseline(
        _ drawing: PKDrawing, store: SyncableNotebookStore, notebookId: String, pageIndex: Int
    ) {
        try? drawing.dataRepresentation().write(
            to: baselineURL(store: store, notebookId: notebookId, pageIndex: pageIndex),
            options: .atomic)
    }

    /// 匯入套件目錄下的所有筆記本，具備破損目錄防禦與 iCloud 佔位檔處理。
    private static func importPackages(
        from packagesDir: URL,
        into store: SyncableNotebookStore,
        deviceId: UInt32,
        ownStrokes: OwnStrokes,
        activeLocalIds: Set<String>,
        deletedNotebookIds: Set<String>,
        report: inout Report
    ) {
        let fm = FileManager.default
        let allPackages = (try? fm.contentsOfDirectory(at: packagesDir, includingPropertiesForKeys: nil))?
            .filter { $0.pathExtension == "padnote" } ?? []
        for package in allPackages {
            let notebookId = packageId(for: package)
            if deletedNotebookIds.contains(notebookId) {
                try? fm.removeItem(at: package)
                SyncLogger.logAsync("已清理已刪除筆記本殘留套件：\(notebookId)", source: .general)
                continue
            }

            var isDir: ObjCBool = false
            if fm.fileExists(atPath: package.path, isDirectory: &isDir), !isDir.boolValue {
                // 如果是 .padnote 單檔封裝（ZIP），先解壓縮成套件目錄
                let tempDir = fm.temporaryDirectory.appendingPathComponent("import-\(UUID().uuidString)")
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
            let manifest = package.appendingPathComponent("manifest.json")
            if !fm.fileExists(atPath: manifest.path) {
                let manifestPlaceholder = package.appendingPathComponent(".manifest.json.icloud")
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
                try importOne(package, into: store, deviceId: deviceId, ownStrokes: ownStrokes)
                report.imported += 1
            } catch {
                report.failures[package.lastPathComponent] = error.localizedDescription
                // 匯入失敗（無論是沒有頁面、非套件、或是壞檔）：
                // 若這本筆記本尚未成功載入本機 store，必須把磁碟上的破損/空套件刪除。
                // 否則下次 pullNewNotebooks 會因為 fileExists(atPath:) 為真而跳過，
                // 導致筆記本永遠卡在無法匯入的死鎖狀態。
                if !activeLocalIds.contains(notebookId) {
                    try? fm.removeItem(at: package)
                }
            }
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
    ) {
        let fm = FileManager.default
        let allPackages = (try? fm.contentsOfDirectory(at: packagesDir, includingPropertiesForKeys: nil))?
            .filter { $0.pathExtension == "padnote" } ?? []
        for package in allPackages {
            let notebookId = packageId(for: package)

            if deletedNotebookIds.contains(notebookId) {
                try? fm.removeItem(at: package)
                continue
            }

            var isDir: ObjCBool = false
            if fm.fileExists(atPath: package.path, isDirectory: &isDir), !isDir.boolValue {
                // 如果是 .padnote 單檔封裝（ZIP），先解壓縮成套件目錄
                let tempDir = fm.temporaryDirectory.appendingPathComponent("import-\(UUID().uuidString)")
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
            let manifest = package.appendingPathComponent("manifest.json")
            if !fm.fileExists(atPath: manifest.path) {
                let manifestPlaceholder = package.appendingPathComponent(".manifest.json.icloud")
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
                try importOne(package, into: store, deviceId: deviceId, ownStrokes: ownStrokes)
                report.imported += 1
            } catch {
                report.failures[package.lastPathComponent] = error.localizedDescription
                if !activeLocalIds.contains(notebookId) {
                    try? fm.removeItem(at: package)
                }
            }
        }
    }

    /// 把雲端資料夾裡本機還沒有的套件整包抓下來。
    ///
    /// `CloudSyncFolder.sync` 只處理「本機已經有這個套件目錄」的情況 ——
    /// 另一台裝置**新建**的筆記本在本機連目錄都沒有，不另外抓的話永遠不會出現。
    nonisolated private static func pullUnknownPackages(
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

            let local = packagesDir.appendingPathComponent(actualName)
            let notebookId = packageId(for: local)

            // 若本機已有此筆記本（活躍），跳過——CloudSyncFolder.sync 已處理雙向同步。
            if activeLocalIds.contains(notebookId) { continue }
            // 若為已刪除的筆記本（帶墓碑），跳過並從雲端清除殘留，絕不重新拉取
            if deletedNotebookIds.contains(notebookId) {
                try? fm.removeItem(at: remoteItem)
                continue
            }
            guard !fm.fileExists(atPath: local.path) else { continue }

            var isDir: ObjCBool = false
            if fm.fileExists(atPath: remoteItem.path, isDirectory: &isDir), !isDir.boolValue {
                // 是單一 .padnote 壓縮檔，直接解壓至本機套件目錄
                let tempDir = fm.temporaryDirectory.appendingPathComponent("pull-\(UUID().uuidString)")
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
            if !result.downloaded.isEmpty { pulled += 1 }
        }
        return pulled
    }


    nonisolated private static func packageId(for package: URL) -> String {
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

extension SyncLogger {
    public nonisolated static func logAsync(_ message: String, source: SyncSource = .general) {
        Task { @MainActor in
            SyncLogger.shared.log(message, source: source)
        }
    }
}
