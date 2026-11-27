import SwiftUI
import SwiftData

// Brand colors and the hex initializer live in Theme.swift.

struct ContentView: View {
    var body: some View {
        MainTabView()
            .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
        .environmentObject(PurchaseManager.shared)
        .environment(NavigationRouter())
        .preferredColorScheme(.dark)
}
