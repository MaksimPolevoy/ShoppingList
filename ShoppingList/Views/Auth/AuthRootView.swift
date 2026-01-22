import SwiftUI

struct AuthRootView: View {
    @StateObject private var viewModel = AuthViewModel()
    @StateObject private var dataController = DataController.shared

    var body: some View {
        Group {
            if viewModel.isCheckingAuth {
                // Loading state
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Загрузка...")
                        .foregroundColor(.secondary)
                }
            } else if viewModel.isAuthenticated {
                // Authenticated - show main content
                MainTabView()
                    .environment(\.managedObjectContext, dataController.container.viewContext)
                    .environmentObject(viewModel)
            } else {
                // Not authenticated - show login
                LoginView(viewModel: viewModel)
            }
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        TabView {
            ListsView()
                .tabItem {
                    Label("Списки", systemImage: "list.bullet")
                }

            ProfileView()
                .tabItem {
                    Label("Профиль", systemImage: "person.circle")
                }
        }
    }
}

#Preview {
    AuthRootView()
}
