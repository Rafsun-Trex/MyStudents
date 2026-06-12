import CoreData
import Foundation

enum PaymentStatus: String, CaseIterable {
    case pending
    case paid
    case overdue
    case cancelled
}

@objc(Payment)
final class Payment: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var amount: NSDecimalNumber
    @NSManaged var paymentDate: Date?
    @NSManaged var month: String
    @NSManaged var status: String
    @NSManaged var student: Student?
    @NSManaged var batch: Batch?

    override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        amount = .zero
        month = ""
        status = PaymentStatus.pending.rawValue
    }

    var paymentStatus: PaymentStatus {
        get { PaymentStatus(rawValue: status) ?? .pending }
        set { status = newValue.rawValue }
    }

    @nonobjc class func fetchRequest() -> NSFetchRequest<Payment> {
        NSFetchRequest<Payment>(entityName: "Payment")
    }
}
