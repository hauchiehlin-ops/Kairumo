//
//  EditorAttachments.swift
//  Kairumo
//
//  編輯器附件視圖、分享面板與遠端游標疊加層（架構模組化 P2）。
//

import SwiftUI
import PencilKit
import UniformTypeIdentifiers
import AVFoundation

#if canImport(PadnoteCore)
import PadnoteCore
#endif


/// 系統分享面板封裝
/// 系統的儲存對話框。
///
/// Catalyst 上這就是 macOS 的儲存面板（拿不到 `NSSavePanel` —— 這是一個
/// UIKit 程式），iOS 上是「檔案」的儲存介面。
///
/// `asCopy: true`：交出去的是副本。少了它，使用者存完之後我們那份暫存檔
/// 會被系統搬走，而暫存目錄隨時會被清掉。
struct SaveToFilesView: UIViewControllerRepresentable {
    let data: Data
    let filename: String

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let tempUrl = FileManager.default.temporaryDirectory.appending(path: filename)
        try? data.write(to: tempUrl, options: .atomic)
        return UIDocumentPickerViewController(forExporting: [tempUrl], asCopy: true)
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
}

struct ShareActivityView: UIViewControllerRepresentable {
    let data: Data
    let filename: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let tempUrl = FileManager.default.temporaryDirectory.appending(path: filename)
        try? data.write(to: tempUrl)
        let controller = UIActivityViewController(activityItems: [tempUrl], applicationActivities: nil)
        if let popover = controller.popoverPresentationController {
            let targetView = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }?.rootViewController?.view
            if let view = targetView {
                popover.sourceView = view
                popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// 畫布共用座標系名稱。
///
/// 拖曳手勢**必須**綁在這個具名座標系上，不能用預設的 `.local`：
/// `.position()` 由手勢自己的 translation 驅動，而 `.local` 是「手勢所在那個
/// 視圖」的座標系 —— 視圖一被移動，座標原點跟著移動，translation 就會被重新
/// 換算回較小的值，形成「移動 → 原點位移 → translation 縮回」的回授迴圈，
/// 表現出來就是物件在手指底下抖動、跟不上。
/// 框選工具列的標籤：手機寬度只顯示圖示（`Label` 的文字仍是無障礙名稱）。
struct MarqueeLabelStyle: LabelStyle {
    let compact: Bool
    // orphan-ok: LabelStyle 協定要求，由 SwiftUI 呼叫
    func makeBody(configuration: Configuration) -> some View {
        if compact {
            configuration.icon
        } else {
            HStack(spacing: 4) {
                configuration.icon
                configuration.title
            }
        }
    }
}

enum CanvasCoordinateSpace {
    static let name = "kairumoCanvas"
}

/// 畫布內嵌附件視圖（支援圖片、算式卡片、數據圖表）
/// 支援手勢拖曳平移、角落手柄縮放、即時濾鏡美化、邊框、立體陰影與旋轉
struct AttachmentItemView: View {
    @Binding var attachment: NoteImageAttachment
    var isSelected: Bool = false
    var isTypeMode: Bool = false
    var onSelect: (() -> Void)? = nil
    let onEdit: () -> Void
    let onDelete: () -> Void

    @ObservedObject var store = NotebookStore.shared
    @ObservedObject var localizationManager = LocalizationManager.shared
    @ObservedObject var collaborationManager = CollaborationManager.shared
    @Environment(\.pageCrossing) private var pageCrossing
    @Environment(\.objectClipboard) private var clipboard
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging: Bool = false
    /// 縮放期間的本地預覽尺寸。
    ///
    /// 縮放中**不寫入 store**：每寫一次就會整份 notebooks 重新 JSON 編碼並原子
    /// 寫檔三次（見 `NotebookStore.persistData`），一秒鐘做六十次會直接卡住主執
    /// 行緒。只在手勢結束時提交一次。
    @State private var liveSize: CGSize? = nil
    /// 手勢開始時的原始尺寸。translation 是「從起點累計」的量，
    /// 若每幀都加到已更新的寬度上，尺寸會以平方成長。
    @State private var resizeBaseSize: CGSize? = nil

    private var lockedByPeer: CollaboratorPeer? {
        // 租約有效（5 秒內有續約）而且對方勝出才算鎖住 —— 對方當機時物件不會永遠鎖住。
        collaborationManager.leaseHolder(for: attachment.id)
    }

    private var displayWidth: CGFloat { liveSize?.width ?? attachment.width }
    private var displayHeight: CGFloat { liveSize?.height ?? attachment.height }

    var body: some View {
        let currentX = attachment.x + dragOffset.width
        let currentY = attachment.y + dragOffset.height

        ZStack(alignment: .topTrailing) {
            Group {
                if let uiImage = store.loadAttachmentImage(fileName: attachment.fileName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: displayWidth, height: displayHeight)
                        .modifier(ImageFilterModifier(filter: attachment.filterStyle))
                        .objectMaterial(attachment.materialType)
                        .background(
                            RoundedRectangle(cornerRadius: attachment.cornerRadius)
                                .fill(ObjectFrameStyleResolver.background(attachment, .image))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: attachment.cornerRadius))
                        .overlay(
                            Group {
                                if let peer = lockedByPeer {
                                    RoundedRectangle(cornerRadius: attachment.cornerRadius)
                                        .stroke(Color(hex: peer.userColor) ?? .blue, lineWidth: 3)
                                } else {
                                    RoundedRectangle(cornerRadius: attachment.cornerRadius)
                                        .stroke(
                                            attachment.hasBorder
                                                ? ObjectFrameStyleResolver.borderColor(attachment, .image)
                                                : (isSelected ? Color.accentColor : Color.clear),
                                            lineWidth: attachment.hasBorder
                                                ? ObjectFrameStyleResolver.borderWidth(attachment, .image)
                                                : 1.5
                                        )
                                }
                            }
                        )
                        .shadow(color: (attachment.hasShadow && !isDragging) ? Color.black.opacity(0.18) : Color.clear, radius: 8, x: 2, y: 4)
                        .rotationEffect(.degrees(attachment.canvasRotation))
                        .contextMenu {
                            ObjectFrameStyleMenu(style: $attachment)
                            ObjectOrderMenu(id: attachment.id)
                            Divider()
                            Button(role: .destructive, action: onDelete) {
                                Label(localizationManager.localized("delete"), systemImage: "trash")
                            }
                        }
                } else {
                    RoundedRectangle(cornerRadius: attachment.cornerRadius)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(width: displayWidth, height: displayHeight)
                        .overlay(
                            ProgressView()
                        )
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                guard lockedByPeer == nil else { return }
                onSelect?()
            }
            .highPriorityGesture(
                ((!isTypeMode && !isSelected) || !CanvasTouchState.canDragObject) ? nil :
                DragGesture(minimumDistance: 4, coordinateSpace: .named(CanvasCoordinateSpace.name))
                    .onChanged { value in
                        guard lockedByPeer == nil else { return }
                        guard CanvasTouchState.canDragObject else {
                            if isDragging {
                                dragOffset = .zero
                                isDragging = false
                                pageCrossing?.ended(nil, nil)
                            }
                            return
                        }
                        if !isDragging { pageCrossing?.began() }
                        isDragging = true
                        var transaction = Transaction()
                        transaction.animation = nil
                        withTransaction(transaction) {
                            dragOffset = value.translation
                        }
                    }
                    .onEnded { value in
                        guard lockedByPeer == nil else { return }
                        guard CanvasTouchState.canDragObject else {
                            dragOffset = .zero
                            isDragging = false
                            pageCrossing?.ended(nil, nil)
                            return
                        }
                        var crossedTo: Int?
                        if hypot(value.translation.width, value.translation.height) < 4 {
                            onSelect?()
                        } else {
                            var transaction = Transaction()
                            transaction.animation = nil
                            withTransaction(transaction) {
                                // 拖出可列印範圍的物件推回邊界（S-85）；連續模式下拖到哪一頁就歸哪一頁。
                                let landed = PrintableArea.land(
                                    x: attachment.x + value.translation.width,
                                    y: attachment.y + value.translation.height,
                                    width: attachment.width, height: attachment.height,
                                    crossing: pageCrossing)
                                var updated = attachment
                                updated.x = landed.origin.x
                                updated.y = landed.origin.y
                                if let page = landed.page { updated.pageIndex = page }
                                attachment = updated
                                crossedTo = landed.page
                                dragOffset = .zero
                                isDragging = false
                            }
                            onSelect?()
                            if let data = try? JSONEncoder().encode(attachment),
                               let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                                collaborationManager.broadcastAttachmentUpsert(type: "image", itemDict: dict)
                            }
                        }
                        dragOffset = .zero
                        isDragging = false
                        pageCrossing?.ended(crossedTo == nil ? nil : attachment.id, crossedTo)
                    }
            )

            // 遠端成員軟鎖定中指示徽章
            if let peer = lockedByPeer {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: peer.userColor) ?? .blue)
                        .frame(width: 8, height: 8)
                    Text("\(peer.userName) \(localizationManager.localized("object_locked_by"))")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(hex: peer.userColor)?.opacity(0.95) ?? Color.blue)
                .cornerRadius(10)
                .offset(x: -8, y: -24)
            }

            // 選取時顯示浮動小操作把手：編輯（依物件類型開啟專屬視窗）、刪除、右下角縮放把手
            if isSelected {
                HStack(spacing: 6) {
                    Button {
                        onEdit()
                    } label: {
                        let iconName = (attachment.mathFormula != nil) ? "function" : ((attachment.chartSpec != nil) ? "chart.bar.xaxis" : "slider.horizontal.3")
                        Image(systemName: iconName)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(5)
                            .background(Color.blue)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(attachment.mathFormula != nil ? localizationManager.localized("math_calc") : (attachment.chartSpec != nil ? localizationManager.localized("chart_edit") : localizationManager.localized("image_beautify")))

                    // 邊框開關已移進「美化圖片」面板（`ImageEditControls` 的
                    // 「保留邊框」）。原本兩個地方都能改同一個值，畫布上那顆
                    // 又只有顏色會變、沒有標示，使用者不知道自己按了什麼。

                    if let clipboard {
                        Button {
                            clipboard.cut(attachment.id)
                        } label: {
                            Image(systemName: "scissors")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(5)
                                .background(Color.orange)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(localizationManager.localized("action_cut"))
                        .accessibilityIdentifier("object.action.cut")

                        Button {
                            clipboard.copy(attachment.id)
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(5)
                                .background(Color.teal)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(localizationManager.localized("action_copy"))
                        .accessibilityIdentifier("object.action.copy")
                    }

                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(5)
                            .background(Color.red)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    // 圖示按鈕一定要有標籤：沒有的話 VoiceOver 念「按鈕」，
                    // 互動矩陣（`InteractionMatrixAudit`）也找不到它。
                    .accessibilityLabel(localizationManager.localized("action_delete"))
                }
                .offset(x: 10, y: -10)

                // 右下角縮放把手
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left")
                            .font(.system(size: 10))
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Color.accentColor)
                            .clipShape(Circle())
                            .gesture(
                                DragGesture(minimumDistance: 1, coordinateSpace: .named(CanvasCoordinateSpace.name))
                                    .onChanged { value in
                                        let base = resizeBaseSize ?? CGSize(width: attachment.width, height: attachment.height)
                                        if resizeBaseSize == nil { resizeBaseSize = base }
                                        let ratio = base.height / max(1, base.width)
                                        let newW = max(80, base.width + value.translation.width)
                                        liveSize = CGSize(width: newW, height: max(60, newW * ratio))
                                    }
                                    .onEnded { _ in
                                        if let size = liveSize {
                                            attachment.width = size.width
                                            attachment.height = size.height
                                            if let data = try? JSONEncoder().encode(attachment),
                                               let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                                                collaborationManager.broadcastAttachmentUpsert(type: "image", itemDict: dict)
                                            }
                                        }
                                        resizeBaseSize = nil
                                        liveSize = nil
                                    }
                            )
                            .offset(x: 6, y: 6)
                    }
                }
                .frame(width: displayWidth, height: displayHeight)

                // 旋轉把手。與內容同層但**不參與** `.rotationEffect` ——
                // 包進旋轉裡的話，拖曳算出的角度會疊加自身旋轉，物件會失控加速。
                ObjectRotationHandle(
                    degrees: $attachment.canvasRotation,
                    size: CGSize(width: displayWidth, height: displayHeight)
                ) {
                    if let data = try? JSONEncoder().encode(attachment),
                       let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        collaborationManager.broadcastAttachmentUpsert(type: "image", itemDict: dict)
                    }
                }
            }
        }
        .objectProbe("image")
        .padding(20)
        .position(x: currentX + displayWidth / 2, y: currentY + displayHeight / 2)
        .animation(nil, value: dragOffset)
    }
}

/// 圖片濾鏡 ViewModifier
struct ImageFilterModifier: ViewModifier {
    let filter: ImageFilterStyle

    func body(content: Content) -> some View {
        switch filter {
        case .original:
            content
        case .vintage:
            content
                .colorMultiply(Color(red: 0.95, green: 0.88, blue: 0.75))
                .contrast(1.1)
                .saturation(0.8)
        case .mono:
            content
                .grayscale(1.0)
                .contrast(1.2)
        case .contrast:
            content
                .contrast(1.3)
                .saturation(1.2)
        case .warm:
            content
                .colorMultiply(Color(red: 1.0, green: 0.93, blue: 0.85))
                .brightness(0.04)
        }
    }
}

/// 畫布內嵌 Word 文字卡片視圖
struct TextAttachmentItemView: View {
    @Binding var textItem: NoteTextAttachment
    @Binding var isEditingInline: Bool
    var isSelected: Bool = false
    var onSelect: (() -> Void)? = nil
    var isTypeMode: Bool = false
    var isUnderInk: Bool = false
    var snapToGrid: Bool = false
    var snapY: ((CGFloat) -> CGFloat)? = nil
    let onEdit: () -> Void
    let onDelete: () -> Void
    var onMoved: ((CGSize) -> Void)? = nil
    var onAnchorInk: (() -> Void)? = nil
    /// 就地編輯的選取範圍（工具列依它決定改選取的字還是整個方塊）。
    var selectionTracker: TextSelectionTracker? = nil

    @Environment(\.objectReorder) private var reorder
    @Environment(\.objectClipboard) private var clipboard

    @ObservedObject var localizationManager = LocalizationManager.shared
    @ObservedObject var collaborationManager = CollaborationManager.shared
    @Environment(\.pageCrossing) private var pageCrossing
    @State private var dragOffset: CGSize = .zero
    /// 縮放期間的本地預覽寬度（理由同 `AttachmentItemView.liveSize`）。
    @State private var liveWidth: CGFloat? = nil
    @State private var resizeBaseWidth: CGFloat? = nil
    @State private var isDragging: Bool = false
    @State private var hasBeenFocused: Bool = false
    /// 就地編輯器是不是第一回應者（由 `RichTextEditorView` 雙向同步）。
    @State private var inlineFocused: Bool = false
    @State private var showSlashMenu: Bool = false

    private var lockedByPeer: CollaboratorPeer? {
        // 租約有效（5 秒內有續約）而且對方勝出才算鎖住 —— 對方當機時物件不會永遠鎖住。
        collaborationManager.leaseHolder(for: textItem.id)
    }

    /// 正在這個方塊打字的人（不鎖住：大家可以同時打字，見設計 §8.3）。只用來畫外框提示。
    private var typingPeer: CollaboratorPeer? {
        collaborationManager.typingPeers(for: textItem.id).first
    }

    /// 選取時的動作按鈕（圖示 + 文字，看得懂也點得到）
    private func textActionButton(_ icon: String, _ titleKey: String, _ tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                Text(localizationManager.localized(titleKey))
                    .font(.system(size: 11, weight: .semibold))
                    .fixedSize()
            }
            .foregroundColor(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(tint)
            .cornerRadius(7)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(localizationManager.localized(titleKey))
        .help(localizationManager.localized(titleKey))
    }

    private var displayWidth: CGFloat { liveWidth ?? textItem.width }
    private var displayHeight: CGFloat { liveHeight ?? textItem.height }
    private var calculatedContentHeight: CGFloat {
        var probe = textItem
        probe.width = displayWidth
        return max(displayHeight, RichText.boxHeight(for: probe))
    }

    private func resolvedFont(size: CGFloat, bold: Bool, italic: Bool, family: String?) -> Font {
        if let family = family, !family.isEmpty, family.lowercased() != "system" {
            var f = Font.custom(family, size: size)
            if bold { f = f.bold() }
            if italic { f = f.italic() }
            return f
        } else {
            var f = Font.system(size: size, weight: bold ? .bold : .regular)
            if italic { f = f.italic() }
            return f
        }
    }
    /// 拖曳縮放中的即時高度。
    @State private var liveHeight: CGFloat? = nil
    @State private var resizeBaseSize: CGSize? = nil

    /// 統一進入就地編輯。由快顯選單觸發時，先讓選單完成關閉再建立
    /// first responder，避免 UIKit 在 dismiss 過程中立刻把新鍵盤焦點收走。
    private func beginInlineEditing(afterContextMenu: Bool = false) {
        let activate = {
            onSelect?()
            hasBeenFocused = false
            isEditingInline = true
            // 打字用「共用」的在場標記：別人可以同時在這個方塊打字（字元 CRDT），但看得到我在打。
            collaborationManager.broadcastSelection(selectedId: CollaborationManager.typingPrefix + textItem.id)
        }
        if afterContextMenu {
            DispatchQueue.main.async(execute: activate)
        } else {
            activate()
        }
    }

    private func afterContextMenuDismisses(_ action: @escaping () -> Void) {
        DispatchQueue.main.async(execute: action)
    }

    private func slashMenuItem(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.accentColor)
                    .frame(width: 20)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.08))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    var body: some View {
        let currentX = textItem.x + dragOffset.width
        let currentY = textItem.y + dragOffset.height

        ZStack(alignment: .topTrailing) {
            VStack(alignment: resolveAlignment(textItem.alignmentRaw), spacing: 4) {
                if isEditingInline {
                    // 就地編輯：隨點隨打，鍵盤自動升起，不必開面板
                    ZStack(alignment: .topLeading) {
                        if textItem.text.isEmpty && !isTypeMode {
                            Text(localizationManager.localized("text_placeholder"))
                                .font(resolvedFont(size: textItem.fontSize, bold: textItem.isBold, italic: textItem.isItalic, family: textItem.fontFamily))
                                .foregroundColor(Color.secondary.opacity(0.45))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 8)
                                .allowsHitTesting(false)
                                .frame(maxWidth: .infinity, alignment: resolveFrameAlignment(textItem.alignmentRaw))
                        }

                        // `TextField(axis: .vertical)` 而不是 `TextEditor`：TextEditor 裡面有自己的
                        // 上下左右內距（隨系統版本不同），第一行基準線因此離方塊頂端多出一個
                        // 量不準的距離 —— 橫線紙上的字對不齊格線。垂直軸的 TextField 沒有內距，
                        // 編輯中與編輯後（`Text`）的字完全重疊，基準線 = 內距 + ascender。
                        // `UITextView` 而不是 `TextField`：要拿得到選取範圍，Word 式的
                        // 「選幾個字、按粗體」才做得到；逐字格式也要在編輯中就看得到。
                        // 內距歸零，編輯中與編輯後（`Text`）的字完全重疊 —— 橫線紙上的基準線才對得齊。
                        RichTextEditorView(item: $textItem, isFocused: $inlineFocused, tracker: selectionTracker)
                            .frame(maxWidth: .infinity, minHeight: 20, alignment: .topLeading)
                    }
                    .overlay(alignment: .topLeading) {
                        if showSlashMenu {
                            VStack(alignment: .leading, spacing: 4) {
                                slashMenuItem(title: localizationManager.localized("text_slash_h1"), icon: "textformat.size.larger") {
                                    textItem.text = ""
                                    textItem.fontSize = 28
                                    textItem.isBold = true
                                    showSlashMenu = false
                                }
                                slashMenuItem(title: localizationManager.localized("text_slash_h2"), icon: "textformat.size") {
                                    textItem.text = ""
                                    textItem.fontSize = 22
                                    textItem.isBold = true
                                    showSlashMenu = false
                                }
                                slashMenuItem(title: localizationManager.localized("text_slash_bullet"), icon: "list.bullet") {
                                    textItem.text = "• "
                                    showSlashMenu = false
                                }
                                slashMenuItem(title: localizationManager.localized("text_slash_todo"), icon: "checklist") {
                                    textItem.text = "☐ "
                                    showSlashMenu = false
                                }
                                slashMenuItem(title: localizationManager.localized("text_slash_quote"), icon: "text.quote") {
                                    textItem.text = "│ "
                                    showSlashMenu = false
                                }
                            }
                            .padding(6)
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .cornerRadius(8)
                            .shadow(color: Color.black.opacity(0.18), radius: 6, y: 3)
                            .offset(y: -170)
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if !isTypeMode {
                            Button {
                                isEditingInline = false
                                inlineFocused = false
                                finishEditing()
                            } label: {
                                Text(localizationManager.localized("done"))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.accentColor)
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            .offset(x: 4, y: 22)
                        }
                    }
                } else if textItem.runs?.isEmpty == false {
                    // 有逐字格式：每一段的字型、顏色、醒目提示都寫在屬性字串裡。
                    Text(RichText.swiftUIText(for: textItem))
                        .multilineTextAlignment(resolveMultilineAlignment(textItem.alignmentRaw))
                        .lineSpacing(textItem.lineSpacing ?? 0)
                        .padding(.leading, textItem.paragraphIndent ?? 0)
                        .frame(maxWidth: .infinity, alignment: resolveFrameAlignment(textItem.alignmentRaw))
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(textItem.text)
                        .font(resolvedFont(size: textItem.fontSize, bold: textItem.isBold, italic: textItem.isItalic, family: textItem.fontFamily))
                        .underline(textItem.isUnderline)
                        .strikethrough(textItem.isStrikethrough)
                        .foregroundColor(Color(hex: textItem.textColorHex) ?? .primary)
                        .multilineTextAlignment(resolveMultilineAlignment(textItem.alignmentRaw))
                        // 段落設定要跟匯出端套同一組值，否則行數不同、版面又分家。
                        .lineSpacing(textItem.lineSpacing ?? 0)
                        .padding(.leading, textItem.paragraphIndent ?? 0)
                        .frame(maxWidth: .infinity, alignment: resolveFrameAlignment(textItem.alignmentRaw))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            // 內距隨方塊大小縮（見 TextBoxMetrics）。小到一格週計畫的格子時，
            // 固定 14 的內距會把可寫的空間吃光。
            .padding(TextBoxMetrics.padding(width: displayWidth, height: calculatedContentHeight))
            .frame(width: displayWidth, height: calculatedContentHeight, alignment: .top)
            .background(resolveBackground(textItem.backgroundColorHex))
            .clipShape(RoundedRectangle(cornerRadius: textItem.cornerRadius))
            .overlay(
                Group {
                    if let peer = lockedByPeer ?? typingPeer {
                        RoundedRectangle(cornerRadius: textItem.cornerRadius)
                            .stroke(Color(hex: peer.userColor) ?? .blue, lineWidth: 3)
                    } else if isEditingInline {
                        if isTypeMode && !textItem.hasBorder {
                            Color.clear
                        } else {
                            RoundedRectangle(cornerRadius: textItem.cornerRadius)
                                .stroke(Color.accentColor.opacity(0.85), lineWidth: 1.5)
                        }
                    } else {
                        RoundedRectangle(cornerRadius: textItem.cornerRadius)
                            .stroke(
                                textItem.hasBorder
                                    ? (Color(hex: textItem.borderColorHex ?? "") ?? Color.secondary.opacity(0.4))
                                    : (isSelected ? Color.accentColor : Color.clear),
                                lineWidth: textItem.hasBorder ? (textItem.borderWidth ?? 1.5) : 1
                            )
                    }
                }
            )
            .shadow(color: (isTypeMode || isDragging || !textItem.hasBorder) ? Color.clear : Color.black.opacity(0.08), radius: 6, y: 3)
            .contentShape(Rectangle())
            .rotationEffect(.degrees(textItem.canvasRotation))
            .overlay(alignment: .bottomTrailing) {
                if (isSelected || isEditingInline) && lockedByPeer == nil {
                    Image(systemName: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 30, height: 30)
                        .background(Color.accentColor)
                        .clipShape(Circle())
                        .contentShape(Circle())
                        .offset(x: 10, y: 10)
                        .accessibilityLabel(localizationManager.localized("resize_text_box"))
                        .help(localizationManager.localized("resize_text_box"))
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 1,
                                        coordinateSpace: .named(CanvasCoordinateSpace.name))
                                .onChanged { value in
                                    let base = resizeBaseSize
                                        ?? CGSize(width: textItem.width, height: textItem.height)
                                    if resizeBaseSize == nil { resizeBaseSize = base }
                                    liveWidth = max(TextBoxMetrics.minWidth,
                                                    base.width + value.translation.width)
                                    liveHeight = max(TextBoxMetrics.minHeight,
                                                     base.height + value.translation.height)
                                }
                                .onEnded { _ in
                                    if let w = liveWidth { textItem.width = w }
                                    if let h = liveHeight { textItem.height = h }
                                    resizeBaseSize = nil
                                    liveWidth = nil
                                    liveHeight = nil
                                    broadcastTextChange()
                                }
                        )
                }
            }
            .overlay {
                if isSelected && !isEditingInline && lockedByPeer == nil {
                    GeometryReader { geo in
                        ObjectRotationHandle(
                            degrees: $textItem.canvasRotation,
                            size: geo.size,
                            onCommit: broadcastTextChange
                        )
                    }
                }
            }
            .onTapGesture(count: 2) {
                // 點兩下＝就地編輯
                guard lockedByPeer == nil else { return }
                beginInlineEditing()
            }
            .onTapGesture {
                // 點一下：若已選取或已在就地編輯則維持/進入編輯；未選取時先選取方塊
                guard lockedByPeer == nil else { return }
                if isSelected || isEditingInline {
                    beginInlineEditing()
                } else {
                    onSelect?()
                    collaborationManager.broadcastSelection(selectedId: textItem.id)
                }
            }
            // 右鍵／長按也要能刪除 —— 這是大家最先嘗試的操作
            .contextMenu {
                Button {
                    beginInlineEditing(afterContextMenu: true)
                } label: { Label(localizationManager.localized("edit_in_place"), systemImage: "character.cursor.ibeam") }

                Button {
                    afterContextMenuDismisses(onEdit)
                } label: { Label(localizationManager.localized("text_studio"), systemImage: "textformat") }

                if let onAnchorInk {
                    Button {
                        afterContextMenuDismisses(onAnchorInk)
                    } label: { Label(localizationManager.localized("sticky_anchor_ink"), systemImage: "link.badge.plus") }
                }

                ObjectFrameStyleMenu(
                    style: $textItem,
                    onChange: broadcastTextChange,
                    schedule: afterContextMenuDismisses
                )
                ObjectOrderMenu(id: textItem.id)

                Divider()

                Button(role: .destructive) {
                    afterContextMenuDismisses(onDelete)
                } label: { Label(localizationManager.localized("delete"), systemImage: "trash") }
            }
            // 高優先：方塊身上還有「點兩下」，它會先等第二下，等的這段時間連續模式的捲動就把
            // 拖曳搶走了（方塊拖不動、畫面反而捲動）。拖曳至少要移動 5 點，點一下、點兩下照常有效。
            .highPriorityGesture(
                (isEditingInline || (!isTypeMode && !isSelected) || !CanvasTouchState.canDragObject) ? nil :
                DragGesture(minimumDistance: 5, coordinateSpace: .named(CanvasCoordinateSpace.name))
                    .onChanged { value in
                        guard lockedByPeer == nil else { return }
                        guard CanvasTouchState.canDragObject else {
                            if isDragging {
                                dragOffset = .zero
                                isDragging = false
                                pageCrossing?.ended(nil, nil)
                            }
                            return
                        }
                        if !isDragging { pageCrossing?.began() }
                        isDragging = true
                        var transaction = Transaction()
                        transaction.animation = nil
                        withTransaction(transaction) {
                            dragOffset = value.translation
                        }
                    }
                    .onEnded { value in
                        guard lockedByPeer == nil else { return }
                        guard CanvasTouchState.canDragObject else {
                            dragOffset = .zero
                            isDragging = false
                            pageCrossing?.ended(nil, nil)
                            return
                        }
                        var crossedTo: Int?
                        if hypot(value.translation.width, value.translation.height) < 4 {
                            beginInlineEditing()
                        } else {
                            let oldX = textItem.x
                            let oldY = textItem.y
                            var transaction = Transaction()
                            transaction.animation = nil
                            withTransaction(transaction) {
                                // 拖出可列印範圍的物件推回邊界（S-85）；連續模式下拖到哪一頁就歸哪一頁。
                                let landed = PrintableArea.land(
                                    x: textItem.x + value.translation.width,
                                    y: textItem.y + value.translation.height,
                                    width: textItem.width, height: calculatedContentHeight,
                                    crossing: pageCrossing)
                                var updated = textItem
                                updated.x = landed.origin.x
                                updated.y = (snapToGrid && snapY != nil) ? snapY!(landed.origin.y) : landed.origin.y
                                updated.height = calculatedContentHeight
                                if let page = landed.page { updated.pageIndex = page }
                                textItem = updated
                                crossedTo = landed.page
                                dragOffset = .zero
                                isDragging = false
                            }
                            // 換頁時不算「在這一頁上平移」：跟著方塊走的東西（便利貼錨點）留在原頁。
                            let deltaX = textItem.x - oldX
                            let deltaY = textItem.y - oldY
                            if crossedTo == nil, deltaX != 0 || deltaY != 0 {
                                onMoved?(CGSize(width: deltaX, height: deltaY))
                            }
                            onSelect?()
                            if let data = try? JSONEncoder().encode(textItem),
                               let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                                collaborationManager.broadcastAttachmentUpsert(type: "text", itemDict: dict)
                            }
                        }
                        dragOffset = .zero
                        isDragging = false
                        pageCrossing?.ended(crossedTo == nil ? nil : textItem.id, crossedTo)
                    }
            )

            // 遠端成員軟鎖定中指示徽章；別人正在這個方塊打字時也標出來（不鎖，可以一起打）。
            if let peer = lockedByPeer ?? typingPeer {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: peer.userColor) ?? .blue)
                        .frame(width: 8, height: 8)
                    Text(lockedByPeer != nil
                         ? "\(peer.userName) \(localizationManager.localized("object_locked_by"))"
                         : String(format: localizationManager.localized("collab_peer_typing"), peer.userName))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(hex: peer.userColor)?.opacity(0.95) ?? Color.blue)
                .cornerRadius(10)
                .offset(x: -8, y: -24)
            }

            // 選取時的動作列。按鈕帶文字，且整條移到方塊上方 ——
            // 原本是三顆無標示的小圓點又壓在方塊角上，很難點也看不懂。
            if isSelected && !isEditingInline {
                HStack(spacing: 6) {
                    textActionButton("pencil", "edit", .blue) { onEdit() }

                    // 🌟 圖層順序與筆跡上下層級切換選單
                    if let reorder {
                        Menu {
                            Button {
                                reorder(textItem.id, .bringAboveInk)
                            } label: {
                                Label(localizationManager.localized("layer_bring_above_ink"), systemImage: "square.2.layers.3d.top.filled")
                            }
                            Button {
                                reorder(textItem.id, .sendBelowInk)
                            } label: {
                                Label(localizationManager.localized("layer_send_below_ink"), systemImage: "square.2.layers.3d.bottom.filled")
                            }
                            Divider()
                            Button {
                                reorder(textItem.id, .toFront)
                            } label: {
                                Label(localizationManager.localized("layer_bring_front"), systemImage: "arrow.up.to.line")
                            }
                            Button {
                                reorder(textItem.id, .toBack)
                            } label: {
                                Label(localizationManager.localized("layer_send_back"), systemImage: "arrow.down.to.line")
                            }
                            Button {
                                reorder(textItem.id, .forward)
                            } label: {
                                Label(localizationManager.localized("layer_bring_forward"), systemImage: "arrow.up")
                            }
                            Button {
                                reorder(textItem.id, .backward)
                            } label: {
                                Label(localizationManager.localized("layer_send_backward"), systemImage: "arrow.down")
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: isUnderInk ? "square.2.layers.3d.bottom.filled" : "square.2.layers.3d.top.filled")
                                    .font(.system(size: 11, weight: .bold))
                                Text(localizationManager.localized(isUnderInk ? "layer_send_below_ink" : "layer_bring_above_ink"))
                                    .font(.system(size: 11, weight: .semibold))
                                    .fixedSize()
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(isUnderInk ? Color.orange : Color.purple)
                            .cornerRadius(7)
                        }
                    }

                    if let clipboard {
                        textActionButton("scissors", "action_cut", .orange) { clipboard.cut(textItem.id) }
                            .accessibilityIdentifier("object.action.cut")
                        textActionButton("doc.on.doc", "action_copy", .teal) { clipboard.copy(textItem.id) }
                            .accessibilityIdentifier("object.action.copy")
                    }

                    // 邊框開關已移進「文字排版」面板的「樣式」分頁。
                    // 保留在畫布上的只有真正需要立即觸及的動作：編輯與刪除。
                    textActionButton("trash.fill", "delete", .red) { onDelete() }
                }
                .padding(4)
                .background(Color(uiColor: .systemBackground).opacity(0.95))
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.15), radius: 5, y: 2)
                .offset(x: 6, y: -42)

                // 原本這裡有一顆「雙向箭頭」縮放把手：它很小、會擋住文字、
                // 又只能改寬度，使用者反映沒必要。寬度改到「文字排版」裡調整，
                // 畫布上只保留編輯／邊框／刪除三個明確的動作。
            }

            // 🌟 頂部精準拖曳把手（膠囊造型 ≡），即使在就地打字中也能隨意拖拉換位排版
            if isSelected || isEditingInline {
                HStack {
                    Spacer()
                    HStack(spacing: 3) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 38, height: 16)
                    .background(Color(uiColor: .secondarySystemBackground).opacity(0.95))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.secondary.opacity(0.3), lineWidth: 0.8))
                    .shadow(color: Color.black.opacity(0.12), radius: 3, y: 1)
                    .contentShape(Rectangle())
                    .highPriorityGesture(
                        !CanvasTouchState.canDragObject ? nil :
                        DragGesture(minimumDistance: 1, coordinateSpace: .named(CanvasCoordinateSpace.name))
                            .onChanged { value in
                                guard lockedByPeer == nil else { return }
                                guard CanvasTouchState.canDragObject else {
                                    if isDragging {
                                        dragOffset = .zero
                                        isDragging = false
                                        pageCrossing?.ended(nil, nil)
                                    }
                                    return
                                }
                                if !isDragging { pageCrossing?.began() }
                                isDragging = true
                                var transaction = Transaction()
                                transaction.animation = nil
                                withTransaction(transaction) {
                                    dragOffset = value.translation
                                }
                            }
                            .onEnded { value in
                                guard lockedByPeer == nil else { return }
                                guard CanvasTouchState.canDragObject else {
                                    dragOffset = .zero
                                    isDragging = false
                                    pageCrossing?.ended(nil, nil)
                                    return
                                }
                                let oldX = textItem.x
                                let oldY = textItem.y
                                var crossedTo: Int?
                                var transaction = Transaction()
                                transaction.animation = nil
                                withTransaction(transaction) {
                                    let landed = PrintableArea.land(
                                        x: textItem.x + value.translation.width,
                                        y: textItem.y + value.translation.height,
                                        width: textItem.width, height: textItem.height,
                                        crossing: pageCrossing)
                                    textItem.x = landed.origin.x
                                    textItem.y = (snapToGrid && snapY != nil) ? snapY!(landed.origin.y) : landed.origin.y
                                    if let page = landed.page { textItem.pageIndex = page }
                                    crossedTo = landed.page
                                    dragOffset = .zero
                                    isDragging = false
                                }
                                let deltaX = textItem.x - oldX
                                let deltaY = textItem.y - oldY
                                if crossedTo == nil, deltaX != 0 || deltaY != 0 {
                                    onMoved?(CGSize(width: deltaX, height: deltaY))
                                }
                                onSelect?()
                                broadcastTextChange()
                                pageCrossing?.ended(crossedTo == nil ? nil : textItem.id, crossedTo)
                            }
                    )
                    Spacer()
                }
                .frame(width: displayWidth)
                .offset(y: (isSelected && !isEditingInline) ? -42 : -24)
            }
        }
        .objectProbe("text")
        .padding(20)
        .position(x: currentX + displayWidth / 2, y: currentY + calculatedContentHeight / 2)
        .animation(nil, value: dragOffset)
        // 方塊跟著內容長高（Word 的行為）。隨點即書的方塊一開始只有一行高，
        // 打到第二行時不長高的話，後面的字被方塊裁掉、看起來像「打了字沒出現」。
        // 內距固定 14（高度一律不小於 60），長高不會讓第一行跳離格線。
        .onChange(of: textItem.text) { newText in
            guard isEditingInline else { return }

            // 🌟 Markdown 前綴快捷排版（即打即轉）
            if newText == "# " {
                textItem.text = ""
                textItem.fontSize = 28
                textItem.isBold = true
            } else if newText == "## " {
                textItem.text = ""
                textItem.fontSize = 22
                textItem.isBold = true
            } else if newText == "### " {
                textItem.text = ""
                textItem.fontSize = 18
                textItem.isBold = true
            } else if newText == "- " || newText == "* " {
                textItem.text = "• "
            } else if newText == "1. " {
                textItem.text = "1. "
            } else if newText == "[] " || newText == "[ ] " {
                textItem.text = "☐ "
            } else if newText == "[x] " {
                textItem.text = "☑ "
            } else if newText == "> " {
                textItem.text = "│ "
            }

            // 快捷排版把整段字換掉了：舊的逐字格式對不上新內容，一併清掉。
            if textItem.text != newText, textItem.runs != nil {
                textItem.runs = nil
            }

            // 🌟 斜線快捷選單觸發
            if textItem.text == "/" {
                showSlashMenu = true
            } else if showSlashMenu && !textItem.text.hasPrefix("/") {
                showSlashMenu = false
            }

            let needed = RichText.boxHeight(for: textItem)
            // 有框線的方塊是使用者自己調過大小的：只在內容放不下時才加高，不縮小。
            // 沒有框線的（隨點即書）完全跟著內容，刪字會縮回去。
            if needed > textItem.height || (!textItem.hasBorder && needed < textItem.height) {
                textItem.height = needed
            }
        }
        .onChange(of: isEditingInline) { editing in
            if editing {
                hasBeenFocused = false
            } else {
                inlineFocused = false
                hasBeenFocused = false
                finishEditing()
            }
        }
        .onChange(of: inlineFocused) { focused in
            if focused {
                hasBeenFocused = true
            } else if hasBeenFocused && isEditingInline {
                isEditingInline = false
                hasBeenFocused = false
                finishEditing()
            }
        }
        // 快顯選單、語音轉錄和一般點擊進來的時機不同。先 yield 讓 TextField
        // 掛進視圖樹，再給 UIKit 一小段時間安裝 responder；第一次仍未成功時
        // 再要求一次，避免鍵盤時有時無。
        .task(id: isEditingInline) {
            guard isEditingInline else { return }
            hasBeenFocused = false
            await Task.yield()
            inlineFocused = true
            try? await Task.sleep(nanoseconds: 80_000_000)
            guard isEditingInline, !hasBeenFocused else { return }
            inlineFocused = false
            await Task.yield()
            inlineFocused = true
        }
    }

    private func finishEditing() {
        broadcastTextChange()
    }

    private func broadcastTextChange() {
        if let data = try? JSONEncoder().encode(textItem),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            collaborationManager.broadcastAttachmentUpsert(type: "text", itemDict: dict)
        }
    }

    /// 解析方框底色。`nil` 是舊檔沒有這個欄位（回落成白色），
    /// `"clear"` 是使用者主動選了透明 —— 兩者不一樣，不能混為一談。
    private func resolveBackground(_ hex: String?) -> Color {
        guard let hex else { return .white }
        if hex == "clear" { return .clear }
        return Color(hex: hex) ?? .white
    }

    private func resolveAlignment(_ raw: String) -> HorizontalAlignment {
        switch raw {
        case "center": return .center
        case "right": return .trailing
        default: return .leading
        }
    }

    private func resolveMultilineAlignment(_ raw: String) -> TextAlignment {
        switch raw {
        case "center": return .center
        case "right": return .trailing
        default: return .leading
        }
    }

    private func resolveFrameAlignment(_ raw: String) -> Alignment {
        switch raw {
        case "center": return .center
        case "right": return .trailing
        default: return .leading
        }
    }
}

/// 畫布內嵌 Rich Link 預覽卡片視圖
struct LinkAttachmentItemView: View {
    @ObservedObject var localizationManager = LocalizationManager.shared
    @Binding var linkItem: NoteLinkAttachment
    var isSelected: Bool = false
    var onSelect: (() -> Void)? = nil
    let onDelete: () -> Void

    @Environment(\.pageCrossing) private var pageCrossing
    @State private var dragOffset: CGSize = .zero
    /// 縮放拖曳中的即時尺寸。直接改 linkItem.width 會每一幀都寫回筆記。
    @State private var liveSize: CGSize? = nil
    @State private var resizeBase: CGSize? = nil
    @State private var isEditing: Bool = false

    private var displayWidth: CGFloat { liveSize?.width ?? linkItem.width }
    private var displayHeight: CGFloat { liveSize?.height ?? linkItem.height }

    var body: some View {
        let currentX = linkItem.x + dragOffset.width
        let currentY = linkItem.y + dragOffset.height

        card
            // 卡片本體跟著轉；把手掛在旋轉**外面**的 overlay ——
            // 包進去的話拖曳算出的角度會疊加自身旋轉，卡片會失控加速。
            .rotationEffect(.degrees(linkItem.canvasRotation))
            .contextMenu {
                ObjectOrderMenu(id: linkItem.id)
                Divider()
                Button(role: .destructive, action: onDelete) {
                    Label(localizationManager.localized("delete"), systemImage: "trash")
                }
            }
            .overlay {
                if isSelected {
                    GeometryReader { geo in
                        ObjectRotationHandle(degrees: $linkItem.canvasRotation, size: geo.size)
                    }
                }
            }
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color.red)
                    }
                    .buttonStyle(.plain)
                    .offset(x: 10, y: -10)
                    .accessibilityLabel(localizationManager.localized("action_delete"))
                }
            }
            // 右下角縮放把手。卡片原本只能用插入時的寬度，標題長一點就被截掉。
            .overlay(alignment: .bottomTrailing) {
                if isSelected { resizeHandle }
            }
            // 左下角編修鈕：網址、標題與說明都存在模型裡，但在這一版之前
            // 沒有任何介面改得到 —— 打錯一個字只能刪掉重插。
            .overlay(alignment: .bottomLeading) {
                if isSelected {
                    Button { isEditing = true } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 30, height: 30)
                            .background(Color.accentColor)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .contentShape(Circle())
                    .offset(x: -10, y: 10)
                    .accessibilityLabel(localizationManager.localized("link_edit"))
                    .help(localizationManager.localized("link_edit"))
                }
            }
            .highPriorityGesture(
                (!isSelected || !CanvasTouchState.canDragObject) ? nil :
                DragGesture(minimumDistance: 4, coordinateSpace: .named(CanvasCoordinateSpace.name))
                    .onChanged { value in
                        guard CanvasTouchState.canDragObject else {
                            dragOffset = .zero
                            pageCrossing?.ended(nil, nil)
                            return
                        }
                        if dragOffset == .zero { pageCrossing?.began() }
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        guard CanvasTouchState.canDragObject else {
                            dragOffset = .zero
                            pageCrossing?.ended(nil, nil)
                            return
                        }
                        var crossedTo: Int?
                        if hypot(value.translation.width, value.translation.height) < 4 {
                            onSelect?()
                        } else {
                            // 拖出可列印範圍的物件推回邊界（S-85）；連續模式下拖到哪一頁就歸哪一頁。
                            let landed = PrintableArea.land(
                                x: linkItem.x + value.translation.width,
                                y: linkItem.y + value.translation.height,
                                width: linkItem.width, height: linkItem.height,
                                crossing: pageCrossing)
                            var updated = linkItem
                            updated.x = landed.origin.x
                            updated.y = landed.origin.y
                            if let page = landed.page { updated.pageIndex = page }
                            linkItem = updated
                            crossedTo = landed.page
                            onSelect?()
                        }
                        dragOffset = .zero
                        pageCrossing?.ended(crossedTo == nil ? nil : linkItem.id, crossedTo)
                    }
            )
            .onTapGesture { onSelect?() }
            .objectProbe("link")
            .padding(20)
        .position(x: currentX + displayWidth / 2, y: currentY + displayHeight / 2)
        .animation(nil, value: dragOffset)
            .sheet(isPresented: $isEditing) { resizableSheet {
                LinkAttachmentEditSheet(linkItem: $linkItem)
            } }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .font(.caption)
                    .foregroundColor(.accentColor)
                Text(linkItem.siteName.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()

                // 開啟連結外鏈圖示
                Button {
                    if let url = URL(string: linkItem.urlString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 3) {
                        Text(localizationManager.localized("open"))
                            .font(.system(size: 10, weight: .medium))
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }

            Text(linkItem.title)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(2)
                .foregroundColor(.primary)

            if !linkItem.descriptionText.isEmpty {
                Text(linkItem.descriptionText)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        // 高度也照模型走。原本只綁寬度、位置用寫死的 +50 推算中心 ——
        // 卡片一變高，選取框、把手與實際內容就對不上。
        .frame(width: displayWidth, height: displayHeight, alignment: .topLeading)
        .background(ObjectFrameStyleResolver.background(linkItem, .link))
        .cornerRadius(linkItem.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: linkItem.cornerRadius)
                .stroke(
                    isSelected ? Color.accentColor
                               : ObjectFrameStyleResolver.borderColor(linkItem, .link),
                    lineWidth: isSelected ? 1.5
                                          : ObjectFrameStyleResolver.borderWidth(linkItem, .link)
                )
        )
        .shadow(color: Color.black.opacity(0.08), radius: 6, y: 3)
        .contentShape(Rectangle())
    }

    private var resizeHandle: some View {
        Image(systemName: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 30, height: 30)
            .background(Color.accentColor)
            .clipShape(Circle())
            .contentShape(Circle())
            .offset(x: 10, y: 10)
            .accessibilityLabel(localizationManager.localized("resize_link"))
            .help(localizationManager.localized("resize_link"))
            .highPriorityGesture(
                DragGesture(minimumDistance: 1,
                            coordinateSpace: .named(CanvasCoordinateSpace.name))
                    .onChanged { value in
                        let base = resizeBase ?? CGSize(width: linkItem.width, height: linkItem.height)
                        if resizeBase == nil { resizeBase = base }
                        // 下限取卡片還讀得出東西的尺寸：再小就只剩邊框。
                        liveSize = CGSize(
                            width: max(140, base.width + value.translation.width),
                            height: max(64, base.height + value.translation.height)
                        )
                    }
                    .onEnded { _ in
                        if let size = liveSize {
                            linkItem.width = size.width
                            linkItem.height = size.height
                        }
                        resizeBase = nil
                        liveSize = nil
                    }
            )
    }
}

/// 連結卡片的編修表單。
///
/// 網址、標題、說明與站名四個欄位一直都在模型裡、也一直跟著同步走，
/// 但在這一版之前沒有任何介面改得到它們 —— 解析錯一次就只能刪掉重插。
struct LinkAttachmentEditSheet: View {
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss
    @Binding var linkItem: NoteLinkAttachment

    var body: some View {
        NavigationStack {
            Form {
                Section(localizationManager.localized("insert_link")) {
                    TextField(localizationManager.localized("link_url_hint"), text: $linkItem.urlString)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                }
                Section(localizationManager.localized("link_title")) {
                    TextField(localizationManager.localized("link_title"), text: $linkItem.title)
                }
                Section(localizationManager.localized("link_description")) {
                    TextField(localizationManager.localized("link_description"),
                              text: $linkItem.descriptionText, axis: .vertical)
                        .lineLimit(2...5)
                }
                Section(localizationManager.localized("link_site_name")) {
                    TextField(localizationManager.localized("link_site_name"), text: $linkItem.siteName)
                }
            }
            .navigationTitle(localizationManager.localized("link_edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(localizationManager.localized("done")) { dismiss() }
                }
            }
        }
    }
}

/// 畫布內嵌 3D 幾何模型互動項目視圖

/// 插入物件共用的外框樣式解析（SwiftUI 端）。
///
/// 匯出端有一份等價的實作（`PageThumbnailRenderer.FrameDefaults`）。兩邊必須
/// 給出同樣的結果 —— 否則「畫布所見」與「匯出所得」又會分家。差異用
/// `ObjectFrameStyleTests` 釘住。
enum ObjectFrameStyleResolver {
    struct Defaults {
        var borderColor: Color
        var borderWidth: CGFloat
        /// `nil` 代表這個型別原本就沒有底色。
        var background: Color?

        static let image = Defaults(
            borderColor: .accentColor.opacity(0.8), borderWidth: 2.5, background: nil)
        static let text = Defaults(
            borderColor: .accentColor.opacity(0.5), borderWidth: 1.5, background: .white)
        static let link = Defaults(
            borderColor: Color(UIColor.separator), borderWidth: 1,
            background: Color(UIColor.tertiarySystemBackground))
        static let model3D = Defaults(
            borderColor: .accentColor.opacity(0.45), borderWidth: 1.5,
            background: Color(UIColor.secondarySystemBackground))
        static let audio = Defaults(
            borderColor: .red.opacity(0.35), borderWidth: 1.5,
            background: Color(UIColor.secondarySystemGroupedBackground))
    }

    /// 底色。`nil`（舊檔沒這欄位）回落預設；`"clear"` 是使用者選的透明。
    static func background(_ style: some ObjectFrameStyled, _ defaults: Defaults) -> Color {
        guard let hex = style.backgroundColorHex else { return defaults.background ?? .clear }
        if hex == "clear" { return .clear }
        return Color(hex: hex) ?? defaults.background ?? .clear
    }

    static func borderColor(_ style: some ObjectFrameStyled, _ defaults: Defaults) -> Color {
        guard style.hasBorder else { return .clear }
        return style.borderColorHex.flatMap { Color(hex: $0) } ?? defaults.borderColor
    }

    static func borderWidth(_ style: some ObjectFrameStyled, _ defaults: Defaults) -> CGFloat {
        style.hasBorder ? (style.borderWidth ?? defaults.borderWidth) : 0
    }
}

struct Model3DCanvasItemView: View {
    @ObservedObject var localizationManager = LocalizationManager.shared
    @ObservedObject var collaborationManager = CollaborationManager.shared
    @Binding var item: Note3DAttachment
    var isSelected: Bool = false
    var onSelect: (() -> Void)? = nil
    let onDelete: () -> Void

    @Environment(\.pageCrossing) private var pageCrossing
    @State private var dragOffset: CGSize = .zero

    private var lockedByPeer: CollaboratorPeer? {
        // 租約有效（5 秒內有續約）而且對方勝出才算鎖住 —— 對方當機時物件不會永遠鎖住。
        collaborationManager.leaseHolder(for: item.id)
    }

    var body: some View {
        let currentX = item.x + dragOffset.width
        let currentY = item.y + dragOffset.height

        VStack(spacing: 0) {
            // 移動拖曳手把條（與 3D 旋轉手勢分離，方便自由平移卡片）
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text(localizationManager.localized("drag_card_hint"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()

                // 遠端成員軟鎖定中提示
                if let peer = lockedByPeer {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(hex: peer.userColor) ?? .blue)
                            .frame(width: 7, height: 7)
                        Text("\(peer.userName) \(localizationManager.localized("object_locked_by"))")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: peer.userColor)?.opacity(0.95) ?? Color.blue)
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(UIColor.tertiarySystemBackground))
            .cornerRadius(8)
            .contentShape(Rectangle())
            .highPriorityGesture(
                (!isSelected || !CanvasTouchState.canDragObject) ? nil :
                DragGesture(minimumDistance: 4, coordinateSpace: .named(CanvasCoordinateSpace.name))
                    .onChanged { value in
                        guard lockedByPeer == nil, CanvasTouchState.canDragObject else {
                            dragOffset = .zero
                            pageCrossing?.ended(nil, nil)
                            return
                        }
                        if dragOffset == .zero { pageCrossing?.began() }
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        guard lockedByPeer == nil, CanvasTouchState.canDragObject else {
                            dragOffset = .zero
                            pageCrossing?.ended(nil, nil)
                            return
                        }
                        // 拖出可列印範圍的物件推回邊界（S-85）；連續模式下拖到哪一頁就歸哪一頁。
                        let landed = PrintableArea.land(
                            x: item.x + value.translation.width,
                            y: item.y + value.translation.height,
                            width: item.width, height: item.height,
                            crossing: pageCrossing)
                        var updated = item
                        updated.x = landed.origin.x
                        updated.y = landed.origin.y
                        if let page = landed.page { updated.pageIndex = page }
                        item = updated
                        dragOffset = .zero
                        pageCrossing?.ended(landed.page == nil ? nil : item.id, landed.page)
                        onSelect?()
                        if let data = try? JSONEncoder().encode(item),
                           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            collaborationManager.broadcastAttachmentUpsert(type: "3d", itemDict: dict)
                        }
                    }
            )

            Model3DInteractiveCardView(
                attachment: $item,
                onDelete: onDelete,
                // 拖卡片本體 = 移動，與畫布上其他每一種物件一致。
                // （旋轉改成卡片右上角那顆鈕先開啟。）
                onMove: { translation in
                    if dragOffset == .zero { pageCrossing?.began() }
                    dragOffset = translation
                },
                onMoveEnded: {
                    // 與頂部手把那條路同一個落點規則（S-85：拖出可列印範圍要推回；連續模式可換頁）。
                    let landed = PrintableArea.land(
                        x: item.x + dragOffset.width,
                        y: item.y + dragOffset.height,
                        width: item.width, height: item.height,
                        crossing: pageCrossing)
                    var updated = item
                    updated.x = landed.origin.x
                    updated.y = landed.origin.y
                    if let page = landed.page { updated.pageIndex = page }
                    item = updated
                    dragOffset = .zero
                    pageCrossing?.ended(landed.page == nil ? nil : item.id, landed.page)
                    onSelect?()
                    if let data = try? JSONEncoder().encode(item),
                       let dict = try? JSONSerialization.jsonObject(with: data)
                        as? [String: Any] {
                        collaborationManager.broadcastAttachmentUpsert(type: "3d", itemDict: dict)
                    }
                }
            )
            .onTapGesture {
                onSelect?()
            }
            // 底色與邊框吃使用者的設定。原本是寫死的 —— 那表示「所有插入的
            // 東西都能調外框」這件事在 3D 模型上是假的。
            .background(
                RoundedRectangle(cornerRadius: item.cornerRadius)
                    .fill(ObjectFrameStyleResolver.background(item, .model3D))
            )
            .overlay(
                RoundedRectangle(cornerRadius: item.cornerRadius)
                    .stroke(
                        isSelected ? Color.accentColor : ObjectFrameStyleResolver.borderColor(item, .model3D),
                        lineWidth: isSelected ? 1.5 : ObjectFrameStyleResolver.borderWidth(item, .model3D)
                    )
            )
            .overlay(
                Group {
                    if let peer = lockedByPeer {
                        RoundedRectangle(cornerRadius: item.cornerRadius)
                            .stroke(Color(hex: peer.userColor) ?? .blue, lineWidth: 3)
                    }
                }
            )
            .contextMenu {
                ObjectFrameStyleMenu(style: $item)
                ObjectOrderMenu(id: item.id)
                Divider()
                Button(role: .destructive, action: onDelete) {
                    Label(localizationManager.localized("delete"), systemImage: "trash")
                }
            }
            // **右下角的縮放把手。**
            //
            // 在此之前 3D 卡片**完全沒有縮放**：圖片、表格、圖表都有四角
            // 把手，只有它沒有，而卡片寬度寫死在 `.frame(width:)` 裡。
            // 使用者回報的「插入 3D 模型後無法改變大小」就是這一項 ——
            // 那不是他沒找到，是真的沒有。
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Circle().fill(Color.accentColor))
                    .offset(x: 6, y: 6)
                    // **要先變成一個無障礙元素，識別字才有東西可以掛。**
                    //
                    // 這是一張沒有標籤的 `Image`，SwiftUI 不會把它當成元素，
                    // 於是 `.accessibilityIdentifier` 掛了等於沒掛 —— 稽核
                    // 在樹裡一個 `model3d.*` 都找不到，訊息說「模型上沒有
                    // 縮放把手」，而把手其實畫得好好的（截圖裡看得見）。
                    //
                    // 這不只是測試看不到：**VoiceOver 的使用者也碰不到它**，
                    // 所以那是真的缺陷，不是測試的毛病。
                    .accessibilityElement()
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel(localizationManager.localized("resize"))
                    .accessibilityIdentifier("model3d.resize")
                    .gesture(
                        DragGesture(minimumDistance: 2)
                            .onChanged { value in
                                // 下限與卡片本身的 `max(200, ...)` 對齊 ——
                                // 不對齊的話縮到最小時把手會跑到卡片外面。
                                item.width = max(200, item.width + value.translation.width)
                                item.height = max(160, item.height + value.translation.height)
                            }
                            .onEnded { _ in
                                if let data = try? JSONEncoder().encode(item),
                                   let dict = try? JSONSerialization.jsonObject(with: data)
                                    as? [String: Any] {
                                    collaborationManager.broadcastAttachmentUpsert(
                                        type: "3d", itemDict: dict)
                                }
                            }
                    )
            }
        }
        .frame(width: max(200, item.width))
        .objectProbe("model3d")
        .padding(20)
        .position(x: currentX + item.width / 2, y: currentY + item.height / 2)
        .animation(nil, value: dragOffset)
    }
}

/// 移動筆記至指定資料夾彈窗
public struct MoveNotebookSheet: View {
    public let notebookId: String
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store = NotebookStore.shared
    @ObservedObject var localizationManager = LocalizationManager.shared

    public init(notebookId: String) {
        self.notebookId = notebookId
    }

    public var body: some View {
        NavigationStack {
            List {
                Section(header: Text(localizationManager.localized("select_destination_folder"))) {
                    // 最上層根資料夾
                    Button {
                        store.moveNotebook(id: notebookId, toFolderId: nil)
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "tray.2.fill")
                                .foregroundColor(.accentColor)
                            Text("\(store.displayRootFolderName) (\(localizationManager.localized("root_folder")))")
                                .foregroundColor(.primary)
                            Spacer()
                            if let note = store.notebooks.first(where: { $0.id == notebookId }), note.folderId == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }

                    // 自訂資料夾清單
                    ForEach(store.folders) { folder in
                        Button {
                            store.moveNotebook(id: notebookId, toFolderId: folder.id)
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: folder.parentId == nil ? "folder.fill" : "folder.badge.gearshape")
                                    .foregroundColor(folder.parentId == nil ? .accentColor : .secondary)
                                Text(folder.displayName)
                                    .foregroundColor(.primary)
                                    .padding(.leading, folder.parentId == nil ? 0 : 16)
                                Spacer()
                                if let note = store.notebooks.first(where: { $0.id == notebookId }), note.folderId == folder.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(localizationManager.localized("move_to_folder"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizationManager.localized("cancel")) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// 遠端協同成員即時游標浮動圖層（平滑動畫、具名標籤與筆尖狀態指示）
struct RemoteCursorsOverlay: View {
    @ObservedObject var collaborationManager = CollaborationManager.shared

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(collaborationManager.peers) { peer in
                if let cursor = peer.cursor {
                    HStack(alignment: .top, spacing: 3) {
                        // 游標 / 筆尖指示圖示
                        Image(systemName: cursor.isDrawing ? "pencil.tip" : "cursorarrow.rays")
                            .font(.system(size: cursor.isDrawing ? 14 : 12, weight: .bold))
                            .foregroundColor(Color(hex: peer.userColor) ?? .accentColor)
                            .shadow(color: Color.black.opacity(0.2), radius: 2, y: 1)

                        // 成員姓名徽章
                        HStack(spacing: 3) {
                            Text(peer.userName)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            if cursor.isDrawing {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 4, height: 4)
                            }
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color(hex: peer.userColor) ?? .accentColor)
                        .cornerRadius(4)
                        .shadow(color: Color.black.opacity(0.15), radius: 3, y: 1)
                    }
                    .position(x: cursor.x, y: cursor.y)
                    .animation(.spring(response: 0.15, dampingFraction: 0.8), value: cursor.x)
                    .animation(.spring(response: 0.15, dampingFraction: 0.8), value: cursor.y)
                }
            }
        }
        .allowsHitTesting(false)
    }
}
