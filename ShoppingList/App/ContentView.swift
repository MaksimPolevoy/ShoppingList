import SwiftUI

struct ContentView: View {
    var body: some View {
        ListsView()
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, DataController.preview.container.viewContext)
}
