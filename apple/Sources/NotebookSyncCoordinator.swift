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
    static func run(store: SyncableNotebookStore, folder: URL, deviceId: UInt32) -> Report {
        var report = Report()
        let fm = FileManager.default
        let packagesDir = store.syncPackagesDirectory
        try? fm.createDirectory(at: packagesDir, withIntermediateDirectories: true)

        // ── 1. 匯出本機的筆記 ──────────────────────────────
        var ownStrokes: OwnStrokes = [:]
        for document in store.syncNotebooks {
            let package = packagesDir.appendingPathComponent("\(document.id).padnote")
            do {
                let own = try exportOne(document, from: store, to: package, deviceId: deviceId)
                ownStrokes.merge(own) { first, _ in first }
                report.exported += 1
            } catch {
                report.failures[document.title] = error.localizedDescription
            }
        }

        // ── 2. 搬檔 ──────────────────────────────────────
        let packages = (try? fm.contentsOfDirectory(at: packagesDir, includingPropertiesForKeys: nil))?
            .filter { $0.pathExtension == "padnote" } ?? []
        for package in packages {
            let result = CloudSyncFolder.sync(localPackage: package, into: folder)
            report.uploaded += result.uploaded.count
            report.downloaded += result.downloaded.count
            report.needsAttention.append(contentsOf: result.needsAttention)
            report.failures.merge(result.failures) { first, _ in first }
        }

        // 另一台裝置建立的筆記本，本機還沒有對應的套件目錄 —— 要先整包抓下來。
        report.newNotebooks += pullUnknownPackages(into: packagesDir, from: folder, report: &report)

        // ── 3. 匯入回筆記 ─────────────────────────────────
        let allPackages = (try? fm.contentsOfDirectory(at: packagesDir, includingPropertiesForKeys: nil))?
            .filter { $0.pathExtension == "padnote" } ?? []
        for package in allPackages {
            do {
                try importOne(package, into: store, deviceId: deviceId, ownStrokes: ownStrokes)
                report.imported += 1
            } catch {
                report.failures[package.lastPathComponent] = error.localizedDescription
            }
        }

        return report
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

    /// 把雲端資料夾裡本機還沒有的套件整包抓下來。
    ///
    /// `CloudSyncFolder.sync` 只處理「本機已經有這個套件目錄」的情況 ——
    /// 另一台裝置**新建**的筆記本在本機連目錄都沒有，不另外抓的話永遠不會出現。
    private static func pullUnknownPackages(
        into packagesDir: URL, from folder: URL, report: inout Report
    ) -> Int {
        let fm = FileManager.default
        let remote = (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil))?
            .filter { $0.pathExtension == "padnote" } ?? []

        var pulled = 0
        for remotePackage in remote {
            let local = packagesDir.appendingPathComponent(remotePackage.lastPathComponent)
            guard !fm.fileExists(atPath: local.path) else { continue }
            let result = CloudSyncFolder.sync(localPackage: local, into: folder)
            report.downloaded += result.downloaded.count
            report.failures.merge(result.failures) { first, _ in first }
            if !result.downloaded.isEmpty { pulled += 1 }
        }
        return pulled
    }
}
