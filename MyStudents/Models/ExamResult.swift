import CoreData
import Foundation

@objc(ExamResult)
final class ExamResult: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var examName: String
    @NSManaged var subject: String?
    @NSManaged var examDate: Date
    @NSManaged var marksObtained: Double
    @NSManaged var totalMarks: Double
    @NSManaged var grade: String?
    @NSManaged var notes: String?
    @NSManaged var student: Student?
    @NSManaged var batch: Batch?

    override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        examName = ""
        examDate = Date()
        marksObtained = 0
        totalMarks = 0
    }

    @nonobjc class func fetchRequest() -> NSFetchRequest<ExamResult> {
        NSFetchRequest<ExamResult>(entityName: "ExamResult")
    }
}
