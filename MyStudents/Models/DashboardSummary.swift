import Foundation

struct DashboardSummary: Equatable {
    let studentCount: Int
    let batchCount: Int
    let attendanceRecordsDueCount: Int
    let outstandingPaymentCount: Int

    static let empty = DashboardSummary(
        studentCount: 0,
        batchCount: 0,
        attendanceRecordsDueCount: 0,
        outstandingPaymentCount: 0
    )
}
