//
//  ICloudSyncFolder.swift
//  Kairumo
//
//  iCloud Drive 當同步資料夾（S-19）。
//
//  # 為什麼不需要另一個 CloudProvider
//
//  iCloud 的 ubiquity container 就是一個檔案系統路徑，核心的
//  `LocalFolderProvider` 直接就能用。真正的差別只有一個：**檔案可能還沒下載**。
//  iCloud 會把沒下載的檔案換成 `.原檔名.icloud` 佔位檔，原檔案不存在。
//  核心那邊已經認得佔位檔（回 `NotMaterialized`），這裡負責另一半 ——
//  叫 iCloud 去下載，然後等它下載完。
//
//  # 為什麼要等
//
//  `startDownloadingUbiquitousItem` 只是**排隊**，不是同步下載。呼叫完立刻去讀
//  檔案還是讀不到，而且錯誤與「檔案不存在」長得一模一樣。不等的話，
//  症狀是「同步好像少了一些東西，再按一次又好了」。
//

import Foundation

public enum ICloudSyncFolder {

    public enum Failure: Error {
        /// 使用者沒登入 iCloud，或這個 App 的 iCloud 功能沒開。
        case unavailable
        /// 下載等太久。
        case downloadTimedOut(String)
        case io(String)
    }

    /// 這個 App 的 iCloud 容器根目錄。
    ///
    /// **第一次呼叫會觸碰網路，不要放在主執行緒。** `url(forUbiquityContainerIdentifier:)`
    /// 在容器還沒建立時會同步等待，UI 會卡住。
    public static func containerURL() -> URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents", isDirectory: true)
    }

    /// 容器可不可用。使用者沒登入 iCloud 時是 nil。
    public static var isAvailable: Bool { containerURL() != nil }

    /// 把某個路徑底下還沒下載的東西全部抓下來，並等到好為止。
    ///
    /// `timeout` 到了就回 `downloadTimedOut`，不要無限等 —— 使用者可能
    /// 根本沒有網路，而一個永遠不回來的同步比失敗更難查。
    public static func materialize(
        relativePath: String,
        timeout: TimeInterval = 60
    ) async throws {
        guard let root = containerURL() else { throw Failure.unavailable }
        let target = root.appendingPathComponent(relativePath, isDirectory: true)

        let placeholders = try findPlaceholders(under: target)
        guard !placeholders.isEmpty else { return }

        for placeholder in placeholders {
            // 對**邏輯檔名**呼叫，不是對佔位檔本身。
            do {
                try FileManager.default.startDownloadingUbiquitousItem(at: logicalURL(of: placeholder))
            } catch {
                throw Failure.io(error.localizedDescription)
            }
        }

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let remaining = try findPlaceholders(under: target)
            if remaining.isEmpty { return }
            // 沒有可靠的完成通知，只能輪詢。0.5 秒是折衷：太短會空轉，
            // 太長會讓「其實早就下載好了」也要等。
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        throw Failure.downloadTimedOut(relativePath)
    }

    /// 找出某個目錄底下所有的 iCloud 佔位檔。
    private static func findPlaceholders(under directory: URL) throws -> [URL] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: directory.path) else { return [] }
        guard
            let walker = fm.enumerator(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey],
                // 佔位檔是隱藏檔（開頭是點）—— 不加這個旗標就一個也看不到，
                // 於是這個函式永遠回空陣列、永遠「沒有東西要下載」。
                options: []
            )
        else { return [] }

        var out: [URL] = []
        for case let url as URL in walker where isPlaceholder(url) {
            out.append(url)
        }
        return out
    }

    /// 是不是 iCloud 佔位檔（`.原檔名.icloud`）。
    ///
    /// 只看副檔名是不夠的：使用者自己建的 `notes.icloud` 不該被當成佔位檔。
    /// 判斷規則與核心的 `logical_name()` 一致 —— 兩邊不一致的話，
    /// 一邊在等下載、另一邊以為已經好了。
    static func isPlaceholder(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        return name.hasPrefix(".") && name.hasSuffix(".icloud") && name.count > ".".count + ".icloud".count
    }

    /// 佔位檔 → 它代表的那個真實檔案。
    static func logicalURL(of placeholder: URL) -> URL {
        let name = placeholder.lastPathComponent
        guard isPlaceholder(placeholder) else { return placeholder }
        let inner = String(name.dropFirst().dropLast(".icloud".count))
        return placeholder.deletingLastPathComponent().appending(path: inner)
    }
}
