import SwiftUI

struct MenuBarContentView: View {
    @EnvironmentObject private var store: DataStore

    var body: some View {
        if store.providers.isEmpty {
            Text("No connections configured")
                .foregroundColor(.secondary)
        } else {
            ForEach(store.providers) { provider in
                ProviderMenuSection(provider: provider)
            }
        }

        Divider()

        Button("Search…") {
            SearchWindowController.shared.open(store: store)
        }
        .keyboardShortcut("f", modifiers: .command)

        Divider()

        Button("Connections…") {
            ConnectionsWindowController.shared.open(store: store)
        }
        .keyboardShortcut("k", modifiers: .command)

        Button("Settings…") {
            SettingsWindowController.shared.open(store: store)
        }
        .keyboardShortcut(",", modifiers: .command)

        Button("About ShuttleClaude") {
            AboutWindowController.shared.open()
        }

        Divider()

        Button("Export Data…") {
            store.exportData()
        }

        Button("Import Data…") {
            store.importData()
        }

        Divider()

        Button("Quit ShuttleClaude") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}
