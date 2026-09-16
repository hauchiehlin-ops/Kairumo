import XCTest

@testable import Kairumo

/// 純圖示控制項必須有無障礙標籤（工作項 S-64）。
///
/// # 這條測試為什麼是掃原始碼而不是跑介面
///
/// 真正要驗的是「VoiceOver 念出來是什麼」，那需要開著旁白操作真機。
/// 退而求其次，掃的是**最容易退步的那個模式**：`.help(...)` 給的是提示
/// （hint），不是標籤（label）。只寫 help 的按鈕，VoiceOver 念出來是
/// 系統從 SF Symbol 名稱猜的東西（「arrow uturn backward」），
/// 而不是「復原」。
///
/// 兩者長得很像，很容易只加一個就以為做完了 —— 這條測試守的就是那個。
final class AccessibilityLabelTests: XCTestCase {

    /// 掃 `apple/Sources` 底下的原始碼。
    private func sources() throws -> [(name: String, text: String)] {
        // 從測試 bundle 往上找專案根目錄。
        var dir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // apple
        dir.appendPathComponent("Sources")
        let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        return try files
            .filter { $0.pathExtension == "swift" }
            .map { (name: $0.lastPathComponent, text: try String(contentsOf: $0, encoding: .utf8)) }
    }

    func testEveryHelpAnnotatedControlAlsoCarriesALabel() throws {
        var offenders: [String] = []
        for file in try sources() {
            let lines = file.text.components(separatedBy: "\n")
            for (index, line) in lines.enumerated() {
                guard line.contains(".help(localizationManager.localized(") else { continue }
                // 前後三行之內要找得到 accessibilityLabel。
                let lower = max(0, index - 3)
                let upper = min(lines.count - 1, index + 3)
                let window = lines[lower...upper].joined(separator: "\n")
                if !window.contains("accessibilityLabel") {
                    offenders.append("\(file.name):\(index + 1)")
                }
            }
        }
        XCTAssertTrue(
            offenders.isEmpty,
            "這些控制項只有 .help（提示）沒有 .accessibilityLabel（標籤），"
                + "VoiceOver 會念 SF Symbol 的名字而不是功能：\n"
                + offenders.joined(separator: "\n"))
    }

    @MainActor
    func testTheInkPaletteEntriesAllHaveNameKeys() {
        // 色票是純色圓點。沒有 key 就沒有標籤可念，VoiceOver 只會說「按鈕」。
        for entry in inkPalette() {
            XCTAssertFalse(entry.key.isEmpty, "墨色 \(entry.hex) 沒有語系鍵")
            XCTAssertFalse(
                LocalizationManager.shared.localized(entry.key) == entry.key,
                "墨色 \(entry.hex) 的鍵 \(entry.key) 在字串表裡查不到")
        }
    }
}
