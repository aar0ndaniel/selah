import SwiftUI
import SwiftData
import UIKit

/// The app shell: the native iOS 26 `TabView` (Liquid Glass floating tab bar) with Phosphor icons and the
/// teal accent, plus a floating + action that is anchored to the tab bar through the safe area.
///
/// Tab bar and + button, decision (details in docs/DESIGN-SYSTEM.md):
/// - The tab bar is the system one. Selected tab = fill icon + accent tint, idle = regular icon.
///   `.tabBarMinimizeBehavior(.onScrollDown)` lets it collapse while scrolling.
/// - The + is a circular glass button placed with `safeAreaInset(edge: .bottom)` INSIDE each tab's content, not as an
///   overlay on the whole TabView. Inside a tab, the bottom safe area already includes the floating tab bar, so the
///   button sits a fixed 8pt above the bar without any guessed offset, follows the bar when it minimises, and
///   scroll views get the right bottom inset for free.
/// - It is not a `Tab(role: .search)` slot: that slot is a selectable tab, so a pure action there would be announced
///   as a tab and would change the selection. Not `tabViewBottomAccessory` either: that is a mini-player strip.
struct RootTabView: View {
    @State private var router = AppRouter()
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    /// Shared with the App Intents (they run in this process). Reading `pending` in `body` makes SwiftUI observe it.
    private let quiet = QuietIntentRouter.shared

    /// A colour scheme forced by a UI-test launch argument; wins over the profile setting.
    private let forcedScheme: ColorScheme?

    init(forcedScheme: ColorScheme? = nil) {
        self.forcedScheme = forcedScheme
    }

    private var appearance: ColorScheme? { forcedScheme ?? profiles.first?.appearance.colorScheme }

    /// First launch: no profile yet, or onboarding not finished.
    private var showOnboarding: Binding<Bool> {
        Binding(
            get: { profiles.first?.onboarded != true },
            set: { _ in }
        )
    }

    var body: some View {
        // Read here so the tab labels below refresh (fill icon) when the selection changes.
        let selected = router.selectedTab

        TabView(selection: $router.selectedTab) {
            Tab(value: AppTab.today) {
                TodayView().plusButtonAboveTabBar()
            } label: {
                tabLabel(.today, selected: selected)
            }
            Tab(value: AppTab.study) {
                StudyView().plusButtonAboveTabBar()
            } label: {
                tabLabel(.study, selected: selected)
            }
            Tab(value: AppTab.services) {
                ServicesView().plusButtonAboveTabBar()
            } label: {
                tabLabel(.services, selected: selected)
            }
            Tab(value: AppTab.notes) {
                NotesView().plusButtonAboveTabBar()
            } label: {
                tabLabel(.notes, selected: selected)
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            router.keyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            router.keyboardVisible = false
        }
        .fullScreenCover(isPresented: showOnboarding) {
            OnboardingView()
                .preferredColorScheme(appearance)
        }
        .preferredColorScheme(appearance)
        .environment(router)
        .onChange(of: scenePhase, initial: true) { _, phase in
            quiet.isSceneActive = phase == .active
            // Refreshes "Time for Philippians 3" style bodies and drops stale reminders.
            if phase == .active {
                NotificationScheduler.shared.reschedule(context: modelContext)
                // The Selah Focus filter can ask for a page; this opens it once per Focus session.
                quiet.consumeFocusSession()
            }
        }
        // Quiet time hand-off from App Intents / the Focus filter. `initial: true` also catches a destination that
        // was set before this view appeared (the app was launched by the intent).
        .onChange(of: quiet.pending, initial: true) { _, destination in
            guard let destination else { return }
            quiet.pending = nil
            router.open(destination)
        }
    }

    private func tabLabel(_ tab: AppTab, selected: AppTab) -> some View {
        Label {
            Text(tab.title)
        } icon: {
            Image(picon: tab.icon, filled: tab == selected)
        }
        .accessibilityIdentifier(tab.identifier)
    }
}

// MARK: - + button

private extension View {
    /// Anchors the + button to the bottom edge of this tab's safe area (directly above the floating tab bar).
    func plusButtonAboveTabBar() -> some View {
        safeAreaInset(edge: .bottom, alignment: .trailing, spacing: 0) {
            PlusSlot()
        }
    }
}

/// Holds the + button and its show / hide behaviour (keyboard up, or a full page that hides it).
private struct PlusSlot: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if !router.plusButtonHidden {
                PlusButton()
                    .padding(.trailing, Theme.Spacing.m)
                    .padding(.bottom, Theme.Spacing.xs)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: router.plusButtonHidden)
    }
}

/// Floating glass + button. Label changes with the selected tab.
private struct PlusButton: View {
    @Environment(AppRouter.self) private var router
    @State private var tapCount = 0
    @ScaledMetric(relativeTo: .title2) private var diameter: CGFloat = 56

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
                PIconView(.plus, size: 26, relativeTo: .title2)
                    // White on deep teal (light), black on bright teal (dark): keeps contrast in both.
                    .foregroundStyle(Color(.systemBackground))
                    .frame(width: diameter, height: diameter)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.tint(.accentColor).interactive(), in: .circle)
            .accessibilityLabel(label)
            .accessibilityIdentifier("plus-button")
        }
        .fixedSize()
        .sensoryFeedback(.impact, trigger: tapCount)
    }
}

#Preview {
    RootTabView()
        .modelContainer(SampleData.container)
}
