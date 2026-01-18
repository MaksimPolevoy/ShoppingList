import Foundation
import CoreData

extension ShoppingListEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ShoppingListEntity> {
        return NSFetchRequest<ShoppingListEntity>(entityName: "ShoppingListEntity")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var items: NSSet?

}

// MARK: Generated accessors for items
extension ShoppingListEntity {

    @objc(addItemsObject:)
    @NSManaged public func addToItems(_ value: ShoppingItemEntity)

    @objc(removeItemsObject:)
    @NSManaged public func removeFromItems(_ value: ShoppingItemEntity)

    @objc(addItems:)
    @NSManaged public func addToItems(_ values: NSSet)

    @objc(removeItems:)
    @NSManaged public func removeFromItems(_ values: NSSet)

}

extension ShoppingListEntity: Identifiable {

}
