import Foundation
import Supabase

// MARK: - Supabase Configuration
enum SupabaseConfig {
    static let projectURL = "https://joeyrlrclujmdfgtohua.supabase.co"
    static let anonKey = "sb_publishable_aInPjfNRR5j5t6eZr1RWrg_GmrbcqxM"
}

// MARK: - Supabase Client Singleton
let supabase = SupabaseClient(
    supabaseURL: URL(string: SupabaseConfig.projectURL)!,
    supabaseKey: SupabaseConfig.anonKey
)

// MARK: - Cloud Data Models
struct CloudProfile: Codable, Identifiable {
    let id: UUID
    let email: String?
    let displayName: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName = "display_name"
        case createdAt = "created_at"
    }
}

struct CloudShoppingList: Codable, Identifiable, Hashable {
    let id: UUID
    let ownerId: UUID
    var name: String
    let createdAt: Date?
    var updatedAt: Date?
    var isShared: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case name
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case isShared = "is_shared"
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: CloudShoppingList, rhs: CloudShoppingList) -> Bool {
        lhs.id == rhs.id
    }
}

struct CloudShoppingItem: Codable, Identifiable {
    let id: UUID
    let listId: UUID
    var name: String
    var quantity: Int
    var unit: String?
    var isChecked: Bool
    var categoryName: String?
    var categoryIcon: String?
    var categorySortOrder: Int
    let addedBy: UUID?
    let createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case listId = "list_id"
        case name
        case quantity
        case unit
        case isChecked = "is_checked"
        case categoryName = "category_name"
        case categoryIcon = "category_icon"
        case categorySortOrder = "category_sort_order"
        case addedBy = "added_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct CloudListMember: Codable, Identifiable {
    let id: UUID
    let listId: UUID
    let userId: UUID
    let role: String
    let invitedBy: UUID?
    let invitedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case listId = "list_id"
        case userId = "user_id"
        case role
        case invitedBy = "invited_by"
        case invitedAt = "invited_at"
    }
}

struct CloudListInvite: Codable, Identifiable {
    let id: UUID
    let listId: UUID
    let code: String
    let createdBy: UUID
    let expiresAt: Date?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case listId = "list_id"
        case code
        case createdBy = "created_by"
        case expiresAt = "expires_at"
        case createdAt = "created_at"
    }
}

// MARK: - Insert Models (without auto-generated fields)
struct InsertShoppingList: Codable {
    let ownerId: UUID
    let name: String

    enum CodingKeys: String, CodingKey {
        case ownerId = "owner_id"
        case name
    }
}

struct InsertShoppingItem: Codable {
    let listId: UUID
    let name: String
    let quantity: Int
    let unit: String?
    let isChecked: Bool
    let categoryName: String?
    let categoryIcon: String?
    let categorySortOrder: Int
    let addedBy: UUID?

    enum CodingKeys: String, CodingKey {
        case listId = "list_id"
        case name
        case quantity
        case unit
        case isChecked = "is_checked"
        case categoryName = "category_name"
        case categoryIcon = "category_icon"
        case categorySortOrder = "category_sort_order"
        case addedBy = "added_by"
    }
}

struct InsertListMember: Codable {
    let listId: UUID
    let userId: UUID
    let role: String
    let invitedBy: UUID?

    enum CodingKeys: String, CodingKey {
        case listId = "list_id"
        case userId = "user_id"
        case role
        case invitedBy = "invited_by"
    }
}

struct InsertListInvite: Codable {
    let listId: UUID
    let createdBy: UUID

    enum CodingKeys: String, CodingKey {
        case listId = "list_id"
        case createdBy = "created_by"
    }
}
