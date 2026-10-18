import SwiftUI

/// Phase 0 placeholder shell. Phase 3 replaces the placeholders with the real tabs
/// and adds the contextual + button beside the tab bar.
struct RootTabView: View {
    var body: some View {
        TabView {
            Tab("Today", systemImage: "sun.max") {
                PlaceholderScreen(title: "Today", systemImage: "sun.max")
            }
            Tab("Study", systemImage: "book") {
                PlaceholderScreen(title: "Study", systemImage: "book")
            }
            Tab("Services", systemImage: "building.columns") {
                PlaceholderScreen(title: "Services", systemImage: "building.columns")
            }
            Tab("Notes", systemImage: "note.text") {
                PlaceholderScreen(title: "Notes", systemImage: "note.text")
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}

private struct PlaceholderScreen: View {
    let title: String
    let systemImage: String

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Coming soon",
                systemImage: systemImage,
                description: Text("This part of Selah is still being built.")
            )
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    RootTabView()
}
