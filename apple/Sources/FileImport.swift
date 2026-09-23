import Foundation
import UniformTypeIdentifiers

/// 從本機檔案匯入東西到筆記頁（Apple）。
///
/// # 為什麼是共用的
///
/// 插入工具原本只給得出**內建的東西** —— 3D 模型只有六個固定幾何體、
/// 插入圖片只通得到相簿、插入錄音只列得出 App 自己錄的那些。使用者手上
/// 那個檔案（一張掃描、一個模型、一段別的 App 錄的音）進不來，而那才是
/// 他真正想放進筆記的東西。
///
/// 每個插入工具各寫一份「挑檔案 → 檢查 → 存起來」的話，第七個工具出現時
/// 會再抄一次，而抄漏的那一次（忘了開安全範圍存取、忘了先問大小就整個讀
/// 進記憶體）要等使用者掉資料或 App 被系統殺掉才發現。這支檔案就是
/// Android 端 `FileImport.kt` 的對應物 —— 兩邊同一套流程、同一套錯誤。
///
/// 「收不收」的判斷在核心（`importCheck`）：同一個檔案在 iPad 上收得進去、
/// 在 Android 手機上被拒絕，而且錯誤訊息還不一樣，是使用者完全無法理解的
/// 行為。
///
/// 整支掛在主執行緒上：`NotebookStore` 與 `AudioRecorderManager` 都是
/// `@MainActor`，而匯入本來就是使用者在畫面上按下去之後的那一步。真正會
/// 花時間的是 `Data(contentsOf:)`，但那發生在「已經確定收得下」之後 ——
/// 先問大小就是為了讓這一步不會變成卡住畫面的那一下。
@MainActor
enum FileImport {

    /// 匯入的結果。`errorKey` 非空時其餘欄位無意義。
    struct Outcome {
        /// 存進附件目錄之後的檔名。
        var storedName: String = ""
        /// 給使用者看的名字（原檔名去掉副檔名）。
        var displayName: String = ""
        /// 正規化後的副檔名（小寫、不含點）。
        var fileExtension: String = ""
        /// 失敗原因的**語系鍵**。成功時是空字串。
        var errorKey: String = ""

        var succeeded: Bool { errorKey.isEmpty }
    }

    /// 檔案挑選器收哪些型別。清單來自核心（`importExtensions`）——
    /// 「這個檔案在 iPad 上挑得到、在手機上挑不到」是使用者完全無法理解
    /// 的行為。
    ///
    /// 全部對不上時退回 `.data`：讓使用者至少挑得到東西，核心的
    /// `importCheck` 會在挑完之後擋下不對的格式。把整個挑選器灰掉的話，
    /// 他會以為功能壞了。
    static func allowedTypes(for slot: FfiImportSlot) -> [UTType] {
        let types = importExtensions(slot: slot).compactMap {
            UTType(filenameExtension: $0)
        }
        return types.isEmpty ? [.data] : types
    }

    /// 檔案要收到哪裡。
    ///
    /// 匯入的音訊**不能**跟其他附件一起放進 `Attachments/` —— 播放與
    /// 同步兩條路都是照「錄音」在解析路徑的（`recordingFileURL`），
    /// 放錯地方的症狀是「按了播放沒有反應」，而且沒有任何錯誤訊息。
    enum Destination {
        case attachments
        case recordings
    }

    /// 把 `url` 指到的檔案收進 App 的附件目錄。
    ///
    /// **先問大小再決定要不要讀。** 讀進來才發現太大的話，手機上那一下
    /// 配置就可能直接被系統殺掉 —— 而那看起來像 App 當掉，不像「檔案太大」。
    static func take(
        url: URL, slot: FfiImportSlot, into destination: Destination = .attachments
    ) -> Outcome {
        // **安全範圍存取**：從檔案 App 挑來的 URL 在沙箱外，不開存取權的話
        // `Data(contentsOf:)` 會回 permission denied，而那個錯誤看起來像
        // 檔案壞了。
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
            .flatMap { UInt64($0) } ?? 0
        let verdict = importCheck(
            slot: slot, fileName: url.lastPathComponent, sizeBytes: size)
        guard verdict.accepted else {
            return Outcome(errorKey: verdict.reasonKey)
        }
        guard let data = try? Data(contentsOf: url) else {
            return Outcome(errorKey: "import_failed_read")
        }
        let saved: String?
        switch destination {
        case .attachments:
            saved = NotebookStore.shared.saveImportedFile(
                data: data, extension: verdict.extension)
        case .recordings:
            saved = saveIntoRecordings(data: data, extension: verdict.extension)
        }
        guard let saved else {
            return Outcome(errorKey: "import_failed_read")
        }
        return Outcome(
            storedName: saved,
            displayName: url.deletingPathExtension().lastPathComponent,
            fileExtension: verdict.extension)
    }

    /// `fileImporter` 的結果一路走到 `Outcome`。
    ///
    /// 挑選器自己失敗（使用者取消不算）也要有語系鍵 —— 不然畫面上是一片
    /// 什麼都沒發生。
    static func take(
        result: Result<[URL], Error>, slot: FfiImportSlot,
        into destination: Destination = .attachments
    ) -> Outcome? {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return nil }
            return take(url: url, slot: slot, into: destination)
        case .failure:
            return Outcome(errorKey: "import_failed_read")
        }
    }

    /// 匯入的音訊寫進錄音目錄，讓它與 App 自己錄的那些**完全一樣**：
    /// 同一份清單看得到、同一條路徑播得出來、同一套遷移搬得進套件。
    private static func saveIntoRecordings(data: Data, extension ext: String) -> String? {
        let clean = ext.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        let name = clean.isEmpty ? "imp_\(UUID().uuidString)" : "imp_\(UUID().uuidString).\(clean)"
        let url = AudioRecorderManager.shared.recordingsDirectory.appending(path: name)
        do {
            // `.atomic`：寫到一半當機留下的是沒有檔，不是一個讀得到但
            // 壞掉的檔 —— 後者會讓使用者看到一張播不出來的卡片。
            try data.write(to: url, options: .atomic)
            return name
        } catch {
            return nil
        }
    }
}
