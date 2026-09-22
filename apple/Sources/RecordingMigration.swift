//
//  RecordingMigration.swift
//  Kairumo
//
//  把舊的 `Kairumo Record/*.m4a` 搬進筆記本套件（R5）。
//
//  # 為什麼要搬
//
//  那個目錄在**套件外面**，而套件才是同步的單位 —— 所以躺在那裡的錄音
//  從來沒有被同步過。使用者不會知道「舊的不同步、新的會同步」，
//  他只會發現有些錄音在另一台看得到、有些看不到，然後不信任整個同步。
//
//  # 為什麼要轉檔而不是原樣搬進去
//
//  同步只認 `media/audio/*.opus`（`padnote-storage` 的 `audio_files()`），
//  而且 Android 端錄的就是 Opus。原樣搬進去等於讓兩種格式永久並存，
//  每一個讀取端都要記得處理兩種 —— 而遲早會有一個忘記。
//
//  轉檔是 AAC→PCM→Opus 的二次有損轉碼。語音上可以接受，
//  真正要防的是**遷移把原檔弄丟**：所以驗證成功之後原檔是**移到
//  `migrated/`**，不是刪除。
//

import AVFoundation
import Foundation

@MainActor
enum RecordingMigration {

    private static let doneKey = "kairumo.recordings.migratedToPackages.v1"

    struct Report {
        var migrated: Int = 0
        var skipped: Int = 0
        var failed: [String] = []
    }

    /// 已經跑過就不再跑。
    ///
    /// 用一個旗標而不是「看看還有沒有 m4a」——後者會讓**失敗的那幾個**
    /// 每次開 App 都重試一次，而失敗通常是檔案本身壞了，重試一百次也一樣。
    static var isDone: Bool {
        UserDefaults.standard.bool(forKey: doneKey)
    }

    /// 跑一次遷移。**會解碼與編碼整段音訊，要在背景執行緒呼叫。**
    @discardableResult
    static func runIfNeeded(store: NotebookStore) async -> Report {
        guard !isDone else { return Report() }
        let report = await migrate(store: store)
        UserDefaults.standard.set(true, forKey: doneKey)
        return report
    }

    static func migrate(store: NotebookStore) async -> Report {
        var report = Report()
        let fm = FileManager.default
        let legacyDir = AudioRecorderManager.shared.recordingsDirectory
        let archiveDir = legacyDir.appendingPathComponent("migrated", isDirectory: true)

        let records = store.recordings
        for record in records {
            let source = legacyDir.appending(path: record.fileName)
            guard fm.fileExists(atPath: source.path),
                  source.pathExtension.lowercased() != "opus"
            else {
                report.skipped += 1
                continue
            }

            // 沒有所屬筆記本的錄音落在收件匣 —— 它必須有個套件可以住，
            // 否則就回到「在套件外面、不會被同步」的原點。
            let notebookId = record.linkedNotebookId ?? store.recordingInbox().id
            let notebookTitle = store.notebooks
                .first { $0.id.caseInsensitiveCompare(notebookId) == .orderedSame }?
                .displayTitle() ?? notebookId

            guard let pcm = decodeToCorePcm(url: source) else {
                report.failed.append(record.fileName)
                continue
            }

            // 套件要先存在（`packageSession` 會建）。
            guard store.packageSession(forNotebookId: notebookId, title: notebookTitle) != nil
            else {
                report.failed.append(record.fileName)
                continue
            }
            let target = store.corePackagesDirectory
                .appending(path: "\(notebookId.lowercased()).padnote")
                .appending(path: "media/audio")
                .appending(path: "\(UUID().uuidString.lowercased()).opus")

            guard audioEncodePcmToOpus(pcm16kMono: pcm, outPath: target.path) != nil else {
                report.failed.append(record.fileName)
                continue
            }

            // 轉出來的檔案要真的讀得回來才算成功。只看「寫檔沒報錯」的話，
            // 一個 0 位元組的檔也會被當成遷移完成，而原檔就被歸檔了。
            guard let check = audioDecoderOpen(path: target.path),
                  check.info().durationUs > 0
            else {
                try? fm.removeItem(at: target)
                report.failed.append(record.fileName)
                continue
            }

            store.replaceRecordingFile(
                recordingId: record.id, fileName: target.lastPathComponent,
                notebookId: notebookId)

            // **原檔不刪，移到 migrated/。** 二次轉碼萬一有問題，
            // 使用者還拿得回原本那一份。
            try? fm.createDirectory(at: archiveDir, withIntermediateDirectories: true)
            let archived = archiveDir.appending(path: record.fileName)
            try? fm.removeItem(at: archived)
            try? fm.moveItem(at: source, to: archived)
            report.migrated += 1
        }

        if report.migrated > 0 {
            store.refreshRecordings()
        }
        return report
    }

    /// 把舊音檔解成核心要的 16 kHz 單聲道 f32。
    ///
    /// 直接用 `AudioPCMDecoder` —— 轉錄早就需要同一個格式了，
    /// 再寫一份只會多一個會漂移的實作（而且兩份對取樣率邊界的處理
    /// 一旦分岔，症狀是「有些檔案轉完之後聲音怪怪的」）。
    private static func decodeToCorePcm(url: URL) -> [Float]? {
        try? AudioPCMDecoder.decodeTo16kMono(url: url)
    }
}
