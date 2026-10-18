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
    @Environment(\.dynamicTypeSize) private var typeSize
    @Query(sort: \Service.date, order: .reverse) private var services: [Service]
    @Query private var meetingDays: [MeetingDay]

    @State private var mode: Mode = .all
    /// The service pushed on the Services stack (a full page, not a sheet).
    @State private var openService: Service?
    @State private var showMeetingDays = false
    @State private var serviceToDelete: Service?

    private var sortedDays: [MeetingDay] { meetingDays.sorted(by: MeetingDay.scheduleOrder) }

    /// The card shown at the top when today is a meeting day.
    private var todayPrompt: TodayPrompt? {
        ServicesLogic.todayPrompt(
            meetings: meetingDays.map { ServiceMeetingSnapshot($0) },
            services: services.map { ServiceStub(date: $0.date, gatheringName: $0.gatheringName) },
            on: Date()
        )
    }

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
                            Image(picon: .calendarBlank)
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .accessibilityLabel("Meeting days")
                    }
                }
                .navigationDestination(item: $openService) { service in
                    ServicePage(service: service)
                }
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
                    MonthlySummaryView(services: services, onNewService: createServiceForToday)
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
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .contentMargins(.bottom, Theme.Spacing.plusButtonClearance, for: .scrollContent)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            if let prompt = todayPrompt {
                todayCard(prompt)
                    .padding(.horizontal, Theme.Spacing.m)
            }
            modePicker
                .padding(.horizontal, Theme.Spacing.m)
                .sensoryFeedback(.selection, trigger: mode)
        }
        .padding(.bottom, Theme.Spacing.xs)
    }

    // MARK: Today card

    private func todayCard(_ prompt: TodayPrompt) -> some View {
        let tone = Tone.sage
        return ToneCard(tone: tone, padding: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                HStack(alignment: .top, spacing: Theme.Spacing.s) {
                    PIconView(.church, filled: true, size: 28, relativeTo: .title3)
                        .foregroundStyle(tone.ink)
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Text(prompt.title)
                            .font(.selahCardTitle)
                            .foregroundStyle(tone.onSurface)
                            .accessibilityAddTraits(.isHeader)
                        Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide)))
                            .font(.selahLabel)
                            .foregroundStyle(tone.inkSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Button {
                    openTodaysService(prompt)
                } label: {
                    Text(prompt.buttonTitle)
                }
                .buttonStyle(.selahPrimaryFull)
            }
        }
    }

    private func openTodaysService(_ prompt: TodayPrompt) {
        if let index = prompt.existingServiceIndex, services.indices.contains(index) {
            openService = services[index]
        } else {
            createService(named: prompt.name)
        }
    }

    /// Segments are too tight for three labels at accessibility text sizes, so they become a menu there.
    @ViewBuilder
    private var modePicker: some View {
        if typeSize.isAccessibilitySize {
            Picker("Show", selection: $mode) { modeOptions }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Picker("Show", selection: $mode) { modeOptions }
                .pickerStyle(.segmented)
        }
    }

    @ViewBuilder
    private var modeOptions: some View {
        ForEach(Mode.allCases) { mode in
            Text(mode.rawValue).tag(mode)
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

    /// Row insets that make each row a card with a little air between cards.
    private var cardRowInsets: EdgeInsets {
        EdgeInsets(top: 6, leading: Theme.Spacing.m, bottom: 6, trailing: Theme.Spacing.m)
    }

    @ViewBuilder
    private var allSections: some View {
        if services.isEmpty {
            Section {
                EmptyState(
                    title: "No services yet",
                    icon: .church,
                    message: "Tap the plus button to record today's service.",
                    actionTitle: "New service",
                    action: createServiceForToday
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        } else {
            ForEach(monthGroups) { group in
                Section {
                    ForEach(group.services) { service in
                        serviceRow(service)
                            .listRowInsets(cardRowInsets)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                } header: {
                    Text(group.start.formatted(.dateTime.month(.wide).year()))
                        .font(.selahHeadline)
                        .foregroundStyle(.primary)
                        .textCase(nil)
                        .accessibilityAddTraits(.isHeader)
                }
            }
        }
    }

    private func serviceRow(_ service: Service) -> some View {
        let name = service.gatheringName.isEmpty ? "Service" : service.gatheringName
        let tone = ServicesLogic.gatheringTone(name)
        let hasClass = !service.classLesson.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !service.classTeacher.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let isFavourite = service.sermonFavourite || service.classFavourite
        let sermonTitle = service.sermonTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        return Button {
            openService = service
        } label: {
            SurfaceCard {
                HStack(alignment: .top, spacing: Theme.Spacing.s) {
                    DateBadge(date: service.date, tone: tone)
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                            Text(sermonTitle.isEmpty ? "No sermon title yet" : sermonTitle)
                                .font(.selahHeadline)
                                .foregroundStyle(sermonTitle.isEmpty ? Color.secondary : Color.primary)
                                .multilineTextAlignment(.leading)
                            if !service.sermonist.isEmpty {
                                Text(service.sermonist)
                                    .font(.selahLabel)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        pills(name: name, tone: tone, hasClass: hasClass)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if isFavourite {
                        PIconView(.star, filled: true, size: 20)
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rowLabel(for: service, hasClass: hasClass, isFavourite: isFavourite))
        .accessibilityHint("Opens this service")
        .accessibilityAddTraits(.isButton)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                serviceToDelete = service
            } label: {
                Label("Delete", picon: .trash)
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                serviceToDelete = service
            } label: {
                Label("Delete", picon: .trash)
            }
        }
    }

    /// Gathering pill, plus "Bible class" when the service has one. Stacks at accessibility sizes.
    private func pills(name: String, tone: Tone, hasClass: Bool) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Spacing.xs))
            : AnyLayout(HStackLayout(spacing: Theme.Spacing.xs))
        return layout {
            Pill(text: name, tone: tone)
            if hasClass {
                Pill(text: "Bible class", icon: .book, tone: .sage)
            }
        }
    }

    private func rowLabel(for service: Service, hasClass: Bool, isFavourite: Bool) -> String {
        var parts = [service.gatheringName.isEmpty ? "Service" : service.gatheringName]
        parts.append(service.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
        if !service.sermonTitle.isEmpty { parts.append(service.sermonTitle) }
        if !service.sermonist.isEmpty { parts.append(service.sermonist) }
        if hasClass { parts.append("Bible class") }
        if isFavourite { parts.append("Favourite") }
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
                    icon: .star,
                    message: "Star a sermon or Bible class in a service to keep it here.",
                    actionTitle: "Show all services",
                    action: { mode = .all }
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        } else {
            if !sermons.isEmpty {
                Section {
                    ForEach(sermons) { service in
                        favouriteRow(
                            service,
                            title: service.sermonTitle.isEmpty ? "Untitled sermon" : service.sermonTitle,
                            detail: service.sermonist
                        )
                        .listRowInsets(cardRowInsets)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                } header: {
                    favouriteHeader("Sermons")
                }
            }
            if !classes.isEmpty {
                Section {
                    ForEach(classes) { service in
                        favouriteRow(
                            service,
                            title: service.classLesson.isEmpty ? "Untitled lesson" : service.classLesson,
                            detail: service.classTeacher.isEmpty ? "" : "Taught by \(service.classTeacher)"
                        )
                        .listRowInsets(cardRowInsets)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                } header: {
                    favouriteHeader("Bible classes")
                }
            }
        }
    }

    private func favouriteHeader(_ title: String) -> some View {
        Text(title)
            .font(.selahHeadline)
            .foregroundStyle(.primary)
            .textCase(nil)
            .accessibilityAddTraits(.isHeader)
    }

    private func favouriteRow(_ service: Service, title: String, detail: String) -> some View {
        let name = service.gatheringName.isEmpty ? "Service" : service.gatheringName
        let tone = ServicesLogic.gatheringTone(name)
        let dateLabel = service.date.formatted(.dateTime.weekday(.wide).day().month(.wide).year())
        return Button {
            openService = service
        } label: {
            SurfaceCard {
                HStack(alignment: .top, spacing: Theme.Spacing.s) {
                    DateBadge(date: service.date, tone: tone)
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Text(title)
                            .font(.selahHeadline)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                        if !detail.isEmpty {
                            Text(detail)
                                .font(.selahLabel)
                                .foregroundStyle(.secondary)
                        }
                        Text(dateLabel)
                            .font(.selahLabelSmall)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    PIconView(.star, filled: true, size: 20)
                        .foregroundStyle(Color.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([title, detail, dateLabel, "Favourite"]
            .filter { !$0.isEmpty }
            .joined(separator: ", "))
        .accessibilityHint("Opens this service")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: New service

    private func handlePendingAction() {
        switch router.pendingAction {
        case .newService:
            router.pendingAction = nil
            createServiceForToday()
        case .openTodayService:
            // Quiet time ("Start service notes"): open today's service, or start one for today.
            router.pendingAction = nil
            openOrCreateTodaysService()
        default:
            break
        }
    }

    /// A meeting day opens (or creates) that gathering's service. Any other day opens a service already recorded
    /// today, or starts a new one with the + flow.
    private func openOrCreateTodaysService() {
        if let prompt = todayPrompt {
            openTodaysService(prompt)
        } else if let existing = services.first(where: { Calendar.current.isDateInToday($0.date) }) {
            openService = existing
        } else {
            createServiceForToday()
        }
    }

    /// The + flow: a new service dated today, named after today's meeting when there is one.
    private func createServiceForToday() {
        let weekday = Calendar.current.component(.weekday, from: Date())
        let match = sortedDays.first { $0.weekday == weekday && $0.isActive }
            ?? sortedDays.first { $0.weekday == weekday }
        createService(named: match?.displayName ?? "Service")
    }

    private func createService(named name: String) {
        let service = Service(date: Date(), gatheringName: name)
        modelContext.insert(service)
        openService = service
    }
}

/// Small calendar-style date badge: month on top, day number below, on the gathering's tone.
private struct DateBadge: View {
    let date: Date
    let tone: Tone

    @ScaledMetric(relativeTo: .body) private var width: CGFloat = 56

    var body: some View {
        VStack(spacing: 0) {
            Text(date.formatted(.dateTime.month(.abbreviated)))
                .font(.selahEyebrow)
                .textCase(.uppercase)
                .foregroundStyle(tone.inkSecondary)
            Text(date.formatted(.dateTime.day()))
                .font(.selahStat)
                .foregroundStyle(tone.onSurface)
        }
        .frame(width: width, height: width)
        .background(tone.pillFill, in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
        .accessibilityHidden(true)
    }
}

#Preview {
    ServicesView()
        .environment(AppRouter())
        .modelContainer(SampleData.container)
}
