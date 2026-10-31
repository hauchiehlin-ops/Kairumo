//
//  LegacyInkCleanupTests.swift
//  KairumoTests
//
//  ADR-0015 階段 4：一次性清舊帳本，只刪帳本、不碰筆畫內容（見 LegacyInkCleanup.swift）。
//

import XCTest
@testable import Kairumo

final class LegacyInkCleanupTests: XCTestCase {
    private var drawings: URL!
    private var baseline: URL!

    override func setUpWithError() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "legacy-ink-\(UUID().uuidString)")
        drawings = root.appending(path: "Drawings")
        baseline = root.appending(path: "SyncBaseline")
        try FileManager.default.createDirectory(at: drawings, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: baseline, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: drawings.deletingLastPathComponent())
    }

    private func touch(_ dir: URL, _ name: String) {
        FileManager.default.createFile(atPath: dir.appending(path: name).path, contents: Data("x".utf8))
    }

    private func exists(_ dir: URL, _ name: String) -> Bool {
        FileManager.default.fileExists(atPath: dir.appending(path: name).path)
    }

    func testRemovesLedgersButKeepsStrokeContent() {
        for name in ["nb_p0.proink-ledger.json", "nb_p1.proink-suppressed.json", "nb_p0.own-exported.drawing"] {
            touch(drawings, name)
        }
        touch(baseline, "nb_p0.erased-ink.json")
        // 內容：不能動。
        for name in ["nb_p0.drawing", "nb_p0.proink.json", "nb_p0.proink-foreign.json"] { touch(drawings, name) }

        let report = LegacyInkCleanup.run(drawingsDirectory: drawings, baselineDirectory: baseline)

        XCTAssertEqual(report.files, 4)
        XCTAssertFalse(exists(drawings, "nb_p0.proink-ledger.json"))
        XCTAssertFalse(exists(drawings, "nb_p1.proink-suppressed.json"))
        XCTAssertFalse(exists(drawings, "nb_p0.own-exported.drawing"))
        XCTAssertFalse(exists(baseline, "nb_p0.erased-ink.json"))
        XCTAssertTrue(exists(drawings, "nb_p0.drawing"))
        XCTAssertTrue(exists(drawings, "nb_p0.proink.json"))
        XCTAssertTrue(exists(drawings, "nb_p0.proink-foreign.json"))
    }

    func testRunsOnlyOncePerProfile() throws {
        let defaults = ProfileDefaults(profileId: "legacy-ink-\(UUID().uuidString)")
        touch(drawings, "nb_p0.proink-ledger.json")
        XCTAssertEqual(LegacyInkCleanup.runOnce(drawingsDirectory: drawings, baselineDirectory: baseline, defaults: defaults).files, 1)

        // 之後新寫的帳本（新版不再產生，但保險起見）不會被反覆清。
        touch(drawings, "nb_p0.proink-ledger.json")
        XCTAssertEqual(LegacyInkCleanup.runOnce(drawingsDirectory: drawings, baselineDirectory: baseline, defaults: defaults).files, 0)
        XCTAssertTrue(exists(drawings, "nb_p0.proink-ledger.json"))
    }
}
