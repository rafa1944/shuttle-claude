import AppKit
import SwiftUI

@MainActor
final class AboutWindowController {
    static let shared = AboutWindowController()

    private var window: NSWindow?

    func open() {
        if let window = window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let aboutView = AboutView()
        let hostingView = NSHostingView(rootView: aboutView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 320, height: 220)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 220),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About ShuttleClaude"
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)

        self.window = window

        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct AboutView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "terminal")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("ShuttleClaude")
                .font(.title2)
                .fontWeight(.bold)

            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()
                .padding(.horizontal, 40)

            Text("Developed by Rafa Alcantara")
                .font(.callout)

            Link("rafa.alcantara@gmail.com", destination: URL(string: "mailto:rafa.alcantara@gmail.com")!)
                .font(.callout)

            Text("\u{00A9} \(Calendar.current.component(.year, from: Date())) All rights reserved")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 320, height: 220)
    }
}
