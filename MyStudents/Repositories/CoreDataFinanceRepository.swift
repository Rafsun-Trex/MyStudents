import CoreData
import Foundation

/// Core Data backed implementation. All work runs against the view context to
/// keep things simple — the data set is small (one record per student per
/// month) and writes are user-initiated.
final class CoreDataFinanceRepository: FinanceRepositoryProtocol {
    private let persistenceService: PersistenceServiceProtocol
    private let calendar: Calendar
    private let monthKeyFormatter: DateFormatter

    init(persistenceService: PersistenceServiceProtocol, calendar: Calendar = .current) {
        self.persistenceService = persistenceService
        self.calendar = calendar

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM"
        self.monthKeyFormatter = formatter
    }

    // MARK: - Fetching

    func fetchPayments() throws -> [Payment] {
        let request = Payment.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(Payment.month), ascending: false),
            NSSortDescriptor(key: #keyPath(Payment.student.fullName), ascending: true)
        ]
        return try persistenceService.viewContext.fetch(request)
    }

    func fetchPayments(forStudentID studentID: UUID) throws -> [Payment] {
        let request = Payment.fetchRequest()
        request.predicate = NSPredicate(format: "%K == %@", "student.id", studentID as CVarArg)
        request.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(Payment.month), ascending: false)
        ]
        return try persistenceService.viewContext.fetch(request)
    }

    func fetchPayments(inMonth month: Date) throws -> [Payment] {
        try fetchPayments(inMonth: month, statuses: [])
    }

    func fetchPayments(inMonth month: Date, statuses: Set<PaymentStatus>) throws -> [Payment] {
        let request = Payment.fetchRequest()
        var predicates: [NSPredicate] = [
            NSPredicate(format: "%K == %@", #keyPath(Payment.month), monthKey(for: month))
        ]
        if !statuses.isEmpty {
            predicates.append(NSPredicate(format: "%K IN %@", #keyPath(Payment.status), statuses.map(\.rawValue)))
        }
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(Payment.student.fullName), ascending: true)
        ]
        return try persistenceService.viewContext.fetch(request)
    }

    func payment(withID id: UUID) throws -> Payment? {
        let request = Payment.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "%K == %@", "id", id as CVarArg)
        return try persistenceService.viewContext.fetch(request).first
    }

    // MARK: - Generation

    @discardableResult
    func generatePayments(forMonth month: Date) throws -> Int {
        let context = persistenceService.viewContext
        let key = monthKey(for: month)

        let existingRequest = Payment.fetchRequest()
        existingRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(Payment.month), key)
        let existing = try context.fetch(existingRequest)
        var existingKeyed: Set<String> = []
        for payment in existing {
            existingKeyed.insert(compositeKey(studentID: payment.student?.id, batchID: payment.batch?.id))
        }

        let batchRequest = Batch.fetchRequest()
        let batches = try context.fetch(batchRequest)

        var inserted = 0
        let generationDate = Date()

        for batch in batches {
            for student in batch.students where !student.isArchived {
                let key = compositeKey(studentID: student.id, batchID: batch.id)
                if existingKeyed.contains(key) { continue }

                let payment = Payment(context: context)
                payment.month = monthKey(for: month)
                payment.amount = expectedAmount(for: student, batch: batch)
                payment.paidAmount = .zero
                payment.generatedDate = generationDate
                payment.paymentStatus = .pending
                payment.student = student
                payment.batch = batch
                existingKeyed.insert(key)
                inserted += 1
            }
        }

        markOverduePayments(beforeMonth: month, in: context)

        try persistenceService.saveViewContext()
        return inserted
    }

    func collect(_ collection: PaymentCollection, forPaymentID paymentID: UUID) throws {
        guard collection.amount.compare(NSDecimalNumber.zero) == .orderedDescending else {
            throw FinanceRepositoryError.invalidAmount
        }

        guard let payment = try payment(withID: paymentID) else {
            throw FinanceRepositoryError.paymentNotFound
        }

        let remaining = payment.dueAmount
        if collection.amount.compare(remaining) == .orderedDescending {
            throw FinanceRepositoryError.overpayment(maxAllowed: remaining)
        }

        let newPaid = payment.paidAmount.adding(collection.amount)
        payment.paidAmount = newPaid
        payment.paymentDate = collection.date
        if let method = collection.method {
            payment.paymentMethod = method
        }
        if let notes = collection.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
            payment.notes = notes
        }
        payment.paymentStatus = derivedStatus(amount: payment.amount, paidAmount: newPaid, currentStatus: payment.paymentStatus)

        try persistenceService.saveViewContext()
    }

    func cancel(paymentID: UUID) throws {
        guard let payment = try payment(withID: paymentID) else {
            throw FinanceRepositoryError.paymentNotFound
        }
        payment.paymentStatus = .cancelled
        try persistenceService.saveViewContext()
    }

    // MARK: - Reports

    func summary(forMonth month: Date) throws -> FinanceSummary {
        let payments = try fetchPayments(inMonth: month)
        var expected: NSDecimalNumber = .zero
        var collected: NSDecimalNumber = .zero
        var overdue: NSDecimalNumber = .zero
        var paidCount = 0
        var partialCount = 0
        var pendingCount = 0
        var overdueCount = 0

        for payment in payments {
            if payment.paymentStatus == .cancelled { continue }
            expected = expected.adding(payment.amount)
            collected = collected.adding(payment.paidAmount)
            switch payment.paymentStatus {
            case .paid: paidCount += 1
            case .partial: partialCount += 1
            case .pending: pendingCount += 1
            case .overdue:
                overdueCount += 1
                overdue = overdue.adding(payment.dueAmount)
            case .cancelled: break
            }
        }

        let pending = expected.subtracting(collected)
        let safePending = pending.compare(NSDecimalNumber.zero) == .orderedAscending ? .zero : pending

        return FinanceSummary(
            month: calendar.startOfMonth(for: month),
            totalExpected: expected,
            totalCollected: collected,
            totalPending: safePending,
            totalOverdue: overdue,
            paidCount: paidCount,
            partialCount: partialCount,
            pendingCount: pendingCount,
            overdueCount: overdueCount,
            totalCount: paidCount + partialCount + pendingCount + overdueCount
        )
    }

    func monthlyRevenue(monthCount: Int) throws -> [MonthlyRevenuePoint] {
        guard monthCount > 0 else { return [] }
        let today = Date()
        let monthStart = calendar.startOfMonth(for: today)
        var months: [Date] = []
        for offset in 0..<monthCount {
            if let date = calendar.date(byAdding: .month, value: -offset, to: monthStart) {
                months.append(date)
            }
        }
        months.reverse()

        let keys = months.map { monthKey(for: $0) }
        let request = Payment.fetchRequest()
        request.predicate = NSPredicate(format: "%K IN %@", #keyPath(Payment.month), keys)
        let payments = try persistenceService.viewContext.fetch(request)

        var collectedByKey: [String: NSDecimalNumber] = [:]
        var expectedByKey: [String: NSDecimalNumber] = [:]
        for payment in payments where payment.paymentStatus != .cancelled {
            collectedByKey[payment.month, default: .zero] = collectedByKey[payment.month, default: .zero].adding(payment.paidAmount)
            expectedByKey[payment.month, default: .zero] = expectedByKey[payment.month, default: .zero].adding(payment.amount)
        }

        return months.map { month in
            let key = monthKey(for: month)
            return MonthlyRevenuePoint(
                month: month,
                collected: collectedByKey[key] ?? .zero,
                expected: expectedByKey[key] ?? .zero
            )
        }
    }

    // MARK: - Helpers

    /// The expected monthly amount for a payment, preferring the student's
    /// personal fee when it is set, otherwise falling back to the batch fee.
    private func expectedAmount(for student: Student, batch: Batch) -> NSDecimalNumber {
        if student.monthlyFee.compare(NSDecimalNumber.zero) == .orderedDescending {
            return student.monthlyFee
        }
        return batch.fee
    }

    private func monthKey(for date: Date) -> String {
        let monthStart = calendar.startOfMonth(for: date)
        return monthKeyFormatter.string(from: monthStart)
    }

    private func compositeKey(studentID: UUID?, batchID: UUID?) -> String {
        "\(studentID?.uuidString ?? "-")|\(batchID?.uuidString ?? "-")"
    }

    private func derivedStatus(
        amount: NSDecimalNumber,
        paidAmount: NSDecimalNumber,
        currentStatus: PaymentStatus
    ) -> PaymentStatus {
        if paidAmount.compare(amount) != .orderedAscending {
            return .paid
        }
        if paidAmount.compare(NSDecimalNumber.zero) == .orderedDescending {
            return .partial
        }
        return currentStatus == .overdue ? .overdue : .pending
    }

    /// Bills generated in earlier months that still carry a balance get pushed
    /// to `.overdue` so they surface visibly when the user lands on the current
    /// month.
    private func markOverduePayments(beforeMonth month: Date, in context: NSManagedObjectContext) {
        let currentKey = monthKey(for: month)
        let request = Payment.fetchRequest()
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "%K < %@", #keyPath(Payment.month), currentKey),
            NSPredicate(format: "%K IN %@", #keyPath(Payment.status), [
                PaymentStatus.pending.rawValue, PaymentStatus.partial.rawValue
            ])
        ])

        let stale = (try? context.fetch(request)) ?? []
        for payment in stale where payment.paidAmount.compare(payment.amount) == .orderedAscending {
            payment.paymentStatus = .overdue
        }
    }
}

extension Calendar {
    fileprivate func startOfMonth(for date: Date) -> Date {
        dateInterval(of: .month, for: date)?.start ?? date
    }
}
