import Foundation

class CategoryDetector {
    static let shared = CategoryDetector()

    private let categories: [Category]

    private init() {
        self.categories = Category.defaultCategories
    }

    func detectCategory(for itemName: String) -> Category {
        let lowercased = itemName.lowercased()

        for category in categories {
            for keyword in category.keywords {
                if lowercased.contains(keyword) {
                    return category
                }
            }
        }

        // Return "Другое" as fallback
        return categories.last ?? Category(name: "Другое", icon: "📦", keywords: [], sortOrder: 999)
    }

    func allCategories() -> [Category] {
        return categories
    }

    func category(byName name: String) -> Category? {
        return categories.first { $0.name == name }
    }
}
