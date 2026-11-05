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
        #if targetEnvironment(macCatalyst) || os(macOS)
        content
            .frame(minWidth: 540, idealWidth: 650, maxWidth: 960, minHeight: 560, idealHeight: 720, maxHeight: 1000)
        #else
        content
            .presentationDetents([.medium, .large], selection: $detent)
            .presentationDragIndicator(.visible)
        #endif
    }
}

// MARK: - Mac：拖得動的捲軸

extension View {
    /// Mac 上給 `ScrollView` 一條**拖得動**的捲軸（點軌道跳過去、拖把手捲動）。
    ///
    /// # 為什麼要自己做
    ///
    /// Catalyst 上 SwiftUI `ScrollView` 右邊那條只是**指示器**：看得到，拖不動 ——
    /// 正常拖、慢慢拖、按住再拖，內容都一動也不動（在實機上逐一試過）。滾輪一格只捲
    /// 約 10pt，而協同面板的內容是面板高度的三倍多，於是使用者的感受是「捲軸失效、
    /// 滾輪一頓一頓、偶爾才下拉一點」。
    ///
    /// 放在 `ScrollView` **裡面**的內容上（`.background` 掛一個看不見的 UIView），
    /// 由它往上找到真正的 `UIScrollView`，把捲軸裝在它旁邊。iPhone／iPad 不動。
    func macDraggableScrollBar() -> some View {
        #if targetEnvironment(macCatalyst)
        background(MacScrollBarInstaller().frame(width: 0, height: 0))
        #else
        self
        #endif
    }
}

#if targetEnvironment(macCatalyst)
import UIKit

private struct MacScrollBarInstaller: UIViewRepresentable {
    func makeUIView(context: Context) -> Finder { Finder() }
    func updateUIView(_ uiView: Finder, context: Context) {}

    final class Finder: UIView {
        private var bar: MacScrollBar?

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            isHidden = true
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else { return }
            installIfNeeded()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            installIfNeeded()
        }

        private func installIfNeeded() {
            if let bar, bar.superview != nil, bar.scrollView != nil { return }
            var view = superview
            while let current = view, !(current is UIScrollView) { view = current.superview }
            guard let scrollView = view as? UIScrollView, let host = scrollView.superview else { return }
            bar?.removeFromSuperview()
            bar = MacScrollBar(scrollView: scrollView, host: host)
        }
    }
}

/// 一條真的捲軸：軌道＋把手。位置跟著 `contentOffset` 走（KVO），拖動時反過來改它。
private final class MacScrollBar: UIView {
    private(set) weak var scrollView: UIScrollView?
    private let knob = UIView()
    private var observations: [NSKeyValueObservation] = []
    private var dragStartKnobY: CGFloat = 0
    private static let width: CGFloat = 12
    private static let inset: CGFloat = 4
    private static let minKnob: CGFloat = 36

    init(scrollView: UIScrollView, host: UIView) {
        self.scrollView = scrollView
        super.init(frame: .zero)
        scrollView.showsVerticalScrollIndicator = false
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = UIColor.label.withAlphaComponent(0.04)
        layer.cornerRadius = Self.width / 2
        knob.backgroundColor = UIColor.secondaryLabel.withAlphaComponent(0.55)
        knob.layer.cornerRadius = (Self.width - 4) / 2
        knob.isUserInteractionEnabled = false
        addSubview(knob)
        host.addSubview(self)
        NSLayoutConstraint.activate([
            trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -2),
            topAnchor.constraint(equalTo: scrollView.topAnchor, constant: Self.inset),
            bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -Self.inset),
            widthAnchor.constraint(equalToConstant: Self.width),
        ])
        addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:))))
        let refresh: () -> Void = { [weak self] in self?.setNeedsLayout() }
        observations = [
            scrollView.observe(\.contentOffset, options: []) { _, _ in refresh() },
            scrollView.observe(\.contentSize, options: []) { _, _ in refresh() },
            scrollView.observe(\.bounds, options: []) { _, _ in refresh() },
        ]
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit { observations.forEach { $0.invalidate() } }

    /// (可捲的距離, 把手高度, 把手可移動的距離)。內容裝得下時回 nil。
    private var metrics: (scrollable: CGFloat, knobHeight: CGFloat, travel: CGFloat)? {
        guard let sv = scrollView else { return nil }
        let visible = sv.bounds.height - sv.adjustedContentInset.top - sv.adjustedContentInset.bottom
        let content = sv.contentSize.height
        let scrollable = content - visible
        guard visible > 0, content > 0, scrollable > 1, bounds.height > 0 else { return nil }
        let knobHeight = max(Self.minKnob, bounds.height * visible / content)
        return (scrollable, knobHeight, max(1, bounds.height - knobHeight))
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let sv = scrollView, let m = metrics else {
            isHidden = true
            return
        }
        isHidden = false
        let progress = (sv.contentOffset.y + sv.adjustedContentInset.top) / m.scrollable
        let y = min(max(0, progress), 1) * m.travel
        knob.frame = CGRect(x: 2, y: y, width: Self.width - 4, height: m.knobHeight)
    }

    @objc private func handlePan(_ g: UIPanGestureRecognizer) {
        guard let sv = scrollView, let m = metrics else { return }
        switch g.state {
        case .began:
            // 點在把手外：先把把手中心移到那裡（像 Mac 的「按一下跳到該處」）。
            let point = g.location(in: self)
            if !knob.frame.contains(point) {
                setKnob(y: point.y - m.knobHeight / 2, metrics: m, in: sv)
            }
            dragStartKnobY = knob.frame.minY
        case .changed:
            setKnob(y: dragStartKnobY + g.translation(in: self).y, metrics: m, in: sv)
        default:
            break
        }
    }

    private func setKnob(y: CGFloat, metrics m: (scrollable: CGFloat, knobHeight: CGFloat, travel: CGFloat), in sv: UIScrollView) {
        let progress = min(max(0, y / m.travel), 1)
        sv.setContentOffset(CGPoint(x: sv.contentOffset.x, y: progress * m.scrollable - sv.adjustedContentInset.top), animated: false)
    }
}
#endif
