import Foundation

struct Student: Identifiable, Equatable {
    let id: UUID
    let fullName: String
    let phoneNumber: String?
    let guardianName: String?
    let createdAt: Date
}
