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
    var syncPackagesDirectory: URL { get }
    var syncAttachmentsDirectory: URL { get }
    /// **別台裝置**寫的那些筆畫。匯出時要扣掉它們，才不會複製一份掛在自己名下。
    var syncBaselineDirectory: URL { get }

    func syncLoadDrawing(notebookId: String, pageIndex: Int) -> PKDrawing
    func syncSaveDrawing(notebookId: String, pageIndex: Int, drawing: PKDrawing)
    func syncUpsert(_ document: NotebookDocument)
}

extension NotebookStore: SyncableNotebookStore {
    var syncNotebooks: [NotebookDocument] { notebooks }
    var syncPackagesDirectory: URL { corePackagesDirectory }
    var syncAttachmentsDirectory: URL { attachmentsDirectory }

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

    /// 跑完一輪同步。
    ///
    /// - Parameters:
    ///   - store: 筆記本的本機儲存。
    ///   - folder: 使用者選的雲端資料夾。呼叫端負責取得 security scope。
    static func run(store: SyncableNotebookStore, folder: URL, deviceId: UInt32) async -> Report {
        SyncLogger.logAsync("【資料夾同步】開始執行，目標：\(folder.lastPathComponent)")
        var report = Report()
        let fm = FileManager.default
        let packagesDir = store.syncPackagesDirectory
        try? fm.createDirectory(at: packagesDir, withIntermediateDirectories: true)

        // ── 1. 匯出本機的筆記 ──────────────────────────────
        SyncLogger.logAsync("步驟 1：匯出本機筆記 (\(store.syncNotebooks.count) 本)...")
        var ownStrokes: OwnStrokes = [:]
        for document in store.syncNotebooks {
            let package = packagesDir.appendingPathComponent("\(document.id).padnote")
            do {
                let own = try exportOne(document, from: store, to: package, deviceId: deviceId)
                ownStrokes.merge(own) { first, _ in first }
                report.exported += 1
            } catch {
                SyncLogger.logAsync("匯出失敗 (\(document.title))：\(error.localizedDescription)")
                report.failures[document.title] = error.localizedDescription
            }
        }
        SyncLogger.logAsync("步驟 1 完成，成功匯出 \(report.exported) 本")

        // ── 2. 搬檔 (Heavy I/O, moved to background) ──────────────────────
        SyncLogger.logAsync("步驟 2：搬移雲端檔案 (背景執行)...")
        let (syncUploaded, syncDownloaded, syncNeedsAttention, syncFailures, newNotebooks) = await Task.detached(priority: .utility) {
            var up = 0
            var down = 0
            var attention = [String]()
            var fails = [String: String]()
            var newBooks = 0
            
            let packages = (try? fm.contentsOfDirectory(at: packagesDir, includingPropertiesForKeys: nil))?
                .filter { $0.pathExtension == "padnote" } ?? []
            for package in packages {
                let result = CloudSyncFolder.sync(localPackage: package, into: folder)
                up += result.uploaded.count
                down += result.downloaded.count
                attention.append(contentsOf: result.needsAttention)
                fails.merge(result.failures) { first, _ in first }
            }

            // 另一台裝置建立的筆記本，本機還沒有對應的套件目錄 —— 要先整包抓下來。
            var tempReport = Report()
            newBooks = pullUnknownPackages(into: packagesDir, from: folder, report: &tempReport)
            attention.append(contentsOf: tempReport.needsAttention)
            fails.merge(tempReport.failures) { first, _ in first }
            
            return (up, down, attention, fails, newBooks)
        }.value

        report.uploaded += syncUploaded
        report.downloaded += syncDownloaded
        report.needsAttention.append(contentsOf: syncNeedsAttention)
        report.failures.merge(syncFailures) { first, _ in first }
        report.newNotebooks += newNotebooks
        SyncLogger.logAsync("步驟 2 完成。上傳: \(syncUploaded), 下載: \(syncDownloaded), 新增: \(newNotebooks), 失敗: \(syncFailures.count)")

        // ── 3. 匯入回筆記 ─────────────────────────────────
        SyncLogger.logAsync("步驟 3：匯入套件回本機筆記...")
        importPackages(from: packagesDir, into: store, deviceId: deviceId, ownStrokes: ownStrokes, report: &report)
        SyncLogger.logAsync("【資料夾同步】全部完成。")

        return report
    }

    /// 跑完一輪**Google Drive** 的同步。
    ///
    /// 三步與資料夾同步完全一樣（匯出 → 搬檔 → 匯入），只有中間那一步換成
    /// Drive。順序同樣不能顛倒 —— 先搬檔的話上傳的是上一輪的舊內容，
    /// 不匯入的話另一台裝置寫的東西永遠不會變成筆記。
    ///
    /// 回傳 nil 表示沒登入。
    static func runDrive(store: SyncableNotebookStore, deviceId: UInt32) async -> Report? {
        guard await GoogleAuth.shared.isSignedIn else { return nil }
        SyncLogger.logAsync("【Google Drive 同步】開始執行")
        var report = Report()
        let fm = FileManager.default
        let packagesDir = store.syncPackagesDirectory
        try? fm.createDirectory(at: packagesDir, withIntermediateDirectories: true)

        // ── 1. 匯出本機的筆記 ──────────────────────────────
        SyncLogger.logAsync("步驟 1：匯出本機筆記 (\(store.syncNotebooks.count) 本)...")
        var ownStrokes: OwnStrokes = [:]
        for document in store.syncNotebooks {
            let package = packagesDir.appendingPathComponent("\(document.id).padnote")
            do {
                let own = try exportOne(document, from: store, to: package, deviceId: deviceId)
                ownStrokes.merge(own) { first, _ in first }
                report.exported += 1
            } catch {
                SyncLogger.logAsync("匯出失敗 (\(document.title))：\(error.localizedDescription)")
                report.failures[document.title] = error.localizedDescription
            }
        }
        SyncLogger.logAsync("步驟 1 完成，成功匯出 \(report.exported) 本")

        // ── 2. 中繼資料，再逐本搬內容 ───────────────────────
        // 順序不能反：先收斂索引，才知道哪些筆記本還活著。先同步內容的話，
        // 會把另一台已經刪掉的筆記本內容又推上去。
        SyncLogger.logAsync("步驟 2：同步元資料與檔案 (連線中)...")
        guard let meta = await CloudSync.runOnce() else {
            SyncLogger.logAsync("無法取得 Google Drive 索引！")
            return nil
        }
        guard meta.ok else {
            SyncLogger.logAsync("元資料同步失敗：\(meta.error)")
            report.failures["cloud"] = meta.error
            if meta.needsReauth {
                await GoogleAuth.shared.signOut()
            }
            return report
        }

        let packages = (try? fm.contentsOfDirectory(at: packagesDir, includingPropertiesForKeys: nil))?
            .filter { $0.pathExtension == "padnote" } ?? []
        SyncLogger.logAsync("雲端元資料同步完成，開始逐本比對套件檔案...")
        for package in packages {
            let id = package.deletingPathExtension().lastPathComponent
            guard let result = await CloudSync.syncNotebook(
                packagePath: package.path, notebookId: id) else { continue }
            if result.ok {
                report.uploaded += Int(result.uploaded)
                report.downloaded += Int(result.downloaded)
            } else {
                SyncLogger.logAsync("筆記本 \(id) 同步失敗：\(result.error)")
                report.failures[id] = result.error
                if result.needsReauth {
                    await GoogleAuth.shared.signOut()
                    break
                }
            }
        }

        // 別台裝置**新建**的筆記本在本機連套件目錄都沒有，上面那一圈看不到它們。
        let newBooks = await pullNewNotebooks(
            into: packagesDir, index: meta.indexJson, report: &report)
        report.newNotebooks += newBooks
        SyncLogger.logAsync("步驟 2 完成。上傳: \(report.uploaded), 下載: \(report.downloaded), 新增: \(report.newNotebooks)")

        // ── 3. 匯入回筆記 ─────────────────────────────────
        SyncLogger.logAsync("步驟 3：匯入套件回本機筆記...")
        importPackages(from: packagesDir, into: store, deviceId: deviceId, ownStrokes: ownStrokes, report: &report)
        SyncLogger.logAsync("【Google Drive 同步】全部完成。")

        return report
    }

    /// 把雲端有、本機還沒有的筆記本整本抓下來。回傳抓了幾本。
    ///
    /// 清單來自**合併後的索引**，不是本機那一份 —— 用本機的話，剛從雲端
    /// 收斂進來的那幾本還不在裡面，永遠差一輪。
    private static func pullNewNotebooks(
        into packagesDir: URL, index: String, report: inout Report
    ) async -> Int {
        let fm = FileManager.default
        var pulled = 0
        for item in syncLiveNotebooks(indexJson: index) {
            let package = packagesDir.appendingPathComponent("\(item.id).padnote")
            guard !fm.fileExists(atPath: package.path) else { continue }
            guard let result = await CloudSync.cloneNotebook(
                packagePath: package.path, notebookId: item.id, title: item.title)
            else { break }
            if result.ok {
                report.downloaded += Int(result.downloaded)
                pulled += 1
            } else {
                // 抓失敗時把空殼刪掉。留著的話，下一輪 `fileExists` 為真，
                // 這本就再也不會被重抓 —— 使用者會看到一本永遠打不開的空筆記。
                try? fm.removeItem(at: package)
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
        report: inout Report
    ) {
        let fm = FileManager.default
        let allPackages = (try? fm.contentsOfDirectory(at: packagesDir, includingPropertiesForKeys: nil))?
            .filter { $0.pathExtension == "padnote" } ?? []
        for package in allPackages {
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
                if error.localizedDescription.contains("不是 .padnote 套件") {
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
        into packagesDir: URL, from folder: URL, report: inout Report
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
}
import Foundation

@MainActor
public final class SyncLogger: ObservableObject {
    public static let shared = SyncLogger()
    
    public struct LogEntry: Identifiable, Sendable {
        public let id = UUID()
        public let timestamp = Date()
        public let message: String
    }
    
    @Published public private(set) var entries: [LogEntry] = []
    
    public func log(_ message: String) {
        let entry = LogEntry(message: message)
        entries.append(entry)
        if entries.count > 300 {
            entries.removeFirst(entries.count - 300)
        }
    }
    
    public func clear() {
        entries.removeAll()
    }
}

extension SyncLogger {
    public static func logAsync(_ message: String) {
        Task { @MainActor in
            SyncLogger.shared.log(message)
        }
    }
}
