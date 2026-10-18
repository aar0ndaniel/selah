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

struct StudyView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var typeSize
    @Query(sort: \ReadingPlan.bookName) private var plans: [ReadingPlan]

    @State private var segment: StudySegment = .reading
    @State private var selectedPlan: ReadingPlan?
    @State private var showAddBook = false
    @State private var planToDelete: ReadingPlan?

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
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: Theme.Spacing.s) {
                    segmentPicker
                    if visiblePlans.isEmpty {
                        emptyState
                    } else {
                        ForEach(visiblePlans) { plan in
                            Button {
                                selectedPlan = plan
                            } label: {
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
        }
        .sensoryFeedback(.selection, trigger: segment)
        .sensoryFeedback(.success, trigger: doneCount) { old, new in new > old }
        .sheet(item: $selectedPlan, onDismiss: deletePendingPlan) { plan in
            BookSheet(plan: plan) { planToDelete = $0 }
        }
        .sheet(isPresented: $showAddBook) { AddBookSheet() }
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

    /// Deleting waits until the book sheet is gone so no view reads a deleted model.
    private func deletePendingPlan() {
        guard let plan = planToDelete else { return }
        planToDelete = nil
        StudyActions.deletePlan(plan, in: modelContext)
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
