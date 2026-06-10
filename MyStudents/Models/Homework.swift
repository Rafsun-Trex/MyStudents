import CoreData
import Foundation

enum HomeworkStatus: String, CaseIterable {
    case assigned
    case completed
    case cancelled
}

@objc(Homework)
final class Homework: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var title: String
    @NSManaged var details: String?
    @NSManaged var assignedDate: Date
    @NSManaged var dueDate: Date?
    @NSManaged var status: String
    @NSManaged var batch: Batch?

    override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        title = ""
        assignedDate = Date()
        status = HomeworkStatus.assigned.rawValue
    }

    var homeworkStatus: HomeworkStatus {
        get { HomeworkStatus(rawValue: status) ?? .assigned }
        set { status = newValue.rawValue }
    }

    @nonobjc class func fetchRequest() -> NSFetchRequest<Homework> {
        NSFetchRequest<Homework>(entityName: "Homework")
    }
}
