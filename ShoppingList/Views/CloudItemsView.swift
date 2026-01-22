import SwiftUI
import UIKit

struct CloudItemsView: View {
    let list: CloudShoppingList

    @State private var items: [CloudShoppingItem] = []
    @State private var newItemText = ""
    @State private var suggestions: [ProductSuggestion] = []
    @State private var selectedSuggestion: ProductSuggestion?
    @State private var itemQuantity: Int = 1
    @State private var itemUnit: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    @FocusState private var isInputFocused: Bool

    // Edit item state
    @State private var editingItem: CloudShoppingItem?
    @State private var editQuantity: Int = 1
    @State private var editUnit: String = ""

    private let syncService = CloudSyncService.shared
    private let realtimeService = RealtimeService.shared

    private var activeItems: [CloudShoppingItem] {
        items.filter { !$0.isChecked }
    }

    private var checkedItems: [CloudShoppingItem] {
        items.filter { $0.isChecked }
    }

    private var itemGroups: [ItemGroup] {
        let grouped = Dictionary(grouping: activeItems) { $0.categoryName ?? "Другое" }
        return grouped.map { name, items in
            let icon = items.first?.categoryIcon ?? "📦"
            let sortOrder = items.first?.categorySortOrder ?? 99
            return ItemGroup(categoryName: name, categoryIcon: icon, sortOrder: sortOrder, items: items)
        }.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var totalCount: Int {
        items.count
    }

    // Step, min and max based on unit type
    private var quantityStep: Int {
        switch itemUnit {
        case "г": return 100
        case "мл": return 50
        default: return 1
        }
    }

    private var minQuantity: Int {
        switch itemUnit {
        case "г": return 100
        case "мл": return 50
        default: return 1
        }
    }

    private var maxQuantity: Int {
        switch itemUnit {
        case "г": return 10000
        case "мл": return 5000
        default: return 99
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            List {
                // Active items grouped by category
                ForEach(itemGroups) { group in
                    Section {
                        ForEach(group.items, id: \.id) { item in
                            CloudItemRowView(item: item, onToggle: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    HapticManager.shared.impact(.medium)
                                    toggleItem(item)
                                }
                            }, onDelete: {
                                withAnimation {
                                    HapticManager.shared.impact(.light)
                                    deleteItem(item)
                                }
                            }, onTap: {
                                HapticManager.shared.impact(.light)
                                editQuantity = item.quantity
                                editUnit = item.unit ?? ""
                                editingItem = item
                            })
                        }
                    } header: {
                        HStack(spacing: 6) {
                            Text(group.categoryIcon)
                            Text(group.categoryName)
                                .textCase(nil)
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondary)
                    }
                }

                // Checked items section
                if !checkedItems.isEmpty {
                    Section {
                        ForEach(checkedItems, id: \.id) { item in
                            CloudItemRowView(item: item, onToggle: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    HapticManager.shared.impact(.light)
                                    toggleItem(item)
                                }
                            }, onDelete: {
                                withAnimation {
                                    deleteItem(item)
                                }
                            }, onTap: {
                                HapticManager.shared.impact(.light)
                                editQuantity = item.quantity
                                editUnit = item.unit ?? ""
                                editingItem = item
                            })
                        }
                    } header: {
                        HStack {
                            Label("Куплено", systemImage: "checkmark.circle.fill")
                                .textCase(nil)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.green)
                            Spacer()
                            Button {
                                HapticManager.shared.notification(.warning)
                                withAnimation {
                                    deleteCheckedItems()
                                }
                            } label: {
                                Text("Очистить")
                                    .font(.caption.weight(.medium))
                            }
                            .foregroundColor(.red)
                        }
                    }
                }

                // Spacer for bottom input
                Color.clear
                    .frame(height: 80)
                    .listRowBackground(Color.clear)
            }
            .listStyle(.insetGrouped)
            .scrollDismissesKeyboard(.interactively)

            // Quick add input at bottom
            quickAddBar
        }
        .navigationTitle(list.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .status) {
                if totalCount > 0 {
                    progressView
                }
            }
        }
        .sheet(item: $editingItem) { item in
            CloudEditItemSheet(
                item: item,
                quantity: $editQuantity,
                unit: $editUnit,
                onSave: {
                    updateItem(item, quantity: editQuantity, unit: editUnit)
                    editingItem = nil
                }
            )
            .presentationDetents([.height(300)])
        }
        .overlay {
            if itemGroups.isEmpty && checkedItems.isEmpty && !isInputFocused && newItemText.isEmpty && !isLoading {
                emptyStateView
            }
        }
        .overlay {
            if isLoading && items.isEmpty {
                ProgressView("Загрузка...")
            }
        }
        .alert("Ошибка", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "Неизвестная ошибка")
        }
        .task {
            await fetchItems()
            await setupRealtime()
        }
        .onDisappear {
            Task {
                await realtimeService.unsubscribeFromItems()
            }
            NotificationCenter.default.post(name: .shoppingListDataChanged, object: nil)
        }
    }

    // MARK: - Data Operations

    private func fetchItems() async {
        isLoading = true
        do {
            items = try await syncService.fetchItems(for: list.id)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isLoading = false
    }

    private func setupRealtime() async {
        realtimeService.onItemChange = { change in
            switch change.type {
            case .insert:
                if let item = change.item {
                    withAnimation {
                        if !items.contains(where: { $0.id == item.id }) {
                            items.append(item)
                        }
                    }
                }
            case .update:
                if let item = change.item,
                   let index = items.firstIndex(where: { $0.id == item.id }) {
                    withAnimation {
                        items[index] = item
                    }
                }
            case .delete:
                let deleteId = change.itemId ?? change.oldItem?.id
                if let itemId = deleteId {
                    withAnimation {
                        items.removeAll { $0.id == itemId }
                    }
                }
            }
        }

        await realtimeService.subscribeToItems(listId: list.id)
    }

    private func toggleItem(_ item: CloudShoppingItem) {
        // Optimistic update
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].isChecked.toggle()
        }

        Task {
            do {
                try await syncService.toggleItem(item.id, isChecked: !(item.isChecked))
            } catch {
                // Rollback
                if let index = items.firstIndex(where: { $0.id == item.id }) {
                    items[index].isChecked = item.isChecked
                }
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func deleteItem(_ item: CloudShoppingItem) {
        // Optimistic update
        items.removeAll { $0.id == item.id }

        Task {
            do {
                try await syncService.deleteItem(item.id)
            } catch {
                // Rollback
                items.append(item)
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func deleteCheckedItems() {
        let checkedIds = checkedItems.map { $0.id }
        items.removeAll { $0.isChecked }

        Task {
            do {
                try await syncService.deleteCheckedItems(from: list.id)
            } catch {
                // Refetch on error
                await fetchItems()
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func updateItem(_ item: CloudShoppingItem, quantity: Int, unit: String) {
        var updated = item
        updated.quantity = quantity
        updated.unit = unit.isEmpty ? nil : unit

        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = updated
        }

        Task {
            do {
                try await syncService.updateItem(updated)
            } catch {
                await fetchItems()
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func addItem() {
        let trimmed = newItemText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        HapticManager.shared.notification(.success)

        let category = CategoryDetector.shared.detectCategory(for: trimmed)

        Task {
            do {
                // Item will be added via Realtime subscription
                _ = try await syncService.addItem(
                    to: list.id,
                    name: trimmed,
                    quantity: itemQuantity,
                    unit: itemUnit.isEmpty ? nil : itemUnit,
                    category: category
                )

                // Save to autocomplete
                ProductSuggestions.shared.addCustomProduct(
                    name: trimmed,
                    unit: itemUnit,
                    quantity: itemQuantity
                )
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }

        clearInput()
    }

    // MARK: - Quick Add Bar

    private var quickAddBar: some View {
        VStack(spacing: 0) {
            // Suggestions list
            if !suggestions.isEmpty && isInputFocused {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestions) { suggestion in
                            Button {
                                selectSuggestion(suggestion)
                            } label: {
                                HStack(spacing: 6) {
                                    let category = CategoryDetector.shared.detectCategory(for: suggestion.name)
                                    Text(category.icon)
                                        .font(.caption)
                                    Text(suggestion.name)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray5))
                                .cornerRadius(16)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Color(.systemBackground).opacity(0.95))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Quantity selector (when suggestion selected)
            if selectedSuggestion != nil {
                HStack(spacing: 16) {
                    Text("Количество:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack(spacing: 0) {
                        Button {
                            if itemQuantity > quantityStep {
                                itemQuantity -= quantityStep
                            } else if itemQuantity > minQuantity {
                                itemQuantity = minQuantity
                            }
                            HapticManager.shared.impact(.light)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                                .foregroundColor(itemQuantity > minQuantity ? .accentColor : .gray)
                        }
                        .disabled(itemQuantity <= minQuantity)

                        Text("\(itemQuantity)")
                            .font(.title3.monospacedDigit().bold())
                            .frame(minWidth: 50)

                        Button {
                            if itemQuantity < maxQuantity {
                                itemQuantity += quantityStep
                            }
                            HapticManager.shared.impact(.light)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(itemQuantity < maxQuantity ? .accentColor : .gray)
                        }
                        .disabled(itemQuantity >= maxQuantity)
                    }

                    Text(itemUnit)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(minWidth: 30)

                    Spacer()

                    Button {
                        clearSelection()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(Color(.systemGray6))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Input bar
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentColor)

                    TextField("Добавить товар...", text: $newItemText)
                        .focused($isInputFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            addItem()
                        }
                        .onChange(of: newItemText) { newValue in
                            updateSuggestions(for: newValue)
                        }

                    if !newItemText.isEmpty {
                        Button {
                            clearInput()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                if !newItemText.isEmpty || selectedSuggestion != nil {
                    Button {
                        addItem()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .background(
            LinearGradient(
                colors: [.clear, Color(.systemBackground).opacity(0.9), Color(.systemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .animation(.spring(response: 0.3), value: newItemText.isEmpty)
        .animation(.spring(response: 0.3), value: suggestions.count)
        .animation(.spring(response: 0.3), value: selectedSuggestion != nil)
    }

    private func updateSuggestions(for text: String) {
        if selectedSuggestion != nil && text != selectedSuggestion?.name {
            selectedSuggestion = nil
        }
        suggestions = ProductSuggestions.shared.suggestions(for: text)
    }

    private func selectSuggestion(_ suggestion: ProductSuggestion) {
        HapticManager.shared.impact(.light)
        newItemText = suggestion.name
        selectedSuggestion = suggestion
        itemQuantity = suggestion.defaultQuantity
        itemUnit = suggestion.unit
        suggestions = []
    }

    private func clearSelection() {
        selectedSuggestion = nil
        itemQuantity = 1
        itemUnit = ""
    }

    private func clearInput() {
        newItemText = ""
        suggestions = []
        clearSelection()
    }

    // MARK: - Progress View

    private var progressView: some View {
        HStack(spacing: 8) {
            // Mini progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.2))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.green, .mint],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progressPercentage)
                }
            }
            .frame(width: 60, height: 6)

            Text("\(checkedItems.count)/\(totalCount)")
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
        }
    }

    private var progressPercentage: CGFloat {
        guard totalCount > 0 else { return 0 }
        return CGFloat(checkedItems.count) / CGFloat(totalCount)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: "cart")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.accentColor, .accentColor.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 8) {
                Text("Список пуст")
                    .font(.title2.weight(.semibold))

                Text("Добавьте первый товар")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Button {
                isInputFocused = true
            } label: {
                Label("Начать покупки", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
        }
        .padding()
    }
}

// MARK: - Item Group

struct ItemGroup: Identifiable {
    let id = UUID()
    let categoryName: String
    let categoryIcon: String
    let sortOrder: Int
    let items: [CloudShoppingItem]
}

// MARK: - Cloud Item Row View

struct CloudItemRowView: View {
    let item: CloudShoppingItem
    let onToggle: () -> Void
    let onDelete: () -> Void
    var onTap: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 14) {
            // Animated checkbox
            Button {
                onToggle()
            } label: {
                ZStack {
                    Circle()
                        .stroke(item.isChecked ? Color.green : Color.gray.opacity(0.4), lineWidth: 2)
                        .frame(width: 26, height: 26)

                    if item.isChecked {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 26, height: 26)
                            .transition(.scale)

                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .transition(.scale)
                    }
                }
                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: item.isChecked)
            }
            .buttonStyle(.plain)

            // Item info
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.body)
                    .strikethrough(item.isChecked, color: .secondary)
                    .foregroundColor(item.isChecked ? .secondary : .primary)
                    .animation(.easeInOut(duration: 0.2), value: item.isChecked)

                if let unit = item.unit, !unit.isEmpty {
                    Text("\(item.quantity) \(unit)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if item.quantity > 1 {
                    Text("\(item.quantity) шт")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Удалить", systemImage: "trash.fill")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                onToggle()
            } label: {
                Label(
                    item.isChecked ? "Вернуть" : "Готово",
                    systemImage: item.isChecked ? "arrow.uturn.backward" : "checkmark"
                )
            }
            .tint(item.isChecked ? .orange : .green)
        }
    }
}

// MARK: - Cloud Edit Item Sheet

struct CloudEditItemSheet: View {
    let item: CloudShoppingItem
    @Binding var quantity: Int
    @Binding var unit: String
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    private let units = ["шт", "г", "л", "мл", "уп", "пучок", ""]

    // Computed properties based on current unit
    private var quantityStep: Int {
        switch unit {
        case "г": return 100
        case "мл": return 50
        default: return 1
        }
    }

    private var minQuantity: Int {
        switch unit {
        case "г": return 100
        case "мл": return 50
        default: return 1
        }
    }

    private var maxQuantity: Int {
        switch unit {
        case "г": return 10000
        case "мл": return 5000
        default: return 99
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Item name
                Text(item.name)
                    .font(.title2.weight(.semibold))
                    .padding(.top)

                // Quantity selector
                HStack(spacing: 20) {
                    Button {
                        if quantity > quantityStep {
                            quantity -= quantityStep
                        } else if quantity > minQuantity {
                            quantity = minQuantity
                        }
                        HapticManager.shared.impact(.light)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(quantity > minQuantity ? .accentColor : .gray)
                    }
                    .disabled(quantity <= minQuantity)

                    VStack(spacing: 4) {
                        Text("\(quantity)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text(unit.isEmpty ? "шт" : unit)
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(minWidth: 150)

                    Button {
                        if quantity < maxQuantity {
                            quantity += quantityStep
                        }
                        HapticManager.shared.impact(.light)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(quantity < maxQuantity ? .accentColor : .gray)
                    }
                    .disabled(quantity >= maxQuantity)
                }

                // Unit picker
                Picker("Единица", selection: $unit) {
                    ForEach(units, id: \.self) { u in
                        Text(u.isEmpty ? "—" : u).tag(u)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .onChange(of: unit) { newUnit in
                    // Adjust quantity when unit changes
                    let newMin = newUnit == "г" ? 100 : (newUnit == "мл" ? 50 : 1)
                    let newMax = newUnit == "г" ? 10000 : (newUnit == "мл" ? 5000 : 99)
                    if quantity < newMin {
                        quantity = newMin
                    } else if quantity > newMax {
                        quantity = newMax
                    }
                }

                Spacer()
            }
            .navigationTitle("Изменить количество")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        HapticManager.shared.notification(.success)
                        onSave()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        CloudItemsView(list: CloudShoppingList(
            id: UUID(),
            ownerId: UUID(),
            name: "Тестовый список",
            createdAt: Date(),
            updatedAt: Date(),
            isShared: false
        ))
    }
}
