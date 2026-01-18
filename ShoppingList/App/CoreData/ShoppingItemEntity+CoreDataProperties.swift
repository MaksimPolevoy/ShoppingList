import Foundation
import CoreData

extension ShoppingItemEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ShoppingItemEntity> {
        return NSFetchRequest<ShoppingItemEntity>(entityName: "ShoppingItemEntity")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var quantity: Int32
    @NSManaged public var unit: String?
    @NSManaged public var isChecked: Bool
    @NSManaged public var categoryName: String?
    @NSManaged public var categoryIcon: String?
    @NSManaged public var categorySortOrder: Int32
    @NSManaged public var addedBy: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var list: ShoppingListEntity?

}

extension ShoppingItemEntity: Identifiable {

}
