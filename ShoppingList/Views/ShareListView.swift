import SwiftUI

struct ShareListView: View {
    let list: CloudShoppingList
    @Environment(\.dismiss) private var dismiss

    @State private var inviteEmail = ""
    @State private var inviteCode: String?
    @State private var members: [CloudListMember] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showCopiedToast = false

    private let syncService = CloudSyncService.shared

    var body: some View {
        NavigationStack {
            List {
                // Invite by Email Section
                Section("Пригласить по email") {
                    HStack {
                        TextField("email@example.com", text: $inviteEmail)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()

                        Button {
                            inviteByEmail()
                        } label: {
                            Image(systemName: "paperplane.fill")
                        }
                        .disabled(inviteEmail.isEmpty || isLoading)
                    }
                }

                // Invite by Link Section
                Section("Пригласить по ссылке") {
                    if let code = inviteCode {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Код приглашения:")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            HStack {
                                Text(code)
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.medium)

                                Spacer()

                                Button {
                                    copyToClipboard(code)
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                }
                            }

                            Text("Действителен 7 дней")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Button {
                            createInviteLink()
                        } label: {
                            HStack {
                                Image(systemName: "link.badge.plus")
                                Text("Создать ссылку-приглашение")
                            }
                        }
                        .disabled(isLoading)
                    }
                }

                // Current Members Section
                Section("Участники") {
                    if members.isEmpty {
                        Text("Только вы")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(members) { member in
                            MemberRowView(member: member, onRemove: {
                                removeMember(member)
                            })
                        }
                    }
                }
            }
            .navigationTitle("Поделиться")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") {
                        dismiss()
                    }
                }
            }
            .overlay {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.1))
                }
            }
            .overlay(alignment: .bottom) {
                if showCopiedToast {
                    Text("Скопировано!")
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 20)
                }
            }
            .alert("Ошибка", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "Неизвестная ошибка")
            }
            .task {
                await loadMembers()
            }
        }
    }

    private func loadMembers() async {
        isLoading = true
        do {
            members = try await syncService.getListMembers(for: list.id)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isLoading = false
    }

    private func inviteByEmail() {
        guard !inviteEmail.isEmpty else { return }

        isLoading = true
        Task {
            do {
                try await syncService.inviteUserByEmail(to: list.id, email: inviteEmail)
                inviteEmail = ""
                await loadMembers()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isLoading = false
        }
    }

    private func createInviteLink() {
        isLoading = true
        Task {
            do {
                inviteCode = try await syncService.createInviteLink(for: list.id)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isLoading = false
        }
    }

    private func removeMember(_ member: CloudListMember) {
        isLoading = true
        Task {
            do {
                try await syncService.removeListMember(memberId: member.id)
                await loadMembers()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isLoading = false
        }
    }

    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
        withAnimation {
            showCopiedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopiedToast = false
            }
        }
    }
}

struct MemberRowView: View {
    let member: CloudListMember
    let onRemove: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .font(.title2)
                .foregroundColor(.blue)

            VStack(alignment: .leading) {
                Text("Участник")
                    .font(.body)
                Text(member.role == "editor" ? "Редактор" : "Просмотр")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(role: .destructive) {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            }
        }
    }
}

// MARK: - Join List View

struct JoinListView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var inviteCode = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showSuccess = false

    private let syncService = CloudSyncService.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)

                Text("Присоединиться к списку")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Введите код приглашения, который вам прислали")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                TextField("Код приглашения", text: $inviteCode)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .padding(.horizontal)

                Button {
                    joinList()
                } label: {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Присоединиться")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(inviteCode.isEmpty ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
                .disabled(inviteCode.isEmpty || isLoading)
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 40)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
            }
            .alert("Ошибка", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "Неизвестная ошибка")
            }
            .alert("Успешно!", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Вы присоединились к списку")
            }
        }
    }

    private func joinList() {
        guard !inviteCode.isEmpty else { return }

        isLoading = true
        Task {
            do {
                try await syncService.joinListByCode(inviteCode.trimmingCharacters(in: .whitespaces))
                showSuccess = true
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isLoading = false
        }
    }
}

#Preview {
    ShareListView(list: CloudShoppingList(
        id: UUID(),
        ownerId: UUID(),
        name: "Тестовый список",
        createdAt: Date(),
        updatedAt: Date(),
        isShared: false
    ))
}
