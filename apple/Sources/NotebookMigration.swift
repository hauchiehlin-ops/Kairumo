//
//  NotebookMigration.swift
//  Kairumo
//
//  把既有的 Apple 筆記資料遷移成核心的 `.padnote` 套件（工作包 WP4c）。
//
//  # 這是整個 WP4 裡唯一會碰到使用者真實資料的一步
//
//  所以規則寫死在這裡，不留彈性：
//
//  1. **原始檔案一律不覆蓋、不刪除。** 遷移只「讀」`notebooks_v1.json` 與
//     `Drawings/`，產物寫到另一個目錄。使用者的資料在遷移前後位元組相同。
//  2. **動手前先備份。** 備份先做完才開始寫任何東西，而不是「出錯了再說」。
//  3. **每一本都要驗過才算數。** 匯出完立刻讀回來逐點比對座標與筆畫數，
//     對不上的那一本就把套件刪掉並記成失敗 —— 不能留下一份看起來成功、
//     其實內容不對的檔案，那比明確失敗更危險。
//  4. **一本失敗不影響其餘。** 逐本獨立處理，報告裡逐本交代結果。
//  5. **可重入。** 重跑不會產生重複，也不會白做已經遷好的。
//  6. **可回滾。** 從備份還原，並清掉遷移產物。
//

import Foundation
import PencilKit
import UIKit

/// 取在地化字串並依序填入 `%1@`、`%2@`…
///
/// 錯誤訊息原本是寫死的繁體中文。英文或日文使用者出錯時看到中文，
/// 等於這個訊息對他完全沒有作用 —— 而錯誤訊息正是最需要看得懂的時候。
func L(_ key: String, _ arguments: String...) -> String {
    // 不標 @MainActor：錯誤訊息會在背景執行緒組成（遷移跑在背景），
    // 而字串表是唯讀的靜態資料，從哪個執行緒讀都一樣。
    var text = LocalizationManager.shared.localizedUnsafe(key)
    if arguments.count == 1 {
        text = text.replacingOccurrences(of: "%@", with: arguments[0])
    }
    for (index, value) in arguments.enumerated() {
        text = text.replacingOccurrences(of: "%\(index + 1)@", with: value)
    }
    return text
}

public enum NotebookMigration {

    // MARK: - 裝置識別碼

    private static let deviceIdKey = "kairumo.core.deviceId"

    /// 這台裝置穩定不變的 32 位元識別碼。
    ///
    /// 它會進 `.padnote` 的 oplog 檔名，用來保證兩台裝置永遠不會寫同一個檔 ——
    /// 撞號的後果是兩邊的編輯互相覆蓋，而且在單機測試時完全不會發生。
    ///
    /// 先用 `identifierForVendor`；取不到（極少數情況會是 nil）就自己產一個
    /// 並存起來。**存起來這一步不能省**：每次啟動換一個 id 會讓同一台裝置
    /// 在檔案裡看起來像很多台。
    public static var deviceId: UInt32 {
        if let saved = UserDefaults.standard.object(forKey: deviceIdKey) as? Int {
            return UInt32(truncatingIfNeeded: saved)
        }
        let seed = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        var hash: UInt32 = 2_166_136_261 // FNV-1a
        for byte in seed.utf8 {
            hash ^= UInt32(byte)
            hash = hash &* 16_777_619
        }
        UserDefaults.standard.set(Int(hash), forKey: deviceIdKey)
        return hash
    }

    // MARK: - 結果

    /// 單一本筆記的遷移結果。
    public enum Outcome: Equatable {
        case migrated(strokeCount: Int)
        /// 內容自上次遷移後沒變，這次不用重做。
        case skippedUnchanged
        /// 失敗的原因要能直接給使用者看，不是「錯誤代碼 3」。
        case failed(reason: String)
    }

    public struct Report {
        public var backupPath: URL?
        public var outcomes: [String: Outcome] = [:]
        public init() {}

        public var migratedCount: Int { outcomes.values.filter { if case .migrated = $0 { return true }; return false }.count }
        public var skippedCount: Int { outcomes.values.filter { $0 == .skippedUnchanged }.count }
        public var failedCount: Int { outcomes.values.filter { if case .failed = $0 { return true }; return false }.count }
        public var allSucceeded: Bool { failedCount == 0 }
    }

    // MARK: - 遷移狀態

    /// 已經遷好的一本筆記。
    ///
    /// `fingerprint` 不能只用 `lastModifiedDate`：手繪是存到獨立的 `.drawing`
    /// 檔的，改了手繪並不會更新那個日期。只看日期的話，使用者畫了一整頁之後
    /// 重跑遷移會被判定成「沒變」而跳過。
    public struct Entry: Codable, Equatable {
        public var packageName: String
        public var fingerprint: String
        public var pageCount: Int
        public var strokeCount: Int
    }

    public struct State: Codable, Equatable {
        public var formatVersion: Int = 1
        public var entries: [String: Entry] = [:]
        public init() {}
    }

    // MARK: - 路徑

    public static func packagesDirectory(in root: URL) -> URL {
        root.appending(path: "Packages", directoryHint: .isDirectory)
    }

    public static func statePath(in root: URL) -> URL {
        packagesDirectory(in: root).appending(path: "migration-state.json")
    }

    /// 遷移會讀、但永遠不會寫的那些檔案。備份與「原檔未被更動」的檢查都看這份清單。
    public static func sourceItems(in root: URL) -> [URL] {
        [
            root.appending(path: "notebooks_v1.json"),
            root.appending(path: "folders_v1.json"),
            root.appending(path: "recordings_v1.json"),
            root.appending(path: "Drawings", directoryHint: .isDirectory),
            root.appending(path: "Attachments", directoryHint: .isDirectory)
        ]
    }

    public static func loadState(in root: URL) -> State {
        guard let data = try? Data(contentsOf: statePath(in: root)),
              let state = try? JSONDecoder().decode(State.self, from: data) else {
            return State()
        }
        return state
    }

    public static func saveState(_ state: State, in root: URL) throws {
        try FileManager.default.createDirectory(
            at: packagesDirectory(in: root), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(state)
        try data.write(to: statePath(in: root), options: .atomic)
    }

    // MARK: - 備份

    /// 把原始資料複製到備份目錄，回傳備份位置。
    ///
    /// 在寫入任何產物**之前**完成。這不是防禦性的客套 —— 遷移過程若在中途
    /// 因為當機或空間不足停下來，使用者要有一條回得去的路。
    @discardableResult
    public static func backup(root: URL, at date: Date = Date()) throws -> URL {
        let stamp = ISO8601DateFormatter().string(from: date)
            .replacingOccurrences(of: ":", with: "-")
        let dir = root.appending(path: "MigrationBackup-\(stamp)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        for item in sourceItems(in: root) where FileManager.default.fileExists(atPath: item.path) {
            let dest = dir.appending(path: item.lastPathComponent)
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.copyItem(at: item, to: dest)
        }
        return dir
    }

    /// 從備份還原，並清掉遷移產物。
    ///
    /// 還原是「覆蓋回去」而不是「合併」：合併會讓使用者拿到一份半新半舊、
    /// 誰也說不清楚狀態的資料。
    public static func rollback(root: URL, from backupDir: URL) throws {
        for item in sourceItems(in: root) {
            let source = backupDir.appending(path: item.lastPathComponent)
            guard FileManager.default.fileExists(atPath: source.path) else { continue }
            try? FileManager.default.removeItem(at: item)
            try FileManager.default.copyItem(at: source, to: item)
        }
        try? FileManager.default.removeItem(at: packagesDirectory(in: root))
    }

    // MARK: - 遷移

    /// 把每一本筆記寫成 `.padnote` 套件。
    ///
    /// - Parameters:
    ///   - documents: 要遷移的筆記。
    ///   - root: 資料根目錄（正式執行時就是 App 的 Documents）。
    ///   - drawingLoader: 取某本某頁的手繪內容。抽成閉包是為了能在測試裡餵假資料。
    ///   - imageLoader: 取圖片附件的位元組；取不到就回 `nil`，該張圖會被略過。
    ///   - deviceId: 這台裝置穩定不變的識別碼。
    ///   - makeBackup: 是否先備份。正式路徑永遠是 `true`。
    public static func migrate(
        documents: [NotebookDocument],
        root: URL,
        deviceId: UInt32,
        drawingLoader: (String, Int) -> PKDrawing,
        imageLoader: (String) -> Data? = { _ in nil },
        makeBackup: Bool = true
    ) -> Report {
        var report = Report()

        if makeBackup {
            do {
                report.backupPath = try backup(root: root)
            } catch {
                // 備份失敗就整個停手。沒有退路的遷移不該開始。
                for doc in documents {
                    report.outcomes[doc.id] = .failed(
                        reason: L("err_backup_failed", error.localizedDescription))
                }
                return report
            }
        }

        var state = loadState(in: root)
        let packagesDir = packagesDirectory(in: root)
        try? FileManager.default.createDirectory(at: packagesDir, withIntermediateDirectories: true)

        for doc in documents {
            let pageCount = max(doc.pageCount, 1)
            let drawings = (0..<pageCount).map { drawingLoader(doc.id, $0) }
            let fingerprint = self.fingerprint(of: doc, drawings: drawings)
            let packageName = "\(doc.id).padnote"
            let packageURL = packagesDir.appending(path: packageName)

            if let existing = state.entries[doc.id],
               existing.fingerprint == fingerprint,
               FileManager.default.fileExists(atPath: packageURL.path) {
                report.outcomes[doc.id] = .skippedUnchanged
                continue
            }

            // 重跑時先清掉舊套件：核心會把 op 追加上去，留著舊的會讓內容疊起來。
            try? FileManager.default.removeItem(at: packageURL)

            do {
                var images: [String: Data] = [:]
                for attachment in doc.attachments ?? [] {
                    if let bytes = imageLoader(attachment.fileName) {
                        images[attachment.fileName] = bytes
                    }
                }

                let summary = try NotebookPackageBridge.export(
                    document: doc, drawings: drawings, imageData: images,
                    to: packageURL, deviceId: deviceId)

                try verify(packageURL: packageURL, against: drawings, deviceId: deviceId)

                state.entries[doc.id] = Entry(
                    packageName: packageName,
                    fingerprint: fingerprint,
                    pageCount: summary.pageCount,
                    strokeCount: summary.strokeCount
                )
                report.outcomes[doc.id] = .migrated(strokeCount: summary.strokeCount)
            } catch {
                // 驗不過的套件必須刪掉。留著一份看起來成功、其實內容不對的檔案，
                // 比明確失敗更危險 —— 使用者會信任它。
                try? FileManager.default.removeItem(at: packageURL)
                state.entries.removeValue(forKey: doc.id)
                report.outcomes[doc.id] = .failed(reason: describe(error))
            }
        }

        try? saveState(state, in: root)
        return report
    }

    // MARK: - 驗證

    public enum VerificationError: LocalizedError {
        case pageCountMismatch(expected: Int, got: Int)
        case strokeCountMismatch(page: Int, expected: Int, got: Int)
        case pointCountMismatch(page: Int, stroke: Int, expected: Int, got: Int)
        case coordinateDrift(page: Int, stroke: Int, point: Int)

        public var errorDescription: String? {
            switch self {
            // 錯誤訊息也要在地化：英文或日文使用者出錯時看到中文，
            // 等於這個訊息對他完全沒有作用。
            case .pageCountMismatch(let e, let g):
                return L("err_page_count_mismatch", "\(e)", "\(g)")
            case .strokeCountMismatch(let p, let e, let g):
                return L("err_stroke_count_mismatch", "\(p + 1)", "\(e)", "\(g)")
            case .pointCountMismatch(let p, let s, let e, let g):
                return L("err_stroke_count_mismatch", "\(p + 1)", "\(e)", "\(g)")
                    + "（\(s + 1)）"
            case .coordinateDrift(let p, let s, _):
                return L("err_coordinate_drift", "\(p + 1)", "\(s + 1)")
            }
        }
    }

    /// 座標容差。
    ///
    /// 核心存的 x / y 是 f32，Swift 端是 CGFloat（double），所以往返一定會有
    /// 最後幾位的差。0.01pt 遠小於任何看得見的偏移，又足以擋下真正的錯位。
    public static let coordinateTolerance: CGFloat = 0.01

    /// 把套件讀回來與原稿逐點比對。對不上就丟錯。
    public static func verify(packageURL: URL, against drawings: [PKDrawing], deviceId: UInt32) throws {
        let readBack = try NotebookPackageBridge.drawings(
            fromPackageAt: packageURL, deviceId: deviceId)

        guard readBack.count == drawings.count else {
            throw VerificationError.pageCountMismatch(
                expected: drawings.count, got: readBack.count)
        }

        for (pageIndex, original) in drawings.enumerated() {
            let restored = readBack[pageIndex]
            guard restored.strokes.count == original.strokes.count else {
                throw VerificationError.strokeCountMismatch(
                    page: pageIndex,
                    expected: original.strokes.count,
                    got: restored.strokes.count)
            }

            for (strokeIndex, originalStroke) in original.strokes.enumerated() {
                let originalPath = originalStroke.path
                let restoredPath = restored.strokes[strokeIndex].path
                guard restoredPath.count == originalPath.count else {
                    throw VerificationError.pointCountMismatch(
                        page: pageIndex, stroke: strokeIndex,
                        expected: originalPath.count, got: restoredPath.count)
                }

                for i in 0..<originalPath.count {
                    let a = originalStroke.transform.apply(to: originalPath[i].location)
                    let b = restoredPath[i].location
                    if abs(a.x - b.x) > coordinateTolerance || abs(a.y - b.y) > coordinateTolerance {
                        throw VerificationError.coordinateDrift(
                            page: pageIndex, stroke: strokeIndex, point: i)
                    }
                }
            }
        }
    }

    // MARK: - 私有

    /// 內容指紋：修改時間**加上**每頁的筆畫數。
    ///
    /// 只看修改時間會漏掉手繪的變動（手繪存在獨立的檔案，不更新那個日期）。
    public static func fingerprint(of doc: NotebookDocument, drawings: [PKDrawing]) -> String {
        let strokes = drawings.map { String($0.strokes.count) }.joined(separator: ",")
        let attachments = (doc.attachments?.count ?? 0)
        let texts = (doc.textAttachments?.count ?? 0)
        return "\(doc.lastModifiedDate.timeIntervalSince1970)|\(doc.pageCount)|\(strokes)|\(attachments)|\(texts)"
    }

    private static func describe(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? String(describing: error)
    }
}

private extension CGAffineTransform {
    func apply(to point: CGPoint) -> CGPoint { point.applying(self) }
}
