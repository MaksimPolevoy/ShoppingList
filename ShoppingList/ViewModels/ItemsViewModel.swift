import Foundation
import CoreData
import Combine

struct ItemGroup: Identifiable {
    let id: String
    let categoryName: String
    let categoryIcon: String
    let items: [ShoppingItemEntity]

    init(categoryName: String, categoryIcon: String, items: [ShoppingItemEntity]) {
        self.id = categoryName
        self.categoryName = categoryName
        self.categoryIcon = categoryIcon
        self.items = items
    }
}

class ItemsViewModel: ObservableObject {
    @Published var itemGroups: [ItemGroup] = []
    @Published var checkedItems: [ShoppingItemEntity] = []
    @Published var showingAddItem = false
    @Published var newItemName = ""
    @Published var newItemQuantity = 1
    @Published var newItemUnit = ""

    let list: ShoppingListEntity
    private let dataController: DataController

    init(list: ShoppingListEntity, dataController: DataController = .shared) {
        self.list = list
        self.dataController = dataController
        fetchItems()
    }

    func fetchItems() {
        let allItems = dataController.fetchItems(for: list)

        // Separate checked and unchecked items
        let uncheckedItems = allItems.filter { !$0.isChecked }
        checkedItems = allItems.filter { $0.isChecked }.sorted {
            ($0.updatedAt ?? Date()) > ($1.updatedAt ?? Date())
        }

        // Group unchecked items by category
        var groups: [String: (icon: String, order: Int, items: [ShoppingItemEntity])] = [:]

        for item in uncheckedItems {
            let categoryName = item.categoryName ?? "Другое"
            let categoryIcon = item.categoryIcon ?? "📦"
            let order = Int(item.categorySortOrder)

            if var group = groups[categoryName] {
                group.items.append(item)
                groups[categoryName] = group
            } else {
                groups[categoryName] = (icon: categoryIcon, order: order, items: [item])
            }
        }

        // Convert to array and sort by category order
        itemGroups = groups.map { key, value in
            ItemGroup(categoryName: key, categoryIcon: value.icon, items: value.items.sorted { ($0.name ?? "") < ($1.name ?? "") })
        }.sorted { $0.items.first?.categorySortOrder ?? 0 < $1.items.first?.categorySortOrder ?? 0 }
    }

    func addItem() {
        let trimmedName = newItemName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        let unit = newItemUnit.trimmingCharacters(in: .whitespaces)
        _ = dataController.addItem(
            to: list,
            name: trimmedName,
            quantity: newItemQuantity,
            unit: unit.isEmpty ? nil : unit
        )

        // Reset form
        newItemName = ""
        newItemQuantity = 1
        newItemUnit = ""
        showingAddItem = false

        fetchItems()
    }

    func toggleItem(_ item: ShoppingItemEntity) {
        dataController.toggleItem(item)
        fetchItems()
    }

    func deleteItem(_ item: ShoppingItemEntity) {
        dataController.deleteItem(item)
        fetchItems()
    }

    func deleteCheckedItems() {
        dataController.deleteCheckedItems(from: list)
        fetchItems()
    }

    func previewCategory(for name: String) -> Category {
        return CategoryDetector.shared.detectCategory(for: name)
    }

    var uncheckedCount: Int {
        itemGroups.reduce(0) { $0 + $1.items.count }
    }

    var totalCount: Int {
        uncheckedCount + checkedItems.count
    }
}
