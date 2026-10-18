import SwiftUI
import SwiftData

enum StudySegment: Hashable, CaseIterable {
    case reading, upNext, done

    var title: String {
        switch self {
        case .reading: return "Reading"
        case .upNext: return "Up next"
        case .done: return "Done"
        }
    }

    var status: ReadingStatus {
        switch self {
        case .reading: return .reading
        case .upNext: return .upNext
        case .done: return .done
        }
    }
}

/// The full-screen note page opened by the heatmap's "Log today" button.
private struct LogCover: Identifiable {
    let plan: ReadingPlan
    let entry: StudyEntry?
    var id: PersistentIdentifier { plan.persistentModelID }
}

/// Pushed value for a book page. Holds the model's ID rather than the model, so a deleted book can never be read.
struct BookRoute: Hashable {
    let id: PersistentIdentifier
}

struct StudyView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var typeSize
    @Query(sort: \ReadingPlan.bookName) private var plans: [ReadingPlan]

    @State private var segment: StudySegment = .reading
    @State private var path: [BookRoute] = []
    @State private var showAddBook = false
    @State private var planToDelete: ReadingPlan?
    @State private var heatmapYear = Calendar.current.component(.year, from: Date())
    @State private var logCover: LogCover?

    private func plans(in segment: StudySegment) -> [ReadingPlan] {
        let matching = plans.filter { $0.status == segment.status }
        if segment == .done {
            return matching.sorted { ($0.finishedDate ?? .distantPast) > ($1.finishedDate ?? .distantPast) }
        }
        return matching
    }

    private var visiblePlans: [ReadingPlan] { plans(in: segment) }

    /// Goes up when a book is finished, so finishing a book gives a success haptic wherever it happens.
    private var doneCount: Int { plans.filter { $0.status == .done }.count }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVStack(spacing: Theme.Spacing.s) {
                    segmentPicker
                    if segment == .reading && !visiblePlans.isEmpty {
                        readingHeatmap
                    }
                    if visiblePlans.isEmpty {
                        emptyState
                    } else {
                        ForEach(visiblePlans) { plan in
                            NavigationLink(value: BookRoute(id: plan.persistentModelID)) {
                                BookCard(plan: plan)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.m)
            }
            .contentMargins(.bottom, Theme.Spacing.plusButtonClearance, for: .scrollContent)
            .background { AppBackground() }
            .navigationTitle("Study")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: BookRoute.self) { route in
                if let plan = plans.first(where: { $0.persistentModelID == route.id }) {
                    BookPage(plan: plan) { planToDelete = $0 }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: segment)
        .sensoryFeedback(.success, trigger: doneCount) { old, new in new > old }
        .sheet(isPresented: $showAddBook) { AddBookSheet() }
        .fullScreenCover(item: $logCover) { cover in
            EntrySheet(plan: cover.plan, entry: cover.entry)
        }
        .onChange(of: path) { _, newPath in
            if newPath.isEmpty { deletePendingPlan() }
        }
        .onChange(of: router.pendingAction) { _, action in
            if action == .addBook {
                showAddBook = true
                router.pendingAction = nil
            }
        }
        .onAppear {
            // The hand-off from Today can arrive before this tab exists.
            if router.pendingAction == .addBook {
                showAddBook = true
                router.pendingAction = nil
            }
        }
    }

    /// Deleting waits until the book page has been popped so no view reads a deleted model.
    private func deletePendingPlan() {
        guard let plan = planToDelete else { return }
        planToDelete = nil
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            StudyActions.deletePlan(plan, in: modelContext)
        }
    }

    // MARK: Heatmap

    private var allEntryDates: [Date] {
        plans.flatMap { $0.entries.map { $0.date } }
    }

    private var readingHeatmap: some View {
        let dates = allEntryDates
        let now = Date()
        return ActivityHeatmapCard(
            title: "Reading",
            subtitle: "Read a little, even on busy days",
            icon: .bookOpen,
            dates: dates,
            year: $heatmapYear,
            unitSingular: "note",
            unitPlural: "notes",
            loggedToday: dates.contains { Calendar.current.isDate($0, inSameDayAs: now) },
            onLogToday: logToday,
            today: now
        )
    }

    /// Opens today's note for the first Reading book (creating it as a new note if there is none yet).
    private func logToday() {
        guard let plan = plans.first(where: { $0.status == .reading }) else {
            showAddBook = true
            return
        }
        logCover = LogCover(plan: plan, entry: StudyActions.entry(on: Date(), in: plan))
    }

    @ViewBuilder
    private var segmentPicker: some View {
        if typeSize.isAccessibilitySize {
            Picker("Show", selection: $segment) { segmentOptions }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Picker("Show", selection: $segment) { segmentOptions }
                .pickerStyle(.segmented)
        }
    }

    @ViewBuilder
    private var segmentOptions: some View {
        ForEach(StudySegment.allCases, id: \.self) { item in
            Text("\(item.title) (\(plans(in: item).count))").tag(item)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        switch segment {
        case .reading:
            EmptyState(
                title: "Nothing in Reading",
                icon: .bookOpen,
                message: "Start a book and it shows up here.",
                actionTitle: "Add a book"
            ) { showAddBook = true }
        case .upNext:
            EmptyState(
                title: "Nothing in Up next",
                icon: .listBullets,
                message: "Add books you plan to read next.",
                actionTitle: "Add a book"
            ) { showAddBook = true }
        case .done:
            EmptyState(
                title: "No finished books yet",
                icon: .checkCircle,
                message: "A book moves here when you read its last chapter.",
                actionTitle: "Add a book"
            ) { showAddBook = true }
        }
    }
}

#Preview {
    StudyView()
        .environment(AppRouter())
        .modelContainer(SampleData.container)
}
