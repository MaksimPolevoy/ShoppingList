import SwiftUI

struct AddItemView: View {
    @ObservedObject var viewModel: ItemsViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isNameFocused: Bool
    @State private var suggestions: [ProductSuggestion] = []

    private let units = ["шт", "г", "л", "мл", "уп", "пучок", ""]

    // Step, min and max based on unit type
    private var quantityStep: Int {
        switch viewModel.newItemUnit {
        case "г": return 100
        case "мл": return 50
        default: return 1
        }
    }

    private var minQuantity: Int {
        switch viewModel.newItemUnit {
        case "г": return 100
        case "мл": return 50
        default: return 1
        }
    }

    private var maxQuantity: Int {
        switch viewModel.newItemUnit {
        case "г": return 10000
        case "мл": return 5000
        default: return 99
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Form {
                    // Item name with category preview
                    Section {
                        TextField("Название товара", text: $viewModel.newItemName)
                            .focused($isNameFocused)
                            .autocorrectionDisabled(false)
                            .textInputAutocapitalization(.sentences)
                            .onChange(of: viewModel.newItemName) { newValue in
                                suggestions = ProductSuggestions.shared.suggestions(for: newValue)
                            }

                        // Category preview
                        if !viewModel.newItemName.isEmpty {
                            let category = viewModel.previewCategory(for: viewModel.newItemName)
                            HStack {
                                Text("Категория:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(category.icon) \(category.name)")
                                    .foregroundColor(.primary)
                            }
                            .font(.subheadline)
                        }
                    } header: {
                        Text("Товар")
                    }

                    // Suggestions
                    if !suggestions.isEmpty {
                        Section {
                            ForEach(suggestions) { suggestion in
                                Button {
                                    selectSuggestion(suggestion)
                                } label: {
                                    HStack {
                                        let category = CategoryDetector.shared.detectCategory(for: suggestion.name)
                                        Text(category.icon)
                                        Text(suggestion.name)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Text("\(suggestion.defaultQuantity) \(suggestion.unit)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        } header: {
                            Text("Подсказки")
                        }
                    }

                    // Quantity and unit
                    Section {
                        // Quantity with +/- buttons
                        HStack {
                            Text("Количество")
                            Spacer()

                            HStack(spacing: 0) {
                                Button {
                                    let step = quantityStep
                                    if viewModel.newItemQuantity > step {
                                        viewModel.newItemQuantity -= step
                                        HapticManager.shared.impact(.light)
                                    } else if viewModel.newItemQuantity > minQuantity {
                                        viewModel.newItemQuantity = minQuantity
                                        HapticManager.shared.impact(.light)
                                    }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(viewModel.newItemQuantity > minQuantity ? .accentColor : .gray)
                                }
                                .buttonStyle(.plain)
                                .disabled(viewModel.newItemQuantity <= minQuantity)

                                TextField("", value: $viewModel.newItemQuantity, format: .number)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.center)
                                    .frame(width: 60)
                                    .font(.title3.monospacedDigit().bold())

                                Button {
                                    let step = quantityStep
                                    if viewModel.newItemQuantity < maxQuantity {
                                        viewModel.newItemQuantity += step
                                        HapticManager.shared.impact(.light)
                                    }
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(viewModel.newItemQuantity < maxQuantity ? .accentColor : .gray)
                                }
                                .buttonStyle(.plain)
                                .disabled(viewModel.newItemQuantity >= maxQuantity)
                            }
                        }

                        Picker("Единица", selection: $viewModel.newItemUnit) {
                            ForEach(units, id: \.self) { unit in
                                Text(unit.isEmpty ? "—" : unit).tag(unit)
                            }
                        }
                    } header: {
                        Text("Количество")
                    }

                    // Quick add suggestions
                    Section {
                        quickAddGrid
                    } header: {
                        Text("Популярные товары")
                    }
                }
            }
            .navigationTitle("Новый товар")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Добавить") {
                        HapticManager.shared.notification(.success)
                        viewModel.addItem()
                        dismiss()
                    }
                    .disabled(viewModel.newItemName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                isNameFocused = true
            }
        }
    }

    private func selectSuggestion(_ suggestion: ProductSuggestion) {
        HapticManager.shared.impact(.light)
        viewModel.newItemName = suggestion.name
        viewModel.newItemQuantity = suggestion.defaultQuantity
        viewModel.newItemUnit = suggestion.unit
        suggestions = []
    }

    private var quickAddGrid: some View {
        let quickItems = [
            ("Молоко", "л", 1),
            ("Хлеб", "шт", 1),
            ("Яйца", "шт", 10),
            ("Масло сливочное", "г", 200),
            ("Сыр", "г", 200),
            ("Курица", "г", 1000),
            ("Картофель", "г", 1000),
            ("Лук", "г", 500),
            ("Помидоры", "г", 500),
            ("Огурцы", "г", 500),
            ("Яблоки", "г", 1000),
            ("Бананы", "г", 1000)
        ]

        return LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 10) {
            ForEach(quickItems, id: \.0) { item in
                Button {
                    HapticManager.shared.impact(.light)
                    viewModel.newItemName = item.0
                    viewModel.newItemUnit = item.1
                    viewModel.newItemQuantity = item.2
                } label: {
                    let category = CategoryDetector.shared.detectCategory(for: item.0)
                    VStack(spacing: 4) {
                        Text(category.icon)
                            .font(.title2)
                        Text(item.0)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    AddItemView(viewModel: {
        let context = DataController.preview.container.viewContext
        let list = ShoppingListEntity(context: context)
        list.id = UUID()
        list.name = "Тест"
        return ItemsViewModel(list: list, dataController: DataController.preview)
    }())
}
