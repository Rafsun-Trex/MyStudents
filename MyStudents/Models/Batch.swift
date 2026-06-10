import Foundation

struct Batch: Identifiable, Equatable {
    let id: UUID
    let name: String
    let subjectName: String?
    let scheduleDescription: String?
    let createdAt: Date
}
