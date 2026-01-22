import Foundation
import Supabase
import AuthenticationServices

// MARK: - Auth Errors
enum AuthError: LocalizedError {
    case signUpFailed(String)
    case signInFailed(String)
    case signOutFailed(String)
    case sessionNotFound
    case profileCreationFailed(String)

    var errorDescription: String? {
        switch self {
        case .signUpFailed(let message):
            return "Ошибка регистрации: \(message)"
        case .signInFailed(let message):
            return "Ошибка входа: \(message)"
        case .signOutFailed(let message):
            return "Ошибка выхода: \(message)"
        case .sessionNotFound:
            return "Сессия не найдена"
        case .profileCreationFailed(let message):
            return "Ошибка создания профиля: \(message)"
        }
    }
}

// MARK: - Auth Service
@MainActor
class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published private(set) var currentUser: User?
    @Published private(set) var currentProfile: CloudProfile?
    @Published private(set) var isAuthenticated = false
    @Published private(set) var isLoading = true

    private var authStateTask: Task<Void, Never>?

    private init() {
        startAuthStateListener()
    }

    deinit {
        authStateTask?.cancel()
    }

    // MARK: - Auth State Listener
    private func startAuthStateListener() {
        authStateTask = Task {
            for await (event, session) in supabase.auth.authStateChanges {
                await MainActor.run {
                    switch event {
                    case .initialSession:
                        self.handleSession(session)
                        self.isLoading = false
                    case .signedIn:
                        self.handleSession(session)
                    case .signedOut:
                        self.currentUser = nil
                        self.currentProfile = nil
                        self.isAuthenticated = false
                    case .tokenRefreshed:
                        self.handleSession(session)
                    case .userUpdated:
                        self.handleSession(session)
                    default:
                        break
                    }
                }
            }
        }
    }

    private func handleSession(_ session: Session?) {
        if let session = session {
            self.currentUser = session.user
            self.isAuthenticated = true
            Task {
                await self.fetchProfile()
            }
        } else {
            self.currentUser = nil
            self.currentProfile = nil
            self.isAuthenticated = false
        }
    }

    // MARK: - Sign Up
    func signUp(email: String, password: String, displayName: String) async throws {
        do {
            let response = try await supabase.auth.signUp(
                email: email,
                password: password,
                data: ["display_name": .string(displayName)]
            )

            if response.user != nil {
                self.currentUser = response.user
                self.isAuthenticated = true
                await fetchProfile()
            }
        } catch {
            throw AuthError.signUpFailed(error.localizedDescription)
        }
    }

    // MARK: - Sign In
    func signIn(email: String, password: String) async throws {
        do {
            let session = try await supabase.auth.signIn(
                email: email,
                password: password
            )
            self.currentUser = session.user
            self.isAuthenticated = true
            await fetchProfile()
        } catch {
            throw AuthError.signInFailed(error.localizedDescription)
        }
    }

    // MARK: - Sign Out
    func signOut() async throws {
        do {
            try await supabase.auth.signOut()
            self.currentUser = nil
            self.currentProfile = nil
            self.isAuthenticated = false
        } catch {
            throw AuthError.signOutFailed(error.localizedDescription)
        }
    }

    // MARK: - Fetch Profile
    func fetchProfile() async {
        guard let userId = currentUser?.id else { return }

        do {
            let profile: CloudProfile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value

            await MainActor.run {
                self.currentProfile = profile
            }
        } catch {
            print("Error fetching profile: \(error)")
        }
    }

    // MARK: - Update Profile
    func updateProfile(displayName: String) async throws {
        guard let userId = currentUser?.id else {
            throw AuthError.sessionNotFound
        }

        do {
            try await supabase
                .from("profiles")
                .update(["display_name": displayName])
                .eq("id", value: userId)
                .execute()

            await fetchProfile()
        } catch {
            throw AuthError.profileCreationFailed(error.localizedDescription)
        }
    }

    // MARK: - Delete Account
    func deleteAccount() async throws {
        guard currentUser != nil else {
            throw AuthError.sessionNotFound
        }

        // Note: Account deletion requires admin privileges
        // For now, just sign out. Full deletion should be handled via Supabase dashboard
        // or a server-side function
        try await signOut()
    }

    // MARK: - Password Reset
    func resetPassword(email: String) async throws {
        do {
            try await supabase.auth.resetPasswordForEmail(
                email,
                redirectTo: URL(string: "shoppinglist://auth/reset-password")
            )
        } catch {
            throw AuthError.signInFailed(error.localizedDescription)
        }
    }

    // MARK: - Get Current User ID
    var currentUserId: UUID? {
        currentUser?.id
    }
}
