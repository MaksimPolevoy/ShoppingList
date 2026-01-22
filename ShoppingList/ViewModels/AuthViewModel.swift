import Foundation
import SwiftUI
import Combine

@MainActor
class AuthViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var displayName = ""

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false

    @Published var isAuthenticated = false
    @Published var isCheckingAuth = true

    // MARK: - Dependencies
    private let authService = AuthService.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties
    var currentUser: CloudProfile? {
        authService.currentProfile
    }

    var isSignUpValid: Bool {
        !email.isEmpty &&
        !password.isEmpty &&
        password.count >= 6 &&
        password == confirmPassword &&
        !displayName.isEmpty
    }

    var isSignInValid: Bool {
        !email.isEmpty && !password.isEmpty
    }

    // MARK: - Init
    init() {
        setupBindings()
    }

    private func setupBindings() {
        authService.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .assign(to: &$isAuthenticated)

        authService.$isLoading
            .receive(on: DispatchQueue.main)
            .map { !$0 }
            .assign(to: &$isCheckingAuth)

        // When checking is done, update isCheckingAuth
        authService.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] loading in
                if !loading {
                    self?.isCheckingAuth = false
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Sign Up
    func signUp() async {
        guard isSignUpValid else {
            showErrorMessage("Пожалуйста, заполните все поля корректно")
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await authService.signUp(
                email: email.trimmingCharacters(in: .whitespaces),
                password: password,
                displayName: displayName.trimmingCharacters(in: .whitespaces)
            )
            clearForm()
        } catch {
            showErrorMessage(error.localizedDescription)
        }

        isLoading = false
    }

    // MARK: - Sign In
    func signIn() async {
        guard isSignInValid else {
            showErrorMessage("Введите email и пароль")
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await authService.signIn(
                email: email.trimmingCharacters(in: .whitespaces),
                password: password
            )
            clearForm()
        } catch {
            showErrorMessage(error.localizedDescription)
        }

        isLoading = false
    }

    // MARK: - Sign Out
    func signOut() async {
        isLoading = true

        do {
            try await authService.signOut()
        } catch {
            showErrorMessage(error.localizedDescription)
        }

        isLoading = false
    }

    // MARK: - Update Profile
    func updateDisplayName(_ newName: String) async {
        isLoading = true

        do {
            try await authService.updateProfile(displayName: newName)
        } catch {
            showErrorMessage(error.localizedDescription)
        }

        isLoading = false
    }

    // MARK: - Reset Password
    func resetPassword() async {
        guard !email.isEmpty else {
            showErrorMessage("Введите email для сброса пароля")
            return
        }

        isLoading = true

        do {
            try await authService.resetPassword(email: email)
            showErrorMessage("Письмо для сброса пароля отправлено")
        } catch {
            showErrorMessage(error.localizedDescription)
        }

        isLoading = false
    }

    // MARK: - Delete Account
    func deleteAccount() async {
        isLoading = true

        do {
            try await authService.deleteAccount()
        } catch {
            showErrorMessage(error.localizedDescription)
        }

        isLoading = false
    }

    // MARK: - Helpers
    private func clearForm() {
        email = ""
        password = ""
        confirmPassword = ""
        displayName = ""
    }

    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }
}
