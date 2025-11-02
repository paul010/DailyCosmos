import Foundation

struct TodoItem: Codable, Identifiable {
    var id = UUID()
    var title: String
    var dueDate: Date?
    var isCompleted: Bool = false

    enum CodingKeys: String, CodingKey {
        case title
        case dueDate
        case isCompleted
    }
}
