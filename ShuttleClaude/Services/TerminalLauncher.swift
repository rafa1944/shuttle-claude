import AppKit
import Foundation

enum TerminalLauncher {
    static func launch(element: Element, terminal: TerminalApp, customPath: String?) {
        let sshCommand = SSHCommandBuilder.command(for: element)

        switch terminal {
        case .terminal:
            launchInTerminalApp(sshCommand)
        case .iterm2:
            launchInITerm2(sshCommand)
        case .warp:
            launchInWarp(sshCommand)
        case .ghostty:
            launchInGhostty(sshCommand, element: element)
        case .alacritty:
            launchInAlacritty(element: element)
        case .custom:
            launchInCustom(sshCommand, appPath: customPath)
        }
    }

    // MARK: - Terminal.app

    private static func launchInTerminalApp(_ command: String) {
        let escaped = command.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = """
        tell application "Terminal"
            do script "\(escaped)"
            activate
        end tell
        """
        runOsascript(source)
    }

    // MARK: - iTerm2

    private static func launchInITerm2(_ command: String) {
        let escaped = command.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = """
        tell application "iTerm"
            create window with default profile command "\(escaped)"
            activate
        end tell
        """
        runOsascript(source)
    }

    // MARK: - Warp

    private static func launchInWarp(_ command: String) {
        // Warp executes .sh scripts opened via `open -a Warp`.
        // This avoids System Events and Accessibility permissions entirely.
        let scriptContent = "#!/bin/bash\n\(command)\n"
        let tempDir = FileManager.default.temporaryDirectory
        let scriptFile = tempDir.appendingPathComponent("shuttle_\(UUID().uuidString).sh")

        do {
            try scriptContent.write(to: scriptFile, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptFile.path)
        } catch {
            print("Failed to create temp script: \(error)")
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "Warp", scriptFile.path]
        try? process.run()
    }

    // MARK: - Ghostty

    private static func launchInGhostty(_ command: String, element: Element) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-na", "Ghostty", "--args", "-e", command]
        try? process.run()
    }

    // MARK: - Alacritty

    private static func launchInAlacritty(element: Element) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")

        var sshArgs = ["ssh"]
        if element.port != 22 {
            sshArgs.append(contentsOf: ["-p", "\(element.port)"])
        }
        sshArgs.append("\(element.user)@\(element.sshAddress)")

        var args = ["-na", "Alacritty", "--args", "-e"]
        args.append(contentsOf: sshArgs)
        process.arguments = args
        try? process.run()
    }

    // MARK: - Custom

    private static func launchInCustom(_ command: String, appPath: String?) {
        guard let appPath = appPath, !appPath.isEmpty else { return }

        let appName = (appPath as NSString).lastPathComponent
            .replacingOccurrences(of: ".app", with: "")

        let escaped = command.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let source = """
        tell application "\(appName)"
            activate
        end tell
        delay 1
        tell application "System Events"
            tell process "\(appName)"
                keystroke "n" using command down
                delay 0.5
                keystroke "\(escaped)"
                keystroke return
            end tell
        end tell
        """
        runOsascriptWithFallback(source, command: command, appName: appName)
    }

    // MARK: - Helpers

    /// Runs AppleScript via /usr/bin/osascript as an external process.
    /// This avoids permission issues tied to ShuttleClaude's code signature.
    private static func runOsascript(_ source: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", source]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try? process.run()
        }
    }

    /// Runs AppleScript via osascript. If it fails, copies the SSH command
    /// to the clipboard and opens the terminal for manual paste.
    private static func runOsascriptWithFallback(_ source: String, command: String, appName: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", source]

            let errorPipe = Pipe()
            process.standardOutput = FileHandle.nullDevice
            process.standardError = errorPipe

            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                print("Failed to run osascript: \(error)")
            }

            if process.terminationStatus != 0 {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorMsg = String(data: errorData, encoding: .utf8) ?? ""
                print("osascript error: \(errorMsg)")

                DispatchQueue.main.async {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(command, forType: .string)

                    let proc = Process()
                    proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                    proc.arguments = ["-a", appName]
                    try? proc.run()

                    let alert = NSAlert()
                    alert.messageText = "Comando copiado al portapapeles"
                    alert.informativeText = """
                    No se pudo escribir el comando en \(appName) automáticamente.

                    El comando SSH se ha copiado al portapapeles. Pégalo con ⌘V.

                    Para que funcione automáticamente, añade /usr/bin/osascript en:
                    Ajustes del Sistema → Privacidad y seguridad → Accesibilidad
                    """
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "Abrir Ajustes")
                    alert.addButton(withTitle: "OK")
                    NSApp.activate(ignoringOtherApps: true)

                    let response = alert.runModal()
                    if response == .alertFirstButtonReturn {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                    }
                }
            }
        }
    }
}
