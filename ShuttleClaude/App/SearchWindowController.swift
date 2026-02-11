import AppKit
import SwiftUI

@MainActor
final class SearchWindowController {
    static let shared = SearchWindowController()

    private var window: NSWindow?

    func open(store: DataStore) {
        if let window = window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let searchView = SearchView()
            .environmentObject(store)

        let hostingView = NSHostingView(rootView: searchView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 400, height: 350)

        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 350),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Search Connections"
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.makeKeyAndOrderFront(nil)

        self.window = window

        NSApp.activate(ignoringOtherApps: true)

        // Focus the search field after the window is fully set up
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            window.makeKey()
            if let contentView = window.contentView {
                self.focusTextField(in: contentView)
            }
        }
    }

    private func focusTextField(in view: NSView) {
        for subview in view.subviews {
            if let textField = subview as? NSTextField, textField.isEditable {
                textField.window?.makeFirstResponder(textField)
                return
            }
            focusTextField(in: subview)
        }
    }
}
