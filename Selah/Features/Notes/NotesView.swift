import SwiftUI

struct NotesView: View {
    @Environment(AppRouter.self) private var router
    @State private var showComingSoon = false

    var body: some View {
        NavigationStack {
            ScrollView {
                SurfaceCard {
                    Text("Coming in a later phase")
                        .font(.headline)
                }
                .padding(.horizontal, Theme.Spacing.m)
            }
            .contentMargins(.bottom, Theme.Spacing.plusButtonClearance, for: .scrollContent)
            .background { AppBackground() }
            .navigationTitle("Notes")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showComingSoon) { ComingSoonSheet(title: "New note") }
        .onChange(of: router.pendingAction) { _, action in
            if action == .newNote {
                showComingSoon = true
                router.pendingAction = nil
            }
        }
    }
}

#Preview {
    NotesView()
        .environment(AppRouter())
        .modelContainer(SampleData.container)
}
