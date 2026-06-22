import Foundation
import UIKit

// MARK: - Shared display helpers

extension PaymentStatus {
    var displayName: String {
        switch self {
        case .pending: "Pending"
        case .partial: "Partial"
        case .paid: "Paid"
        case .overdue: "Overdue"
        case .cancelled: "Cancelled"
        }
    }

    var color: UIColor {
        switch self {
        case .pending: .systemOrange
        case .partial: .systemBlue
        case .paid: .systemGreen
        case .overdue: .systemRed
        case .cancelled: .systemGray
        }
    }
}

extension PaymentMethod {
    var displayName: String {
        switch self {
        case .cash: "Cash"
        case .bankTransfer: "Bank Transfer"
        case .mobileBanking: "Mobile Banking"
        case .card: "Card"
        case .other: "Other"
        }
    }
}

enum FinanceFormatter {
    static let monthTitle: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }()

    static let shortMonth: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLL"
        return formatter
    }()

    static let mediumDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static func amount(_ value: NSDecimalNumber) -> String {
        NumberFormatter.financeAmount.string(from: value) ?? value.stringValue
    }
}

// MARK: - Dashboard

struct FinanceDashboardMetric {
    let title: String
    let value: String
    let subtitle: String
    let color: UIColor
}

struct FinanceDashboardRecentRow {
    let id: UUID
    let studentName: String
    let batchName: String
    let amount: String
    let date: String
    let status: PaymentStatus
}

struct FinanceMonthRevenueBar {
    let monthLabel: String
    let collected: NSDecimalNumber
    let expected: NSDecimalNumber
    let ratio: Double  // 0...1, collected / max(collected, expected) within the series
}

final class FinanceDashboardViewModel: ScreenViewModel {
    let title = AppTab.finance.title

    private let repository: FinanceRepositoryProtocol
    private let calendar: Calendar
    private(set) var selectedMonth: Date

    private var lastSummary: FinanceSummary?
    private var lastRevenue: [MonthlyRevenuePoint] = []
    private var recentPayments: [Payment] = []

    init(
        repository: FinanceRepositoryProtocol,
        calendar: Calendar = .current,
        initialMonth: Date = Date()
    ) {
        self.repository = repository
        self.calendar = calendar
        self.selectedMonth = Self.startOfMonth(for: initialMonth, calendar: calendar)
    }

    var monthTitle: String {
        FinanceFormatter.monthTitle.string(from: selectedMonth)
    }

    var hasData: Bool {
        (lastSummary?.totalCount ?? 0) > 0
    }

    func reload() throws {
        lastSummary = try repository.summary(forMonth: selectedMonth)
        lastRevenue = try repository.monthlyRevenue(monthCount: 6)
        let allInMonth = try repository.fetchPayments(inMonth: selectedMonth)
        recentPayments = allInMonth
            .filter { $0.paymentStatus != .cancelled && $0.paymentDate != nil }
            .sorted {
                ($0.paymentDate ?? .distantPast) > ($1.paymentDate ?? .distantPast)
            }
            .prefix(5)
            .map { $0 }
    }

    @discardableResult
    func goToPreviousMonth() throws -> FinanceSummary? {
        guard let previous = calendar.date(byAdding: .month, value: -1, to: selectedMonth) else { return lastSummary }
        selectedMonth = Self.startOfMonth(for: previous, calendar: calendar)
        try reload()
        return lastSummary
    }

    @discardableResult
    func goToNextMonth() throws -> FinanceSummary? {
        guard let next = calendar.date(byAdding: .month, value: 1, to: selectedMonth) else { return lastSummary }
        selectedMonth = Self.startOfMonth(for: next, calendar: calendar)
        try reload()
        return lastSummary
    }

    /// Generates monthly bills for `selectedMonth`, then refreshes state.
    @discardableResult
    func generateMonthlyFees() throws -> Int {
        let inserted = try repository.generatePayments(forMonth: selectedMonth)
        try reload()
        return inserted
    }

    func metrics() -> [FinanceDashboardMetric] {
        let summary = lastSummary
        return [
            FinanceDashboardMetric(
                title: "Total Collected",
                value: FinanceFormatter.amount(summary?.totalCollected ?? .zero),
                subtitle: "\(summary?.paidCount ?? 0) paid • \(summary?.partialCount ?? 0) partial",
                color: PaymentStatus.paid.color
            ),
            FinanceDashboardMetric(
                title: "Pending Collection",
                value: FinanceFormatter.amount(summary?.totalPending ?? .zero),
                subtitle: "\((summary?.pendingCount ?? 0) + (summary?.partialCount ?? 0)) bills outstanding",
                color: PaymentStatus.pending.color
            ),
            FinanceDashboardMetric(
                title: "Overdue",
                value: FinanceFormatter.amount(summary?.totalOverdue ?? .zero),
                subtitle: "\(summary?.overdueCount ?? 0) overdue bills",
                color: PaymentStatus.overdue.color
            ),
            FinanceDashboardMetric(
                title: "Expected",
                value: FinanceFormatter.amount(summary?.totalExpected ?? .zero),
                subtitle: "\(summary?.totalCount ?? 0) bills this month",
                color: .systemIndigo
            )
        ]
    }

    func recentRows() -> [FinanceDashboardRecentRow] {
        recentPayments.map { payment in
            FinanceDashboardRecentRow(
                id: payment.id,
                studentName: payment.student?.fullName ?? "Unknown student",
                batchName: payment.batch?.name ?? "—",
                amount: FinanceFormatter.amount(payment.paidAmount),
                date: payment.paymentDate.map(FinanceFormatter.mediumDate.string(from:)) ?? "—",
                status: payment.paymentStatus
            )
        }
    }

    func revenueBars() -> [FinanceMonthRevenueBar] {
        guard !lastRevenue.isEmpty else { return [] }
        let maxValue = lastRevenue.map { max($0.collected.doubleValue, $0.expected.doubleValue) }.max() ?? 0
        return lastRevenue.map { point in
            let collected = point.collected.doubleValue
            let ratio = maxValue > 0 ? collected / maxValue : 0
            return FinanceMonthRevenueBar(
                monthLabel: FinanceFormatter.shortMonth.string(from: point.month),
                collected: point.collected,
                expected: point.expected,
                ratio: ratio
            )
        }
    }

    func makePaymentListViewModel(filter: PaymentListFilter = .all) -> PaymentListViewModel {
        PaymentListViewModel(
            repository: repository,
            calendar: calendar,
            initialMonth: selectedMonth,
            initialFilter: filter
        )
    }

    func makeCollectViewModel(forPaymentID id: UUID) throws -> CollectPaymentViewModel {
        guard let payment = try repository.payment(withID: id) else {
            throw FinanceRepositoryError.paymentNotFound
        }
        return CollectPaymentViewModel(payment: payment, repository: repository)
    }

    private static func startOfMonth(for date: Date, calendar: Calendar) -> Date {
        calendar.dateInterval(of: .month, for: date)?.start ?? date
    }
}

// MARK: - Payment List

enum PaymentListFilter: Int, CaseIterable {
    case all
    case pending
    case partial
    case paid
    case overdue

    var title: String {
        switch self {
        case .all: "All"
        case .pending: "Pending"
        case .partial: "Partial"
        case .paid: "Paid"
        case .overdue: "Overdue"
        }
    }

    var statuses: Set<PaymentStatus> {
        switch self {
        case .all: []
        case .pending: [.pending]
        case .partial: [.partial]
        case .paid: [.paid]
        case .overdue: [.overdue]
        }
    }
}

struct PaymentListRow {
    let id: UUID
    let studentName: String
    let batchName: String
    let expected: String
    let paid: String
    let due: String
    let status: PaymentStatus
    let dateSubtitle: String
}

final class PaymentListViewModel {
    let title = "Payments"

    private let repository: FinanceRepositoryProtocol
    private let calendar: Calendar
    private(set) var selectedMonth: Date
    private(set) var filter: PaymentListFilter

    private var payments: [Payment] = []

    init(
        repository: FinanceRepositoryProtocol,
        calendar: Calendar = .current,
        initialMonth: Date = Date(),
        initialFilter: PaymentListFilter = .all
    ) {
        self.repository = repository
        self.calendar = calendar
        self.selectedMonth = calendar.dateInterval(of: .month, for: initialMonth)?.start ?? initialMonth
        self.filter = initialFilter
    }

    var monthTitle: String {
        FinanceFormatter.monthTitle.string(from: selectedMonth)
    }

    func reload() throws -> [PaymentListRow] {
        payments = try repository.fetchPayments(inMonth: selectedMonth, statuses: filter.statuses)
        return rows()
    }

    func setFilter(_ newFilter: PaymentListFilter) throws -> [PaymentListRow] {
        filter = newFilter
        return try reload()
    }

    func goToPreviousMonth() throws -> [PaymentListRow] {
        guard let previous = calendar.date(byAdding: .month, value: -1, to: selectedMonth) else {
            return rows()
        }
        selectedMonth = calendar.dateInterval(of: .month, for: previous)?.start ?? previous
        return try reload()
    }

    func goToNextMonth() throws -> [PaymentListRow] {
        guard let next = calendar.date(byAdding: .month, value: 1, to: selectedMonth) else {
            return rows()
        }
        selectedMonth = calendar.dateInterval(of: .month, for: next)?.start ?? next
        return try reload()
    }

    func generateMonthlyFees() throws -> (inserted: Int, rows: [PaymentListRow]) {
        let inserted = try repository.generatePayments(forMonth: selectedMonth)
        let updated = try reload()
        return (inserted, updated)
    }

    func makeCollectViewModel(forPaymentID id: UUID) throws -> CollectPaymentViewModel {
        guard let payment = try repository.payment(withID: id) else {
            throw FinanceRepositoryError.paymentNotFound
        }
        return CollectPaymentViewModel(payment: payment, repository: repository)
    }

    func cancelPayment(id: UUID) throws -> [PaymentListRow] {
        try repository.cancel(paymentID: id)
        return try reload()
    }

    private func rows() -> [PaymentListRow] {
        payments.map { payment in
            PaymentListRow(
                id: payment.id,
                studentName: payment.student?.fullName ?? "Unknown student",
                batchName: payment.batch?.name ?? "—",
                expected: FinanceFormatter.amount(payment.amount),
                paid: FinanceFormatter.amount(payment.paidAmount),
                due: FinanceFormatter.amount(payment.dueAmount),
                status: payment.paymentStatus,
                dateSubtitle: subtitle(for: payment)
            )
        }
    }

    private func subtitle(for payment: Payment) -> String {
        switch payment.paymentStatus {
        case .paid, .partial:
            if let date = payment.paymentDate {
                return "Last paid \(FinanceFormatter.mediumDate.string(from: date))"
            }
            return "—"
        case .pending:
            return "Awaiting payment"
        case .overdue:
            return "Overdue from \(monthDisplay(for: payment.month))"
        case .cancelled:
            return "Cancelled"
        }
    }

    private func monthDisplay(for monthKey: String) -> String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM"
        guard let date = parser.date(from: monthKey) else { return monthKey }
        return FinanceFormatter.monthTitle.string(from: date)
    }
}

// MARK: - Collect Payment

struct CollectPaymentSnapshot {
    let studentName: String
    let batchName: String
    let monthTitle: String
    let expected: String
    let paid: String
    let due: String
    let status: PaymentStatus
    let suggestedAmount: NSDecimalNumber
    let allowsCollection: Bool
    let notes: String?
    let method: PaymentMethod?
}

struct CollectPaymentValidationError: LocalizedError {
    let errorDescription: String?

    static let invalidAmount = CollectPaymentValidationError(
        errorDescription: "Enter a valid amount greater than zero."
    )
    static let alreadyPaid = CollectPaymentValidationError(
        errorDescription: "This bill is already fully paid."
    )
    static let cancelled = CollectPaymentValidationError(
        errorDescription: "This bill has been cancelled."
    )
}

final class CollectPaymentViewModel {
    let title = "Collect Payment"

    private let paymentID: UUID
    private let repository: FinanceRepositoryProtocol
    private var payment: Payment

    init(payment: Payment, repository: FinanceRepositoryProtocol) {
        self.paymentID = payment.id
        self.payment = payment
        self.repository = repository
    }

    func snapshot() -> CollectPaymentSnapshot {
        let allowsCollection = payment.paymentStatus != .paid && payment.paymentStatus != .cancelled
        return CollectPaymentSnapshot(
            studentName: payment.student?.fullName ?? "Unknown student",
            batchName: payment.batch?.name ?? "—",
            monthTitle: monthDisplay(for: payment.month),
            expected: FinanceFormatter.amount(payment.amount),
            paid: FinanceFormatter.amount(payment.paidAmount),
            due: FinanceFormatter.amount(payment.dueAmount),
            status: payment.paymentStatus,
            suggestedAmount: payment.dueAmount,
            allowsCollection: allowsCollection,
            notes: payment.notes,
            method: payment.paymentMethod
        )
    }

    /// Parses, validates, and applies the collection. Throws on invalid input.
    func collect(amountText: String, date: Date, method: PaymentMethod?, notes: String?) throws {
        switch payment.paymentStatus {
        case .paid: throw CollectPaymentValidationError.alreadyPaid
        case .cancelled: throw CollectPaymentValidationError.cancelled
        default: break
        }

        let trimmed = amountText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw CollectPaymentValidationError.invalidAmount
        }

        let amount = NSDecimalNumber(string: trimmed, locale: Locale.current)
        guard amount != .notANumber, amount.compare(NSDecimalNumber.zero) == .orderedDescending else {
            throw CollectPaymentValidationError.invalidAmount
        }

        let collection = PaymentCollection(amount: amount, date: date, method: method, notes: notes)
        try repository.collect(collection, forPaymentID: paymentID)
        try refresh()
    }

    func cancel() throws {
        try repository.cancel(paymentID: paymentID)
        try refresh()
    }

    private func refresh() throws {
        if let refreshed = try repository.payment(withID: paymentID) {
            payment = refreshed
        }
    }

    private func monthDisplay(for monthKey: String) -> String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM"
        guard let date = parser.date(from: monthKey) else { return monthKey }
        return FinanceFormatter.monthTitle.string(from: date)
    }
}
