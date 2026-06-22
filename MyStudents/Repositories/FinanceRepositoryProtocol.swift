import Foundation

/// A collected payment, partial or full, applied to a single monthly bill.
struct PaymentCollection {
    let amount: NSDecimalNumber
    let date: Date
    let method: PaymentMethod?
    let notes: String?
}

/// Aggregated finance metrics surfaced on the dashboard.
struct FinanceSummary {
    let month: Date
    let totalExpected: NSDecimalNumber
    let totalCollected: NSDecimalNumber
    let totalPending: NSDecimalNumber
    let totalOverdue: NSDecimalNumber
    let paidCount: Int
    let partialCount: Int
    let pendingCount: Int
    let overdueCount: Int
    let totalCount: Int
}

/// One bar in a small monthly-revenue chart.
struct MonthlyRevenuePoint {
    let month: Date
    let collected: NSDecimalNumber
    let expected: NSDecimalNumber
}

protocol FinanceRepositoryProtocol {
    /// All payments, most recent first.
    func fetchPayments() throws -> [Payment]

    /// Payments for one student, most recent first.
    func fetchPayments(forStudentID studentID: UUID) throws -> [Payment]

    /// Payments belonging to the calendar month of `month`, sorted by student name.
    func fetchPayments(inMonth month: Date) throws -> [Payment]

    /// Payments belonging to the calendar month of `month` with any of the
    /// supplied statuses, sorted by student name. Pass an empty set for "all".
    func fetchPayments(inMonth month: Date, statuses: Set<PaymentStatus>) throws -> [Payment]

    /// Single payment lookup.
    func payment(withID id: UUID) throws -> Payment?

    /// Generates one Payment per active student×batch pair for `month` if it
    /// doesn't already exist. Returns the number of new records created.
    /// Marks any previously-pending bill from earlier months as `.overdue`.
    @discardableResult
    func generatePayments(forMonth month: Date) throws -> Int

    /// Applies a collection to the payment, advancing `paidAmount` and updating
    /// `status` automatically. Throws if the resulting paidAmount would exceed
    /// the expected amount.
    func collect(_ collection: PaymentCollection, forPaymentID paymentID: UUID) throws

    /// Marks a payment as cancelled; clears any partial balance.
    func cancel(paymentID: UUID) throws

    /// Summary metrics for the dashboard for the calendar month of `month`.
    func summary(forMonth month: Date) throws -> FinanceSummary

    /// Revenue points for the most recent `monthCount` months, oldest first.
    func monthlyRevenue(monthCount: Int) throws -> [MonthlyRevenuePoint]
}

enum FinanceRepositoryError: LocalizedError {
    case paymentNotFound
    case invalidAmount
    case overpayment(maxAllowed: NSDecimalNumber)

    var errorDescription: String? {
        switch self {
        case .paymentNotFound:
            "Payment not found."
        case .invalidAmount:
            "Enter an amount greater than zero."
        case .overpayment(let max):
            "Amount exceeds the remaining due of \(NumberFormatter.financeAmount.string(from: max) ?? max.stringValue)."
        }
    }
}

extension NumberFormatter {
    /// Shared currency formatter for displaying finance amounts. Falls back to
    /// the device locale so the symbol matches the user's region.
    static let financeAmount: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter
    }()
}
