import SwiftUI

private enum SettingsSection: String, CaseIterable, Identifiable {
    case general = "General", appearance = "Appearance", shortcuts = "Shortcuts"
    case cloud = "Cloud Account"
    case window = "Window", storage = "Storage", about = "About"
    var id: Self { self }
}

/// Present shared preferences in the app's native Settings window.
struct AppSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var store: AppSettingsStore
    let account: CloudAccountStore
    let transfers: CloudTransferStore
    let fileStore: ProjectFileStore
    let maintenance: RecoveryMaintenanceCoordinator
    var cloudPrimary = false
    @State private var selection: SettingsSection? = .general

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $selection) { section in
                Text(section.rawValue).tag(section)
            }
            .navigationSplitViewColumnWidth(150)
        } detail: {
            ScrollView {
                settingsContent
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppSpacing.pageInset)
            }
        }
        .frame(width: 780, height: 480)
        .onChange(of: account.isSignedIn) { wasSignedIn, isSignedIn in
            if wasSignedIn && !isSignedIn { dismiss() }
        }
    }

    @ViewBuilder
    private var settingsContent: some View {
        switch selection ?? .general {
        case .general:
            Form {
                Toggle("Autosave", isOn: $store.settings.autosaveEnabled)
                    .accessibilityIdentifier("autosaveEnabled")
                Picker("Autosave delay", selection: $store.settings.autosaveDelay) {
                    ForEach(AutosaveDelay.allCases) { delay in
                        Text("\(delay.rawValue) seconds").tag(delay)
                    }
                }
                .disabled(!store.settings.autosaveEnabled)
                Toggle("Confirm before deleting projects", isOn: $store.settings.confirmBeforeDelete)
                Toggle("Ask before restoring recovery drafts", isOn: $store.settings.showRecoveryPrompt)
                Text("When the recovery prompt is off, available drafts are restored automatically.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Restore Defaults") { store.restoreDefaults() }
            }
        case .appearance:
            Picker("Appearance", selection: $store.settings.appearance) {
                ForEach(AppAppearance.allCases) { appearance in
                    Text(appearance.rawValue.capitalized).tag(appearance)
                }
            }
            .pickerStyle(.radioGroup)
        case .shortcuts:
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                Text("Keyboard Shortcuts").font(.title2.bold())
                shortcut("New Project", "⌘N")
                shortcut("Open Project Browser", "⌘O")
                shortcut("Save Report", "⌘S")
                shortcut("Preview Report", "⌘P")
                shortcut("Export Report", "⌘E")
                shortcut("Validate Report", "⇧⌘A")
                shortcut("Settings", "⌘,")
                Text("Shortcuts are fixed. Editor actions are available when a report is open.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        case .window:
            Form {
                Toggle("Restore workspace after unexpected termination",
                       isOn: $store.settings.restoreWorkspaceAfterInterruption)
                Text("Normal launches open the Project Browser. After an unexpected termination, reopen the last project if it is available.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        case .cloud:
            CloudAccountView(account: account, transfers: transfers, cloudPrimary: cloudPrimary)
        case .storage:
            StorageSettingsView(store: fileStore, maintenance: maintenance)
        case .about:
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                Text("Project Reporting Builder").font(.title2.bold())
                Text("Create, preview, and share structured project reports.")
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unavailable")
                LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unavailable")
            }
        }
    }

    private func shortcut(_ title: String, _ keys: String) -> some View {
        LabeledContent(title, value: keys)
    }
}
