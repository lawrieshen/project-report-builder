import SwiftUI

/// Expose actions only from the focused editing scene.
struct ReportActions {
    var newProject: (() -> Void)?
    var openProject: (() -> Void)?
    var save: (() -> Void)?
    var preview: (() -> Void)?
    var export: (() -> Void)?
    var accessibility: (() -> Void)?
}

private struct ReportActionsKey: FocusedValueKey {
    typealias Value = ReportActions
}

extension FocusedValues {
    var reportActions: ReportActions? {
        get { self[ReportActionsKey.self] }
        set { self[ReportActionsKey.self] = newValue }
    }
}

struct AppCommands: Commands {
    @FocusedValue(\.reportActions) private var actions

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Project") { actions?.newProject?() }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(actions?.newProject == nil)
            Button("Open Project Browser") { actions?.openProject?() }
                .keyboardShortcut("o", modifiers: .command)
                .disabled(actions?.openProject == nil)
            Divider()
            Button("Close Window") { NSApp.keyWindow?.performClose(nil) }
                .keyboardShortcut("w", modifiers: .command)
        }
        CommandGroup(replacing: .saveItem) {
            Button("Save Report") { actions?.save?() }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(actions?.save == nil)
        }
        CommandGroup(replacing: .printItem) {
            Button("Preview Report") { actions?.preview?() }
                .keyboardShortcut("p", modifiers: .command)
                .disabled(actions?.preview == nil)
            Button("Export Report…") { actions?.export?() }
                .keyboardShortcut("e", modifiers: .command)
                .disabled(actions?.export == nil)
            Button("Validate Accessibility") { actions?.accessibility?() }
                .keyboardShortcut("a", modifiers: [.command, .shift])
                .disabled(actions?.accessibility == nil)
        }
    }
}
