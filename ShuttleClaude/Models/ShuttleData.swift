import Foundation

struct AppSettings: Hashable {
    var terminalApp: TerminalApp
    var customTerminalPath: String?
    var copySudoOnConnect: Bool

    init(terminalApp: TerminalApp = .terminal, customTerminalPath: String? = nil, copySudoOnConnect: Bool = true) {
        self.terminalApp = terminalApp
        self.customTerminalPath = customTerminalPath
        self.copySudoOnConnect = copySudoOnConnect
    }
}

extension AppSettings: Codable {
    enum CodingKeys: String, CodingKey {
        case terminalApp, customTerminalPath, copySudoOnConnect
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        terminalApp = try container.decode(TerminalApp.self, forKey: .terminalApp)
        customTerminalPath = try container.decodeIfPresent(String.self, forKey: .customTerminalPath)
        copySudoOnConnect = try container.decodeIfPresent(Bool.self, forKey: .copySudoOnConnect) ?? true
    }
}

struct ShuttleData: Codable {
    var providers: [Provider]
    var settings: AppSettings
    var exportSalt: String?

    init(providers: [Provider] = [], settings: AppSettings = AppSettings(), exportSalt: String? = nil) {
        self.providers = providers
        self.settings = settings
        self.exportSalt = exportSalt
    }
}
