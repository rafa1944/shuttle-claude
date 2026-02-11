import AppKit
import SwiftUI

private class EscapableWindow: NSWindow {
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            close()
        } else {
            super.keyDown(with: event)
        }
    }
}

@MainActor
final class ConnectionsWindowController {
    static let shared = ConnectionsWindowController()
    var store: DataStore?

    private var window: NSWindow?

    func open(store: DataStore) {
        self.store = store

        if let window = window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let connectionsView = DataManagementView()
            .environmentObject(store)

        let hostingView = NSHostingView(rootView: connectionsView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 750, height: 500)

        let window = EscapableWindow(
            contentRect: NSRect(x: 0, y: 0, width: 750, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Connections"
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)

        self.window = window

        NSApp.activate(ignoringOtherApps: true)
    }
}
