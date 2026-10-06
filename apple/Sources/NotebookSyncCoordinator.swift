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

import CryptoKit
import Foundation
import PencilKit

/// **每一本筆記本一把鎖**（核心：`notebook_lock_*`）。
///
/// 整庫互斥閘（`SyncGateQueue`）擋的是兩輪整庫同步並行。焦點通道與區網
/// 直連刻意不走它 —— 整庫一輪可能跑幾十秒，秒同步等不起。兩條通道真正會撞在
/// 一起的地方只有**同一本筆記本的套件目錄**（匯出寫、下載寫、匯入讀），
/// 所以鎖的粒度是筆記本：焦點通道在處理 A 的時候，整庫通道照跑其他本，
/// 遇到 A 就略過或稍等。
enum NotebookLock {
    private static var nowMs: UInt64 {
        UInt64(ProcessInfo.processInfo.systemUptime * 1000)
    }

    static func tryEnter(_ notebookId: String, label: String) -> UInt64? {
        let grant = notebookLockTryEnter(
            notebookId: notebookId.lowercased(), label: label, nowMs: nowMs
        )
        return grant.granted ? grant.ticket : nil
    }

    static func leave(_ notebookId: String, ticket: UInt64) {
        _ = notebookLockLeave(notebookId: notebookId.lowercased(), ticket: ticket)
    }

    /// 等一下再拿。給**不能略過**的動作用（例如把整庫下載到的內容匯入畫面：
    /// 略過的話那份內容就沒有人會再去匯入）。焦點通道每輪很短，等幾秒夠了。
    static func enter(_ notebookId: String, label: String, waitMs: UInt64) async -> UInt64? {
        let started = nowMs
        while !Task.isCancelled {
            if let ticket = tryEnter(notebookId, label: label) { return ticket }
            if nowMs - started >= waitMs { return nil }
            try? await Task.sleep(nanoseconds: 80_000_000)
        }
        return nil
    }
}

/// 同一個 App 行程內的同步入口佇列。
///
/// 核心閘保證互斥；這一層把「忙碌就丟掉」改成「等前一輪收尾」。因此自動
/// 同步、手動同步、資料夾同步與重置不會同時寫同一批套件，也不需要使用者
/// 看見「上一輪仍在跑」後再手動重按。跨裝置不共用這把鎖：不同裝置靠各自
/// oplog 與 CRDT 合併，才能離線工作。
enum SyncGateQueue {
    private static let pollNanoseconds: UInt64 = 150_000_000
    private static let maxWaitMs: UInt64 = 2 * 60_000

    static func enter(label: String) async -> FfiSyncGrant? {
        let started = UInt64(ProcessInfo.processInfo.systemUptime * 1000)
        while !Task.isCancelled {
            let now = UInt64(ProcessInfo.processInfo.systemUptime * 1000)
            let grant = syncGateTryEnter(label: label, nowMs: now)
            if grant.granted { return grant }
            if now.saturatingSubtract(started) >= maxWaitMs { return nil }
            try? await Task.sleep(nanoseconds: pollNanoseconds)
        }
        return nil
    }
}

private extension UInt64 {
    func saturatingSubtract(_ other: UInt64) -> UInt64 {
        self >= other ? self - other : 0
    }
}

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
    var syncDrawingsDirectory: URL { get }
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

    // unused-param-ok: 協定要求只有宣告、沒有主體；檢查器把相鄰宣告之後的 { 誤認成它們的主體。
    func syncLoadDrawing(notebookId: String, pageIndex: Int) -> PKDrawing
    func syncSaveDrawing(notebookId: String, pageIndex: Int, drawing: PKDrawing)
    func syncUpsert(_ document: NotebookDocument)
    func syncPurgeDeletedNotebooks(_ deletedIds: Set<String>)
    /// 永久清掉已期滿的本機回收桶項目，回傳清了幾本（回收桶，見 docs/plans/expiry-purge.md）。
    func syncPurgeExpiredTrash() -> Int
    func syncRepairSeedDuplicates()
    func syncRefreshRecordings()
    /// 錄音清單。匯出時取出「屬於這本筆記的錄音」的名字。
    var syncRecordings: [AudioRecordingRecord] { get }
    /// 把別台改的錄音名字套進清單。`exported` 是匯出當下各錄音的名字：
    /// 匯出之後使用者在這台又改過的（名字與 `exported` 不同）不被蓋掉。
    func syncApplyRecordingTitles(_ titles: [String: String], exported: [String: String]?)
}

extension SyncableNotebookStore {
    var activeNotebookId: String? {
        nil
    }

    func syncPurgeDeletedNotebooks(_: Set<String>) {}
    /// 預設沒有回收桶（測試用的假 store）：什麼都不清。
    func syncPurgeExpiredTrash() -> Int { 0 }
    func syncRepairSeedDuplicates() {}
    func syncRefreshRecordings() {}
    var syncRecordings: [AudioRecordingRecord] { [] }
    func syncApplyRecordingTitles(_: [String: String], exported _: [String: String]?) {}
}

extension NotebookStore: SyncableNotebookStore {
    var syncRecordings: [AudioRecordingRecord] { recordings }

    func syncApplyRecordingTitles(_ titles: [String: String], exported: [String: String]?) {
        applyRecordingTitles(titles, exported: exported)
    }

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

    func syncPurgeExpiredTrash() -> Int {
        purgeExpiredTrash()
    }

    func syncRepairSeedDuplicates() {
        repairSyncedSeedDuplicates()
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

    var syncDrawingsDirectory: URL {
        drawingsDirectory
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
        upsertNotebook(document, fromSync: true)
    }
}

/// 這一輪匯出當下，每本筆記上有哪些物件、各自長什麼樣子（id → 內容指紋）。
///
/// 匯入要拿它判斷「匯出之後、匯入之前，使用者又動了什麼」——
/// 新增的、移動過的、改過內容的，見 `NotebookSyncCoordinator.preservingLocalChanges`。
/// 每本筆記本「最後一次匯出（或匯入採用）時，各物件的內容指紋」（跨行程穩定，SHA-256）。
///
/// `workingCopyNeedsExport` 只看檔案時間：移動／縮放膠帶這類**只改物件**的編輯，
/// 碰上「套件的檔案時間比文件新」（匯入剛碰過 manifest、筆跡增量剛寫進套件）就被判成不必匯出 ——
/// 於是沒有匯出名單，下一次匯入就把套件裡的舊版本整份蓋回來：使用者看到的是
/// 「移到別處、調整大小之後，自己又跳回原來的位置與大小」。
/// 有了這份帳本，物件跟上次匯出的不一樣就一定匯出，不受檔案時間先後影響。
enum ObjectLedger {
    private static func url(in directory: URL, notebookId: String) -> URL {
        directory.appending(path: "\(notebookId.lowercased())_objects.json")
    }

    static func stableFingerprints(of d: NotebookDocument) -> [String: String] {
        var out: [String: String] = [:]
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        func add<T: Identifiable & Encodable>(_ items: [T]?) where T.ID == String {
            for item in items ?? [] {
                let data = (try? encoder.encode(item)) ?? Data()
                out[item.id.lowercased()] = SHA256.hash(data: data).prefix(8)
                    .map { String(format: "%02x", $0) }.joined()
            }
        }
        add(d.attachments); add(d.textAttachments); add(d.tableAttachments); add(d.shapeAttachments)
        add(d.connectionAttachments); add(d.linkAttachments); add(d.model3DAttachments)
        add(d.audioAttachments); add(d.commentPins); add(d.tapeAttachments); add(d.stickyAnchors)
        return out
    }

    static func save(_ document: NotebookDocument, in directory: URL) {
        let prints = stableFingerprints(of: document)
        guard let data = try? JSONEncoder().encode(prints) else { return }
        try? data.write(to: url(in: directory, notebookId: document.id), options: .atomic)
    }

    /// 有帳本、而且現在的物件與帳本不同（改過、新增或刪掉）才算有變動；沒有帳本不強制（維持原本行為）。
    static func hasUnsynced(_ document: NotebookDocument, in directory: URL) -> Bool {
        guard let data = try? Data(contentsOf: url(in: directory, notebookId: document.id)),
              let known = try? JSONDecoder().decode([String: String].self, from: data)
        else { return false }
        return stableFingerprints(of: document) != known
    }
}

/// 每本筆記本「套件裡已經有的錄音名字」：檔名（小寫）→ 名字。
///
/// 名字不在 `NotebookDocument` 裡，`workingCopyNeedsExport` 只看檔案時間就看不出名字有沒有變。
/// 這份帳本記下最後一次匯出（或匯入採用）的名字，之後只要這台現在的名字跟它不一樣，
/// 就一定要匯出 —— 檔案時間再怎麼排都不會漏。
enum RecordingTitleLedger {
    private static func url(in directory: URL, notebookId: String) -> URL {
        directory.appending(path: "\(notebookId.lowercased())_rectitles.json")
    }

    static func load(in directory: URL, notebookId: String) -> [String: String] {
        guard let data = try? Data(contentsOf: url(in: directory, notebookId: notebookId)),
              let map = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return map
    }

    /// 這台現在的名字裡，有沒有哪一個跟帳本不一樣（含帳本沒有的）。
    static func hasUnsynced(
        _ titles: [String: String], in directory: URL, notebookId: String
    ) -> Bool {
        guard !titles.isEmpty else { return false }
        let known = load(in: directory, notebookId: notebookId)
        return titles.contains { known[$0.key] != $0.value }
    }

    /// 整份換成這一輪匯出的名字。
    static func save(_ titles: [String: String], in directory: URL, notebookId: String) {
        write(titles, in: directory, notebookId: notebookId)
    }

    /// 併入匯入時採用的名字，其餘不動。
    static func merge(_ titles: [String: String], in directory: URL, notebookId: String) {
        guard !titles.isEmpty else { return }
        var known = load(in: directory, notebookId: notebookId)
        known.merge(titles) { _, new in new }
        write(known, in: directory, notebookId: notebookId)
    }

    private static func write(_ titles: [String: String], in directory: URL, notebookId: String) {
        guard let data = try? JSONEncoder().encode(titles) else { return }
        try? data.write(to: url(in: directory, notebookId: notebookId), options: .atomic)
    }
}

final class ExportedObjectIds: @unchecked Sendable {
    static let shared = ExportedObjectIds()
    private let lock = NSLock()
    private var prints: [String: [String: Int]] = [:]

    func record(_ document: NotebookDocument) {
        let fingerprints = Self.fingerprints(of: document)
        lock.lock(); defer { lock.unlock() }
        prints[document.id.lowercased()] = fingerprints
    }

    private var titles: [String: [String: String]] = [:]

    func recordTitles(_ value: [String: String], for notebookId: String) {
        lock.lock(); defer { lock.unlock() }
        titles[notebookId.lowercased()] = value
    }

    func takeTitles(_ notebookId: String) -> [String: String]? {
        lock.lock(); defer { lock.unlock() }
        return titles.removeValue(forKey: notebookId.lowercased())
    }

    func take(_ notebookId: String) -> [String: Int]? {
        lock.lock(); defer { lock.unlock() }
        return prints.removeValue(forKey: notebookId.lowercased())
    }

    /// 每個物件的內容指紋。位置、大小、文字、外觀任何一項變了，指紋就不同。
    static func fingerprints(of d: NotebookDocument) -> [String: Int] {
        var out: [String: Int] = [:]
        func add<T: Identifiable & Encodable>(_ items: [T]?) where T.ID == String {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            for item in items ?? [] {
                out[item.id.lowercased()] = (try? encoder.encode(item)).map { Data($0).hashValue } ?? 0
            }
        }
        add(d.attachments); add(d.textAttachments); add(d.tableAttachments); add(d.shapeAttachments)
        add(d.connectionAttachments); add(d.linkAttachments); add(d.model3DAttachments)
        add(d.audioAttachments); add(d.commentPins); add(d.tapeAttachments); add(d.stickyAnchors)
        return out
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
    typealias OwnStrokes = [String: PKDrawing]

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
        guard let grant = await SyncGateQueue.enter(label: "folder") else {
            SyncLogger.logAsync(
                "【資料夾同步】等待上一輪結束逾時，已保留待同步狀態",
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
                    failures[input.document.title] = L10n.errorText(error)
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
        store.syncRepairSeedDuplicates()
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
        guard let grant = await SyncGateQueue.enter(label: "google-drive") else {
            SyncLogger.logAsync(
                "【Google Drive 同步】等待上一輪結束逾時，已保留待同步狀態",
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

        // (A) 只把「索引從未見過」的舊版本機筆記補進去。
        //
        // 絕對不能在這裡用工作副本的標題去「校正」既有索引。工作副本可能是
        // 一台離線很久的裝置留下的舊畫面；若每輪都 record，它會取得全新的
        // Lamport 時戳，反而擊敗另一台較早發生、但語意上真正較新的改名。
        // 使用者新增／改名／搬移的入口本來就會 record；同步只能合併事件，
        // 不能把「啟動同步」偽裝成一次使用者編輯。
        for document in store.allNotebooks {
            let docId = document.id.lowercased()
            guard !AccountSyncStore.shared.isDeleted(id: document.id) else { continue }
            if localLiveById[docId] == nil {
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
                // 焦點通道正在處理這一本（它自己會匯出、推送、匯入）：
                // 略過，不要兩條通道同時寫同一個套件。同步是冪等的，
                // 這一本下一輪再看沒有任何代價。
                guard let lockTicket = NotebookLock.tryEnter(
                    input.document.id, label: "full-export"
                ) else { continue }
                defer { NotebookLock.leave(input.document.id, ticket: lockTicket) }
                // 前景心跳與事件觸發會反覆進來。沒有這道判斷時，每一輪都把
                // 每一本套件完整重建，即使一個字都沒改；iPad 實機曾因此在
                // 25 分鐘內寫入 4.3 GB，最後被系統以 excessive disk writes
                // 終止。套件比工作副本新代表編輯器的增量寫入或上一輪匯出
                // 已經包含這份內容，直接沿用即可。
                if !workingCopyNeedsExport(input) {
                    do {
                        own.merge(try snapshotOwnStrokes(input)) { first, _ in first }
                    } catch is CancellationError {
                        return (own, exported, failures, true)
                    } catch {
                        failures[input.document.title] = L10n.errorText(error)
                    }
                    continue
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
                    failures[input.document.title] = L10n.errorText(error)
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
            let message = refreshed?.error ?? L10n.t("sync_snapshot_timeout")
            SyncLogger.logAsync("雲端快照更新失敗：\(message)", source: .googleDrive)
            report.failures["cloud"] = L10n.coreText(message)
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
            report.failures["cloud"] = L10n.coreText(meta.error)
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
        let deletedNotebookIds = Set(AccountSyncStore.shared.deletedNotebookIds.map { $0.lowercased() })
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
            if deletedNotebookIds.contains(id) {
                try? fm.removeItem(at: pkg)
                cleanedCount += 1
                continue
            }
            if activeLocalIds.contains(id) {
                packages.append(pkg)
                continue
            }
            if !cloudLiveIds.contains(id) {
                try? fm.removeItem(at: pkg)
                cleanedCount += 1
            }
        }

        // 只碰真的有差異的那幾本。**這一行是整個改善的重點。**
        //
        // **必須在背景執行緒問。** `notebookNeedsSync` 會鎖住核心 `FfiSyncSession` 的 mutex，
        // 而焦點通道（`runFocusRound`）拿著同一個 session 在背景做 `focusRound` 時，整段網路
        // 下載期間都握著那把鎖。原本這裡在 MainActor 上同步呼叫 —— 主執行緒就卡在
        // `pthread_mutex_lock` 直到那次下載結束，iPad 實機被看門狗以 0x8BADF00D 殺掉
        // （2026-10-04 TestFlight 4.19.0 (79) 當機報告，主執行緒停在 notebook_needs_sync）。
        let activeId = store.activeNotebookId
        let candidates = packages.map { (url: $0, id: packageId(for: $0)) }
        let pendingIds = await Task.detached(priority: .utility) { () -> Set<String> in
            var out = Set<String>()
            for candidate in candidates
            where session.notebookNeedsSync(packagePath: candidate.url.path, notebookId: candidate.id) {
                out.insert(candidate.url.path)
            }
            return out
        }.value
        let pending = packages.filter { pendingIds.contains($0.path) }
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
            // 同上：焦點通道拿著這一本就略過。
            guard let lockTicket = NotebookLock.tryEnter(id, label: "full-sync") else { continue }
            defer { NotebookLock.leave(id, ticket: lockTicket) }
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
                report.failures[id] = L10n.coreText(result.error)
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
            store.syncRepairSeedDuplicates()
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
        store.syncRepairSeedDuplicates()
        store.syncPurgeDeletedNotebooks(deletedNotebookIds)
        store.syncRefreshRecordings()

        // ── 5. 回收桶：發布確認、回收期滿的、清掉本機期滿的 ──────────
        //
        // 刪除是先進回收桶、保留一段期限（預設 30 天）才永久刪除，不是同步一輪就刪
        // （設計見 docs/plans/expiry-purge.md）。雲端檔案要**期滿、而且每一台必要裝置都
        // 確認過這個刪除**才會動；還在等的會回報在 `waitingDevices`。
        await AccountSyncStore.shared.stampLegacyTombstonesIfNeeded()
        let library = await AccountSyncStore.shared.indexJSON
        let syncDeviceId = await AccountSyncStore.shared.deviceId
        let now = TrashRetention.nowUnixSeconds()
        let retentionDays = TrashRetention.days

        // 先發布「這台已經合併到哪裡」。順序在回收之前：別台要靠它判斷能不能刪。
        // 背景執行緒：它會上傳到 Drive，而且握著 session 的鎖（見上面 notebookNeedsSync 的說明）。
        let ack = await Task.detached(priority: .utility) {
            session.publishAck(deviceId: syncDeviceId, libraryIndexJson: library, nowUnixS: now)
        }.value
        if !ack.ok {
            SyncLogger.logAsync("【回收桶】確認檔沒發布成功：\(ack.error)", source: .googleDrive)
        }

        let gcResult = await Task.detached(priority: .utility) {
            session.collectGarbage(
                libraryIndexJson: library,
                deviceId: syncDeviceId,
                nowUnixS: now,
                retentionDays: retentionDays,
                emptyTrash: false)
        }.value
        if gcResult.deleted > 0 {
            SyncLogger.logAsync("【回收桶】已永久清理雲端 \(gcResult.deleted) 個過期檔案", source: .googleDrive)
            await CloudSync.persist(session)
        }
        if gcResult.waitingNotebooks > 0 {
            SyncLogger.logAsync(
                "【回收桶】\(gcResult.waitingNotebooks) 本已期滿，等待這些裝置確認：\(gcResult.waitingDevices.joined(separator: ", "))",
                source: .googleDrive)
        }
        let purgedLocal = store.syncPurgeExpiredTrash()
        if purgedLocal > 0 {
            SyncLogger.logAsync("【回收桶】已永久清理本機 \(purgedLocal) 本過期筆記本", source: .googleDrive)
        }

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
                report.failures[item.title] = L10n.coreText(result.error)
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
            drawingsDirectory: inputs.drawingsDirectory,
            deviceId: inputs.deviceId, loadDrawing: inputs.loadDrawing,
            recordingTitles: inputs.recordingTitles
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
        applyImported(imported, documentId: documentId, into: store, ownStrokes: [:])
    }

    @MainActor
    private static func packageURL(for notebookId: String, in store: SyncableNotebookStore) -> URL {
        try? FileManager.default.createDirectory(
            at: store.syncPackagesDirectory, withIntermediateDirectories: true
        )
        return store.syncPackagesDirectory
            .appending(path: "\(notebookId.lowercased()).padnote")
    }

    // MARK: - 焦點通道（秒同步）

    /// 焦點通道一輪的結果。
    struct FocusReport {
        var ok = true
        var hadWork = false
        var uploaded = 0
        var downloaded = 0
        var remoteChanges = 0
        var error = ""
        var needsReauth = false
        var warnings: [String] = []
        /// 各段耗時（毫秒）。**量出來才知道慢在哪** —— 有工作的那幾輪寫進同步日誌。
        var exportMs = 0
        var driveMs = 0
        var importMs = 0
    }

    private static func millis(since start: ContinuousClock.Instant, clock: ContinuousClock) -> Int {
        let parts = start.duration(to: clock.now).components
        return Int(parts.seconds * 1000 + parts.attoseconds / 1_000_000_000_000_000)
    }

    /// 焦點通道的一輪：只處理使用者現在開著的那一本。
    ///
    /// 整庫那一輪（匯出每一本、中繼資料、逐本同步、匯入、垃圾回收）的成本
    /// 跟筆記本數量成正比，所以「改一個字要多久才到另一台」取決於整個
    /// 資料庫有多大。這裡縮成：**匯出這一本 →（區網通知）→ 一次 `changes.list`
    /// → 有差異才傳這一本 → 有下載才匯入這一本。**
    ///
    /// **呼叫端要先拿 `NotebookLock`。** 這個函式不自己拿：鎖的生命週期
    /// 要涵蓋呼叫端在前後做的事（區網通知、排程回報）。
    ///
    /// - Parameter afterExport: 匯出完成、還沒去問 Drive 之前呼叫。區網直連
    ///   在這裡把「我有新東西」通知對端 —— 不必等 Drive 那一趟。
    @MainActor
    static func runFocusRound(
        store: SyncableNotebookStore,
        deviceId: UInt32,
        notebookId: String,
        push: Bool,
        session: FfiSyncSession,
        afterExport: @escaping @Sendable () -> Void
    ) async -> FocusReport {
        var report = FocusReport()
        guard let document = store.syncNotebooks.first(where: {
            $0.id.caseInsensitiveCompare(notebookId) == .orderedSame
        }) else {
            return report
        }
        let packagesDir = store.syncPackagesDirectory
        try? FileManager.default.createDirectory(at: packagesDir, withIntermediateDirectories: true)
        let inputs = exportInputs(for: document, store: store, packagesDir: packagesDir, deviceId: deviceId)

        // ── 1. 匯出。使用者剛寫的東西要先進套件，否則後面推的是舊的。
        //
        // **`push` 不強制匯出**：編輯器每次落筆都已經把增量追加進同一個套件
        // （`flushPendingCoreInk`），這時套件比工作副本新，`workingCopyNeedsExport`
        // 會判定不必重建。強制匯出等於每一筆都把整本筆記的每一頁重寫一次。
        // 文字、物件這類走 `updateNotebook` 的編輯會讓文件時間比套件新，
        // 那時候它自然會回 true。
        let clock = ContinuousClock()
        let exportStart = clock.now
        let exported = await Task.detached(priority: .userInitiated) {
            () -> (own: OwnStrokes?, didExport: Bool, error: String) in
            do {
                if workingCopyNeedsExport(inputs) {
                    return (try exportOne(inputs), true, "")
                }
                return (try snapshotOwnStrokes(inputs), false, "")
            } catch {
                return (nil, false, error.localizedDescription)
            }
        }.value
        report.exportMs = Self.millis(since: exportStart, clock: clock)
        guard let own = exported.own else {
            report.ok = false
            report.error = String(format: LocalizationManager.shared.localized("export_failed"), L10n.coreText(exported.error))
            return report
        }
        // 有寫入就通知區網對端（不論是這裡匯出的、還是編輯器已經追加進套件的）。
        if push || exported.didExport { afterExport() }

        // ── 2. 問 Drive、只傳這一本的差異。
        let packagePath = inputs.package.path
        let id = notebookId.lowercased()
        let driveStart = clock.now
        let round = await Task.detached(priority: .userInitiated) {
            session.focusRound(packagePath: packagePath, notebookId: id, deviceId: deviceId)
        }.value
        report.driveMs = Self.millis(since: driveStart, clock: clock)
        report.hadWork = round.hadWork
        report.uploaded = Int(round.uploaded)
        report.downloaded = Int(round.downloaded)
        report.remoteChanges = Int(round.remoteChanges)
        report.warnings = round.warnings
        guard round.ok else {
            report.ok = false
            report.error = L10n.coreText(round.error)
            report.needsReauth = round.needsReauth
            return report
        }

        // ── 3. 有下載才匯入這一本。**匯入前的匯出已經做完了**（步驟 1），
        // 所以使用者剛寫的東西已經在套件裡，不會被合併結果蓋掉。
        if round.downloaded > 0 {
            let importStart = clock.now
            defer { report.importMs = Self.millis(since: importStart, clock: clock) }
            do {
                try await importOne(inputs.package, into: store, deviceId: deviceId, ownStrokes: own)
                NotificationCenter.default.post(
                    name: AppCommand.notebookPackageChanged, object: id
                )
            } catch {
                report.ok = false
                report.error = String(format: LocalizationManager.shared.localized("import_failed"), L10n.errorText(error))
            }
        }
        return report
    }

    /// 區網對端把新的檔案寫進了套件 —— 把它匯入畫面。
    ///
    /// **順序是匯出、再匯入**，與 Drive 那條路一致：匯入會用套件的合併結果
    /// 取代工作副本，使用者在這之前剛寫、還沒進套件的筆畫必須先匯出，
    /// 不然會被蓋掉。呼叫端要先拿 `NotebookLock`。
    @MainActor
    static func importReceived(
        store: SyncableNotebookStore, deviceId: UInt32, notebookId: String
    ) async -> Bool {
        guard let document = store.syncNotebooks.first(where: {
            $0.id.caseInsensitiveCompare(notebookId) == .orderedSame
        }) else { return false }
        let packagesDir = store.syncPackagesDirectory
        let inputs = exportInputs(for: document, store: store, packagesDir: packagesDir, deviceId: deviceId)
        let own = await Task.detached(priority: .userInitiated) { () -> OwnStrokes? in
            do {
                if workingCopyNeedsExport(inputs) { return try exportOne(inputs) }
                return try snapshotOwnStrokes(inputs)
            } catch {
                return nil
            }
        }.value
        guard let own else { return false }
        do {
            try await importOne(inputs.package, into: store, deviceId: deviceId, ownStrokes: own)
        } catch {
            return false
        }
        NotificationCenter.default.post(
            name: AppCommand.notebookPackageChanged, object: notebookId.lowercased()
        )
        return true
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
        let drawingsDirectory: URL
        let deviceId: UInt32
        let loadDrawing: @Sendable (String, Int) -> PKDrawing
        /// 屬於這本筆記的錄音：檔名 → 名字。寫進套件，名字才跟著同步（見 `RecordingTitle`）。
        var recordingTitles: [String: String] = [:]
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
            // 套件路徑與雲端路徑都以 canonical id 為準。iOS/macOS 常見磁碟
            // 不分大小寫，測不出 A… 與 a… 其實是兩個雲端物件；Android 與
            // Google Drive 會分開看，最後就變成兩本內容相同的筆記。
            package: packagesDir.appending(path: "\(document.id.lowercased()).padnote"),
            baselineDirectory: store.syncBaselineDirectory,
            attachmentsDirectory: store.syncAttachmentsDirectory,
            drawingsDirectory: store.syncDrawingsDirectory,
            deviceId: deviceId,
            loadDrawing: store.syncDrawingLoader,
            recordingTitles: recordingTitles(of: document, in: store)
        )
    }

    /// 這本筆記的套件裡的錄音（`linkedNotebookId` 是它，或者未歸檔但匯出收件匣時）：檔名（小寫）→ 名字。
    @MainActor
    private static func recordingTitles(
        of document: NotebookDocument, in store: SyncableNotebookStore
    ) -> [String: String] {
        var out: [String: String] = [:]
        let isInbox = document.id.caseInsensitiveCompare(recordingInboxNotebookId()) == .orderedSame
        for record in store.syncRecordings {
            if let linked = record.linkedNotebookId {
                if linked.caseInsensitiveCompare(document.id) == .orderedSame {
                    out[record.fileName.lowercased()] = record.title
                }
            } else if isInbox {
                // 未指定筆記本的錄音屬於收件匣，匯出收件匣時必須帶上其標題
                out[record.fileName.lowercased()] = record.title
            }
        }
        return out
    }

    /// 匯出一本，回傳這台裝置在各頁自己擁有的筆畫。
    ///
    /// `nonisolated`：這裡每頁要讀一次檔、解一次 `PKDrawing`、再寫一次
    /// CRDT 套件，是整個同步最貴的一段。留在 MainActor 上的話，筆記本一多
    /// 主執行緒就被連續佔住十秒以上 —— iOS 的 scene-update 看門狗會直接
    /// SIGKILL（0x8BADF00D），實機上就是「按下同步之後整個 App 消失」。
    @discardableResult
    nonisolated static func exportOne(_ inputs: ExportInputs) throws -> OwnStrokes {
        let document = inputs.document
        let pageCount = max(document.pageCount, 1)
        ExportedObjectIds.shared.record(document)
        // 匯入時要知道「匯出那一刻的名字」，才分得出錄音是誰改的名。
        ExportedObjectIds.shared.recordTitles(inputs.recordingTitles, for: document.id)
        // 只寫這台裝置自己新增的筆畫。
        //
        // 寫整份的話，等於把從別台裝置下載下來的筆畫複製一份掛在自己名下，
        // 下一次合併就會看到兩份、再下一次四份 —— 使用者看到的是筆跡愈來愈粗，
        // 因為同一條線被重複畫了好幾遍。
        //
        // 扣掉的是「別台裝置寫的那些」，不是「上次同步時的全部」——
        // 扣掉全部的話，這台裝置自己的筆畫在下一次匯出時會被扣成空的，
        // 而它的檔案又會被整個重寫，等於自己把自己的內容刪掉。
        let own = try snapshotOwnStrokes(inputs)
        var drawings = [PKDrawing]()
        drawings.reserveCapacity(pageCount)
        for page in 0 ..< pageCount {
            if NotebookSyncCoordinator.isCancelled || Task.isCancelled {
                throw CancellationError()
            }
            drawings.append(own[baselineKey(document.id, page)] ?? PKDrawing())
        }
        var images: [String: Data] = [:]
        for attachment in document.attachments ?? [] {
            let url = inputs.attachmentsDirectory.appending(path: attachment.fileName)
            if let bytes = try? Data(contentsOf: url) {
                images[attachment.fileName] = bytes
            }
        }
        // 專業筆刷（自繪引擎）：只寫這台自己的。別台的另存一份（`.proink-foreign`），不在這裡。
        let pro = (0 ..< pageCount).map {
            ProInkStore.load(in: inputs.drawingsDirectory, notebookId: document.id, page: $0)
        }
        // 錄音的名字要**一起**交給匯出：漏傳的話套件裡永遠沒有 `rectitle` 區塊，
        // 別台只看得到掃描時取的預設名稱（單元測試直接呼叫橋接層、有帶這個參數，所以測不出來）。
        try NotebookPackageBridge.exportPreservingOtherDevices(
            document: document, drawings: drawings, imageData: images,
            to: inputs.package, deviceId: inputs.deviceId, proStrokes: pro,
            recordingTitles: inputs.recordingTitles
        )
        RecordingTitleLedger.save(
            inputs.recordingTitles, in: inputs.baselineDirectory, notebookId: document.id)
        ObjectLedger.save(document, in: inputs.baselineDirectory)
        return own
    }

    /// 算出這台裝置在各頁擁有的筆畫，但不改寫套件。
    ///
    /// 未修改的筆記雖然可以跳過匯出，後續若下載了遠端內容，匯入仍需要這份
    /// own/others 邊界來更新 baseline；省略它會把自己的舊筆畫誤認成別人的，
    /// 下一次匯出時再把自己的 oplog 刪掉，造成看似隨機的內容回退。
    private nonisolated static func snapshotOwnStrokes(_ inputs: ExportInputs) throws -> OwnStrokes {
        var own: OwnStrokes = [:]
        for page in 0 ..< max(inputs.document.pageCount, 1) {
            if NotebookSyncCoordinator.isCancelled || Task.isCancelled {
                throw CancellationError()
            }
            let current = inputs.loadDrawing(inputs.document.id, page)
            let others = loadBaseline(
                in: inputs.baselineDirectory,
                notebookId: inputs.document.id,
                pageIndex: page
            )
            own[baselineKey(inputs.document.id, page)] = PKDrawing(
                strokes: StrokeDelta.added(in: current, since: others)
            )
        }
        return own
    }

    /// 工作副本是否真的比套件新。
    ///
    /// 只讀檔案時間，不讀內容也不寫任何東西。目錄自己的 mtime 不可靠，
    /// 所以取套件內所有檔案的最大值；工作副本則看文件時間、各頁 drawing
    /// 與它引用的附件。任何資訊讀不到都保守地回 true，寧可多匯出一次，
    /// 不冒漏資料的風險。
    nonisolated static func workingCopyNeedsExport(_ inputs: ExportInputs) -> Bool {
        let fm = FileManager.default
        guard fm.fileExists(atPath: inputs.package.path) else { return true }
        // 錄音的名字不在文件裡，檔案時間看不出它變了：新錄的音檔（比筆記本新）、改名之後又落筆
        // （增量寫入讓套件比較新）都會被判成「不必匯出」，名字就沒帶出去。
        if RecordingTitleLedger.hasUnsynced(
            inputs.recordingTitles, in: inputs.baselineDirectory, notebookId: inputs.document.id) {
            return true
        }

        if ObjectLedger.hasUnsynced(inputs.document, in: inputs.baselineDirectory) { return true }

        guard let enumerator = fm.enumerator(
            at: inputs.package,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return true }

        var packageNewest = Date.distantPast
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
                  let modified = values.contentModificationDate
            else { continue }
            packageNewest = max(packageNewest, modified)
        }
        guard packageNewest != .distantPast else { return true }

        var workingNewest = inputs.document.lastModifiedDate
        let drawingsDir = inputs.drawingsDirectory
        for page in 0 ..< max(inputs.document.pageCount, 1) {
            let url = drawingsDir.appending(path: "\(inputs.document.id)_p\(page).drawing")
            if let values = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
               let modified = values.contentModificationDate {
                workingNewest = max(workingNewest, modified)
            }
        }
        for page in 0 ..< max(inputs.document.pageCount, 1) {
            if let modified = ProInkStore.modified(in: drawingsDir, notebookId: inputs.document.id, page: page) {
                workingNewest = max(workingNewest, modified)
            }
        }
        for attachment in inputs.document.attachments ?? [] {
            let url = inputs.attachmentsDirectory.appending(path: attachment.fileName)
            if let values = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
               let modified = values.contentModificationDate {
                workingNewest = max(workingNewest, modified)
            }
        }
        return workingNewest > packageNewest
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
        applyImported(imported, documentId: documentId, into: store, ownStrokes: ownStrokes)
    }

    private static func applyImported(
        _ imported: NotebookPackageBridge.ImportedNotebook,
        documentId: String,
        into store: SyncableNotebookStore,
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
        // 專業筆刷：合併後的全部 − 這台自己的 = 別台的。比對用內容指紋（核心每次匯出都換 id）。
        let drawingsDir = store.syncDrawingsDirectory
        for (index, merged) in imported.proStrokes.enumerated() {
            let own = Set(
                ProInkStore.load(in: drawingsDir, notebookId: documentId, page: index).map(\.contentKey))
            ProInkStore.save(
                merged.filter { !own.contains($0.contentKey) },
                in: drawingsDir, notebookId: documentId, page: index, foreign: true)
        }
        if !imported.proStrokes.isEmpty {
            NotificationCenter.default.post(
                name: .kairumoProInkChangedOnDisk, object: nil, userInfo: ["notebookId": documentId])
        }
        let (merged, preserved) = preservingLocalChanges(
            imported.document, local: store.allNotebooks.first {
                $0.id.caseInsensitiveCompare(documentId) == .orderedSame
            },
            exported: ExportedObjectIds.shared.take(documentId))
        store.syncUpsert(merged)
        SyncKnownObjects.recordVisible(merged)
        store.syncApplyRecordingTitles(
            imported.recordingTitles, exported: ExportedObjectIds.shared.takeTitles(documentId))
        // 套件裡已經是這個名字、這台也採用了的，記進帳本：不然下一輪會以為「名字沒同步」而白匯出一次。
        if !imported.recordingTitles.isEmpty,
           let doc = store.allNotebooks.first(where: {
               $0.id.caseInsensitiveCompare(documentId) == .orderedSame
           }) {
            let local = recordingTitles(of: doc, in: store)
            let adopted = imported.recordingTitles.filter { local[$0.key] == $0.value }
            RecordingTitleLedger.merge(
                adopted, in: store.syncBaselineDirectory, notebookId: documentId)
        }
        // 採用了匯入結果（沒有保住本機的剛改動）→ 帳本跟著更新，不然下一輪白匯出一次。
        if !preserved { ObjectLedger.save(merged, in: store.syncBaselineDirectory) }
        // 有保住使用者剛新增的東西就**不要**標成「已同步」：那些東西還沒進套件，下一輪要匯出。
        if !preserved {
            markWorkingCopyInSync(documentId: documentId, store: store)
        }
    }

    /// 匯出之後、匯入之前，使用者**新增或動過**的物件不能被匯入的結果蓋掉。
    ///
    /// 一輪同步是「匯出 → 等網路 → 匯入」，匯入是**整份取代**工作副本。等網路的那幾秒裡使用者
    /// 又插了一段錄音、移動了一張圖 —— 它們在剛匯出的套件裡還是舊的樣子，整份取代之後
    /// 新增的消失、移動過的**跳回原位**（使用者回報：畫布上的物件移不動，一同步就回去）。
    ///
    /// 做法：匯出當下記下每個物件的內容指紋。匯入時，工作副本上的物件
    /// - 不在名單、匯入結果也沒有 → 匯出之後新增的，補回去；
    /// - 指紋與匯出當下不同 → 匯出之後改過（移動、改字、改外觀），**用工作副本的版本**。
    ///
    /// **沒有名單就不動**（分不出「新增」與「被別台刪掉」，補回去會讓刪除復活）。
    static func preservingLocalChanges(
        _ imported: NotebookDocument, local: NotebookDocument?, exported: [String: Int]?
    ) -> (NotebookDocument, Bool) {
        guard let local else { return (imported, false) }
        guard let exported else {
            // 這一輪**沒有匯出**就匯入（例如套件時間較新）。沒有名單分不出新增／刪除，
            // 所以不補、不刪；但兩邊都有的物件若工作副本比較新，**保留工作副本的版本** ——
            // 否則第二次移動／旋轉後一同步，物件會跳回第一次移動的位置（使用者回報 iPad 定位失效）。
            guard local.lastModifiedDate > imported.lastModifiedDate else { return (imported, false) }
            return keepNewerLocalObjects(imported, local: local)
        }
        var merged = imported
        var preserved = false
        let current = ExportedObjectIds.fingerprints(of: local)
        func keep<T: Identifiable>(_ keyPath: WritableKeyPath<NotebookDocument, [T]?>) where T.ID == String {
            let localItems = Dictionary(
                (local[keyPath: keyPath] ?? []).map { ($0.id.lowercased(), $0) },
                uniquingKeysWith: { first, _ in first })
            var result: [T] = []
            var have = Set<String>()
            for item in imported[keyPath: keyPath] ?? [] {
                let id = item.id.lowercased()
                have.insert(id)
                // 匯出當下有、現在本機沒有 ⇒ 使用者在匯出之後刪掉的。匯入的是匯出當時的套件，
                // 照單全收會讓剛刪的東西「秒出現」。
                if exported[id] != nil, localItems[id] == nil {
                    preserved = true
                    continue
                }
                if let mine = localItems[id], let was = exported[id], current[id] != was {
                    result.append(mine)
                    preserved = true
                } else {
                    result.append(item)
                }
            }
            let added = (local[keyPath: keyPath] ?? []).filter {
                exported[$0.id.lowercased()] == nil && !have.contains($0.id.lowercased())
            }
            if !added.isEmpty { preserved = true }
            result.append(contentsOf: added)
            if !result.isEmpty || imported[keyPath: keyPath] != nil {
                merged[keyPath: keyPath] = result
            }
        }
        keep(\.attachments); keep(\.textAttachments); keep(\.tableAttachments)
        keep(\.shapeAttachments); keep(\.connectionAttachments); keep(\.linkAttachments)
        keep(\.model3DAttachments); keep(\.audioAttachments); keep(\.commentPins)
        keep(\.tapeAttachments); keep(\.stickyAnchors)

        // 形狀與連接線的外觀不在核心的物件模型裡 —— 匯入的版本只有幾何。
        // 沒被上面「使用者剛改過」那條路保住的，也要把本機的外觀帶回來。
        if var shapes = merged.shapeAttachments, let mine = local.shapeAttachments {
            let byId = Dictionary(mine.map { ($0.id.lowercased(), $0) }, uniquingKeysWith: { first, _ in first })
            for i in shapes.indices {
                if let m = byId[shapes[i].id.lowercased()] { shapes[i].adoptStyle(from: m) }
            }
            merged.shapeAttachments = shapes
        }
        if var links = merged.connectionAttachments, let mine = local.connectionAttachments {
            let byId = Dictionary(mine.map { ($0.id.lowercased(), $0) }, uniquingKeysWith: { first, _ in first })
            for i in links.indices {
                if let m = byId[links[i].id.lowercased()] { links[i].adoptStyle(from: m) }
            }
            merged.connectionAttachments = links
        }
        return (merged, preserved)
    }

    /// 沒有匯出名單時的保守合併：只替換「兩邊都有、而且內容不同」的物件為工作副本版本。
    static func keepNewerLocalObjects(
        _ imported: NotebookDocument, local: NotebookDocument
    ) -> (NotebookDocument, Bool) {
        var merged = imported
        var preserved = false
        let mine = ExportedObjectIds.fingerprints(of: local)
        let theirs = ExportedObjectIds.fingerprints(of: imported)
        func keep<T: Identifiable>(_ keyPath: WritableKeyPath<NotebookDocument, [T]?>) where T.ID == String {
            guard var items = merged[keyPath: keyPath] else { return }
            let localItems = Dictionary(
                (local[keyPath: keyPath] ?? []).map { ($0.id.lowercased(), $0) },
                uniquingKeysWith: { first, _ in first })
            for i in items.indices {
                let id = items[i].id.lowercased()
                if let m = localItems[id], mine[id] != theirs[id] {
                    items[i] = m
                    preserved = true
                }
            }
            merged[keyPath: keyPath] = items
        }
        keep(\.attachments); keep(\.textAttachments); keep(\.tableAttachments)
        keep(\.shapeAttachments); keep(\.connectionAttachments); keep(\.linkAttachments)
        keep(\.model3DAttachments); keep(\.audioAttachments); keep(\.commentPins)
        keep(\.tapeAttachments); keep(\.stickyAnchors)
        return (merged, preserved)
    }

    /// 匯入之後，工作副本與套件是**同一份內容**，不是「工作副本比較新」。
    ///
    /// 匯入會寫各頁的 `.drawing`、基準線等檔案，它們的修改時間都晚於套件 ——
    /// `workingCopyNeedsExport` 只看修改時間，就會判定「有新編輯、要匯出」，於是重建並上傳套件，
    /// 對方下載、匯入、再重建、再上傳……（兩台互相推，永遠安靜不下來）。
    /// 把套件的 manifest 時間更新到現在，讓下一輪看到的是「套件比較新或一樣新」。
    /// 只動時間，不動內容，所以不會被當成有變動而上傳。
    private static func markWorkingCopyInSync(documentId: String, store: SyncableNotebookStore) {
        let manifest = store.syncPackagesDirectory
            .appending(path: "\(documentId.lowercased()).padnote")
            .appending(path: "manifest.json")
        try? FileManager.default.setAttributes(
            [.modificationDate: Date()], ofItemAtPath: manifest.path)
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
                    report.failures[package.lastPathComponent] = L10n.f("sync_fail_unpack", error.localizedDescription)
                    continue
                }
            }

            // 檢查目錄內是否有 manifest.json
            let manifest = package.appending(path: "manifest.json")
            if !fm.fileExists(atPath: manifest.path) {
                let manifestPlaceholder = package.appending(path: ".manifest.json.icloud")
                if fm.fileExists(atPath: manifestPlaceholder.path) {
                    try? fm.startDownloadingUbiquitousItem(at: manifest)
                    report.failures[package.lastPathComponent] = L10n.t("sync_fail_icloud_downloading")
                    continue
                }
                // 損毀的空目錄或非套件檔案，清理避免日後每次同步都重複報「不是 .padnote 套件」
                try? fm.removeItem(at: package)
                report.failures[package.lastPathComponent] = L10n.t("sync_fail_no_manifest")
                continue
            }

            // 匯入**不能略過**：這一輪下載到的內容，除了這裡沒有別人會去匯入。
            // 焦點通道每輪很短，等它放鎖。
            guard let lockTicket = await NotebookLock.enter(
                normId, label: "full-import", waitMs: 10_000
            ) else {
                SyncLogger.logAsync(
                    "筆記本 \(normId.prefix(8))… 正在被焦點同步佔用，這一輪略過匯入",
                    source: .googleDrive
                )
                continue
            }
            defer { NotebookLock.leave(normId, ticket: lockTicket) }
            do {
                try await importOne(package, into: store, deviceId: deviceId, ownStrokes: ownStrokes)
                report.imported += 1
            } catch {
                report.failures[package.lastPathComponent] = L10n.errorText(error)
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
                    report.failures[package.lastPathComponent] = L10n.f("sync_fail_unpack", error.localizedDescription)
                    continue
                }
            }

            // 檢查目錄內是否有 manifest.json
            let manifest = package.appending(path: "manifest.json")
            if !fm.fileExists(atPath: manifest.path) {
                let manifestPlaceholder = package.appending(path: ".manifest.json.icloud")
                if fm.fileExists(atPath: manifestPlaceholder.path) {
                    try? fm.startDownloadingUbiquitousItem(at: manifest)
                    report.failures[package.lastPathComponent] = L10n.t("sync_fail_icloud_downloading")
                    continue
                }
                // 損毀的空目錄或非套件檔案，清理避免日後每次同步都重複報錯
                try? fm.removeItem(at: package)
                report.failures[package.lastPathComponent] = L10n.t("sync_fail_no_manifest")
                continue
            }

            do {
                try await importOne(package, into: store, deviceId: deviceId, ownStrokes: ownStrokes)
                report.imported += 1
            } catch {
                report.failures[package.lastPathComponent] = L10n.errorText(error)
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
                    report.failures[actualName] = L10n.f("sync_fail_unpack_cloud", error.localizedDescription)
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
        /// **事件發生的時刻**，不是「這一行被寫進清單的時刻」。
        public let timestamp: Date
        public let source: SyncSource
        public let message: String

        init(source: SyncSource, message: String, timestamp: Date = Date()) {
            self.source = source
            self.message = message
            self.timestamp = timestamp
        }
    }

    @Published public private(set) var entries: [LogEntry] = []

    public func log(_ message: String, source: SyncSource = .general, at timestamp: Date = Date()) {
        let entry = LogEntry(source: source, message: message, timestamp: timestamp)
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
        // 時間在**呼叫當下**取。原本是排進主執行緒之後才取 —— 主執行緒忙（同步、匯出）時，
        // 背景執行緒寫的幾十行日誌會一起被蓋上「它們終於輪到執行」的時間，
        // 於是日誌時間比實際發生的時間晚（實測差約四分鐘）。
        let happenedAt = Date()
        Task { @MainActor in
            SyncLogger.shared.log(message, source: source, at: happenedAt)
        }
    }
}
