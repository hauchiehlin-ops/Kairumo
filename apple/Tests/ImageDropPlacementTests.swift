//
//  ImageDropPlacementTests.swift
//  KairumoTests
//
//  拖進來的圖片要放在哪、放多大（工作項 S-68）。
//
//  **拖放這個手勢本身在這裡驗不到** —— 它要兩個 App 同時在畫面上（分割
//  畫面或幕前調度），模擬器上驅動得動但自動化不了。能驗的是落點與尺寸的
//  算法，而那正是會出事的地方：算錯的症狀是「圖有一半在頁面外」，畫面上
//  看得見，匯出與列印時卻被裁掉。
//
//  Android 端的對照組是 `ImageDropPlacementTest.kt`，數字刻意一致。
//

import CoreGraphics
import XCTest
@testable import Kairumo

final class ImageDropPlacementTests: XCTestCase {

    private let page = CGSize(width: 800, height: 1132)

    func testTheImageIsCentredOnWhereYouLetGo() {
        let frame = ImageDropPlacement.frame(
            dropPoint: CGPoint(x: 400, y: 500),
            imageSize: CGSize(width: 1000, height: 1000),
            pageSize: page)
        XCTAssertEqual(frame.midX, 400, accuracy: 0.5)
        XCTAssertEqual(frame.midY, 500, accuracy: 0.5)
    }

    func testAPhoneCameraPhotoIsScaledDown() {
        // 4000 像素寬的照片照原尺寸放會蓋掉整個頁面。
        let frame = ImageDropPlacement.frame(
            dropPoint: CGPoint(x: 400, y: 500),
            imageSize: CGSize(width: 4032, height: 3024),
            pageSize: page)
        XCTAssertEqual(frame.width, ImageDropPlacement.preferredWidth, accuracy: 0.5)
        // 比例要留著 —— 拉變形比太大還糟。
        XCTAssertEqual(frame.height / frame.width, 3024.0 / 4032.0, accuracy: 0.01)
    }

    func testATinyIconIsNotBlownUp() {
        // 放大只會讓它糊掉。
        let frame = ImageDropPlacement.frame(
            dropPoint: CGPoint(x: 400, y: 500),
            imageSize: CGSize(width: 64, height: 64),
            pageSize: page)
        XCTAssertEqual(frame.width, 64, accuracy: 0.5)
    }

    func testDroppingAtTheEdgeKeepsTheWholeImageOnThePage() {
        // 以落點為中心的直接後果：拖到角落會有一半在頁面外，而那一半
        // 匯出與列印時會被裁掉 —— 畫面上卻看得見。
        for point in [CGPoint(x: 0, y: 0),
                      CGPoint(x: 800, y: 1132),
                      CGPoint(x: 800, y: 0),
                      CGPoint(x: 0, y: 1132)] {
            let frame = ImageDropPlacement.frame(
                dropPoint: point,
                imageSize: CGSize(width: 1000, height: 1000),
                pageSize: page)
            XCTAssertGreaterThanOrEqual(frame.minX, 0, "落在 \(point) 時超出左緣")
            XCTAssertGreaterThanOrEqual(frame.minY, 0, "落在 \(point) 時超出上緣")
            XCTAssertLessThanOrEqual(frame.maxX, page.width + 0.5, "落在 \(point) 時超出右緣")
            XCTAssertLessThanOrEqual(frame.maxY, page.height + 0.5, "落在 \(point) 時超出下緣")
        }
    }

    func testAVeryTallImageStillLandsInsideThePage() {
        // 極端長條圖：高度可能比頁面還長。這時 min 與 max 會打架，
        // 沒有夾好的話算出來是負數座標。
        let frame = ImageDropPlacement.frame(
            dropPoint: CGPoint(x: 400, y: 500),
            imageSize: CGSize(width: 100, height: 4000),
            pageSize: page)
        XCTAssertGreaterThanOrEqual(frame.minX, 0)
        XCTAssertGreaterThanOrEqual(frame.minY, 0)
    }

    func testANarrowPageNeverLetsOneImageFillTheWholeRow() {
        let narrow = CGSize(width: 200, height: 400)
        let frame = ImageDropPlacement.frame(
            dropPoint: CGPoint(x: 100, y: 200),
            imageSize: CGSize(width: 1000, height: 1000),
            pageSize: narrow)
        XCTAssertLessThanOrEqual(frame.width, narrow.width * 0.8 + 0.5)
    }

    func testADegenerateImageSizeDoesNotProduceZeroOrNaN() {
        // 讀不出尺寸的圖（有些來源回 0×0）不能讓版面變成 0 或 NaN。
        let frame = ImageDropPlacement.frame(
            dropPoint: CGPoint(x: 400, y: 500),
            imageSize: .zero,
            pageSize: page)
        XCTAssertGreaterThan(frame.width, 0)
        XCTAssertGreaterThan(frame.height, 0)
        XCTAssertFalse(frame.width.isNaN || frame.height.isNaN)
    }
}
