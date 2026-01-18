import Foundation
import CoreData
import Combine

class ListsViewModel: ObservableObject {
    @Published var lists: [ShoppingListEntity] = []
    @Published var showingAddList = false
    @Published var newListName = ""

    private let dataController: DataController

    init(dataController: DataController = .shared) {
        self.dataController = dataController
        fetchLists()
    }

    func fetchLists() {
        lists = dataController.fetchLists()
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
