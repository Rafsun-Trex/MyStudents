import CoreData
import Foundation

enum PaymentStatus: String, CaseIterable {
    case pending
    case partial
    case paid
    case overdue
    case cancelled
}

enum PaymentMethod: String, CaseIterable {
    case cash
    case bankTransfer = "bank_transfer"
    case mobileBanking = "mobile_banking"
    case card
    case other
}

@objc(Payment)
final class Payment: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var amount: NSDecimalNumber
    @NSManaged var paidAmount: NSDecimalNumber
    @NSManaged var paymentDate: Date?
    @NSManaged var generatedDate: Date?
    @NSManaged var month: String
    @NSManaged var status: String
    @NSManaged var notes: String?
    @NSManaged var method: String?
    @NSManaged var student: Student?
    @NSManaged var batch: Batch?

    override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        amount = .zero
        paidAmount = .zero
        month = ""
        status = PaymentStatus.pending.rawValue
        generatedDate = Date()
    }

    var paymentStatus: PaymentStatus {
        get { PaymentStatus(rawValue: status) ?? .pending }
        set { status = newValue.rawValue }
    }

    var paymentMethod: PaymentMethod? {
        get { method.flatMap(PaymentMethod.init(rawValue:)) }
        set { method = newValue?.rawValue }
    }

    var dueAmount: NSDecimalNumber {
        let result = amount.subtracting(paidAmount)
        return result.compare(NSDecimalNumber.zero) == .orderedAscending ? .zero : result
    }

    @nonobjc class func fetchRequest() -> NSFetchRequest<Payment> {
        NSFetchRequest<Payment>(entityName: "Payment")
    }
}
