import Foundation

enum PaymentStatus: String {
    case pending
    case paid
    case overdue
}

struct Payment: Identifiable, Equatable {
    let id: UUID
    let studentID: UUID
    let batchID: UUID?
    let amount: Decimal
    let dueDate: Date
    let paidDate: Date?
    let status: PaymentStatus
}
