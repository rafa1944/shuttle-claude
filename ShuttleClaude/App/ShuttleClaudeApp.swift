import SwiftUI

@main
struct ShuttleClaudeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var store: DataStore

    init() {
        let dataStore = DataStore()
        _store = StateObject(wrappedValue: dataStore)
        AppDelegate.sharedStore = dataStore
    }

    var body: some Scene {
        MenuBarExtra("ShuttleClaude", systemImage: "terminal") {
            MenuBarContentView()
                .environmentObject(store)
        }
        .menuBarExtraStyle(.menu)
    }
}
