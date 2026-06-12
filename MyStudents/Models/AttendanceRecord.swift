import CoreData
import Foundation

enum AttendanceStatus: String, CaseIterable {
    case present
    case absent
    case late
    case excused
}

@objc(AttendanceRecord)
final class AttendanceRecord: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var date: Date
    @NSManaged var status: String
    @NSManaged var student: Student?
    @NSManaged var batch: Batch?

    override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        date = Date()
        status = AttendanceStatus.present.rawValue
    }

    var attendanceStatus: AttendanceStatus {
        get { AttendanceStatus(rawValue: status) ?? .present }
        set { status = newValue.rawValue }
    }

    @nonobjc class func fetchRequest() -> NSFetchRequest<AttendanceRecord> {
        NSFetchRequest<AttendanceRecord>(entityName: "AttendanceRecord")
    }
}
