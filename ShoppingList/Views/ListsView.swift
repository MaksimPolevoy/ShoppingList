import SwiftUI

extension Notification.Name {
    static let shoppingListDataChanged = Notification.Name("shoppingListDataChanged")
}

struct ListsView: View {
    @StateObject private var syncService = CloudSyncService.shared
    @State private var showingAddList = false
    @State private var showingJoinList = false
    @State private var newListName = ""
    @State private var navigationPath = NavigationPath()
    @State private var listCounts: [UUID: (remaining: Int, checked: Int)] = [:]
    @State private var selectedListForSharing: CloudShoppingList?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if syncService.lists.isEmpty && !isLoading {
                    emptyStateView
                } else {
                    listView
                }
            }
            .navigationTitle("Списки покупок")
            .navigationDestination(for: CloudShoppingList.self) { list in
                CloudItemsView(list: list)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingJoinList = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                    }
                }
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
            .alert("Ошибка", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "Неизвестная ошибка")
            }
            .sheet(isPresented: $showingJoinList) {
                JoinListView()
            }
            .sheet(item: $selectedListForSharing) { list in
                ShareListView(list: list)
            }
            .task {
                await fetchLists()
            }
            .onChange(of: navigationPath) { newPath in
                if newPath.isEmpty {
                    Task {
                        await fetchLists()
                    }
                }
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active {
                    Task {
                        await fetchLists()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .shoppingListDataChanged)) { _ in
                Task {
                    await fetchLists()
                }
            }
            .overlay {
                if isLoading && syncService.lists.isEmpty {
                    ProgressView("Загрузка...")
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

            Button {
                showingJoinList = true
            } label: {
                Label("Присоединиться к списку", systemImage: "person.badge.plus")
                    .font(.subheadline)
            }
            .padding(.top, 8)
        }
        .padding()
    }

    private var listView: some View {
        List {
            ForEach(syncService.lists) { list in
                NavigationLink(value: list) {
                    CloudListRowView(
                        list: list,
                        counts: listCounts[list.id] ?? (0, 0),
                        onShare: {
                            selectedListForSharing = list
                        }
                    )
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        deleteList(list)
                    } label: {
                        Label("Удалить", systemImage: "trash")
                    }

                    Button {
                        selectedListForSharing = list
                    } label: {
                        Label("Поделиться", systemImage: "square.and.arrow.up")
                    }
                    .tint(.blue)
                }
            }
        }
        .refreshable {
            await fetchLists()
        }
    }

    private func fetchLists() async {
        isLoading = true
        do {
            let lists = try await syncService.fetchLists()

            // Fetch counts for each list
            var counts: [UUID: (remaining: Int, checked: Int)] = [:]
            for list in lists {
                counts[list.id] = try await syncService.getItemCounts(for: list.id)
            }
            listCounts = counts
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isLoading = false
    }

    private func createList() {
        guard !newListName.trimmingCharacters(in: .whitespaces).isEmpty else {
            newListName = ""
            return
        }

        let name = newListName.trimmingCharacters(in: .whitespaces)
        newListName = ""

        Task {
            do {
                _ = try await syncService.createList(name: name)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func deleteList(_ list: CloudShoppingList) {
        Task {
            do {
                // If it's a shared list and user is not owner, leave it
                if list.isShared == true {
                    try await syncService.leaveList(list.id)
                } else {
                    try await syncService.deleteList(list)
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

struct CloudListRowView: View {
    let list: CloudShoppingList
    let counts: (remaining: Int, checked: Int)
    let onShare: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(list.name)
                        .font(.headline)

                    if list.isShared == true {
                        Image(systemName: "person.2.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }

                HStack(spacing: 8) {
                    if counts.remaining > 0 {
                        Label("\(counts.remaining) осталось", systemImage: "circle")
                            .font(.caption)
                            .foregroundColor(.primary)
                    }

                    if counts.checked > 0 {
                        Label("\(counts.checked) куплено", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }

                    if counts.remaining == 0 && counts.checked == 0 {
                        Text("Пустой список")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Progress indicator
            let total = counts.remaining + counts.checked
            if total > 0 {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: CGFloat(counts.checked) / CGFloat(total))
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 30, height: 30)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

#Preview {
    ListsView()
}
