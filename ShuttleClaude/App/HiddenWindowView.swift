import SwiftUI

struct HiddenWindowView: View {
    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onReceive(NotificationCenter.default.publisher(for: .openSettingsRequest)) { _ in
                openSettingsWindow()
            }
    }

    private func openSettingsWindow() {
        if #available(macOS 14.0, *) {
            // On macOS 14+, we can't use @Environment(\.openSettings) outside a direct view hierarchy,
            // so fall through to the legacy approach which still works.
        }
        // Works on macOS 13+: use the legacy selector
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
