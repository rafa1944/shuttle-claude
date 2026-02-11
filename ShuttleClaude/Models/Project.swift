import Foundation

struct Project: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var url: String?
    var elements: [Element]

    init(id: UUID = UUID(), name: String, url: String? = nil, elements: [Element] = []) {
        self.id = id
        self.name = name
        self.url = url
        self.elements = elements
    }
}
