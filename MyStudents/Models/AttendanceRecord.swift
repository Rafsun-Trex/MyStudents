import Foundation

enum AttendanceStatus: String {
    case present
    case absent
    case excused
}

struct AttendanceRecord: Identifiable, Equatable {
    let id: UUID
    let studentID: UUID
    let batchID: UUID?
    let date: Date
    let status: AttendanceStatus
}
