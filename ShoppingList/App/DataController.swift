import CoreData
import Foundation

class DataController: ObservableObject {
    static let shared = DataController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "ShoppingListModel")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Core Data failed to load: \(error.localizedDescription)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        // Create default list if none exists
        createDefaultListIfNeeded()
    }

    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    func save() {
        let context = container.viewContext

        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Error saving context: \(error)")
            }
        }
    }

    private func createDefaultListIfNeeded() {
        let context = container.viewContext
        let request: NSFetchRequest<ShoppingListEntity> = ShoppingListEntity.fetchRequest()

        do {
            let count = try context.count(for: request)
            if count == 0 {
                let defaultList = ShoppingListEntity(context: context)
                defaultList.id = UUID()
                defaultList.name = "Мой список"
                defaultList.createdAt = Date()
                save()
            }
        } catch {
            print("Error checking for default list: \(error)")
        }
    }

    // MARK: - Shopping Lists

    func createList(name: String) -> ShoppingListEntity {
        let context = container.viewContext
        let list = ShoppingListEntity(context: context)
        list.id = UUID()
        list.name = name
        list.createdAt = Date()
        save()
        return list
    }

    func deleteList(_ list: ShoppingListEntity) {
        let context = container.viewContext
        context.delete(list)
        save()
    }

    func fetchLists() -> [ShoppingListEntity] {
        let request: NSFetchRequest<ShoppingListEntity> = ShoppingListEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ShoppingListEntity.createdAt, ascending: false)]

        do {
            return try container.viewContext.fetch(request)
        } catch {
            print("Error fetching lists: \(error)")
            return []
        }
    }

    // MARK: - Shopping Items

    func addItem(to list: ShoppingListEntity, name: String, quantity: Int = 1, unit: String? = nil) -> ShoppingItemEntity {
        let context = container.viewContext
        let item = ShoppingItemEntity(context: context)
        item.id = UUID()
        item.name = name
        item.quantity = Int32(quantity)
        item.unit = unit
        item.isChecked = false
        item.createdAt = Date()
        item.updatedAt = Date()
        item.addedBy = "ios"

        // Auto-detect category
        let category = CategoryDetector.shared.detectCategory(for: name)
        item.categoryName = category.name
        item.categoryIcon = category.icon
        item.categorySortOrder = Int32(category.sortOrder)

        item.list = list
        save()
        return item
    }

    func toggleItem(_ item: ShoppingItemEntity) {
        item.isChecked.toggle()
        item.updatedAt = Date()
        save()
    }

    func deleteItem(_ item: ShoppingItemEntity) {
        let context = container.viewContext
        context.delete(item)
        save()
    }

    func deleteCheckedItems(from list: ShoppingListEntity) {
        guard let items = list.items as? Set<ShoppingItemEntity> else { return }
        let checkedItems = items.filter { $0.isChecked }

        for item in checkedItems {
            container.viewContext.delete(item)
        }
        save()
    }

    func fetchItems(for list: ShoppingListEntity) -> [ShoppingItemEntity] {
        guard let items = list.items as? Set<ShoppingItemEntity> else { return [] }
        return Array(items).sorted { item1, item2 in
            // Sort by category order, then by name
            if item1.categorySortOrder != item2.categorySortOrder {
                return item1.categorySortOrder < item2.categorySortOrder
            }
            return (item1.name ?? "") < (item2.name ?? "")
        }
    }

    // MARK: - Preview Support

    static var preview: DataController = {
        let controller = DataController(inMemory: true)
        let context = controller.container.viewContext

        // Create sample list
        let list = ShoppingListEntity(context: context)
        list.id = UUID()
        list.name = "Продукты на неделю"
        list.createdAt = Date()

        // Create sample items
        let sampleItems = [
            ("Молоко", 2, "л"),
            ("Хлеб белый", 1, "шт"),
            ("Яблоки", 1, "кг"),
            ("Курица", 1, "кг"),
            ("Картофель", 2, "кг"),
            ("Сыр", 200, "г"),
        ]

        for (name, quantity, unit) in sampleItems {
            let item = ShoppingItemEntity(context: context)
            item.id = UUID()
            item.name = name
            item.quantity = Int32(quantity)
            item.unit = unit
            item.isChecked = false
            item.createdAt = Date()
            item.updatedAt = Date()
            item.addedBy = "ios"

            let category = CategoryDetector.shared.detectCategory(for: name)
            item.categoryName = category.name
            item.categoryIcon = category.icon
            item.categorySortOrder = Int32(category.sortOrder)

            item.list = list
        }

        return controller
    }()
}
