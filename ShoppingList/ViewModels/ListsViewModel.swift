import Foundation
import CoreData
import Combine

class ListsViewModel: ObservableObject {
    @Published var lists: [ShoppingListEntity] = []
    @Published var listCounts: [UUID: (remaining: Int, checked: Int)] = [:]
    @Published var showingAddList = false
    @Published var newListName = ""

    private let dataController: DataController

    init(dataController: DataController = .shared) {
        self.dataController = dataController
        fetchLists()
    }

    func fetchLists() {
        // Reset context to force fresh data from store
        let context = dataController.container.viewContext
        context.reset()

        // Fetch fresh lists
        lists = dataController.fetchLists()

        // Compute counts using COUNT queries (bypasses object cache)
        var counts: [UUID: (remaining: Int, checked: Int)] = [:]
        for list in lists {
            if let id = list.id {
                let (remaining, checked) = dataController.fetchItemCounts(for: list)
                counts[id] = (remaining, checked)
            }
        }
        listCounts = counts
    }

    func createList() {
        guard !newListName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        _ = dataController.createList(name: newListName.trimmingCharacters(in: .whitespaces))
        newListName = ""
        showingAddList = false
        fetchLists()
    }

    func deleteList(_ list: ShoppingListEntity) {
        dataController.deleteList(list)
        fetchLists()
    }

    func deleteList(at offsets: IndexSet) {
        for index in offsets {
            let list = lists[index]
            dataController.deleteList(list)
        }
        fetchLists()
    }

    func itemCount(for list: ShoppingListEntity) -> Int {
        guard let items = list.items as? Set<ShoppingItemEntity> else { return 0 }
        return items.filter { !$0.isChecked }.count
    }

    func checkedCount(for list: ShoppingListEntity) -> Int {
        guard let items = list.items as? Set<ShoppingItemEntity> else { return 0 }
        return items.filter { $0.isChecked }.count
    }

    func totalCount(for list: ShoppingListEntity) -> Int {
        guard let items = list.items as? Set<ShoppingItemEntity> else { return 0 }
        return items.count
    }
}
