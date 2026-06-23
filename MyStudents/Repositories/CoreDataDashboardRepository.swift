import CoreData
import Foundation

final class CoreDataDashboardRepository: DashboardRepositoryProtocol {
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

    var managedObjectContext: NSManagedObjectContext {
        persistenceService.viewContext
    }

    func fetchSummary() throws -> DashboardSummary {
        let context = persistenceService.viewContext

        let studentRequest = Student.fetchRequest()
        studentRequest.predicate = NSPredicate(format: "%K == NO", #keyPath(Student.isArchived))
        let totalStudents = try context.count(for: studentRequest)

        let batchRequest = Batch.fetchRequest()
        let activeBatches = try context.count(for: batchRequest)

        let todaysClasses = try countDistinctBatchesWithAttendanceToday(in: context)

        let (duePayments, monthlyRevenue, monthlyExpected) = try monthlyFinanceMetrics(in: context)

        return DashboardSummary(
            totalStudents: totalStudents,
            activeBatches: activeBatches,
            todaysClasses: todaysClasses,
            duePayments: duePayments,
            monthlyRevenue: monthlyRevenue,
            monthlyExpected: monthlyExpected
        )
    }

    private func countDistinctBatchesWithAttendanceToday(in context: NSManagedObjectContext) throws -> Int {
        let dayStart = calendar.startOfDay(for: Date())
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return 0
        }

        let request = AttendanceRecord.fetchRequest()
        request.predicate = NSPredicate(
            format: "%K >= %@ AND %K < %@",
            #keyPath(AttendanceRecord.date), dayStart as NSDate,
            #keyPath(AttendanceRecord.date), dayEnd as NSDate
        )
        let records = try context.fetch(request)

        var batchIDs: Set<UUID> = []
        for record in records {
            if let id = record.batch?.id {
                batchIDs.insert(id)
            }
        }
        return batchIDs.count
    }

    private func monthlyFinanceMetrics(
        in context: NSManagedObjectContext
    ) throws -> (duePayments: Int, collected: NSDecimalNumber, expected: NSDecimalNumber) {
        let monthKey = monthKeyFormatter.string(from: calendar.startOfMonth(for: Date()))
        let request = Payment.fetchRequest()
        request.predicate = NSPredicate(format: "%K == %@", #keyPath(Payment.month), monthKey)
        let payments = try context.fetch(request)

        var due = 0
        var collected: NSDecimalNumber = .zero
        var expected: NSDecimalNumber = .zero

        for payment in payments {
            let status = payment.paymentStatus
            if status == .cancelled { continue }
            expected = expected.adding(payment.amount)
            collected = collected.adding(payment.paidAmount)
            switch status {
            case .pending, .partial, .overdue:
                due += 1
            case .paid, .cancelled:
                break
            }
        }

        return (due, collected, expected)
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        dateInterval(of: .month, for: date)?.start ?? date
    }
}
