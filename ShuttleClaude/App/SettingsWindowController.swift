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
final class SettingsWindowController {
    static let shared = SettingsWindowController()
    var store: DataStore?

    private var window: NSWindow?

    func open(store: DataStore) {
        self.store = store

        if let window = window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = GeneralSettingsView()
            .environmentObject(store)
            .frame(width: 450, height: 520)

        let hostingView = NSHostingView(rootView: settingsView)

        let window = EscapableWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.contentView = hostingView
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let windowSize = NSSize(width: 450, height: 520)
        let origin = NSPoint(
            x: screenFrame.midX - windowSize.width / 2,
            y: screenFrame.midY - windowSize.height / 2
        )
        window.setFrame(NSRect(origin: origin, size: windowSize), display: true)

        self.window = window

        NSApp.activate(ignoringOtherApps: true)
    }
}
