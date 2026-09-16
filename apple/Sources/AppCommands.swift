import SwiftUI
import UIKit

/// 實體鍵盤快捷鍵（工作項 S-64）。
///
/// # 前兩次的做法都失敗了，而且失敗得很安靜
///
/// 1. **SwiftUI 的 `keyboardShortcut` 掛在隱藏按鈕上。** 編譯零警告，
///    按下去什麼也沒發生。
/// 2. **`UIKeyCommand` 放在一個包住內容的 controller 上。** 理論上它是整棵
///    子樹的祖先，響應鏈會經過它 —— 實際加上日誌之後發現 `keyCommands`
///    **一次都沒有被查詢**。
///
/// 兩次都是「編得過、看起來對、實際沒作用」。這種東西只有真的按下去才知道。
///
/// # 這一版：走 App 層級的選單
///
/// `buildMenu(with:)` 把命令註冊在**應用程式層級**，不依賴目前的響應鏈。
/// 動作沿著鏈往上找不到人處理時，最後會落到 App delegate —— 而 delegate
/// 永遠在。這也是 iPadOS 長按 ⌘ 那張表、以及 Mac 選單列的來源。
///
/// # 「檔案」選單插不進去 —— 而且是無聲的
///
/// ⌘N 與 ⌘F 曾經也寫在這裡，插在 `.file` 的最前面。`.file` 查得到、
/// `insertChild` 有跑、沒有例外 —— 選單列裡就是沒有那兩項。原因是
/// 「檔案」整個是 SwiftUI 從 `WindowGroup` 產生的（新增視窗、複製、移動、
/// 重新命名、輸出），delegate 的 `buildMenu` 先跑，SwiftUI 之後重建那個
/// 選單，插進去的東西一起被蓋掉。
///
/// 所以那兩個命令改用 SwiftUI 的 `.commands`（見 `KairumoApp`）。
/// 「顯示」選單 SwiftUI 不碰，⌘E 與 ⌘1–⌘9 留在這裡沒問題。
///
/// # 為什麼用通知而不是直接改狀態
///
/// delegate 是 UIKit 的物件，SwiftUI 的狀態在 view 裡。用通知把兩邊接起來
/// 是最少耦合的方式：delegate 不需要知道有哪些畫面，畫面也不需要知道命令
/// 是從選單還是別的地方來的。
enum AppCommand {
    /// 新增筆記本。
    static let newNotebook = Notification.Name("kairumo.command.newNotebook")
    /// 把游標送進搜尋框。
    static let focusSearch = Notification.Name("kairumo.command.focusSearch")
    /// 切換手寫／打字模式。
    static let toggleEditorMode = Notification.Name("kairumo.command.toggleEditorMode")
    /// 選第 n 個工具（`object` 是 `Int`，從 0 起算）。
    static let selectTool = Notification.Name("kairumo.command.selectTool")
}

/// App delegate。存在的唯一理由就是註冊上面那些命令。
final class KairumoAppDelegate: UIResponder, UIApplicationDelegate {

    override func buildMenu(with builder: UIMenuBuilder) {
        super.buildMenu(with: builder)
        // 只動主選單，不要碰 context menu。
        guard builder.system == .main else { return }

        func string(_ key: String) -> String {
            LocalizationManager.shared.localizedUnsafe(key)
        }

        // 編輯器：切換模式與選工具。
        //
        // 用 ⌘ 加數字而不是直接數字：打字模式下直接數字會被文字輸入吃掉，
        // 使用者在文字方塊裡打「2024」會變成切換四次工具。
        //
        // **每一個工具要有自己的 selector。** 九個 `UIKeyCommand` 共用同一個
        // selector 時，UIKit 會算出重複的選單識別碼，然後在 buildMenu 當下
        // 丟例外把 App 打掉 —— 而那個 crash 的堆疊只會停在 UIKitCore，
        // 完全看不出原因。
        var editorChildren: [UIMenuElement] = [
            UIKeyCommand(
                title: string("handwriting_mode") + " / " + string("typing_mode"),
                action: #selector(commandToggleEditorMode),
                input: "e",
                modifierFlags: .command)
        ]
        let toolSelectors: [Selector] = [
            #selector(commandTool1), #selector(commandTool2), #selector(commandTool3),
            #selector(commandTool4), #selector(commandTool5), #selector(commandTool6),
            #selector(commandTool7), #selector(commandTool8), #selector(commandTool9)
        ]
        for (index, tool) in EditorToolType.allCases.enumerated()
        where index < toolSelectors.count {
            editorChildren.append(
                UIKeyCommand(
                    title: string(tool.localizationKey),
                    action: toolSelectors[index],
                    input: "\(index + 1)",
                    modifierFlags: .command))
        }
        if builder.menu(for: .view) != nil {
            builder.insertChild(
                UIMenu(title: "", options: .displayInline, children: editorChildren),
                atEndOfMenu: .view)
        }
    }

    // MARK: - 命令

    @objc private func commandToggleEditorMode() {
        NotificationCenter.default.post(name: AppCommand.toggleEditorMode, object: nil)
    }

    private func postTool(_ index: Int) {
        NotificationCenter.default.post(name: AppCommand.selectTool, object: index)
    }

    @objc private func commandTool1() { postTool(0) }
    @objc private func commandTool2() { postTool(1) }
    @objc private func commandTool3() { postTool(2) }
    @objc private func commandTool4() { postTool(3) }
    @objc private func commandTool5() { postTool(4) }
    @objc private func commandTool6() { postTool(5) }
    @objc private func commandTool7() { postTool(6) }
    @objc private func commandTool8() { postTool(7) }
    @objc private func commandTool9() { postTool(8) }
}
