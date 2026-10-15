//
//  RichTextTests.swift
//  KairumoTests
//
//  逐字格式（`RichText` / `runs`）：套用範圍、跟著文字移動、跨平台編碼。
//

import XCTest
@testable import Kairumo

final class RichTextTests: XCTestCase {

    private func box(_ text: String) -> NoteTextAttachment {
        NoteTextAttachment(pageIndex: 0, text: text, x: 40, y: 100, width: 300, height: 160)
    }

    // MARK: - 套用範圍

    func testBoldOnASelectionOnlyTouchesThoseCharacters() {
        var item = box("Hello world")
        RichText.apply(TextCharStyle(bold: true), range: NSRange(location: 6, length: 5), to: &item)
        XCTAssertEqual(item.runs, [TextStyleRun(start: 6, length: 5, style: TextCharStyle(bold: true))])
        XCTAssertFalse(item.isBold, "方塊層級不變")
        XCTAssertFalse(RichText.resolvedStyle(at: NSRange(location: 0, length: 1), in: item).bold)
        XCTAssertTrue(RichText.resolvedStyle(at: NSRange(location: 6, length: 2), in: item).bold)
    }

    func testOverridesEqualToTheBoxDefaultAreNotStored() {
        // 存下來的區段要最少：與方塊預設相同的覆寫是雜訊，還會讓跨平台比對誤判為「有改」。
        var item = box("abc")
        item.fontSize = 20
        RichText.apply(TextCharStyle(fontSize: 20), range: NSRange(location: 0, length: 3), to: &item)
        XCTAssertNil(item.runs)
    }

    func testAdjacentRunsWithTheSameStyleMerge() {
        var item = box("abcdef")
        RichText.apply(TextCharStyle(italic: true), range: NSRange(location: 0, length: 2), to: &item)
        RichText.apply(TextCharStyle(italic: true), range: NSRange(location: 2, length: 2), to: &item)
        XCTAssertEqual(item.runs, [TextStyleRun(start: 0, length: 4, style: TextCharStyle(italic: true))])
    }

    func testWholeBoxChangeRemovesTheSameOverrideFromRuns() {
        // 否則有覆寫的那幾個字看起來「改不動」。
        var item = box("abcdef")
        RichText.apply(TextCharStyle(fontSize: 30, textColorHex: "#FF0000"), range: NSRange(location: 0, length: 3), to: &item)
        RichText.applyToWholeBox(TextCharStyle(fontSize: 12), to: &item)
        XCTAssertEqual(item.fontSize, 12)
        XCTAssertEqual(item.runs, [TextStyleRun(start: 0, length: 3, style: TextCharStyle(textColorHex: "#FF0000"))])
    }

    func testHighlightIsPerCharacterAndClearRemovesIt() {
        var item = box("重點在這裡")
        RichText.apply(TextCharStyle(highlightHex: "#FFFF00"), range: NSRange(location: 0, length: 2), to: &item)
        XCTAssertEqual(RichText.resolvedStyle(at: NSRange(location: 0, length: 1), in: item).highlightHex, "#FFFF00")
        XCTAssertNil(RichText.resolvedStyle(at: NSRange(location: 3, length: 1), in: item).highlightHex)
        RichText.apply(TextCharStyle(highlightHex: "clear"), range: NSRange(location: 0, length: 5), to: &item)
        XCTAssertNil(item.runs)
    }

    func testClearFormattingOnlyClearsTheSelection() {
        var item = box("abcdef")
        RichText.apply(TextCharStyle(bold: true), range: NSRange(location: 0, length: 6), to: &item)
        RichText.clearOverrides(in: NSRange(location: 0, length: 3), of: &item)
        XCTAssertEqual(item.runs, [TextStyleRun(start: 3, length: 3, style: TextCharStyle(bold: true))])
    }

    // MARK: - 文字變動

    func testTypingInsideABoldRunExtendsIt() {
        var item = box("abcdef")
        RichText.apply(TextCharStyle(bold: true), range: NSRange(location: 2, length: 2), to: &item)
        RichText.replaceCharacters(in: NSRange(location: 3, length: 0), with: "XY", in: &item)
        XCTAssertEqual(item.text, "abcXYdef")
        XCTAssertEqual(item.runs, [TextStyleRun(start: 2, length: 4, style: TextCharStyle(bold: true))])
    }

    func testDeletingTextBeforeARunShiftsIt() {
        var item = box("abcdef")
        RichText.apply(TextCharStyle(bold: true), range: NSRange(location: 4, length: 2), to: &item)
        let old = item.text
        item.text = "cdef"
        RichText.adjustRuns(of: &item, from: old)
        XCTAssertEqual(item.runs, [TextStyleRun(start: 2, length: 2, style: TextCharStyle(bold: true))])
    }

    func testListToggleKeepsEachLinesFormatting() {
        // 清單開關在每一行開頭加符號。整段當成一次替換的話，中間各行的格式會被洗掉。
        var item = box("甲乙\n丙丁")
        RichText.apply(TextCharStyle(bold: true), range: NSRange(location: 3, length: 2), to: &item)
        let old = item.text
        item.text = WordListKind.bullet.toggle(in: old)
        RichText.adjustRunsLineByLine(of: &item, from: old)
        XCTAssertEqual(item.text, "• 甲乙\n• 丙丁")
        XCTAssertEqual(RichText.resolvedStyle(at: NSRange(location: 8, length: 2), in: item).bold, true)
        XCTAssertEqual(RichText.resolvedStyle(at: NSRange(location: 2, length: 2), in: item).bold, false)
    }

    func testRunsBeyondTheTextAreClampedNotFatal() {
        // 別的平台（或舊版）改了文字卻沒改區段時，區段會超出範圍。
        var item = box("abc")
        item.runs = [TextStyleRun(start: 1, length: 50, style: TextCharStyle(bold: true))]
        XCTAssertEqual(RichText.normalized(item), [TextStyleRun(start: 1, length: 2, style: TextCharStyle(bold: true))])
        XCTAssertEqual(RichText.attributedString(for: item).length, 3)
    }

    func testPositionsAreUtf16SoEmojiDoNotShiftFormatting() {
        // 👍 是兩個 UTF-16 碼元。Android 的索引也是 UTF-16，兩邊才會套在同一個字上。
        var item = box("👍好")
        RichText.apply(TextCharStyle(bold: true), range: NSRange(location: 2, length: 1), to: &item)
        let attributed = RichText.attributedString(for: item)
        let font = attributed.attribute(.font, at: 2, effectiveRange: nil) as? UIFont
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.traitBold) == true)
        let emojiFont = attributed.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertFalse(emojiFont?.fontDescriptor.symbolicTraits.contains(.traitBold) == true)
    }

    func testWordUnderTheCaret() {
        XCTAssertEqual(RichText.wordRange(around: 2, in: "hello world"), NSRange(location: 0, length: 5))
        XCTAssertNil(RichText.wordRange(around: 5, in: "hello world"), "詞的邊界：改接下來打的字")
        XCTAssertNil(RichText.wordRange(around: 11, in: "hello world"), "行尾")
    }

    // MARK: - 編輯器往返

    func testAttributedStringRoundTripsTheRuns() {
        var item = box("Hello world")
        RichText.apply(TextCharStyle(italic: true, textColorHex: "#C00000"), range: NSRange(location: 0, length: 5), to: &item)
        let attributed = RichText.attributedString(for: item)
        XCTAssertEqual(RichText.runs(from: attributed, item: item), item.runs)
    }

    func testMixedSizesNeedMoreHeightThanTheBaseSize() {
        var plain = box(String(repeating: "格式", count: 4))
        plain.height = 1
        var big = plain
        RichText.apply(TextCharStyle(fontSize: 48), range: NSRange(location: 0, length: 2), to: &big)
        XCTAssertGreaterThan(RichText.boxHeight(for: big), RichText.boxHeight(for: plain))
    }

    // MARK: - 跨平台編碼（format-spec §6.2）

    func testRunsSurviveTheAppearanceRoundTrip() {
        var item = box("Hello world")
        item.fontFamily = "Georgia"
        RichText.apply(TextCharStyle(bold: true, fontSize: 24, highlightHex: "#FFFF00"),
                       range: NSRange(location: 6, length: 5), to: &item)
        let json = TextBoxAppearance.encode(item)
        var other = box("Hello world")
        TextBoxAppearance.apply(json, to: &other)
        XCTAssertEqual(other.runs, item.runs)
        XCTAssertEqual(other.fontFamily, "Georgia")
    }

    func testRunKeysAreFlatAndShared() throws {
        // Android 讀的是同一組扁平鍵名 —— 巢狀成 {"style": {...}} 的話，那邊一個都讀不到。
        var item = box("abc")
        RichText.apply(TextCharStyle(underline: true), range: NSRange(location: 0, length: 1), to: &item)
        let map = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(TextBoxAppearance.encode(item).utf8)) as? [String: Any])
        let runs = try XCTUnwrap(map["runs"] as? [[String: Any]])
        XCTAssertEqual(runs.first?["start"] as? Int, 0)
        XCTAssertEqual(runs.first?["length"] as? Int, 1)
        XCTAssertEqual(runs.first?["underline"] as? Bool, true)
        XCTAssertNil(runs.first?["style"])
    }

    func testMissingRunsKeyMeansUniformFormatting() {
        // 別台把逐字格式全部移除時，送來的 JSON 就是沒有 runs 鍵。留著本機的舊區段 = 格式刪不掉。
        var item = box("abc")
        item.runs = [TextStyleRun(start: 0, length: 1, style: TextCharStyle(bold: true))]
        TextBoxAppearance.apply(#"{"fontSize":16}"#, to: &item)
        XCTAssertNil(item.runs)
    }

    func testOldFilesWithoutRunsStillDecode() throws {
        let json = ##"{"id":"a","pageIndex":0,"text":"t","fontSize":16,"isBold":false,"isItalic":false,"isUnderline":false,"isStrikethrough":false,"alignmentRaw":"left","textColorHex":"#000000","hasBorder":true,"cornerRadius":8,"x":0,"y":0,"width":100,"height":40}"##
        let item = try JSONDecoder().decode(NoteTextAttachment.self, from: Data(json.utf8))
        XCTAssertNil(item.runs)
    }
}
