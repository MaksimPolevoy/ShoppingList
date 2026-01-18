import SwiftUI

struct AddItemView: View {
    @ObservedObject var viewModel: ItemsViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isNameFocused: Bool
    @State private var suggestions: [ProductSuggestion] = []

    private let units = ["шт", "кг", "г", "л", "мл", "уп", "пучок", ""]

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
                                    if viewModel.newItemQuantity > 1 {
                                        viewModel.newItemQuantity -= 1
                                        HapticManager.shared.impact(.light)
                                    }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(viewModel.newItemQuantity > 1 ? .accentColor : .gray)
                                }
                                .buttonStyle(.plain)
                                .disabled(viewModel.newItemQuantity <= 1)

                                TextField("", value: $viewModel.newItemQuantity, format: .number)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.center)
                                    .frame(width: 50)
                                    .font(.title3.monospacedDigit().bold())

                                Button {
                                    if viewModel.newItemQuantity < 999 {
                                        viewModel.newItemQuantity += 1
                                        HapticManager.shared.impact(.light)
                                    }
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.accentColor)
                                }
                                .buttonStyle(.plain)
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
            ("Курица", "кг", 1),
            ("Картофель", "кг", 1),
            ("Лук", "кг", 1),
            ("Помидоры", "кг", 1),
            ("Огурцы", "кг", 1),
            ("Яблоки", "кг", 1),
            ("Бананы", "кг", 1)
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
