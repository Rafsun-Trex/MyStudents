import CoreData
import Foundation

final class CoreDataAttendanceRepository: AttendanceRepositoryProtocol {
    private let persistenceService: PersistenceServiceProtocol
    private let calendar: Calendar

    init(persistenceService: PersistenceServiceProtocol, calendar: Calendar = .current) {
        self.persistenceService = persistenceService
        self.calendar = calendar
    }

    func fetchBatches() throws -> [Batch] {
        let request = Batch.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(Batch.name), ascending: true)
        ]
        return try persistenceService.viewContext.fetch(request)
    }

    func batch(withID id: UUID) throws -> Batch? {
        let request = Batch.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "%K == %@", "id", id as CVarArg)
        return try persistenceService.viewContext.fetch(request).first
    }

    func students(inBatch batchID: UUID) throws -> [Student] {
        guard let batch = try batch(withID: batchID) else {
            throw AttendanceRepositoryError.batchNotFound
        }

        return batch.students
            .filter { !$0.isArchived }
            .sorted { $0.fullName.localizedCaseInsensitiveCompare($1.fullName) == .orderedAscending }
    }

    func attendanceRecords(forBatch batchID: UUID, on date: Date) throws -> [AttendanceRecord] {
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return []
        }

        return try fetchRecords(
            forBatch: batchID,
            predicate: NSPredicate(
                format: "%K >= %@ AND %K < %@",
                #keyPath(AttendanceRecord.date), dayStart as NSDate,
                #keyPath(AttendanceRecord.date), dayEnd as NSDate
            ),
            ascending: true
        )
    }

    func attendanceRecords(forBatch batchID: UUID) throws -> [AttendanceRecord] {
        try fetchRecords(forBatch: batchID, predicate: nil, ascending: false)
    }

    func attendanceRecords(forBatch batchID: UUID, inMonth month: Date) throws -> [AttendanceRecord] {
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: month)
        else {
            return []
        }

        return try fetchRecords(
            forBatch: batchID,
            predicate: NSPredicate(
                format: "%K >= %@ AND %K < %@",
                #keyPath(AttendanceRecord.date), monthInterval.start as NSDate,
                #keyPath(AttendanceRecord.date), monthInterval.end as NSDate
            ),
            ascending: false
        )
    }

    func saveAttendance(_ entries: [AttendanceEntry], forBatch batchID: UUID, on date: Date) throws {
        guard let batch = try batch(withID: batchID) else {
            throw AttendanceRepositoryError.batchNotFound
        }

        let context = persistenceService.viewContext
        let dayStart = calendar.startOfDay(for: date)
        let existing = try attendanceRecords(forBatch: batchID, on: date)
        var recordsByStudentID = Dictionary(
            existing.compactMap { record -> (UUID, AttendanceRecord)? in
                guard let studentID = record.student?.id else { return nil }
                return (studentID, record)
            },
            uniquingKeysWith: { first, _ in first }
        )

        let students = try fetchStudents(withIDs: entries.map(\.studentID))
        let studentsByID = Dictionary(students.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        for entry in entries {
            guard let student = studentsByID[entry.studentID] else { continue }

            if let record = recordsByStudentID[entry.studentID] {
                record.attendanceStatus = entry.status
                record.date = dayStart
            } else {
                let record = AttendanceRecord(context: context)
                record.date = dayStart
                record.attendanceStatus = entry.status
                record.student = student
                record.batch = batch
                recordsByStudentID[entry.studentID] = record
            }
        }

        try persistenceService.saveViewContext()
    }

    private func fetchRecords(
        forBatch batchID: UUID,
        predicate: NSPredicate?,
        ascending: Bool
    ) throws -> [AttendanceRecord] {
        let request = AttendanceRecord.fetchRequest()
        let batchPredicate = NSPredicate(
            format: "%K == %@",
            "batch.id", batchID as CVarArg
        )

        if let predicate {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [batchPredicate, predicate])
        } else {
            request.predicate = batchPredicate
        }

        request.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(AttendanceRecord.date), ascending: ascending),
            NSSortDescriptor(key: #keyPath(AttendanceRecord.student.fullName), ascending: true)
        ]

        return try persistenceService.viewContext.fetch(request)
    }

    private func fetchStudents(withIDs ids: [UUID]) throws -> [Student] {
        guard !ids.isEmpty else { return [] }

        let request = Student.fetchRequest()
        request.predicate = NSPredicate(format: "%K IN %@", "id", ids)
        return try persistenceService.viewContext.fetch(request)
    }
}

enum AttendanceRepositoryError: LocalizedError {
    case batchNotFound

    var errorDescription: String? {
        switch self {
        case .batchNotFound:
            "Batch not found."
        }
    }
}
