import SwiftUI

struct AddItemView: View {
    @ObservedObject var viewModel: ItemsViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isNameFocused: Bool

    private let units = ["шт", "кг", "г", "л", "мл", "уп", ""]

    var body: some View {
        NavigationStack {
            Form {
                // Item name with category preview
                Section {
                    TextField("Название товара", text: $viewModel.newItemName)
                        .focused($isNameFocused)
                        .autocorrectionDisabled(false)
                        .textInputAutocapitalization(.sentences)

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

                // Quantity and unit
                Section {
                    Stepper("Количество: \(viewModel.newItemQuantity)", value: $viewModel.newItemQuantity, in: 1...999)

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
                    Text("Быстрое добавление")
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

    private var quickAddGrid: some View {
        let quickItems = [
            "Молоко", "Хлеб", "Яйца", "Масло",
            "Сыр", "Курица", "Картофель", "Лук",
            "Помидоры", "Огурцы", "Яблоки", "Бананы"
        ]

        return LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 10) {
            ForEach(quickItems, id: \.self) { item in
                Button {
                    viewModel.newItemName = item
                } label: {
                    let category = CategoryDetector.shared.detectCategory(for: item)
                    VStack(spacing: 4) {
                        Text(category.icon)
                            .font(.title2)
                        Text(item)
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
