import SwiftUI

struct RegisterView: View {
    @ObservedObject var viewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)

                        Text("Создать аккаунт")
                            .font(.title)
                            .fontWeight(.bold)

                        Text("Заполните данные для регистрации")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)

                    // Form
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Имя")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("Ваше имя", text: $viewModel.displayName)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.name)
                                .autocorrectionDisabled()
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Email")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("email@example.com", text: $viewModel.email)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Пароль")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            SecureField("Минимум 6 символов", text: $viewModel.password)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.newPassword)

                            if !viewModel.password.isEmpty && viewModel.password.count < 6 {
                                Text("Пароль должен содержать минимум 6 символов")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Подтвердите пароль")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            SecureField("Повторите пароль", text: $viewModel.confirmPassword)
                                .textFieldStyle(.roundedBorder)
                                .textContentType(.newPassword)

                            if !viewModel.confirmPassword.isEmpty && viewModel.password != viewModel.confirmPassword {
                                Text("Пароли не совпадают")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Register Button
                    Button {
                        Task {
                            await viewModel.signUp()
                            if viewModel.isAuthenticated {
                                dismiss()
                            }
                        }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Зарегистрироваться")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.isSignUpValid ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .disabled(!viewModel.isSignUpValid || viewModel.isLoading)
                    .padding(.horizontal)

                    // Terms
                    Text("Регистрируясь, вы соглашаетесь с условиями использования и политикой конфиденциальности")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
            }
            .alert("Ошибка", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage ?? "Неизвестная ошибка")
            }
        }
    }
}

#Preview {
    RegisterView(viewModel: AuthViewModel())
}
