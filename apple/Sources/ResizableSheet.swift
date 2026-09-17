//
//  ResizableSheet.swift
//  Kairumo
//
//  讓所有彈出視窗都能由使用者自行調整大小。
//

import SwiftUI

/// 把 sheet 內容包成「可調整大小」的版本。
///
/// # 為什麼不是每個 sheet 自己寫
///
/// 全 App 有三十來個 sheet。尺寸規則各寫一份的結果是：改了其中一個，
/// 其他二十九個還是固定大小，而使用者的期待是「所有視窗都能拉」。
///
/// # 為什麼是 detent，不是自己做的把手
///
/// 先做過右下角拖曳把手那一版，在模擬器上逐一驗過：手勢有進來（log 印得
/// 出位移）、`preferredContentSize` 也套進去了，**外框紋風不動** ——
/// iOS 18 的 `PresentationHostingController` 不理它。
/// `.presentationSizing(.fitted)` 則會讓這幾張表整個攤成全螢幕，
/// 導覽列還被畫了兩次。
///
/// 真正會動的是 `presentationDetents`，而且 iPhone 與 iPad 都會動
/// （iPad 的 form sheet 也吃這組值，實機驗證過）。
/// 代價是**只能調高度**：sheet 的寬度由系統決定，這是系統的限制，不是
/// 這個檔案能繞過去的。要連寬度一起拉的面板請改用 `FloatingPanel`。
func resizableSheet<V: View>(@ViewBuilder _ content: () -> V) -> AnyView {
    AnyView(content().modifier(ResizableSheetChrome()))
}

struct ResizableSheetChrome: ViewModifier {
    /// **預設要開在 `.large`。**
    ///
    /// `presentationDetents` 沒有給 selection 的話，系統會挑最小的那一個 ——
    /// 於是每一張表都開在半高，而這些面板的主要動作（「貼入畫布」、「建立」、
    /// 「確認」）都在最下面：使用者打開來看到的是一張**按鈕被切掉**的表，
    /// 而且不會知道要往上拉。開在整高、想縮再往下拉，順序才是對的。
    @State private var detent: PresentationDetent = .large

    func body(content: Content) -> some View {
        content
            .presentationDetents([.medium, .large], selection: $detent)
            .presentationDragIndicator(.visible)
    }
}
