import Foundation

enum SSHCommandBuilder {
    static func command(for element: Element) -> String {
        var parts = ["ssh"]
        if element.port != 22 {
            parts.append("-p \(element.port)")
        }
        parts.append("\(element.user)@\(element.sshAddress)")
        return parts.joined(separator: " ")
    }
}
