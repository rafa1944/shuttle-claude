import AppKit
import SwiftUI
import KeyboardShortcuts

final class AppDelegate: NSObject, NSApplicationDelegate {
    static var sharedStore: DataStore?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide any windows that might appear on launch (the hidden helper window)
        for window in NSApplication.shared.windows {
            if window.title == "ShuttleClaude Hidden" {
                window.orderOut(nil)
            }
        }

        KeyboardShortcuts.onKeyUp(for: .openSearch) {
            guard let store = AppDelegate.sharedStore else { return }
            SearchWindowController.shared.open(store: store)
        }
    }
}
