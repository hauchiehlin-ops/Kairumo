import SwiftUI

struct AdvancedPenSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var settings = PenHardwareSettings.shared

    private let controls: [(FfiPenControl, String)] = [
        (.doubleTap, "pen_double_tap"),
        (.squeeze, "pen_squeeze")
    ]
    
    private let actions: [(FfiPenAction, String)] = [
        (.none, "pen_action_none"),
        (.eraser, "pen_action_eraser"),
        (.lastBrush, "pen_action_lastBrush"),
        (.inkAttributes, "pen_action_inkAttributes"),
        (.lasso, "pen_action_lasso"),
        (.undo, "pen_action_undo"),
        (.redo, "pen_action_redo"),
        (.ruler, "pen_action_ruler")
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(LocalizationManager.shared.localized("pen_pressure_apple_note"))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text(LocalizationManager.shared.localized("pen_controls_title"))) {
                    ForEach(controls, id: \.0.hashValue) { control, labelKey in
                        Picker(LocalizationManager.shared.localized(labelKey), selection: Binding(
                            get: { settings.action(for: control) },
                            set: { settings.setAction($0, for: control) }
                        )) {
                            ForEach(actions, id: \.0.hashValue) { action, actionLabelKey in
                                Text(LocalizationManager.shared.localized(actionLabelKey)).tag(action)
                            }
                        }
                    }
                }
            }
            .navigationTitle(LocalizationManager.shared.localized("pen_settings_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizationManager.shared.localized("done")) { dismiss() }
                }
            }
        }
    }
}
