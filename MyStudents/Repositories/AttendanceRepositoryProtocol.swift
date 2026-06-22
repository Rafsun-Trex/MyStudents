import CoreData
import Foundation

/// A single student's status on a given day, used when persisting a batch's
/// attendance for a date.
struct AttendanceEntry {
    let studentID: UUID
    let status: AttendanceStatus
}

protocol AttendanceRepositoryProtocol {
    /// The Core Data context used for fetches and saves, exposed so view
    /// controllers can subscribe to save notifications and refresh on change.
    var managedObjectContext: NSManagedObjectContext { get }

    /// Batches that attendance can be taken for, sorted by name.
    func fetchBatches() throws -> [Batch]
    func batch(withID id: UUID) throws -> Batch?

    /// Active students belonging to a batch, sorted by name.
    func students(inBatch batchID: UUID) throws -> [Student]

    /// Existing attendance records for a batch on the start-of-day of `date`.
    func attendanceRecords(forBatch batchID: UUID, on date: Date) throws -> [AttendanceRecord]

    /// All attendance records for a batch, most recent first.
    func attendanceRecords(forBatch batchID: UUID) throws -> [AttendanceRecord]

    /// Attendance records for a batch within the calendar month containing `month`.
    func attendanceRecords(forBatch batchID: UUID, inMonth month: Date) throws -> [AttendanceRecord]

    /// Inserts or updates one record per entry for the batch on `date`, so a day
    /// can be re-marked without creating duplicates.
    func saveAttendance(_ entries: [AttendanceEntry], forBatch batchID: UUID, on date: Date) throws
}
