import Foundation

struct Provider: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var projects: [Project]

    init(id: UUID = UUID(), name: String, projects: [Project] = []) {
        self.id = id
        self.name = name
        self.projects = projects
    }
}
