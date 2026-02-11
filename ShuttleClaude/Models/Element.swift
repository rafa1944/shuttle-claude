import Foundation

struct Element: Identifiable, Hashable {
    var id: UUID
    var name: String
    var user: String
    var host: String
    var ip: String
    var port: Int
    var sudoPassword: String?
    var notes: String?

    init(id: UUID = UUID(), name: String, user: String, host: String = "", ip: String, port: Int = 22, sudoPassword: String? = nil, notes: String? = nil) {
        self.id = id
        self.name = name
        self.user = user
        self.host = host
        self.ip = ip
        self.port = port
        self.sudoPassword = sudoPassword
        self.notes = notes
    }

    /// The address used for SSH connection: IP if available, otherwise host.
    var sshAddress: String {
        ip.isEmpty ? host : ip
    }
}

// Custom Codable to migrate old data where "host" contained the IP and "ip" didn't exist.
extension Element: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, user, host, ip, port, sudoPassword, notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        user = try container.decode(String.self, forKey: .user)
        port = try container.decode(Int.self, forKey: .port)
        sudoPassword = try container.decodeIfPresent(String.self, forKey: .sudoPassword)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)

        let hostValue = try container.decode(String.self, forKey: .host)

        if let ipValue = try container.decodeIfPresent(String.self, forKey: .ip) {
            host = hostValue
            ip = ipValue
        } else {
            host = ""
            ip = hostValue
        }
    }
}
