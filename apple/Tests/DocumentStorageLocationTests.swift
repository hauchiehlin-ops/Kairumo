//
//  DocumentStorageLocationTests.swift
//  KairumoTests
//

import XCTest
@testable import Kairumo

@MainActor
final class DocumentStorageLocationTests: XCTestCase {
    private var temporaryRoot: URL!

    override func setUpWithError() throws {
        temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("kairumo-storage-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryRoot)
    }

    func testDefaultLibraryNameIsUserVisibleAndStable() {
        XCTAssertEqual(DocumentStorageLocation.defaultFolderName, "Kairumo Doc")
    }

    func testMovingLibraryCopiesMetadataPackagesAndRecordings() throws {
        let source = temporaryRoot.appendingPathComponent("source", isDirectory: true)
        let destination = temporaryRoot.appendingPathComponent("destination", isDirectory: true)
        try FileManager.default.createDirectory(
            at: source.appendingPathComponent("Packages/note.padnote/doc/ops"),
            withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: source.appendingPathComponent("Kairumo Record"),
            withIntermediateDirectories: true)
        try Data("[]".utf8).write(to: source.appendingPathComponent("notebooks_v1.json"))
        try Data("operation".utf8).write(
            to: source.appendingPathComponent("Packages/note.padnote/doc/ops/a.oplog"))
        try Data("audio".utf8).write(
            to: source.appendingPathComponent("Kairumo Record/legacy.m4a"))

        try DocumentStorageLocation.copyDirectoryContents(from: source, to: destination)

        XCTAssertEqual(
            try String(contentsOf: destination.appendingPathComponent("notebooks_v1.json")),
            "[]")
        XCTAssertEqual(
            try String(contentsOf: destination.appendingPathComponent(
                "Packages/note.padnote/doc/ops/a.oplog")),
            "operation")
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: destination.appendingPathComponent("Kairumo Record/legacy.m4a").path))
    }

    func testLibraryManifestKeepsStableIdentityAfterCopy() throws {
        let source = temporaryRoot.appendingPathComponent("source", isDirectory: true)
        let destination = temporaryRoot.appendingPathComponent("destination", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        let original = try DocumentStorageLocation.ensureManifest(in: source)

        try DocumentStorageLocation.copyDirectoryContents(from: source, to: destination)
        let copied = try DocumentStorageLocation.readManifest(in: destination)

        XCTAssertEqual(copied.libraryId, original.libraryId)
        XCTAssertEqual(copied.schemaVersion, 1)
    }
}
