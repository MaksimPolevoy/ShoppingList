import SwiftUI

extension Notification.Name {
    static let shoppingListDataChanged = Notification.Name("shoppingListDataChanged")
}

struct ListsView: View {
    @StateObject private var viewModel = ListsViewModel()
    @State private var showingAddList = false
    @State private var newListName = ""
    @State private var navigationPath = NavigationPath()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if viewModel.lists.isEmpty {
                    emptyStateView
                } else {
                    listView
                }
            }
            .navigationTitle("Списки покупок")
            .navigationDestination(for: ShoppingListEntity.self) { list in
                ItemsView(list: list)
            }
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
            .onReceive(NotificationCenter.default.publisher(for: .shoppingListDataChanged)) { _ in
                DispatchQueue.main.async {
                    viewModel.fetchLists()
                }
            }
            .onChange(of: navigationPath) { newPath in
                // Refresh when navigating back (path becomes empty)
                if newPath.isEmpty {
                    viewModel.fetchLists()
                }
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active {
                    viewModel.fetchLists()
                }
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
                NavigationLink(value: list) {
                    ListRowView(list: list, viewModel: viewModel)
                }
            }
            .onDelete(perform: viewModel.deleteList)
        }
        .refreshable {
            viewModel.fetchLists()
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

    private var counts: (remaining: Int, checked: Int) {
        guard let id = list.id else { return (0, 0) }
        return viewModel.listCounts[id] ?? (0, 0)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(list.name ?? "Без названия")
                    .font(.headline)

                HStack(spacing: 8) {
                    let remaining = counts.remaining
                    let checked = counts.checked

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
            let total = counts.remaining + counts.checked
            let checked = counts.checked
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
