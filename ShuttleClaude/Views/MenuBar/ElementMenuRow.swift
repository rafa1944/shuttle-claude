import SwiftUI
import AppKit

struct ElementMenuRow: View {
    let element: Element
    @EnvironmentObject private var store: DataStore

    var body: some View {
        Button {
            if store.settings.copySudoOnConnect, let pwd = element.sudoPassword, !pwd.isEmpty {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(pwd, forType: .string)
            }
            TerminalLauncher.launch(
                element: element,
                terminal: store.settings.terminalApp,
                customPath: store.settings.customTerminalPath
            )
        } label: {
            Text(element.name)
        }

        if element.sudoPassword != nil {
            Button("Copy sudo password") {
                if let pwd = element.sudoPassword {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(pwd, forType: .string)
                }
            }
        }
    }
}
