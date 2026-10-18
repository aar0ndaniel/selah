import SwiftUI
import SwiftData

struct ServicesView: View {
    private enum Mode: String, CaseIterable, Identifiable {
        case all = "All"
        case favourites = "Favourites"
        case monthly = "Monthly"
        var id: String { rawValue }
    }

    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Service.date, order: .reverse) private var services: [Service]
    @Query private var meetingDays: [MeetingDay]

    @State private var mode: Mode = .all
    @State private var openService: Service?
    @State private var editingDay: MeetingDay?
    @State private var showMeetingDays = false
    @State private var serviceToDelete: Service?

    private var sortedDays: [MeetingDay] { meetingDays.sorted(by: MeetingDay.scheduleOrder) }

    var body: some View {
        NavigationStack {
            content
                .background { AppBackground() }
                .navigationTitle("Services")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showMeetingDays = true
                        } label: {
                            Image(systemName: "calendar")
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .accessibilityLabel("Meeting days")
                    }
                }
        }
        .sheet(item: $openService) { service in
            ServiceSheet(service: service)
        }
        .sheet(item: $editingDay) { day in
            NavigationStack {
                MeetingDayEditor(day: day)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { editingDay = nil }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showMeetingDays) {
            NavigationStack {
                MeetingDaysView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showMeetingDays = false }
                        }
                    }
            }
        }
        .alert(
            "Delete this service?",
            isPresented: Binding(
                get: { serviceToDelete != nil },
                set: { if !$0 { serviceToDelete = nil } }
            ),
            presenting: serviceToDelete
        ) { service in
            Button("Delete", role: .destructive) {
                modelContext.delete(service)
                serviceToDelete = nil
            }
            Button("Cancel", role: .cancel) { serviceToDelete = nil }
        } message: { _ in
            Text("Its sermon, class notes and songs will be deleted too.")
        }
        .onChange(of: router.pendingAction) { _, _ in
            handlePendingAction()
        }
        .onAppear {
            handlePendingAction()
        }
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .monthly:
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    header
                    MonthlySummaryView(services: services)
                }
            }
            .contentMargins(.bottom, Theme.Spacing.plusButtonClearance, for: .scrollContent)
        case .all, .favourites:
            List {
                Section {
                    header
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                if mode == .all {
                    allSections
                } else {
                    favouriteSections
                }
            }
            .scrollContentBackground(.hidden)
            .contentMargins(.bottom, Theme.Spacing.plusButtonClearance, for: .scrollContent)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            MeetingDayChips(
                days: sortedDays,
                onSelect: { editingDay = $0 },
                onAdd: { showMeetingDays = true }
            )
            Picker("Show", selection: $mode) {
                ForEach(Mode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Theme.Spacing.m)
        }
    }

    // MARK: All

    private struct MonthGroup: Identifiable {
        let start: Date
        let services: [Service]
        var id: Date { start }
    }

    private var monthGroups: [MonthGroup] {
        let grouped = Dictionary(grouping: services) { MonthlySummary.monthStart(for: $0.date) }
        return grouped
            .map { MonthGroup(start: $0.key, services: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.start > $1.start }
    }

    @ViewBuilder
    private var allSections: some View {
        if services.isEmpty {
            Section {
                EmptyState(
                    title: "No services yet",
                    systemImage: "building.columns",
                    message: "Tap the plus button to record today's service.",
                    actionTitle: "New service",
                    action: createServiceForToday
                )
                .listRowBackground(Color.clear)
            }
        } else {
            ForEach(monthGroups) { group in
                Section {
                    ForEach(group.services) { service in
                        serviceRow(service)
                    }
                } header: {
                    Text(group.start.formatted(.dateTime.month(.wide).year()))
                }
            }
        }
    }

    private func serviceRow(_ service: Service) -> some View {
        Button {
            openService = service
        } label: {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                HStack(alignment: .firstTextBaseline) {
                    Text(service.gatheringName.isEmpty ? "Service" : service.gatheringName)
                        .font(.headline)
                    Spacer(minLength: Theme.Spacing.xs)
                    Text(service.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if !service.sermonTitle.isEmpty {
                    Text(service.sermonTitle)
                        .font(.body)
                }
                if !service.sermonist.isEmpty {
                    Text(service.sermonist)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rowLabel(for: service))
        .accessibilityHint("Opens this service")
        .accessibilityAddTraits(.isButton)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                serviceToDelete = service
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                serviceToDelete = service
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func rowLabel(for service: Service) -> String {
        var parts = [service.gatheringName.isEmpty ? "Service" : service.gatheringName]
        parts.append(service.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
        if !service.sermonTitle.isEmpty { parts.append(service.sermonTitle) }
        if !service.sermonist.isEmpty { parts.append(service.sermonist) }
        return parts.joined(separator: ", ")
    }

    // MARK: Favourites

    @ViewBuilder
    private var favouriteSections: some View {
        let sermons = services.filter { $0.sermonFavourite }
        let classes = services.filter { $0.classFavourite }
        if sermons.isEmpty && classes.isEmpty {
            Section {
                EmptyState(
                    title: "No favourites yet",
                    systemImage: "star",
                    message: "Star a sermon or Bible class in a service to keep it here."
                )
                .listRowBackground(Color.clear)
            }
        } else {
            if !sermons.isEmpty {
                Section("Sermons") {
                    ForEach(sermons) { service in
                        favouriteRow(
                            service,
                            title: service.sermonTitle.isEmpty ? "Untitled sermon" : service.sermonTitle,
                            detail: service.sermonist
                        )
                    }
                }
            }
            if !classes.isEmpty {
                Section("Bible classes") {
                    ForEach(classes) { service in
                        favouriteRow(
                            service,
                            title: service.classLesson.isEmpty ? "Untitled lesson" : service.classLesson,
                            detail: service.classTeacher.isEmpty ? "" : "Taught by \(service.classTeacher)"
                        )
                    }
                }
            }
        }
    }

    private func favouriteRow(_ service: Service, title: String, detail: String) -> some View {
        Button {
            openService = service
        } label: {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(title)
                    .font(.headline)
                if !detail.isEmpty {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text(service.date.formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([title, detail, service.date.formatted(.dateTime.weekday(.wide).day().month(.wide).year())]
            .filter { !$0.isEmpty }
            .joined(separator: ", "))
        .accessibilityHint("Opens this service")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: New service

    private func handlePendingAction() {
        guard router.pendingAction == .newService else { return }
        router.pendingAction = nil
        createServiceForToday()
    }

    private func createServiceForToday() {
        let today = Date()
        let weekday = Calendar.current.component(.weekday, from: today)
        let match = sortedDays.first { $0.weekday == weekday && $0.isActive }
            ?? sortedDays.first { $0.weekday == weekday }
        let service = Service(date: today, gatheringName: match?.displayName ?? "Service")
        modelContext.insert(service)
        openService = service
    }
}

/// Row of chips, one per meeting day. Tap a chip to edit that day.
private struct MeetingDayChips: View {
    let days: [MeetingDay]
    let onSelect: (MeetingDay) -> Void
    let onAdd: () -> Void

    var body: some View {
        ScrollView(.horizontal) {
            GlassEffectContainer(spacing: Theme.Spacing.xs) {
                HStack(spacing: Theme.Spacing.xs) {
                    if days.isEmpty {
                        Button(action: onAdd) {
                            Label("Add meeting days", systemImage: "plus")
                                .font(.subheadline)
                                .padding(.horizontal, Theme.Spacing.m)
                                .frame(minHeight: 44)
                                .glassEffect(.regular.interactive(), in: .capsule)
                        }
                        .buttonStyle(.plain)
                    } else {
                        ForEach(days) { day in
                            Button {
                                onSelect(day)
                            } label: {
                                Text(day.chipLabel)
                                    .font(.subheadline)
                                    .foregroundStyle(day.isActive ? .primary : .secondary)
                                    .padding(.horizontal, Theme.Spacing.m)
                                    .frame(minHeight: 44)
                                    .glassEffect(.regular.interactive(), in: .capsule)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(day.displayName), \(day.weekdayName) at \(day.timeLabel)")
                            .accessibilityValue(day.isActive ? "" : "Off")
                            .accessibilityHint("Edits this meeting day")
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.vertical, Theme.Spacing.xxs)
            }
        }
        .scrollIndicators(.hidden)
    }
}

#Preview {
    ServicesView()
        .environment(AppRouter())
        .modelContainer(SampleData.container)
}
