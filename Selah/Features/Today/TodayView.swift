import SwiftUI

struct TodayView: View {
    @Environment(AppRouter.self) private var router
    @State private var showComingSoon = false
    @State private var showSettings = false

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
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "person.crop.circle")
                            .font(.title3)
                    }
                    .accessibilityLabel("Profile and settings")
                }
            }
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showComingSoon) { ComingSoonSheet(title: "Today's entry") }
        .onChange(of: router.pendingAction) { _, action in
            if action == .writeTodayEntry {
                showComingSoon = true
                router.pendingAction = nil
            }
        }
    }
}

#Preview {
    TodayView()
        .environment(AppRouter())
        .modelContainer(SampleData.container)
}
