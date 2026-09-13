//
//  ObjectLayerTests.swift
//  KairumoTests
//
//  形狀的堆疊順序與群組。
//
//  # 這組測試在守什麼
//
//  順序的錯誤不會跳例外，只會讓畫面上的東西**疊錯**：該在上面的跑到下面、
//  群組裡的成員被別的東西夾在中間、多選一起搬時每次的結果都不一樣。
//  這些都要盯著「使用者最後看到什麼」來驗。
//
//  陣列的順序就是堆疊順序：索引 0 在最底層。面板由上到下顯示的是由前到後，
//  兩者相反 —— 那個轉換本身就值得一條測試。
//

import XCTest
@testable import Kairumo

final class ObjectLayerTests: XCTestCase {

    private func shapes(_ labels: [String]) -> [NoteShapeAttachment] {
        labels.map { NoteShapeAttachment(id: $0, label: $0) }
    }

    private func order(_ shapes: [NoteShapeAttachment]) -> [String] {
        shapes.map(\.id)
    }

    // MARK: - 堆疊順序

    func testBringToFrontPutsItOnTop() {
        var items = shapes(["a", "b", "c"])
        ObjectLayerOps.bringToFront("a", in: &items)
        XCTAssertEqual(order(items), ["b", "c", "a"], "最後一個才是最上層")
    }

    func testSendToBackPutsItAtTheBottom() {
        var items = shapes(["a", "b", "c"])
        ObjectLayerOps.sendToBack("c", in: &items)
        XCTAssertEqual(order(items), ["c", "a", "b"])
    }

    func testBringForwardMovesOneStepOnly() {
        // 一次跳兩層的話，使用者要按幾次才對得準就沒人知道了。
        var items = shapes(["a", "b", "c"])
        ObjectLayerOps.bringForward("a", in: &items)
        XCTAssertEqual(order(items), ["b", "a", "c"])
    }

    func testSendBackwardMovesOneStepOnly() {
        var items = shapes(["a", "b", "c"])
        ObjectLayerOps.sendBackward("c", in: &items)
        XCTAssertEqual(order(items), ["a", "c", "b"])
    }

    func testMovingBeyondTheEdgeDoesNothing() {
        // 夾住而不是繞回去：已經在最上層還按「上移」，東西不該跑到最底下。
        var items = shapes(["a", "b"])
        ObjectLayerOps.bringForward("b", in: &items)
        XCTAssertEqual(order(items), ["a", "b"])
        ObjectLayerOps.sendBackward("a", in: &items)
        XCTAssertEqual(order(items), ["a", "b"])
    }

    func testMovingAnUnknownIdChangesNothing() {
        var items = shapes(["a", "b"])
        ObjectLayerOps.bringToFront("不存在", in: &items)
        XCTAssertEqual(order(items), ["a", "b"])
    }

    func testReorderingKeepsEveryShape() {
        // 少一個就是畫面上有東西不見了。
        var items = shapes(["a", "b", "c", "d"])
        ObjectLayerOps.bringToFront("b", in: &items)
        ObjectLayerOps.sendToBack("d", in: &items)
        ObjectLayerOps.bringForward("a", in: &items)
        XCTAssertEqual(Set(order(items)), ["a", "b", "c", "d"])
        XCTAssertEqual(items.count, 4)
    }

    // MARK: - 群組

    func testGroupingMarksEveryMember() {
        var items = shapes(["a", "b", "c"])
        let groupId = ObjectLayerOps.group(["a", "c"], in: &items)
        XCTAssertNotNil(groupId)
        XCTAssertEqual(items.first { $0.id == "a" }?.groupId, groupId)
        XCTAssertEqual(items.first { $0.id == "c" }?.groupId, groupId)
        XCTAssertNil(items.first { $0.id == "b" }?.groupId, "沒選到的不該被拉進群組")
    }

    func testGroupingASingleShapeIsRefused() {
        // 一個物件的「群組」沒有意義，而且解散之後使用者會發現什麼也沒變，
        // 只會覺得按鈕壞了。
        var items = shapes(["a", "b"])
        XCTAssertNil(ObjectLayerOps.group(["a"], in: &items))
        XCTAssertNil(items[0].groupId)
    }

    func testGroupingNothingIsRefused() {
        var items = shapes(["a"])
        XCTAssertNil(ObjectLayerOps.group([], in: &items))
    }

    func testUngroupingReleasesEveryMember() {
        var items = shapes(["a", "b"])
        let groupId = try! XCTUnwrap(ObjectLayerOps.group(["a", "b"], in: &items))
        ObjectLayerOps.ungroup(groupId, in: &items)
        XCTAssertTrue(items.allSatisfy { $0.groupId == nil })
    }

    func testUngroupingKeepsTheShapesThemselves() {
        // 解散群組不是刪除 —— 成員要留在原地。
        var items = shapes(["a", "b"])
        let groupId = try! XCTUnwrap(ObjectLayerOps.group(["a", "b"], in: &items))
        ObjectLayerOps.ungroup(groupId, in: &items)
        XCTAssertEqual(order(items), ["a", "b"])
    }

    func testGroupMatesIncludeEveryMember() {
        // 選到群組裡的一個，整組都要一起動 —— 那正是群組的意義。
        var items = shapes(["a", "b", "c"])
        ObjectLayerOps.group(["a", "b"], in: &items)
        XCTAssertEqual(ObjectLayerOps.groupMates(of: "a", in: items), ["a", "b"])
    }

    func testAnUngroupedShapeIsItsOwnMate() {
        let items = shapes(["a", "b"])
        XCTAssertEqual(ObjectLayerOps.groupMates(of: "a", in: items), ["a"])
    }

    func testRegroupingReplacesTheOldGroup() {
        // 兩個群組 id 掛在同一批形狀上的話，解散時會解不乾淨。
        var items = shapes(["a", "b"])
        let first = try! XCTUnwrap(ObjectLayerOps.group(["a", "b"], in: &items))
        let second = try! XCTUnwrap(ObjectLayerOps.group(["a", "b"], in: &items))
        XCTAssertNotEqual(first, second)
        XCTAssertTrue(items.allSatisfy { $0.groupId == second })
    }

    // MARK: - 面板的列

    func testRowsAreListedFrontToBack() {
        // 面板由上到下＝由前到後，那是圖層面板的慣例。反過來的話，
        // 使用者每按一次「上移」都要在腦中翻譯一次。
        let items = shapes(["底", "中", "頂"])
        let rows = ObjectLayerOps.rows(for: items, unnamed: "未命名") { "群組 \($0)" }
        XCTAssertEqual(rows.map(\.label), ["頂", "中", "底"])
    }

    func testAGroupCollapsesIntoOneRow() {
        // 一個群組在面板上是一列，不是散開的成員 —— 否則群組就沒有意義。
        var items = shapes(["a", "b", "c"])
        ObjectLayerOps.group(["a", "b"], in: &items)
        let rows = ObjectLayerOps.rows(for: items, unnamed: "未命名") { "群組 \($0)" }
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows.filter(\.isGroup).count, 1)
        XCTAssertEqual(rows.first(where: \.isGroup)?.memberCount, 2)
    }

    func testAnUnnamedShapeGetsAPlaceholderLabel() {
        // 空字串在清單裡是一列看不出是什麼的空白。
        let items = [NoteShapeAttachment(id: "a", label: "")]
        let rows = ObjectLayerOps.rows(for: items, unnamed: "未命名") { "群組 \($0)" }
        XCTAssertEqual(rows.first?.label, "未命名")
    }

    func testTwoSeparateGroupsGetTwoRows() {
        var items = shapes(["a", "b", "c", "d"])
        ObjectLayerOps.group(["a", "b"], in: &items)
        ObjectLayerOps.group(["c", "d"], in: &items)
        let rows = ObjectLayerOps.rows(for: items, unnamed: "未命名") { "群組 \($0)" }
        XCTAssertEqual(rows.count, 2)
        XCTAssertTrue(rows.allSatisfy(\.isGroup))
    }
}
