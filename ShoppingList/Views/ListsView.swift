import SwiftUI

struct ListsView: View {
    @StateObject private var viewModel = ListsViewModel()
    @State private var showingAddList = false
    @State private var newListName = ""

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.lists.isEmpty {
                    emptyStateView
                } else {
                    listView
                }
            }
            .navigationTitle("Списки покупок")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddList = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("Новый список", isPresented: $showingAddList) {
                TextField("Название списка", text: $newListName)
                Button("Отмена", role: .cancel) {
                    newListName = ""
                }
                Button("Создать") {
                    createList()
                }
            } message: {
                Text("Введите название для нового списка")
            }
            .onAppear {
                viewModel.fetchLists()
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "cart")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("Нет списков покупок")
                .font(.title2)
                .foregroundColor(.secondary)

            Text("Нажмите + чтобы создать первый список")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button {
                showingAddList = true
            } label: {
                Label("Создать список", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var listView: some View {
        List {
            ForEach(viewModel.lists, id: \.id) { list in
                NavigationLink {
                    ItemsView(list: list)
                } label: {
                    ListRowView(list: list, viewModel: viewModel)
                }
            }
            .onDelete(perform: viewModel.deleteList)
        }
    }

    private func createList() {
        guard !newListName.trimmingCharacters(in: .whitespaces).isEmpty else {
            newListName = ""
            return
        }
        _ = DataController.shared.createList(name: newListName.trimmingCharacters(in: .whitespaces))
        newListName = ""
        viewModel.fetchLists()
    }
}

struct ListRowView: View {
    let list: ShoppingListEntity
    let viewModel: ListsViewModel

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(list.name ?? "Без названия")
                    .font(.headline)

                HStack(spacing: 8) {
                    let remaining = viewModel.itemCount(for: list)
                    let checked = viewModel.checkedCount(for: list)

                    if remaining > 0 {
                        Label("\(remaining) осталось", systemImage: "circle")
                            .font(.caption)
                            .foregroundColor(.primary)
                    }

                    if checked > 0 {
                        Label("\(checked) куплено", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }

                    if remaining == 0 && checked == 0 {
                        Text("Пустой список")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Progress indicator
            let total = viewModel.totalCount(for: list)
            let checked = viewModel.checkedCount(for: list)
            if total > 0 {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: CGFloat(checked) / CGFloat(total))
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 30, height: 30)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ListsView()
        .environment(\.managedObjectContext, DataController.preview.container.viewContext)
}
