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
    func useParentFolder(_ selectedFolder: URL, movingFrom source: URL) async throws -> URL {
        let parentScoped = selectedFolder.startAccessingSecurityScopedResource()
        defer {
            if parentScoped { selectedFolder.stopAccessingSecurityScopedResource() }
        }

        let destination: URL
        if selectedFolder.lastPathComponent == Self.defaultFolderName {
            destination = selectedFolder
        } else {
            destination = selectedFolder.appending(path: Self.defaultFolderName, directoryHint: .isDirectory)
        }

        let sourceStandard = source.standardizedFileURL
        let destinationStandard = destination.standardizedFileURL
        do {
            try await Task.detached(priority: .utility) {
                let fm = FileManager.default
                try fm.createDirectory(at: destination, withIntermediateDirectories: true)
                if sourceStandard != destinationStandard {
                    try Self.validateDestination(destination, source: source)
                    try Self.copyDirectoryContents(from: source, to: destination)
                }
                try Self.ensureManifest(in: destination)
            }.value
        } catch let error as LocationError {
            throw error
        } catch {
            throw LocationError.cannotMoveLibrary(error.localizedDescription)
        }

        let bookmark: Data
        do {
            bookmark = try destination.bookmarkData(options: Self.bookmarkCreationOptions)
        } catch {
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
