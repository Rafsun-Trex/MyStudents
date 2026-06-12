import CoreData
import Foundation

@objc(Batch)
final class Batch: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var subject: String?
    @NSManaged var schedule: String?
    @NSManaged var fee: NSDecimalNumber
    @NSManaged var students: Set<Student>
    @NSManaged var attendanceRecords: Set<AttendanceRecord>
    @NSManaged var payments: Set<Payment>
    @NSManaged var expenses: Set<Expense>
    @NSManaged var homework: Set<Homework>
    @NSManaged var examResults: Set<ExamResult>

    override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        name = ""
        fee = .zero
    }

    @nonobjc class func fetchRequest() -> NSFetchRequest<Batch> {
        NSFetchRequest<Batch>(entityName: "Batch")
    }
}
