import SwiftUI
import Supabase

@main
struct ShoppingListApp: App {
    @State private var showURLError = false
    @State private var urlErrorMessage = ""

    var body: some Scene {
        WindowGroup {
            AuthRootView()
                .onOpenURL { url in
                    print("📱 Received URL: \(url.absoluteString)")
                    Task {
                        do {
                            try await supabase.auth.session(from: url)
                            print("✅ Session created from URL")
                        } catch {
                            print("❌ Error handling auth URL: \(error)")
                            await MainActor.run {
                                urlErrorMessage = error.localizedDescription
                                showURLError = true
                            }
                        }
                    }
                }
                .alert("Ошибка авторизации", isPresented: $showURLError) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text(urlErrorMessage)
                }
        }
    }
}
