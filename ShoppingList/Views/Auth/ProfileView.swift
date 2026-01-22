import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var viewModel: AuthViewModel
    @State private var showingEditName = false
    @State private var newDisplayName = ""
    @State private var showingDeleteConfirmation = false
    @State private var showingSignOutConfirmation = false

    private var authService: AuthService {
        AuthService.shared
    }

    var body: some View {
        NavigationStack {
            List {
                // User Info Section
                Section {
                    HStack(spacing: 16) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(authService.currentProfile?.displayName ?? "Пользователь")
                                .font(.title2)
                                .fontWeight(.semibold)

                            Text(authService.currentProfile?.email ?? "")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Profile Settings
                Section("Настройки профиля") {
                    Button {
                        newDisplayName = authService.currentProfile?.displayName ?? ""
                        showingEditName = true
                    } label: {
                        HStack {
                            Label("Изменить имя", systemImage: "pencil")
                            Spacer()
                            Text(authService.currentProfile?.displayName ?? "")
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                }

                // Sync Info
                Section("Синхронизация") {
                    HStack {
                        Label("Статус", systemImage: "arrow.triangle.2.circlepath")
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Синхронизировано")
                                .foregroundColor(.secondary)
                        }
                    }

                    HStack {
                        Label("Аккаунт", systemImage: "person.badge.clock")
                        Spacer()
                        if let createdAt = authService.currentProfile?.createdAt {
                            Text(createdAt, style: .date)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Actions
                Section {
                    Button(role: .destructive) {
                        showingSignOutConfirmation = true
                    } label: {
                        Label("Выйти из аккаунта", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }

                // Danger Zone
                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Удалить аккаунт", systemImage: "trash")
                    }
                } footer: {
                    Text("Удаление аккаунта приведёт к потере всех данных. Это действие необратимо.")
                }
            }
            .navigationTitle("Профиль")
            .alert("Изменить имя", isPresented: $showingEditName) {
                TextField("Имя", text: $newDisplayName)
                Button("Отмена", role: .cancel) { }
                Button("Сохранить") {
                    Task {
                        await viewModel.updateDisplayName(newDisplayName)
                    }
                }
            }
            .alert("Выйти из аккаунта?", isPresented: $showingSignOutConfirmation) {
                Button("Отмена", role: .cancel) { }
                Button("Выйти", role: .destructive) {
                    Task {
                        await viewModel.signOut()
                    }
                }
            } message: {
                Text("Вы сможете войти снова в любое время")
            }
            .alert("Удалить аккаунт?", isPresented: $showingDeleteConfirmation) {
                Button("Отмена", role: .cancel) { }
                Button("Удалить", role: .destructive) {
                    Task {
                        await viewModel.deleteAccount()
                    }
                }
            } message: {
                Text("Все ваши данные будут удалены. Это действие необратимо.")
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.1))
                }
            }
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
}
