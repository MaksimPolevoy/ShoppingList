import Foundation
import Supabase

// MARK: - Update Models
struct UpdateItemFields: Codable {
    let name: String
    let quantity: Int
    let unit: String?
    let isChecked: Bool
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case name, quantity, unit
        case isChecked = "is_checked"
        case updatedAt = "updated_at"
    }
}

struct UpdateItemToggle: Codable {
    let isChecked: Bool
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case isChecked = "is_checked"
        case updatedAt = "updated_at"
    }
}

struct UpdateListName: Codable {
    let name: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case name
        case updatedAt = "updated_at"
    }
}

// MARK: - Sync Errors
enum SyncError: LocalizedError {
    case notAuthenticated
    case fetchFailed(String)
    case createFailed(String)
    case updateFailed(String)
    case deleteFailed(String)
    case inviteNotFound
    case inviteExpired

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Необходимо войти в аккаунт"
        case .fetchFailed(let message):
            return "Ошибка загрузки: \(message)"
        case .createFailed(let message):
            return "Ошибка создания: \(message)"
        case .updateFailed(let message):
            return "Ошибка обновления: \(message)"
        case .deleteFailed(let message):
            return "Ошибка удаления: \(message)"
        case .inviteNotFound:
            return "Приглашение не найдено"
        case .inviteExpired:
            return "Срок приглашения истёк"
        }
    }
}

// MARK: - Cloud Sync Service
@MainActor
class CloudSyncService: ObservableObject {
    static let shared = CloudSyncService()

    @Published var lists: [CloudShoppingList] = []
    @Published var isLoading = false
    @Published var error: SyncError?

    private var authService: AuthService {
        AuthService.shared
    }

    private var currentUserId: UUID? {
        authService.currentUserId
    }

    private init() {}

    // MARK: - Lists

    func fetchLists() async throws -> [CloudShoppingList] {
        guard let userId = currentUserId else {
            throw SyncError.notAuthenticated
        }

        isLoading = true
        defer { isLoading = false }

        do {
            // Fetch owned lists
            let ownedLists: [CloudShoppingList] = try await supabase
                .from("shopping_lists")
                .select()
                .eq("owner_id", value: userId)
                .order("created_at", ascending: false)
                .execute()
                .value

            // Fetch shared lists (where user is a member)
            let memberRecords: [CloudListMember] = try await supabase
                .from("list_members")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value

            let sharedListIds = memberRecords.map { $0.listId }

            var sharedLists: [CloudShoppingList] = []
            if !sharedListIds.isEmpty {
                sharedLists = try await supabase
                    .from("shopping_lists")
                    .select()
                    .in("id", values: sharedListIds)
                    .order("created_at", ascending: false)
                    .execute()
                    .value
            }

            // Mark shared lists
            sharedLists = sharedLists.map { list in
                var mutableList = list
                mutableList.isShared = true
                return mutableList
            }

            // Combine and deduplicate
            var allLists = ownedLists
            for sharedList in sharedLists {
                if !allLists.contains(where: { $0.id == sharedList.id }) {
                    allLists.append(sharedList)
                }
            }

            self.lists = allLists
            return allLists
        } catch {
            throw SyncError.fetchFailed(error.localizedDescription)
        }
    }

    func createList(name: String) async throws -> CloudShoppingList {
        guard let userId = currentUserId else {
            throw SyncError.notAuthenticated
        }

        do {
            let newList = InsertShoppingList(ownerId: userId, name: name)

            let createdList: CloudShoppingList = try await supabase
                .from("shopping_lists")
                .insert(newList)
                .select()
                .single()
                .execute()
                .value

            lists.insert(createdList, at: 0)
            return createdList
        } catch {
            throw SyncError.createFailed(error.localizedDescription)
        }
    }

    func updateList(_ list: CloudShoppingList, name: String) async throws {
        do {
            let updateData = UpdateListName(
                name: name,
                updatedAt: ISO8601DateFormatter().string(from: Date())
            )
            try await supabase
                .from("shopping_lists")
                .update(updateData)
                .eq("id", value: list.id)
                .execute()

            if let index = lists.firstIndex(where: { $0.id == list.id }) {
                lists[index].name = name
                lists[index].updatedAt = Date()
            }
        } catch {
            throw SyncError.updateFailed(error.localizedDescription)
        }
    }

    func deleteList(_ list: CloudShoppingList) async throws {
        do {
            try await supabase
                .from("shopping_lists")
                .delete()
                .eq("id", value: list.id)
                .execute()

            lists.removeAll { $0.id == list.id }
        } catch {
            throw SyncError.deleteFailed(error.localizedDescription)
        }
    }

    // MARK: - Items

    func fetchItems(for listId: UUID) async throws -> [CloudShoppingItem] {
        do {
            let items: [CloudShoppingItem] = try await supabase
                .from("shopping_items")
                .select()
                .eq("list_id", value: listId)
                .order("category_sort_order", ascending: true)
                .order("name", ascending: true)
                .execute()
                .value

            return items
        } catch {
            throw SyncError.fetchFailed(error.localizedDescription)
        }
    }

    func addItem(to listId: UUID, name: String, quantity: Int, unit: String?, category: Category) async throws -> CloudShoppingItem {
        guard let userId = currentUserId else {
            throw SyncError.notAuthenticated
        }

        do {
            let newItem = InsertShoppingItem(
                listId: listId,
                name: name,
                quantity: quantity,
                unit: unit,
                isChecked: false,
                categoryName: category.name,
                categoryIcon: category.icon,
                categorySortOrder: category.sortOrder,
                addedBy: userId
            )

            let createdItem: CloudShoppingItem = try await supabase
                .from("shopping_items")
                .insert(newItem)
                .select()
                .single()
                .execute()
                .value

            return createdItem
        } catch {
            throw SyncError.createFailed(error.localizedDescription)
        }
    }

    func updateItem(_ item: CloudShoppingItem) async throws {
        do {
            let updateData = UpdateItemFields(
                name: item.name,
                quantity: item.quantity,
                unit: item.unit,
                isChecked: item.isChecked,
                updatedAt: ISO8601DateFormatter().string(from: Date())
            )
            try await supabase
                .from("shopping_items")
                .update(updateData)
                .eq("id", value: item.id)
                .execute()
        } catch {
            throw SyncError.updateFailed(error.localizedDescription)
        }
    }

    func toggleItem(_ itemId: UUID, isChecked: Bool) async throws {
        do {
            let updateData = UpdateItemToggle(
                isChecked: isChecked,
                updatedAt: ISO8601DateFormatter().string(from: Date())
            )
            try await supabase
                .from("shopping_items")
                .update(updateData)
                .eq("id", value: itemId)
                .execute()
        } catch {
            throw SyncError.updateFailed(error.localizedDescription)
        }
    }

    func deleteItem(_ itemId: UUID) async throws {
        do {
            try await supabase
                .from("shopping_items")
                .delete()
                .eq("id", value: itemId)
                .execute()
        } catch {
            throw SyncError.deleteFailed(error.localizedDescription)
        }
    }

    func deleteCheckedItems(from listId: UUID) async throws {
        do {
            try await supabase
                .from("shopping_items")
                .delete()
                .eq("list_id", value: listId)
                .eq("is_checked", value: true)
                .execute()
        } catch {
            throw SyncError.deleteFailed(error.localizedDescription)
        }
    }

    // MARK: - Sharing

    func getListMembers(for listId: UUID) async throws -> [CloudListMember] {
        do {
            let members: [CloudListMember] = try await supabase
                .from("list_members")
                .select()
                .eq("list_id", value: listId)
                .execute()
                .value

            return members
        } catch {
            throw SyncError.fetchFailed(error.localizedDescription)
        }
    }

    func inviteUserByEmail(to listId: UUID, email: String) async throws {
        guard let userId = currentUserId else {
            throw SyncError.notAuthenticated
        }

        do {
            // Find user by email
            let profiles: [CloudProfile] = try await supabase
                .from("profiles")
                .select()
                .eq("email", value: email)
                .execute()
                .value

            guard let targetUser = profiles.first else {
                throw SyncError.fetchFailed("Пользователь с таким email не найден")
            }

            // Add to list_members
            let member = InsertListMember(
                listId: listId,
                userId: targetUser.id,
                role: "editor",
                invitedBy: userId
            )

            try await supabase
                .from("list_members")
                .insert(member)
                .execute()
        } catch let error as SyncError {
            throw error
        } catch {
            throw SyncError.createFailed(error.localizedDescription)
        }
    }

    func createInviteLink(for listId: UUID) async throws -> String {
        guard let userId = currentUserId else {
            throw SyncError.notAuthenticated
        }

        do {
            let invite = InsertListInvite(listId: listId, createdBy: userId)

            let createdInvite: CloudListInvite = try await supabase
                .from("list_invites")
                .insert(invite)
                .select()
                .single()
                .execute()
                .value

            return createdInvite.code
        } catch {
            throw SyncError.createFailed(error.localizedDescription)
        }
    }

    func joinListByCode(_ code: String) async throws {
        guard let userId = currentUserId else {
            throw SyncError.notAuthenticated
        }

        do {
            // Find invite
            let invites: [CloudListInvite] = try await supabase
                .from("list_invites")
                .select()
                .eq("code", value: code)
                .execute()
                .value

            guard let invite = invites.first else {
                throw SyncError.inviteNotFound
            }

            // Check expiration
            if let expiresAt = invite.expiresAt, expiresAt < Date() {
                throw SyncError.inviteExpired
            }

            // Add user to list_members
            let member = InsertListMember(
                listId: invite.listId,
                userId: userId,
                role: "editor",
                invitedBy: invite.createdBy
            )

            try await supabase
                .from("list_members")
                .insert(member)
                .execute()

            // Refresh lists
            _ = try await fetchLists()
        } catch let error as SyncError {
            throw error
        } catch {
            throw SyncError.createFailed(error.localizedDescription)
        }
    }

    func removeListMember(memberId: UUID) async throws {
        do {
            try await supabase
                .from("list_members")
                .delete()
                .eq("id", value: memberId)
                .execute()
        } catch {
            throw SyncError.deleteFailed(error.localizedDescription)
        }
    }

    func leaveList(_ listId: UUID) async throws {
        guard let userId = currentUserId else {
            throw SyncError.notAuthenticated
        }

        do {
            try await supabase
                .from("list_members")
                .delete()
                .eq("list_id", value: listId)
                .eq("user_id", value: userId)
                .execute()

            lists.removeAll { $0.id == listId }
        } catch {
            throw SyncError.deleteFailed(error.localizedDescription)
        }
    }

    // MARK: - Item Counts

    func getItemCounts(for listId: UUID) async throws -> (remaining: Int, checked: Int) {
        do {
            let items: [ItemCountRow] = try await supabase
                .from("shopping_items")
                .select("id, is_checked")
                .eq("list_id", value: listId)
                .execute()
                .value

            let remaining = items.filter { !$0.isChecked }.count
            let checked = items.filter { $0.isChecked }.count

            return (remaining, checked)
        } catch {
            print("Error getting item counts: \(error)")
            return (0, 0)
        }
    }
}

// MARK: - Helper Models
struct ItemCountRow: Codable {
    let id: UUID
    let isChecked: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case isChecked = "is_checked"
    }
}
