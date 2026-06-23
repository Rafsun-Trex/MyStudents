import Foundation

/// Aggregated metrics surfaced on the dashboard's stat cards.
struct DashboardSummary {
    let totalStudents: Int
    let activeBatches: Int
    let todaysClasses: Int
    let duePayments: Int
    let monthlyRevenue: NSDecimalNumber
    let monthlyExpected: NSDecimalNumber

    static let empty = DashboardSummary(
        totalStudents: 0,
        activeBatches: 0,
        todaysClasses: 0,
        duePayments: 0,
        monthlyRevenue: .zero,
        monthlyExpected: .zero
    )
}
