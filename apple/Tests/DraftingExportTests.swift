//
//  DraftingExportTests.swift
//  KairumoTests
//
//  匯出：SVG、DXF、STL、OBJ、GLB、USDZ，以及玻璃盒展開的一格。
//  3D 檔案用 Model I/O 真的讀回來 —— 檔案能被系統的 3D 管線載入、尺寸對，才算匯出成功。
//

import ModelIO
import XCTest
@testable import Kairumo

@MainActor
final class DraftingExportTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("kairumo-export-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    /// 50 × 40 × 30 mm 的長方體（紙上毫米；一個頁面單位是 1/每毫米單位數 毫米）。
    private func box() -> (FfiSolidProfile, Float) {
        let u = draftUnitsPerMm()
        return (solidPresetProfile(name: "rect", w: 50 * u, h: 40 * u)!, 30 * u)
    }

    private func write(_ format: String) throws -> URL {
        let (profile, depth) = box()
        let data = try XCTUnwrap(solidExport3d(profile: profile, depth: depth, format: format, mmPerUnit: 1 / draftUnitsPerMm()))
        let url = dir.appendingPathComponent("solid.\(format)")
        try Data(data).write(to: url)
        return url
    }

    // MARK: 3D

    func testEveryFormatIsOffered() {
        XCTAssertEqual(solidExportFormats(), ["stl", "obj", "glb", "usdz"])
    }

    func testTheUsdzLoadsInModelIOWithTheRightSizeInMetres() throws {
        let url = try write("usdz")
        XCTAssertTrue(MDLAsset.canImportFileExtension("usdz"))
        let asset = MDLAsset(url: url)
        XCTAssertGreaterThan(asset.count, 0, "USDZ 讀不進 Model I/O")
        let box = asset.boundingBox
        // 公尺：50 × 40 × 30 mm。
        XCTAssertEqual(box.maxBounds.x - box.minBounds.x, 0.050, accuracy: 1e-4)
        XCTAssertEqual(box.maxBounds.y - box.minBounds.y, 0.040, accuracy: 1e-4)
        XCTAssertEqual(box.maxBounds.z - box.minBounds.z, 0.030, accuracy: 1e-4)
        // 裡面是一個網格、12 個三角形。
        let meshes = asset.childObjects(of: MDLMesh.self) as? [MDLMesh] ?? []
        XCTAssertEqual(meshes.count, 1)
        let triangles = meshes.first?.submeshes?.compactMap { ($0 as? MDLSubmesh)?.indexCount }.reduce(0, +) ?? 0
        XCTAssertEqual(triangles, 36, "長方體 12 個三角形 = 36 個索引")
    }

    func testTheStlAndObjLoadInModelIOInMillimetres() throws {
        for format in ["stl", "obj"] {
            let url = try write(format)
            XCTAssertTrue(MDLAsset.canImportFileExtension(format))
            let asset = MDLAsset(url: url)
            XCTAssertGreaterThan(asset.count, 0, "\(format) 讀不進 Model I/O")
            let box = asset.boundingBox
            XCTAssertEqual(box.maxBounds.x - box.minBounds.x, 50, accuracy: 0.01, format)
            XCTAssertEqual(box.maxBounds.y - box.minBounds.y, 40, accuracy: 0.01, format)
            XCTAssertEqual(box.maxBounds.z - box.minBounds.z, 30, accuracy: 0.01, format)
        }
    }

    func testTheGlbHasTheBinaryContainerAndTheModelSizeInMetres() throws {
        let data = try Data(contentsOf: try write("glb"))
        XCTAssertEqual(String(data: data.prefix(4), encoding: .ascii), "glTF")
        XCTAssertEqual(data.subdata(in: 4 ..< 8).withUnsafeBytes { $0.load(as: UInt32.self) }, 2)
        XCTAssertEqual(Int(data.subdata(in: 8 ..< 12).withUnsafeBytes { $0.load(as: UInt32.self) }), data.count)
        let jsonLength = Int(data.subdata(in: 12 ..< 16).withUnsafeBytes { $0.load(as: UInt32.self) })
        let json = try JSONSerialization.jsonObject(with: data.subdata(in: 20 ..< 20 + jsonLength)) as? [String: Any]
        let accessors = json?["accessors"] as? [[String: Any]]
        let max = accessors?.first?["max"] as? [Double]
        XCTAssertEqual(max?[0] ?? 0, 0.050, accuracy: 1e-4)
        XCTAssertEqual(max?[1] ?? 0, 0.040, accuracy: 1e-4)
    }

    func testAShapeWithHolesExportsToAUsdzModelIOCanLoad() throws {
        let u = draftUnitsPerMm()
        let plate = try XCTUnwrap(solidPresetProfile(name: "plate_holes", w: 80 * u, h: 60 * u))
        let data = try XCTUnwrap(solidExport3d(profile: plate, depth: 10 * u, format: "usdz", mmPerUnit: 1 / draftUnitsPerMm()))
        let url = dir.appendingPathComponent("plate.usdz")
        try Data(data).write(to: url)
        let asset = MDLAsset(url: url)
        XCTAssertGreaterThan(asset.count, 0)
        XCTAssertEqual(asset.boundingBox.maxBounds.x - asset.boundingBox.minBounds.x, 0.080, accuracy: 1e-4)
    }

    func testBadInputIsRefused() {
        let (profile, depth) = box()
        XCTAssertNil(solidExport3d(profile: profile, depth: depth, format: "step", mmPerUnit: 0.25))
        XCTAssertNil(solidExport3d(profile: profile, depth: 0, format: "stl", mmPerUnit: 0.25))
    }

    // MARK: 玻璃盒

    func testTheGlassBoxFramesUnfoldAndShareOneBounds() throws {
        let (profile, depth) = box()
        let bounds = try XCTUnwrap(solidGlassBounds(profile: profile, depth: depth, thirdAngle: true, yawDeg: 30, pitchDeg: 25))
        XCTAssertEqual(bounds.count, 4)
        let closed = try XCTUnwrap(solidGlassFrame(profile: profile, depth: depth, thirdAngle: true, t: 0, yawDeg: 30, pitchDeg: 25))
        let flat = try XCTUnwrap(solidGlassFrame(profile: profile, depth: depth, thirdAngle: true, t: 1, yawDeg: 30, pitchDeg: 25))
        XCTAssertEqual(closed.lines.count, flat.lines.count)
        XCTAssertTrue(zip(closed.lines, flat.lines).contains { abs($0.ax - $1.ax) > 1 }, "展開前後的線要不一樣")
        // 長方體沒有隱藏線；U 形有（右視圖裡凹槽的底看不到）。
        let u = draftUnitsPerMm()
        let uShape = try XCTUnwrap(solidPresetProfile(name: "u_shape", w: 50 * u, h: 40 * u))
        let uFlat = try XCTUnwrap(solidGlassFrame(profile: uShape, depth: depth, thirdAngle: true, t: 1, yawDeg: 30, pitchDeg: 25))
        for kind in [FfiGlassKind.frame, .object, .visible, .hidden, .projection] {
            XCTAssertTrue(uFlat.lines.contains { $0.kind == kind }, "\(kind)")
        }
        // 第一角法也算得出來，而且與第三角法不同。
        let first = try XCTUnwrap(solidGlassFrame(profile: profile, depth: depth, thirdAngle: false, t: 1, yawDeg: 30, pitchDeg: 25))
        XCTAssertTrue(zip(first.lines, flat.lines).contains { abs($0.ax - $1.ax) > 1 || abs($0.ay - $1.ay) > 1 })
    }

    // MARK: 2D

    func testTheSvgAndDxfHoldThePageLinesInMillimetres() {
        let u = draftUnitsPerMm()
        let strokes = [
            FfiExportStroke(points: [FfiPoint(x: 0, y: 0), FfiPoint(x: 100 * u, y: 0)], layer: 3, lineType: 0, width: 2.6, colorHex: "#111827"),
            FfiExportStroke(points: [FfiPoint(x: 0, y: 10 * u), FfiPoint(x: 100 * u, y: 10 * u)], layer: 3, lineType: 1, width: 1.4, colorHex: "#111827"),
        ]
        let svg = draftExportSvg(strokes: strokes, pageWidth: 800, pageHeight: 1132)
        XCTAssertTrue(svg.contains("width=\"210mm\""))
        XCTAssertTrue(svg.contains("points=\"0,0 100,0\""))
        XCTAssertEqual(svg.components(separatedBy: "stroke-dasharray").count - 1, 1, "只有隱藏線有虛線圖樣")
        let dxf = draftExportDxf(strokes: strokes, pageWidth: 800, pageHeight: 1132)
        XCTAssertTrue(dxf.contains("AC1009"))
        XCTAssertEqual(dxf.components(separatedBy: "0\nPOLYLINE\n").count - 1, 2)
        XCTAssertTrue(dxf.hasSuffix("0\nEOF\n"))
    }
}
