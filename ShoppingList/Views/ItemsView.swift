import SwiftUI
import UIKit

struct ItemsView: View {
    @StateObject private var viewModel: ItemsViewModel
    @State private var showingAddItem = false
    @State private var newItemText = ""
    @State private var suggestions: [ProductSuggestion] = []
    @State private var selectedSuggestion: ProductSuggestion?
    @State private var itemQuantity: Int = 1
    @State private var itemUnit: String = ""
    @FocusState private var isInputFocused: Bool

    init(list: ShoppingListEntity) {
        _viewModel = StateObject(wrappedValue: ItemsViewModel(list: list))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            List {
                // Active items grouped by category
                ForEach(viewModel.itemGroups) { group in
                    Section {
                        ForEach(group.items, id: \.id) { item in
                            ItemRowView(item: item, onToggle: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    HapticManager.shared.impact(.medium)
                                    viewModel.toggleItem(item)
                                }
                            }, onDelete: {
                                withAnimation {
                                    HapticManager.shared.impact(.light)
                                    viewModel.deleteItem(item)
                                }
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
                if !viewModel.checkedItems.isEmpty {
                    Section {
                        ForEach(viewModel.checkedItems, id: \.id) { item in
                            ItemRowView(item: item, onToggle: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    HapticManager.shared.impact(.light)
                                    viewModel.toggleItem(item)
                                }
                            }, onDelete: {
                                withAnimation {
                                    viewModel.deleteItem(item)
                                }
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
                                    viewModel.deleteCheckedItems()
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
        .navigationTitle(viewModel.list.name ?? "Список")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddItem = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
            }

            ToolbarItem(placement: .status) {
                if viewModel.totalCount > 0 {
                    progressView
                }
            }
        }
        .sheet(isPresented: $showingAddItem) {
            AddItemView(viewModel: viewModel)
        }
        .overlay {
            if viewModel.itemGroups.isEmpty && viewModel.checkedItems.isEmpty {
                emptyStateView
            }
        }
        .onAppear {
            viewModel.fetchItems()
        }
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
                            if itemQuantity > 1 { itemQuantity -= 1 }
                            HapticManager.shared.impact(.light)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                                .foregroundColor(itemQuantity > 1 ? .accentColor : .gray)
                        }
                        .disabled(itemQuantity <= 1)

                        Text("\(itemQuantity)")
                            .font(.title3.monospacedDigit().bold())
                            .frame(minWidth: 40)

                        Button {
                            if itemQuantity < 99 { itemQuantity += 1 }
                            HapticManager.shared.impact(.light)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.accentColor)
                        }
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
                            addQuickItem()
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
                        addQuickItem()
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

    private func addQuickItem() {
        let trimmed = newItemText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        HapticManager.shared.notification(.success)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            _ = DataController.shared.addItem(
                to: viewModel.list,
                name: trimmed,
                quantity: itemQuantity,
                unit: itemUnit.isEmpty ? nil : itemUnit
            )
            viewModel.fetchItems()
        }
        clearInput()
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

            Text("\(viewModel.checkedItems.count)/\(viewModel.totalCount)")
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
        }
    }

    private var progressPercentage: CGFloat {
        guard viewModel.totalCount > 0 else { return 0 }
        return CGFloat(viewModel.checkedItems.count) / CGFloat(viewModel.totalCount)
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

// MARK: - Item Row View

struct ItemRowView: View {
    let item: ShoppingItemEntity
    let onToggle: () -> Void
    let onDelete: () -> Void

    @State private var isPressed = false

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
                Text(item.name ?? "")
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

            // Source indicator with tooltip
            if let addedBy = item.addedBy, addedBy != "ios" {
                sourceIcon(for: addedBy)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
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

    @ViewBuilder
    private func sourceIcon(for source: String) -> some View {
        HStack(spacing: 4) {
            switch source {
            case "telegram":
                Image(systemName: "paperplane.fill")
                    .font(.caption2)
                    .foregroundColor(.blue)
            case "alice":
                Image(systemName: "waveform")
                    .font(.caption2)
                    .foregroundColor(.purple)
            default:
                EmptyView()
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(source == "telegram" ? Color.blue.opacity(0.1) : Color.purple.opacity(0.1))
        )
    }
}

// MARK: - Haptic Manager

class HapticManager {
    static let shared = HapticManager()

    private init() {}

    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }

    func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
}

#Preview {
    NavigationStack {
        ItemsView(list: {
            let context = DataController.preview.container.viewContext
            let list = ShoppingListEntity(context: context)
            list.id = UUID()
            list.name = "Продукты"
            return list
        }())
    }
    .environment(\.managedObjectContext, DataController.preview.container.viewContext)
}
