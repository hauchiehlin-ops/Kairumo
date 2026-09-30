//
//  DocumentStorageLocation.swift
//  Kairumo
//
//  使用者文件庫的位置。這和 CloudSyncFolder 不同：前者是持續讀寫的主要
//  資料來源，後者只是跨裝置交換 CRDT 套件的同步端點。
//

import Combine
import Foundation

private let documentLibraryManifestFileName = ".kairumo-library.json"

@MainActor
final class DocumentStorageLocation: ObservableObject {
    static let shared = DocumentStorageLocation()

    static let defaultFolderName = "Kairumo Doc"
    static let manifestFileName = documentLibraryManifestFileName

    private static let bookmarkKey = "kairumo.documents.libraryBookmark.v1"
    private static let migrationKey = "kairumo.documents.defaultFolderMigration.v1"

    struct Manifest: Codable, Equatable {
        let schemaVersion: Int
        let libraryId: String
        let createdAt: Date
    }

    enum LocationError: LocalizedError {
        case cannotCreateFolder(String)
        case cannotMoveLibrary(String)
        case nestedLibraryLocation
        case destinationContainsAnotherLibrary(String)
        case cannotRememberFolder

        var errorDescription: String? {
            switch self {
            case let .cannotCreateFolder(path):
                return "Cannot create the Kairumo document folder at \(path)."
            case let .cannotMoveLibrary(message):
                return "Kairumo could not move the document library: \(message)"
            case .nestedLibraryLocation:
                return "Choose a folder outside the current Kairumo Doc folder."
            case let .destinationContainsAnotherLibrary(path):
                return "\(path) already contains another Kairumo library. Choose an empty folder so existing documents are not overwritten."
            case .cannotRememberFolder:
                return "Kairumo could not retain access to the selected folder. Please choose it again."
            }
        }
    }

    /// 搬移進度，給畫面顯示。
    struct MoveProgress: Sendable, Equatable {
        enum Phase: Sendable, Equatable {
            case waitingForSync, copying, verifying, removingOld
        }

        var phase: Phase
        var copiedFiles = 0
        var totalFiles = 0
    }

    typealias ProgressHandler = @Sendable (MoveProgress) -> Void

    /// 這個位置（或它任何一層上層）是不是被 iCloud 雲碟同步。
    ///
    /// 要看**上層**：`~/Documents` 開了「桌面與文件」同步時，`~/Documents` 自己回報
    /// `isUbiquitousItem == true`，但底下剛建的資料夾可能還回 `nil`。
    nonisolated static func isICloudSynced(_ url: URL) -> Bool {
        let fm = FileManager.default
        var probe = url.standardizedFileURL
        while probe.pathComponents.count > 1 {
            if probe.path.contains("/Library/Mobile Documents/") { return true }
            if fm.fileExists(atPath: probe.path),
               (try? probe.resourceValues(forKeys: [.isUbiquitousItemKey]))?.isUbiquitousItem == true
            {
                return true
            }
            probe.deleteLastPathComponent()
        }
        return false
    }

    @Published private(set) var rootURL: URL
    @Published private(set) var isUserSelected: Bool

    /// Mac App Store 審查要求 Mac 的主要使用者文件不能只留在隱藏 container。
    /// iPhone / iPad 的 Documents 會透過 Files App 暴露，因此內建預設值可用；
    /// Catalyst 第一次啟動則一定讓使用者透過系統文件選擇器挑位置。
    var requiresMacSelection: Bool {
        #if targetEnvironment(macCatalyst)
        return !isUserSelected
        #else
        return false
        #endif
    }

    var displayPath: String {
        rootURL.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }

    private var scopedURL: URL?
    private var scopedAccessActive = false

    private init() {
        let legacyDocuments = Self.containerDocumentsDirectory
        let defaultRoot = legacyDocuments.appending(path: Self.defaultFolderName, directoryHint: .isDirectory)

        if let bookmarked = Self.resolveBookmark() {
            rootURL = bookmarked
            isUserSelected = true
            scopedURL = bookmarked
            scopedAccessActive = bookmarked.startAccessingSecurityScopedResource()
            try? FileManager.default.createDirectory(
                at: bookmarked, withIntermediateDirectories: true)
            _ = try? Self.ensureManifest(in: bookmarked)
        } else {
            rootURL = defaultRoot
            isUserSelected = false
            Self.migrateLegacyContainerIfNeeded(from: legacyDocuments, to: defaultRoot)
            try? FileManager.default.createDirectory(
                at: defaultRoot, withIntermediateDirectories: true)
            _ = try? Self.ensureManifest(in: defaultRoot)
        }
    }

    /// 使用者挑的是「父資料夾」。若他直接挑到既有的 Kairumo Doc，就不再
    /// 套一層；其他位置一律建立預設名稱，讓 Finder / Files 裡清楚可辨識。
    ///
    /// 流程：複製（可取消、回報進度）→ **驗證**（每個來源檔都在目的地、大小一樣）→ 切換書籤 →
    /// 舊的資料庫確認是同一份才移除（以前只複製不處理，舊資料永遠留在隱藏的容器裡）。
    /// 任何一步失敗或被取消，舊的資料庫原封不動；這次新建的目的地會清掉。
    func useParentFolder(
        _ selectedFolder: URL,
        movingFrom source: URL,
        progress: ProgressHandler? = nil
    ) async throws -> URL {
        let parentScoped = selectedFolder.startAccessingSecurityScopedResource()
        defer {
            if parentScoped { selectedFolder.stopAccessingSecurityScopedResource() }
        }

        let destination: URL
        if selectedFolder.lastPathComponent == Self.defaultFolderName {
            destination = selectedFolder
        } else {
            destination = selectedFolder.appending(
                path: Self.defaultFolderName, directoryHint: .isDirectory)
        }

        let sourceStandard = source.standardizedFileURL
        let destinationStandard = destination.standardizedFileURL
        let isSameFolder = sourceStandard == destinationStandard
        let destinationExisted = FileManager.default.fileExists(atPath: destination.path)

        do {
            let work = Task.detached(priority: .utility) {
                let fm = FileManager.default
                try fm.createDirectory(at: destination, withIntermediateDirectories: true)
                if !isSameFolder {
                    try Self.validateDestination(destination, source: source)
                    try Self.copyLibrary(from: source, to: destination, progress: progress)
                    progress?(MoveProgress(phase: .verifying))
                    try Self.verifyCopy(from: source, to: destination)
                }
                try Self.ensureManifest(in: destination)
            }
            try await withTaskCancellationHandler {
                try await work.value
            } onCancel: {
                work.cancel()
            }
        } catch {
            // 失敗或取消：這次新建的目的地不留殘骸；原本就存在的不動。
            if !destinationExisted { try? FileManager.default.removeItem(at: destination) }
            if error is CancellationError { throw error }
            if let error = error as? LocationError { throw error }
            throw LocationError.cannotMoveLibrary(error.localizedDescription)
        }

        let bookmark: Data
        do {
            bookmark = try destination.bookmarkData(options: Self.bookmarkCreationOptions)
        } catch {
            if !destinationExisted && !isSameFolder {
                try? FileManager.default.removeItem(at: destination)
            }
            throw LocationError.cannotRememberFolder
        }

        if scopedAccessActive, let scopedURL {
            scopedURL.stopAccessingSecurityScopedResource()
        }
        UserDefaults.standard.set(bookmark, forKey: Self.bookmarkKey)
        rootURL = destination
        isUserSelected = true
        scopedURL = destination
        scopedAccessActive = destination.startAccessingSecurityScopedResource()

        // 已經切過去了：舊的那份若確定是**同一個資料庫**（文庫識別碼相同），就移除。
        // 只做這一種確定的情況；對不上的（使用者自己放的資料夾）一律不碰。
        if !isSameFolder {
            progress?(MoveProgress(phase: .removingOld))
            let old = source
            let new = destination
            await Task.detached(priority: .utility) {
                Self.removeOldLibraryIfSame(old, as: new)
            }.value
        }
        return destination
    }

    // MARK: - Bookmark

    private static var bookmarkCreationOptions: URL.BookmarkCreationOptions {
        #if targetEnvironment(macCatalyst)
        return [.withSecurityScope]
        #else
        // iOS / iPadOS 的 document picker 也會交回 security-scoped URL；
        // minimal bookmark 可在下次啟動重建該授權，不把裝置絕對路徑同步出去。
        return [.minimalBookmark]
        #endif
    }

    private static var bookmarkResolutionOptions: URL.BookmarkResolutionOptions {
        #if targetEnvironment(macCatalyst)
        return [.withSecurityScope]
        #else
        return [.withoutUI]
        #endif
    }

    private static func resolveBookmark() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
        var stale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: bookmarkResolutionOptions,
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) else { return nil }

        if stale {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            if let refreshed = try? url.bookmarkData(options: bookmarkCreationOptions) {
                UserDefaults.standard.set(refreshed, forKey: bookmarkKey)
            }
        }
        return url
    }

    // MARK: - Library migration

    static var containerDocumentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// 舊版把資料直接散在 Documents 根目錄。升級時先複製到名稱固定、可由
    /// 使用者辨認的資料夾；保留舊檔，直到新位置完整可讀，不做破壞性搬移。
    private static func migrateLegacyContainerIfNeeded(from source: URL, to destination: URL) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: migrationKey) else { return }

        let fm = FileManager.default
        guard fm.fileExists(atPath: source.appending(path: "notebooks_v1.json", directoryHint: .notDirectory).path)
        else {
            defaults.set(true, forKey: migrationKey)
            return
        }
        guard !fm.fileExists(atPath: destination.appending(path: "notebooks_v1.json", directoryHint: .notDirectory).path)
        else {
            defaults.set(true, forKey: migrationKey)
            return
        }

        do {
            try fm.createDirectory(at: destination, withIntermediateDirectories: true)
            let children = try fm.contentsOfDirectory(
                at: source, includingPropertiesForKeys: [.isDirectoryKey])
            for child in children where child.lastPathComponent != defaultFolderName {
                try copyItemReplacingIfNeeded(
                    from: child,
                    to: destination.appending(path: child.lastPathComponent, directoryHint: .notDirectory))
            }
            defaults.set(true, forKey: migrationKey)
        } catch {
            StartupLogger.log("文件庫預設位置遷移失敗：\(error.localizedDescription)")
        }
    }

    nonisolated private static func validateDestination(_ destination: URL, source: URL) throws {
        let fm = FileManager.default
        let sourcePath = source.standardizedFileURL.path
        let destinationPath = destination.standardizedFileURL.path
        if sourcePath != destinationPath,
           destinationPath.hasPrefix(sourcePath + "/") || sourcePath.hasPrefix(destinationPath + "/")
        {
            throw LocationError.nestedLibraryLocation
        }
        let destinationIndex = destination.appending(path: "notebooks_v1.json", directoryHint: .notDirectory)
        guard fm.fileExists(atPath: destinationIndex.path) else { return }

        let sourceManifest = try? readManifest(in: source)
        let destinationManifest = try? readManifest(in: destination)
        guard sourceManifest?.libraryId == destinationManifest?.libraryId,
              sourceManifest != nil
        else {
            throw LocationError.destinationContainsAnotherLibrary(destination.path)
        }
    }

    nonisolated static func copyDirectoryContents(from source: URL, to destination: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: destination, withIntermediateDirectories: true)
        let children = try fm.contentsOfDirectory(
            at: source, includingPropertiesForKeys: [.isDirectoryKey])
        for child in children {
            let target = destination.appending(path: child.lastPathComponent, directoryHint: .notDirectory)
            try copyItemReplacingIfNeeded(from: child, to: target)
        }
    }

    /// 資料庫裡所有一般檔案：相對路徑與大小。
    nonisolated private static func libraryFiles(in root: URL) -> [(relative: String, size: Int64)] {
        let fm = FileManager.default
        guard let walker = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: []
        ) else { return [] }
        let prefix = root.standardizedFileURL.path + "/"
        var files: [(String, Int64)] = []
        for case let url as URL in walker {
            guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  values.isRegularFile == true
            else { continue }
            let path = url.standardizedFileURL.path
            guard path.hasPrefix(prefix) else { continue }
            files.append((String(path.dropFirst(prefix.count)), Int64(values.fileSize ?? 0)))
        }
        return files
    }

    /// 逐檔複製，回報進度，每一檔之間檢查取消。已經在目的地且大小一樣的檔案跳過 ——
    /// 所以中斷後重來不必從頭複製。
    nonisolated static func copyLibrary(
        from source: URL, to destination: URL, progress: ProgressHandler?
    ) throws {
        let fm = FileManager.default
        let files = libraryFiles(in: source)
        let total = files.count
        progress?(MoveProgress(phase: .copying, copiedFiles: 0, totalFiles: total))
        for (index, file) in files.enumerated() {
            try Task.checkCancellation()
            let from = source.appending(path: file.relative, directoryHint: .notDirectory)
            let to = destination.appending(path: file.relative, directoryHint: .notDirectory)
            let existing = (try? to.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
            if existing.map(Int64.init) != file.size {
                try fm.createDirectory(
                    at: to.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? fm.removeItem(at: to)
                try fm.copyItem(at: from, to: to)
            }
            if index % 25 == 0 || index == total - 1 {
                progress?(MoveProgress(phase: .copying, copiedFiles: index + 1, totalFiles: total))
            }
        }
    }

    /// 來源的每個檔案都要在目的地、大小一樣。少一個就不准切換。
    nonisolated static func verifyCopy(from source: URL, to destination: URL) throws {
        let fm = FileManager.default
        for file in libraryFiles(in: source) {
            try Task.checkCancellation()
            let to = destination.appending(path: file.relative, directoryHint: .notDirectory)
            guard fm.fileExists(atPath: to.path),
                  Int64((try? to.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? -1) == file.size
            else {
                throw LocationError.cannotMoveLibrary("複製後驗證失敗：\(file.relative)")
            }
        }
    }

    /// 清空資料庫根目錄底下的東西（「重設本機資料」用），但保留 `keeping` 裡的名字。
    ///
    /// Mac 先丟垃圾桶（還能救回來），丟不了才直接刪；iOS 沒有垃圾桶可用，直接刪。
    /// 回傳 (移除幾項, 失敗幾項)。**只動根目錄的直接子項**，不會往外爬。
    @discardableResult
    nonisolated static func clearLibraryContents(
        at root: URL, keeping: Set<String> = []
    ) -> (removed: Int, failed: Int) {
        let fm = FileManager.default
        let children = (try? fm.contentsOfDirectory(atPath: root.path)) ?? []
        var removed = 0
        var failed = 0
        for name in children where !keeping.contains(name) && name != ".DS_Store" {
            let url = root.appending(path: name, directoryHint: .notDirectory)
            var done = false
            #if targetEnvironment(macCatalyst)
            done = (try? fm.trashItem(at: url, resultingItemURL: nil)) != nil
            #endif
            if !done { done = (try? fm.removeItem(at: url)) != nil }
            if done { removed += 1 } else { failed += 1 }
        }
        return (removed, failed)
    }

    /// 舊資料庫確定與新的是同一份（文庫識別碼相同）才移除。先丟垃圾桶，丟不了才直接刪。
    @discardableResult
    nonisolated static func removeOldLibraryIfSame(_ old: URL, as new: URL) -> Bool {
        let fm = FileManager.default
        guard fm.fileExists(atPath: old.path),
              let oldManifest = try? readManifest(in: old),
              let newManifest = try? readManifest(in: new),
              oldManifest.libraryId == newManifest.libraryId
        else { return false }
        do {
            try fm.trashItem(at: old, resultingItemURL: nil)
            return true
        } catch {
            return (try? fm.removeItem(at: old)) != nil
        }
    }

    nonisolated private static func copyItemReplacingIfNeeded(from source: URL, to destination: URL) throws {
        let values = try source.resourceValues(forKeys: [.isDirectoryKey])
        let fm = FileManager.default
        if values.isDirectory == true {
            try fm.createDirectory(at: destination, withIntermediateDirectories: true)
            for child in try fm.contentsOfDirectory(
                at: source, includingPropertiesForKeys: [.isDirectoryKey])
            {
                try copyItemReplacingIfNeeded(
                    from: child,
                    to: destination.appending(path: child.lastPathComponent, directoryHint: .notDirectory))
            }
        } else {
            try? fm.removeItem(at: destination)
            try fm.copyItem(at: source, to: destination)
        }
    }

    @discardableResult
    nonisolated static func ensureManifest(in root: URL) throws -> Manifest {
        if let existing = try? readManifest(in: root) { return existing }
        let manifest = Manifest(
            schemaVersion: 1,
            libraryId: UUID().uuidString.lowercased(),
            createdAt: Date()
        )
        let data = try JSONEncoder().encode(manifest)
        try data.write(
            to: root.appending(path: documentLibraryManifestFileName, directoryHint: .notDirectory), options: .atomic)
        return manifest
    }

    nonisolated static func readManifest(in root: URL) throws -> Manifest {
        let data = try Data(contentsOf: root.appending(path: documentLibraryManifestFileName, directoryHint: .notDirectory))
        return try JSONDecoder().decode(Manifest.self, from: data)
    }
}
