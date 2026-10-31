//
//  LegacyInkCleanup.swift
//  Kairumo
//
//  ADR-0015 階段 4：一次性清掉舊版留在本機的「筆跡帳本」。
//
//  # 為什麼可以刪
//
//  階段 2 起，擦除／新增在編輯當下就以事件寫進套件的筆畫串流（`InkEventSink`），
//  階段 5 起所有筆刷都由自繪引擎算繪、筆畫有穩定 id。下面這些檔案都是舊版為了
//  「事後比對推論擦除」留下的副本與帳本，沒有東西會再讀它們：
//
//  - `<id>_p<n>.proink-ledger.json`        退休、已匯出、墓碑、PencilKit 世代表
//  - `<id>_p<n>.proink-suppressed.json`    被擦掉的別台專業筆畫
//  - `<id>_p<n>.own-exported.drawing`      上次匯出時自己的 PencilKit 筆畫
//  - `SyncBaseline/<id>_p<n>.erased-ink.json`  這台擦掉的 PencilKit 筆畫指紋
//
//  # 安全
//
//  - **只刪上面這幾種檔名**；`.drawing`（舊 PencilKit 筆畫）、`.proink.json`（自己的專業筆畫）、
//    `.proink-foreign.json`（別台的）都不碰 —— 那些是內容，不是帳本。
//  - 刪的是**本機**的檔案；雲端（Drive）資料不動。套件裡的筆畫與墓碑才是真相，
//    下一次同步會從它們重新讀回。
//  - 每個設定檔只跑一次（以 `UserDefaults` 記號控管），可重複呼叫、不會出錯。

import Foundation

enum LegacyInkCleanup {
    /// 已經清過的記號（放在設定檔專屬的 defaults）。
    static let doneKey = "kairumo.legacyInkCleanup.v1"

    /// 放在逐頁筆跡資料夾（`Drawings/`）的舊帳本。
    nonisolated static let drawingsSuffixes = [".proink-ledger.json", ".proink-suppressed.json", ".own-exported.drawing"]
    /// 放在同步基準資料夾（`SyncBaseline/`）的舊帳本。
    nonisolated static let baselineSuffixes = [".erased-ink.json"]

    struct Report: Equatable, Sendable {
        var files = 0
        var bytes: Int64 = 0
    }

    /// 清一次。`defaults` 記錄已完成，之後的呼叫直接回傳空報告。
    @discardableResult
    nonisolated static func runOnce(
        drawingsDirectory: URL, baselineDirectory: URL, defaults: ProfileDefaults = ProfileDefaults.current
    ) -> Report {
        guard !defaults.bool(forKey: doneKey) else { return Report() }
        let report = run(drawingsDirectory: drawingsDirectory, baselineDirectory: baselineDirectory)
        defaults.set(true, forKey: doneKey)
        return report
    }

    /// 不看記號、直接清（測試與手動整理用）。
    @discardableResult
    nonisolated static func run(drawingsDirectory: URL, baselineDirectory: URL) -> Report {
        var report = Report()
        for (directory, suffixes) in [(drawingsDirectory, drawingsSuffixes), (baselineDirectory, baselineSuffixes)] {
            report = merge(report, remove(suffixes: suffixes, in: directory))
        }
        return report
    }

    private nonisolated static func merge(_ a: Report, _ b: Report) -> Report {
        Report(files: a.files + b.files, bytes: a.bytes + b.bytes)
    }

    private nonisolated static func remove(suffixes: [String], in directory: URL) -> Report {
        let fm = FileManager.default
        var report = Report()
        for name in (try? fm.contentsOfDirectory(atPath: directory.path)) ?? [] where suffixes.contains(where: name.hasSuffix) {
            let url = directory.appending(path: name)
            let bytes = ((try? fm.attributesOfItem(atPath: url.path))?[.size] as? NSNumber)?.int64Value ?? 0
            if (try? fm.removeItem(at: url)) != nil {
                report.files += 1
                report.bytes += bytes
            }
        }
        return report
    }
}
