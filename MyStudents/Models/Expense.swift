import CoreData
import Foundation

@objc(Expense)
final class Expense: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var title: String
    @NSManaged var amount: Decimal
    @NSManaged var expenseDate: Date
    @NSManaged var category: String?
    @NSManaged var notes: String?
    @NSManaged var batch: Batch?

    override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        title = ""
        amount = .zero
        expenseDate = Date()
    }

    @nonobjc class func fetchRequest() -> NSFetchRequest<Expense> {
        NSFetchRequest<Expense>(entityName: "Expense")
    }
}
