//
//  ObjectStackingTests.swift
//  KairumoTests
//
//  畫布物件堆疊順序規則測試（與 Android 端 ObjectStackingTest 雙向對齊）。
//

import XCTest
@testable import Kairumo

final class ObjectStackingTests: XCTestCase {

    private let order = ["a", "b", "c", "d"]

    func testBringForwardMovesOneUp() {
        XCTAssertEqual(
            ["a", "c", "b", "d"],
            ObjectStacking.bringForward(["b"], in: order),
            "將 b 往前移一層應與 c 對調"
        )
    }

    func testSendBackwardMovesOneDown() {
        XCTAssertEqual(
            ["a", "c", "b", "d"],
            ObjectStacking.sendBackward(["c"], in: order),
            "將 c 往後移一層應與 b 對調"
        )
    }

    func testBringToFrontGoesLast() {
        XCTAssertEqual(
            ["b", "c", "d", "a"],
            ObjectStacking.bringToFront(["a"], in: order),
            "置頂物件應移至陣列末尾（最上層）"
        )
    }

    func testSendToBackGoesFirst() {
        XCTAssertEqual(
            ["d", "a", "b", "c"],
            ObjectStacking.sendToBack(["d"], in: order),
            "置底物件應移至陣列首位（最底層）"
        )
    }

    func testTopStaysPut() {
        XCTAssertEqual(
            order,
            ObjectStacking.bringForward(["d"], in: order),
            "已在最上層者往前移應維持原序"
        )
    }

    func testBottomStaysPut() {
        XCTAssertEqual(
            order,
            ObjectStacking.sendBackward(["a"], in: order),
            "已在最底層者往後移應維持原序"
        )
    }

    /// 多選要保持彼此的相對順序，不能取決於集合的迭代順序。
    func testMultiSelectKeepsRelativeOrder() {
        XCTAssertEqual(
            ["b", "d", "a", "c"],
            ObjectStacking.bringToFront(["c", "a"], in: order),
            "多選置頂時應維持選取成員之間的相對順序"
        )
    }

    func testMultiSelectMovesAsAGroup() {
        XCTAssertEqual(
            ["c", "a", "b", "d"],
            ObjectStacking.bringForward(["a", "b"], in: order),
            "連續多選往前移一層應整組推進"
        )
    }

    /// 一整組一起往上，遇到頂就整組停 —— 不可以拆散。
    func testGroupStopsAtTop() {
        XCTAssertEqual(
            order,
            ObjectStacking.bringForward(["c", "d"], in: order),
            "觸頂群組不應拆散"
        )
    }

    func testGroupStopsAtBottom() {
        XCTAssertEqual(
            order,
            ObjectStacking.sendBackward(["a", "b"], in: order),
            "觸底群組不應拆散"
        )
    }

    func testSelectingEverythingChangesNothing() {
        XCTAssertEqual(
            order,
            ObjectStacking.bringForward(["a", "b", "c", "d"], in: order),
            "全選移動不應改變任何順序"
        )
    }

    /// 刪掉的物件要從順序裡剔除，否則清單會無限長大。
    func testNormalizedDropsMissingAndAppendsNew() {
        let items = [
            StackableObject(id: "b", kind: .text, title: ""),
            StackableObject(id: "z", kind: .image, title: "")
        ]
        XCTAssertEqual(
            ["b", "z"],
            ObjectStacking.normalized(objects: items, order: order),
            "已刪除物件應被剔除，新加入物件應接在末尾"
        )
    }

    /// 沒排過的物件排在排過的之上，並照型別預設分層（圖片在文字下面）。
    func testUnorderedFollowsTypeDefaults() {
        let items = [
            StackableObject(id: "t", kind: .text, title: ""),
            StackableObject(id: "i", kind: .image, title: "")
        ]
        XCTAssertEqual(
            ["i", "t"],
            ObjectStacking.normalized(objects: items, order: []),
            "未排序物件應遵循型別預設層級（圖片在文字下）"
        )
    }
}
