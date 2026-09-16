import SwiftUI

/// 版面與外觀的共用尺度（工作項 S-62）。
///
/// # 為什麼需要它
///
/// 在此之前，間距、圓角、字級、卡片底色都是**每一處各寫一個數字**：
/// 有 10、12、14、16、18、22、24 的內距，8、10、12、14、16、20 的圓角，
/// 灰色有 `.gray`、`.secondary`、`.systemGray5`、`#8E8E93` 四種寫法。
/// 單看每一處都合理，放在同一個畫面上就是「說不出哪裡怪，但就是不精緻」。
///
/// 這個檔案是那些數字的唯一來源。新增介面時**從這裡取值**，不要再寫一個
/// 新的數字 —— 多一個數字，畫面就多一分雜訊。
///
/// # 與 Android 的對應
///
/// `android/.../ui/DesignSystem.kt` 是同一組尺度、同一組語意名稱。
/// 改這裡之前先確認那邊要不要一起改。
enum DS {

    // MARK: - 間距
    //
    // 4 的倍數。中間值（例如 10、14、18）刻意不提供 —— 它們是雜訊的來源：
    // 兩個相鄰區塊一個用 14 一個用 16，看得出來不齊，但看不出來為什麼。
    enum Space {
        /// 4 —— 圖示與其標籤之間。
        static let xxs: CGFloat = 4
        /// 8 —— 同一組元件之內。
        static let xs: CGFloat = 8
        /// 12 —— 卡片內的列距。
        static let s: CGFloat = 12
        /// 16 —— 卡片內距、元件之間的標準距離。
        static let m: CGFloat = 16
        /// 24 —— 區塊與區塊之間。
        static let l: CGFloat = 24
        /// 32 —— 大段落之間、頁面上下留白。
        static let xl: CGFloat = 32
    }

    // MARK: - 圓角

    enum Radius {
        /// 8 —— 小元件（標籤、色票）。
        static let s: CGFloat = 8
        /// 12 —— 卡片、輸入框。
        static let m: CGFloat = 12
        /// 16 —— 大卡片、彈出視窗。
        static let l: CGFloat = 16
    }

    // MARK: - 內容寬度
    //
    // **這是「響應式」最關鍵的一個數字。**
    //
    // 在此之前，內容是把整個視窗寬度填滿。13 吋 iPad 橫向是 1376pt，於是
    // 一列設定的文字從最左邊延伸到最右邊 —— 眼睛要橫掃 1300pt 才讀完一行，
    // 而右邊三分之二是空的。那不是「用到了空間」，是「沒有版面」。
    //
    // 上限之後，寬螢幕多出來的寬度變成兩側留白，內容維持可讀的行長。
    // 這是所有成熟的桌面／平板 App 都在做的事。
    enum Content {
        /// 一般內容的最大寬度。超過就置中並留白。
        static let maxWidth: CGFloat = 1040
        /// 以文字為主的內容（說明、長段落）的最大寬度，比一般更窄。
        static let readableMaxWidth: CGFloat = 720

        /// 依可用寬度決定左右外距。窄螢幕留少一點，寬螢幕留多一點。
        static func gutter(for width: CGFloat) -> CGFloat {
            if width < 420 { return Space.m }
            if width < 900 { return Space.l }
            return Space.xl
        }
    }

    // MARK: - 字級
    //
    // 一律走系統字級（Dynamic Type），不要寫死 pt —— 寫死的話，
    // 使用者把系統字體調大時畫面不會跟著變，那是無障礙問題不是風格問題。

    enum Font {
        /// 畫面主標題。
        static let screenTitle: SwiftUI.Font = .largeTitle.weight(.bold)
        /// 區塊標題（「繼續」「全部筆記」）。
        static let section: SwiftUI.Font = .title3.weight(.semibold)
        /// 卡片標題。
        static let cardTitle: SwiftUI.Font = .headline
        /// 內文。
        static let body: SwiftUI.Font = .subheadline
        /// 次要說明。
        static let caption: SwiftUI.Font = .footnote
        /// 標籤、徽章。
        static let label: SwiftUI.Font = .caption.weight(.medium)
    }

    // MARK: - 顏色
    //
    // 只用語意名稱。畫面上出現 `.purple`、`.orange` 這種具體顏色時，
    // 它就脫離了系統 —— 換深色模式或改主色時會被漏掉。

    enum Color {
        static let accent = SwiftUI.Color.accentColor
        /// 卡片底。
        static let surface = SwiftUI.Color(uiColor: .secondarySystemGroupedBackground)
        /// 頁面底。
        static let canvas = SwiftUI.Color(uiColor: .systemGroupedBackground)
        /// 卡片邊線。**非常淡** —— 邊線一重，整個畫面就吵。
        static let hairline = SwiftUI.Color(uiColor: .separator).opacity(0.5)
        static let primaryText = SwiftUI.Color(uiColor: .label)
        static let secondaryText = SwiftUI.Color(uiColor: .secondaryLabel)
        static let tertiaryText = SwiftUI.Color(uiColor: .tertiaryLabel)
        /// 破壞性動作。只有真的會刪掉東西的按鈕可以用。
        static let destructive = SwiftUI.Color(uiColor: .systemRed)
        /// 標籤底色：主色的極淡版本，用來取代各自為政的彩色。
        static let accentSoft = SwiftUI.Color.accentColor.opacity(0.12)
    }

    // MARK: - 圖示
    //
    // 圖示大小只有三種。四種以上就看得出來沒有系統。
    enum Icon {
        /// 16 —— 行內、標籤裡。
        static let small: CGFloat = 16
        /// 22 —— 清單列、工具列。
        static let medium: CGFloat = 22
        /// 28 —— 主要動作卡片。
        static let large: CGFloat = 28
    }
}

// MARK: - 共用修飾子

extension View {

    /// 內容置中並限制最大寬度。**寬螢幕的版面就靠這一個。**
    func dsContentWidth(_ maxWidth: CGFloat = DS.Content.maxWidth) -> some View {
        frame(maxWidth: maxWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    /// 標準卡片：底色、圓角、極淡的邊線。
    ///
    /// 用邊線而不是陰影：一個畫面上十幾張卡片各自投影時，整體會顯得髒。
    /// 陰影留給真正浮起來的東西（彈出視窗、拖曳中的物件）。
    func dsCard(padding: CGFloat = DS.Space.m, radius: CGFloat = DS.Radius.m) -> some View {
        self
            .padding(padding)
            .background(DS.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(DS.Color.hairline, lineWidth: 1)
            )
    }

    /// 標籤／小按鈕。整個 App 只有這一種樣式。
    func dsChip(prominent: Bool = false) -> some View {
        font(DS.Font.label)
            .foregroundStyle(prominent ? AnyShapeStyle(.white) : AnyShapeStyle(DS.Color.accent))
            .padding(.horizontal, DS.Space.s)
            .padding(.vertical, DS.Space.xxs + 2)
            .background(prominent ? AnyShapeStyle(DS.Color.accent) : AnyShapeStyle(DS.Color.accentSoft))
            .clipShape(Capsule())
    }
}

/// 區塊標題。左邊標題、右邊動作，整個 App 一種寫法。
struct DSSectionHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    init(_ title: String, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Space.s) {
            Text(title)
                .font(DS.Font.section)
                .foregroundStyle(DS.Color.primaryText)
            Spacer(minLength: DS.Space.s)
            trailing
        }
    }
}
