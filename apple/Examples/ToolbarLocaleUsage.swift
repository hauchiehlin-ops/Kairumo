import SwiftUI

/// 工具列與語言切換的 Apple UI 範例（S-53）。
///
/// Rust core 只提供工具分組、可見性與在地化標籤；實際的按鈕、Picker、
/// Sheet 與偏好儲存都應留在平台層，才能符合 iPadOS/macOS 的互動慣例。
struct EditorToolbarView: View {
    @StateObject private var model: EditorToolbarModel

    init(initialLocaleTag: String) {
        _model = StateObject(wrappedValue: EditorToolbarModel(localeTag: initialLocaleTag))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ForEach(model.groups, id: \.group) { group in
                    HStack(spacing: 4) {
                        ForEach(group.tools, id: \.tool) { tool in
                            Button {
                                model.select(tool.tool)
                            } label: {
                                Image(systemName: symbol(for: tool.tool))
                                    .frame(width: 32, height: 32)
                            }
                            .help(tool.label)
                        }
                    }

                    if group.group != model.groups.last?.group {
                        Divider().frame(height: 26)
                    }
                }

                Spacer(minLength: 12)

                Picker("", selection: $model.locale) {
                    ForEach(model.locales, id: \.tag) { info in
                        Text(info.endonym).tag(info.locale)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 140)
                .onChange(of: model.locale) { _, locale in
                    model.setLocale(locale)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.regularMaterial)
        }
    }

    private func symbol(for tool: FfiTool) -> String {
        switch tool {
        case .fountainPen: return "pencil.tip"
        case .ballPoint: return "pencil.line"
        case .highlighter: return "highlighter"
        case .pencil: return "pencil"
        case .eraser: return "eraser"
        case .lasso: return "lasso"
        case .text: return "textformat"
        case .image: return "photo"
        case .shape: return "square.on.circle"
        case .table: return "tablecells"
        case .embed: return "paperclip"
        case .undo: return "arrow.uturn.backward"
        case .redo: return "arrow.uturn.forward"
        case .ruler: return "ruler"
        case .shapeRecognition: return "sparkles"
        case .zoomWrite: return "rectangle.inset.filled.and.person.filled"
        case .laserPointer: return "laser.burst"
        case .record: return "record.circle"
        }
    }
}

final class EditorToolbarModel: ObservableObject {
    @Published var locale: FfiLocale
    @Published private(set) var groups: [FfiToolGroupInfo] = []

    let locales: [FfiLocaleInfo]
    private let toolbar: FfiToolbar
    private(set) var selectedTool: FfiTool = .fountainPen

    init(localeTag: String) {
        let initial = localeForTag(tag: localeTag)
        locale = initial
        locales = supportedLocales()
        toolbar = FfiToolbar.new(locale: initial)
        reload()
    }

    func setLocale(_ locale: FfiLocale) {
        toolbar.setLocale(locale: locale)
        reload()
    }

    func select(_ tool: FfiTool) {
        selectedTool = tool
    }

    func setVisible(_ tool: FfiTool, visible: Bool) {
        toolbar.setVisible(tool: tool, visible: visible)
        reload()
        UserDefaults.standard.set(toolbar.toJson(), forKey: "kairumo.toolbar")
    }

    private func reload() {
        groups = toolbar.visibleGroups()
    }
}
