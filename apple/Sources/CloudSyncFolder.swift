//
//  CloudSyncFolder.swift
//  Kairumo
//
//  用使用者自己的雲端硬碟同步（決策 D3 選項 A）。
//
//  # 我們不碰網路
//
//  同步由 iCloud Drive / Google Drive / Dropbox / Syncthing / NAS 負責 ——
//  使用者挑一個資料夾，兩台裝置指到同一個地方就好。沒有帳號、沒有伺服器、
//  沒有我們要維運的東西，這也是隱私權政策上寫的那件事。
//
//  # 為什麼「複製檔案」就夠了
//
//  `.padnote` 套件裡的每個檔案都是 append-only，而且檔名帶著寫入它的
//  `device_id`。同一個檔名只會有一台裝置在寫，所以兩邊都有時，較長的那份
//  必然是較新的超集。同步因此退化成聯集複製 —— 不需要合併，也不需要仲裁。
//
//  判斷「複製哪些、往哪邊」的策略在核心（`plan_folder_sync`），與 Android
//  共用同一份。這裡只做 I/O。
//

import Foundation

enum CloudSyncFolder {

    private static let bookmarkKey = "kairumo.sync.folderBookmark"

    // MARK: - 資料夾位置

    /// 建立書籤時要帶的選項。
    ///
    /// Mac 版是沙盒 App（Mac App Store 的硬性要求）。沙盒裡的書籤**必須**是
    /// security-scoped 的，否則下次啟動時書籤解得開、卻沒有存取權 ——
    /// 而且不會有任何錯誤，同步只是靜靜地什麼都沒搬。
    ///
    /// iOS 沒有這個選項（帶了會擲出例外），那裡的一般書籤本來就夠用。
    static var bookmarkCreationOptions: URL.BookmarkCreationOptions {
        #if targetEnvironment(macCatalyst)
        return [.withSecurityScope]
        #else
        return []
        #endif
    }

    /// 解析書籤時要帶的選項。必須與建立時對稱，不對稱就解不開。
    static var bookmarkResolutionOptions: URL.BookmarkResolutionOptions {
        #if targetEnvironment(macCatalyst)
        return [.withSecurityScope]
        #else
        return []
        #endif
    }

    /// 使用者選定的同步資料夾。尚未設定時為 `nil`。
    ///
    /// 用書籤而不是路徑字串：使用者選的可能是雲端硬碟或別的 App 的容器，
    /// 路徑會變，而且下次啟動時沒有存取權。
    static func resolveFolder() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
        var stale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: bookmarkResolutionOptions,
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) else { return nil }

        // 書籤過期（資料夾被搬過）時重存一份，否則下次啟動又要使用者重選。
        //
        // 重存前要先取得存取權：沙盒裡對一個沒有 scope 的 URL 建書籤會失敗，
        // 於是過期的書籤永遠不會被更新。
        if stale {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            if let refreshed = try? url.bookmarkData(options: bookmarkCreationOptions) {
                UserDefaults.standard.set(refreshed, forKey: bookmarkKey)
            }
        }
        return url
    }

    /// 記住使用者選的資料夾。
    static func setFolder(_ url: URL) throws {
        let data = try url.bookmarkData(options: bookmarkCreationOptions)
        UserDefaults.standard.set(data, forKey: bookmarkKey)
    }

    static func clearFolder() {
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
    }

    // MARK: - 檔案清單

    /// 列出套件目錄下的所有檔案（相對路徑）。
    ///
    /// 一定要**遞迴**：`doc/ops/` 與 `ink/` 底下的東西才是真正要同步的內容，
    /// 只列單層會得到一份看起來成功、其實什麼都沒同步的計畫。
    static func entries(in packageURL: URL) -> [SyncFileEntry] {
        let fm = FileManager.default
        guard let walker = fm.enumerator(
            at: packageURL,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: []
        ) else { return [] }

        let baseStandardized = packageURL.resolvingSymlinksInPath().standardizedFileURL.path
        let prefix = baseStandardized.hasSuffix("/") ? baseStandardized : baseStandardized + "/"

        var out: [SyncFileEntry] = []
        for case let url as URL in walker {
            let resolvedUrl = url.resolvingSymlinksInPath().standardizedFileURL
            let last = resolvedUrl.lastPathComponent
            if ICloudSyncFolder.isPlaceholder(url) {
                let logical = ICloudSyncFolder.logicalURL(of: url).resolvingSymlinksInPath().standardizedFileURL
                try? fm.startDownloadingUbiquitousItem(at: logical)
                let relative = logical.path.replacingOccurrences(of: prefix, with: "")
                out.append(SyncFileEntry(path: relative, size: 0))
                continue
            }
            if last.hasPrefix(".") { continue }

            let values = try? resolvedUrl.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard values?.isRegularFile == true else { continue }
            let relative = resolvedUrl.path.replacingOccurrences(of: prefix, with: "")
            out.append(SyncFileEntry(path: relative, size: UInt64(values?.fileSize ?? 0)))
        }
        return out
    }

    // MARK: - 同步

    struct Result {
        var uploaded: [String] = []
        var downloaded: [String] = []
        /// 需要使用者注意的檔案（目前只有 manifest.json）。
        var needsAttention: [String] = []
        var failures: [String: String] = [:]

        var isNoOp: Bool { uploaded.isEmpty && downloaded.isEmpty }
    }

    /// 把本機套件與雲端資料夾裡的同名套件對齊。
    ///
    /// - Parameters:
    ///   - localPackage: 本機的 `.padnote` 目錄。
    ///   - remoteFolder: 使用者選的同步資料夾。套件會以同名子目錄存在其中。
    @discardableResult
    static func sync(localPackage: URL, into remoteFolder: URL) -> Result {
        let fm = FileManager.default
        let remotePackage = remoteFolder.appendingPathComponent(localPackage.lastPathComponent)

        var result = Result()
        do {
            try fm.createDirectory(at: remotePackage, withIntermediateDirectories: true)
        } catch {
            result.failures["<資料夾>"] = error.localizedDescription
            return result
        }

        let plan = planFolderSync(
            local: entries(in: localPackage),
            remote: entries(in: remotePackage)
        )
        result.needsAttention = plan.needsAttention

        for relative in plan.upload {
            copy(relative, from: localPackage, to: remotePackage, into: &result, uploading: true)
        }
        for relative in plan.download {
            copy(relative, from: remotePackage, to: localPackage, into: &result, uploading: false)
        }
        return result
    }

    private static func copy(
        _ relative: String,
        from source: URL,
        to destination: URL,
        into result: inout Result,
        uploading: Bool
    ) {
        let fm = FileManager.default
        let src = source.appendingPathComponent(relative)
        let dst = destination.appendingPathComponent(relative)

        // 若來源尚未自 iCloud 下載，觸發下載並短暫等待
        let placeholder = src.deletingLastPathComponent().appendingPathComponent(".\(src.lastPathComponent).icloud")
        if fm.fileExists(atPath: placeholder.path) && !fm.fileExists(atPath: src.path) {
            try? fm.startDownloadingUbiquitousItem(at: src)
            for _ in 0..<6 {
                if fm.fileExists(atPath: src.path) { break }
                Thread.sleep(forTimeInterval: 0.2)
            }
        }

        do {
            try fm.createDirectory(
                at: dst.deletingLastPathComponent(), withIntermediateDirectories: true)
            // 先讀再原子寫，而不是 copyItem：目的檔可能已存在（較舊的版本），
            // 而 copyItem 遇到既有檔案會直接失敗。
            let bytes = try Data(contentsOf: src)
            try bytes.write(to: dst, options: .atomic)
            if uploading { result.uploaded.append(relative) } else { result.downloaded.append(relative) }
        } catch {
            if fm.fileExists(atPath: placeholder.path) {
                result.failures[relative] = "檔案正在從 iCloud 雲端下載中，請稍候重試"
            } else {
                result.failures[relative] = error.localizedDescription
            }
        }
    }
}
