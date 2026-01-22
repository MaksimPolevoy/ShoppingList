import Foundation
import Supabase

// MARK: - Realtime Change Types
enum RealtimeChangeType {
    case insert
    case update
    case delete
}

struct ItemChange {
    let type: RealtimeChangeType
    let item: CloudShoppingItem?
    let oldItem: CloudShoppingItem?
    let itemId: UUID?
}

struct ListChange {
    let type: RealtimeChangeType
    let list: CloudShoppingList?
    let listId: UUID?
}

// MARK: - Realtime Service
@MainActor
class RealtimeService: ObservableObject {
    static let shared = RealtimeService()

    private var itemsChannel: RealtimeChannelV2?
    private var listsChannel: RealtimeChannelV2?
    private var currentListId: UUID?
    private var subscriptions: [RealtimeSubscription] = []

    // Callbacks
    var onItemChange: ((ItemChange) -> Void)?
    var onListChange: ((ListChange) -> Void)?

    // Decoder for Supabase dates
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            let formatterWithFractional = ISO8601DateFormatter()
            formatterWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatterWithFractional.date(from: dateString) {
                return date
            }

            let formatterWithoutFractional = ISO8601DateFormatter()
            formatterWithoutFractional.formatOptions = [.withInternetDateTime]
            if let date = formatterWithoutFractional.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateString)")
        }
        return decoder
    }()

    private init() {}

    // MARK: - Subscribe to Items

    func subscribeToItems(listId: UUID) async {
        // Unsubscribe from previous list if any
        await unsubscribeFromItems()

        currentListId = listId

        let channel = supabase.realtimeV2.channel("items-\(listId.uuidString)")
        subscriptions.removeAll()

        // Handle insertions
        let insertSub = channel.onPostgresChange(
            InsertAction.self,
            schema: "public",
            table: "shopping_items",
            filter: "list_id=eq.\(listId.uuidString)"
        ) { [weak self] insertion in
            guard let self = self else { return }
            print("📡 Realtime: received INSERT")
            do {
                let item = try insertion.decodeRecord(as: CloudShoppingItem.self, decoder: self.decoder)
                Task { @MainActor in
                    print("📡 Realtime: INSERT item \(item.name)")
                    self.onItemChange?(ItemChange(type: .insert, item: item, oldItem: nil, itemId: item.id))
                }
            } catch {
                print("📡 Realtime: failed to decode INSERT - \(error)")
            }
        }
        subscriptions.append(insertSub)

        // Handle updates
        let updateSub = channel.onPostgresChange(
            UpdateAction.self,
            schema: "public",
            table: "shopping_items",
            filter: "list_id=eq.\(listId.uuidString)"
        ) { [weak self] update in
            guard let self = self else { return }
            print("📡 Realtime: received UPDATE")
            do {
                let item = try update.decodeRecord(as: CloudShoppingItem.self, decoder: self.decoder)
                Task { @MainActor in
                    print("📡 Realtime: UPDATE item \(item.name), isChecked=\(item.isChecked)")
                    self.onItemChange?(ItemChange(type: .update, item: item, oldItem: nil, itemId: item.id))
                }
            } catch {
                print("📡 Realtime: failed to decode UPDATE - \(error)")
            }
        }
        subscriptions.append(updateSub)

        // Handle deletions
        let deleteSub = channel.onPostgresChange(
            DeleteAction.self,
            schema: "public",
            table: "shopping_items",
            filter: "list_id=eq.\(listId.uuidString)"
        ) { [weak self] deletion in
            guard let self = self else { return }
            print("📡 Realtime: received DELETE")
            // Try to decode old record first
            if let oldItem = try? deletion.decodeOldRecord(as: CloudShoppingItem.self, decoder: self.decoder) {
                print("📡 Realtime: DELETE item \(oldItem.name)")
                Task { @MainActor in
                    self.onItemChange?(ItemChange(type: .delete, item: nil, oldItem: oldItem, itemId: oldItem.id))
                }
            } else {
                // Fallback: try to get ID from raw data
                print("📡 Realtime: DELETE - could not decode oldRecord, trying raw data")
                let oldRecord = deletion.oldRecord
                if let idValue = oldRecord["id"],
                   case .string(let idString) = idValue,
                   let id = UUID(uuidString: idString) {
                    print("📡 Realtime: DELETE item id \(id)")
                    Task { @MainActor in
                        self.onItemChange?(ItemChange(type: .delete, item: nil, oldItem: nil, itemId: id))
                    }
                } else {
                    print("📡 Realtime: DELETE - failed to get item ID, oldRecord: \(oldRecord)")
                }
            }
        }
        subscriptions.append(deleteSub)

        do {
            try await channel.subscribe()
            itemsChannel = channel
            print("📡 Realtime: subscribed to items for list \(listId)")
        } catch {
            print("📡 Realtime: failed to subscribe to items - \(error)")
        }
    }

    func unsubscribeFromItems() async {
        if let channel = itemsChannel {
            await channel.unsubscribe()
            itemsChannel = nil
        }
        currentListId = nil
    }

    // MARK: - Subscribe to Lists

    func subscribeToLists(userId: UUID) async {
        await unsubscribeFromLists()

        let channel = supabase.realtimeV2.channel("lists-\(userId.uuidString)")

        // Handle insertions
        let listInsertSub = channel.onPostgresChange(
            InsertAction.self,
            schema: "public",
            table: "shopping_lists",
            filter: "owner_id=eq.\(userId.uuidString)"
        ) { [weak self] insertion in
            guard let self = self else { return }
            if let list = try? insertion.decodeRecord(as: CloudShoppingList.self, decoder: self.decoder) {
                Task { @MainActor in
                    self.onListChange?(ListChange(type: .insert, list: list, listId: list.id))
                }
            }
        }
        _ = listInsertSub

        // Handle updates
        let listUpdateSub = channel.onPostgresChange(
            UpdateAction.self,
            schema: "public",
            table: "shopping_lists",
            filter: "owner_id=eq.\(userId.uuidString)"
        ) { [weak self] update in
            guard let self = self else { return }
            if let list = try? update.decodeRecord(as: CloudShoppingList.self, decoder: self.decoder) {
                Task { @MainActor in
                    self.onListChange?(ListChange(type: .update, list: list, listId: list.id))
                }
            }
        }
        _ = listUpdateSub

        // Handle deletions
        let listDeleteSub = channel.onPostgresChange(
            DeleteAction.self,
            schema: "public",
            table: "shopping_lists",
            filter: "owner_id=eq.\(userId.uuidString)"
        ) { [weak self] deletion in
            guard let self = self else { return }
            if let oldList = try? deletion.decodeOldRecord(as: CloudShoppingList.self, decoder: self.decoder) {
                Task { @MainActor in
                    self.onListChange?(ListChange(type: .delete, list: nil, listId: oldList.id))
                }
            }
        }
        _ = listDeleteSub

        do {
            try await channel.subscribe()
            listsChannel = channel
        } catch {
            print("📡 Realtime: failed to subscribe to lists - \(error)")
        }
    }

    func unsubscribeFromLists() async {
        if let channel = listsChannel {
            await channel.unsubscribe()
            listsChannel = nil
        }
    }

    // MARK: - Unsubscribe All

    func unsubscribeAll() async {
        await unsubscribeFromItems()
        await unsubscribeFromLists()
        onItemChange = nil
        onListChange = nil
    }
}
