import SwiftUI
import ServiceManagement
import KeyboardShortcuts

struct GeneralSettingsView: View {
    @EnvironmentObject private var store: DataStore
    @State private var customPath: String = ""
    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            }

            Section("Global Shortcut") {
                HStack {
                    Text("Open Search")
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .openSearch)
                }
            }

            Section("Connection") {
                Toggle("Copy sudo password on connect", isOn: Binding(
                    get: { store.settings.copySudoOnConnect },
                    set: { store.updateCopySudoOnConnect($0) }
                ))
            }

            Section("Terminal Application") {
                ForEach(TerminalApp.allCases) { terminal in
                    HStack {
                        Image(systemName: store.settings.terminalApp == terminal
                              ? "largecircle.fill.circle"
                              : "circle")
                            .foregroundColor(store.settings.terminalApp == terminal ? .accentColor : .secondary)

                        Text(terminal.displayName)

                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        store.updateTerminal(terminal)
                    }
                }
            }

            if store.settings.terminalApp == .custom {
                Section("Custom Terminal") {
                    TextField("Application name or path (e.g. MyTerminal)", text: $customPath)
                        .textFieldStyle(.roundedBorder)
                        .onAppear {
                            customPath = store.settings.customTerminalPath ?? ""
                        }
                        .onChange(of: customPath) { newValue in
                            store.updateCustomTerminalPath(newValue.isEmpty ? nil : newValue)
                        }
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 400, minHeight: 300)
    }
}
