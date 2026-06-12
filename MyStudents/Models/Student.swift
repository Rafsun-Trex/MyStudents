import CoreData
import Foundation

@objc(Student)
final class Student: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var fullName: String
    @NSManaged var guardianName: String?
    @NSManaged var phoneNumber: String?
    @NSManaged var school: String?
    @NSManaged private var classNameValue: String?
    @NSManaged var admissionDate: Date
    @NSManaged var monthlyFee: Decimal
    @NSManaged var photoPath: String?
    @NSManaged var notes: String?
    @NSManaged var isArchived: Bool
    @NSManaged var batches: Set<Batch>
    @NSManaged var attendanceRecords: Set<AttendanceRecord>
    @NSManaged var payments: Set<Payment>
    @NSManaged var examResults: Set<ExamResult>

    override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        fullName = ""
        admissionDate = Date()
        monthlyFee = .zero
        isArchived = false
    }

    var className: String? {
        get { classNameValue }
        set { classNameValue = newValue }
    }

    @nonobjc class func fetchRequest() -> NSFetchRequest<Student> {
        NSFetchRequest<Student>(entityName: "Student")
    }
}
