import SwiftUI
import SwiftData

struct RootTabView: View {
    @State private var router = AppRouter()
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    private var appearance: ColorScheme? { profiles.first?.appearance.colorScheme }

    /// First launch: no profile yet, or onboarding not finished.
    private var showOnboarding: Binding<Bool> {
        Binding(
            get: { profiles.first?.onboarded != true },
            set: { _ in }
        )
    }

    var body: some View {
        TabView(selection: $router.selectedTab) {
            Tab("Today", systemImage: "sun.max", value: AppTab.today) {
                TodayView()
            }
            Tab("Study", systemImage: "book", value: AppTab.study) {
                StudyView()
            }
            Tab("Services", systemImage: "building.columns", value: AppTab.services) {
                ServicesView()
            }
            Tab("Notes", systemImage: "note.text", value: AppTab.notes) {
                NotesView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .overlay(alignment: .bottomTrailing) {
            PlusButton()
                .padding(.trailing, Theme.Spacing.m)
                .padding(.bottom, 72)
        }
        .fullScreenCover(isPresented: showOnboarding) {
            OnboardingView()
                .preferredColorScheme(appearance)
        }
        .preferredColorScheme(appearance)
        .environment(router)
        .onChange(of: scenePhase, initial: true) { _, phase in
            // Refreshes "Time for Philippians 3" style bodies and drops stale reminders.
            if phase == .active {
                NotificationScheduler.shared.reschedule(context: modelContext)
            }
        }
    }
}

/// Floating glass + button. Label changes with the selected tab.
private struct PlusButton: View {
    @Environment(AppRouter.self) private var router
    @State private var tapCount = 0

    private var label: String {
        switch router.selectedTab {
        case .today: return "Write today's entry"
        case .study: return "Add a book"
        case .services: return "New service for today"
        case .notes: return "New note"
        }
    }

    private var action: PlusAction {
        switch router.selectedTab {
        case .today: return .writeTodayEntry
        case .study: return .addBook
        case .services: return .newService
        case .notes: return .newNote
        }
    }

    var body: some View {
        GlassEffectContainer {
            Button {
                tapCount += 1
                router.pendingAction = action
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    // White on deep teal (light), black on bright teal (dark): keeps contrast in both.
                    .foregroundStyle(Color(.systemBackground))
                    .frame(width: 56, height: 56)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.tint(.accentColor).interactive(), in: .circle)
            .accessibilityLabel(label)
        }
        .fixedSize()
        .sensoryFeedback(.impact, trigger: tapCount)
    }
}

#Preview {
    RootTabView()
        .modelContainer(SampleData.container)
}
