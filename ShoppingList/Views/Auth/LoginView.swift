import SwiftUI

struct LoginView: View {
    @ObservedObject var viewModel: AuthViewModel
    @State private var showingRegister = false
    @State private var showingResetPassword = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "cart.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)

                        Text("Списки покупок")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Войдите для синхронизации")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)

                    // Form
                    VStack(spacing: 16) {
                        TextField("Email", text: $viewModel.email)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()

                        SecureField("Пароль", text: $viewModel.password)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.password)

                        Button {
                            showingResetPassword = true
                        } label: {
                            Text("Забыли пароль?")
                                .font(.footnote)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .padding(.horizontal)

                    // Sign In Button
                    Button {
                        Task {
                            await viewModel.signIn()
                        }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Войти")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.isSignInValid ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .disabled(!viewModel.isSignInValid || viewModel.isLoading)
                    .padding(.horizontal)

                    // Divider
                    HStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 1)

                        Text("или")
                            .font(.footnote)
                            .foregroundColor(.secondary)

                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 1)
                    }
                    .padding(.horizontal)

                    // Register Button
                    Button {
                        showingRegister = true
                    } label: {
                        Text("Создать аккаунт")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingRegister) {
                RegisterView(viewModel: viewModel)
            }
            .alert("Сброс пароля", isPresented: $showingResetPassword) {
                TextField("Email", text: $viewModel.email)
                Button("Отмена", role: .cancel) { }
                Button("Отправить") {
                    Task {
                        await viewModel.resetPassword()
                    }
                }
            } message: {
                Text("Введите email для получения ссылки на сброс пароля")
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
    LoginView(viewModel: AuthViewModel())
}
