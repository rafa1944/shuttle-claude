import Foundation

enum TerminalApp: String, Codable, CaseIterable, Identifiable {
    case terminal = "Terminal"
    case iterm2 = "iTerm2"
    case warp = "Warp"
    case ghostty = "Ghostty"
    case alacritty = "Alacritty"
    case custom = "Custom"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var bundleIdentifier: String? {
        switch self {
        case .terminal: return "com.apple.Terminal"
        case .iterm2: return "com.googlecode.iterm2"
        case .warp: return "dev.warp.Warp-Stable"
        case .ghostty: return "com.mitchellh.ghostty"
        case .alacritty: return "org.alacritty"
        case .custom: return nil
        }
    }
}
