import SwiftUI
import SwiftData

/// First-launch setup: three short pages, skippable on every page (HIG rule 8.1).
struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            if let profile = profiles.first {
                OnboardingPages(profile: profile)
            } else {
                // Exactly one UserProfile is created lazily.
                Color.clear.onAppear {
                    ProfileStore.ensure(profiles, in: modelContext)
                }
            }
        }
    }
}

// MARK: - Presets

private struct MeetingPreset: Identifiable {
    let name: String
    let weekday: Int
    let hour: Int
    let minute: Int
    var id: String { "\(weekday)-\(hour)-\(minute)-\(name)" }

    var detail: String {
        let day = Calendar.current.weekdaySymbols[weekday - 1]
        return "\(day) at " + String(format: "%02d:%02d", hour, minute)
    }

    static let all = [
        MeetingPreset(name: "Bible study", weekday: 3, hour: 18, minute: 30),
        MeetingPreset(name: "Prayer meeting", weekday: 6, hour: 18, minute: 30),
        MeetingPreset(name: "Sunday worship", weekday: 1, hour: 9, minute: 0)
    ]

    var icon: PIcon {
        switch name {
        case "Bible study": return .bookOpen
        case "Prayer meeting": return .users
        default: return .church
        }
    }

    var tone: Tone {
        switch name {
        case "Bible study": return .sky
        case "Prayer meeting": return .sage
        default: return .coral
        }
    }

    func matches(_ day: MeetingDay) -> Bool {
        day.weekday == weekday && day.hour == hour && day.minute == minute && day.name == name
    }
}

/// Rounded-square icon tile. Scales with Dynamic Type; hidden from VoiceOver.
private struct IconTile: View {
    let icon: PIcon
    let fill: Color
    let ink: Color
    @ScaledMetric private var size: CGFloat

    init(_ icon: PIcon, fill: Color = Theme.brandFill, ink: Color = Theme.brandInk, size: CGFloat = 64, relativeTo style: Font.TextStyle = .largeTitle) {
        self.icon = icon
        self.fill = fill
        self.ink = ink
        _size = ScaledMetric(wrappedValue: size, relativeTo: style)
    }

    var body: some View {
        Image(picon: icon, filled: true)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size * 0.5, height: size * 0.5)
            .foregroundStyle(ink)
            .frame(width: size, height: size)
            .background(fill, in: RoundedRectangle(cornerRadius: size * 18 / 64, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// Card background shared by selectable rows.
private struct RowCard: ViewModifier {
    var selected: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(Theme.Spacing.m)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(
                Color(.secondarySystemBackground),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(selected ? Theme.accent : Color(.separator), lineWidth: selected ? 1.5 : 0.5)
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// Trailing check circle: filled accent when on, empty ring when off.
private struct CheckCircle: View {
    let isOn: Bool

    var body: some View {
        PIconView(.checkCircle, filled: isOn, size: 26)
            .foregroundStyle(isOn ? Theme.accent : Color(.tertiaryLabel))
    }
}

// MARK: - Pages

private struct OnboardingPages: View {
    @Bindable var profile: UserProfile

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var days: [MeetingDay]

    private enum Field: Hashable { case name, congregation }

    @State private var page = 0
    @State private var editingDay: MeetingDay?
    /// Deleted after the editor sheet is gone so nothing reads a deleted model.
    @State private var dayToRemove: MeetingDay?
    @State private var isAsking = false
    @FocusState private var focused: Field?

    private let lastPage = 2

    var body: some View {
        VStack(spacing: 0) {
            topBar

            TabView(selection: $page) {
                welcomePage.tag(0)
                meetingPage.tag(1)
                finalPage.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(reduceMotion ? nil : .default, value: page)

            bottomBar
        }
        .sheet(item: $editingDay, onDismiss: removePendingDay) { day in
            NavigationStack {
                MeetingDayEditor(day: day)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Remove", role: .destructive) {
                                dayToRemove = day
                                editingDay = nil
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { editingDay = nil }
                        }
                    }
            }
        }
    }

    private func removePendingDay() {
        guard let day = dayToRemove else { return }
        dayToRemove = nil
        modelContext.delete(day)
        NotificationScheduler.shared.reschedule(context: modelContext)
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Step \(page + 1) of 3")
                    .selahEyebrow()
                HStack(spacing: Theme.Spacing.xxs) {
                    ForEach(0..<3, id: \.self) { index in
                        Capsule()
                            .fill(index == page ? Theme.accent : Color(.tertiarySystemFill))
                            .frame(width: 28, height: 4)
                    }
                }
                .accessibilityHidden(true)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Step \(page + 1) of 3")
            Spacer()
            Button("Skip", action: finish)
                .buttonStyle(.selahTertiary)
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.top, Theme.Spacing.xs)
    }

    // MARK: Bottom bar

    @ViewBuilder
    private var bottomBar: some View {
        VStack(spacing: Theme.Spacing.xs) {
            if page < lastPage {
                Button {
                    focused = nil
                    withAnimation(reduceMotion ? nil : .default) { page += 1 }
                } label: {
                    Text("Next")
                }
                .buttonStyle(.selahPrimaryFull)
            } else {
                Button {
                    turnOnReminders()
                } label: {
                    Text("Turn on reminders")
                }
                .buttonStyle(.selahPrimaryFull)
                .disabled(isAsking)

                Button("Not now", action: finish)
                    .buttonStyle(.selahTertiary)
            }
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.bottom, Theme.Spacing.m)
    }

    private func header(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title)
                .font(.selahDisplay)
                .accessibilityAddTraits(.isHeader)
            Text(body)
                .font(.selahBody)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Page 1

    private var welcomePage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                IconTile(.book)
                header(
                    "Welcome to Tehila",
                    "A quiet place for your Bible study and your notes from worship services. Everything stays on this iPhone."
                )
                VStack(spacing: Theme.Spacing.m) {
                    labelledField("Name", placeholder: "Your name", text: $profile.name, field: .name, content: .givenName, submit: .next)
                    labelledField("Congregation", placeholder: "Your congregation", text: $profile.congregation, field: .congregation, content: nil, submit: .done)
                }
            }
            .padding(Theme.Spacing.l)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func labelledField(
        _ label: String,
        placeholder: String,
        text: Binding<String>,
        field: Field,
        content: UITextContentType?,
        submit: SubmitLabel
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text(label)
                .font(.selahLabelSmall)
                .foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .textContentType(content)
                .textInputAutocapitalization(.words)
                .submitLabel(submit)
                .focused($focused, equals: field)
                .onSubmit {
                    if field == .name {
                        focused = .congregation
                    } else {
                        focused = nil
                    }
                }
                .padding(.horizontal, Theme.Spacing.m)
                .frame(minHeight: 52)
                .background(
                    Color(.secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color(.separator), lineWidth: 0.5)
                }
        }
    }

    // MARK: Page 2

    private var customDays: [MeetingDay] {
        days
            .filter { day in !MeetingPreset.all.contains { $0.matches(day) } }
            .sorted(by: MeetingDay.scheduleOrder)
    }

    private func isOn(_ preset: MeetingPreset) -> Bool {
        days.contains { preset.matches($0) }
    }

    private func setPreset(_ preset: MeetingPreset, on: Bool) {
        if on {
            guard !isOn(preset) else { return }
            modelContext.insert(MeetingDay(
                weekday: preset.weekday,
                hour: preset.hour,
                minute: preset.minute,
                name: preset.name,
                reminderMinutesBefore: ReminderDefaults.serviceMinutes
            ))
        } else {
            for day in days where preset.matches(day) {
                modelContext.delete(day)
            }
        }
        NotificationScheduler.shared.reschedule(context: modelContext)
    }

    private func addCustomDay() {
        let day = MeetingDay(
            weekday: 1,
            hour: 9,
            minute: 0,
            name: "New meeting",
            reminderMinutesBefore: ReminderDefaults.serviceMinutes
        )
        modelContext.insert(day)
        editingDay = day
    }

    private func presetRow(_ preset: MeetingPreset) -> some View {
        let on = isOn(preset)
        return Button {
            setPreset(preset, on: !on)
        } label: {
            HStack(spacing: Theme.Spacing.m) {
                IconTile(preset.icon, fill: preset.tone.pillFill, ink: preset.tone.ink, size: 44, relativeTo: .headline)
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text(preset.name)
                        .font(.selahCardTitle)
                        .foregroundStyle(.primary)
                    SelahPill(preset.detail, icon: .clock, style: .soft(preset.tone))
                }
                Spacer(minLength: 0)
                CheckCircle(isOn: on)
            }
            .modifier(RowCard(selected: on))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(preset.name), \(preset.detail)")
        .accessibilityValue(on ? "On" : "Off")
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : [.isButton])
        .sensoryFeedback(.selection, trigger: on)
    }

    private var meetingPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                IconTile(.calendarBlank)
                header(
                    "When do you meet?",
                    "Pick the gatherings you go to. Today will show the next one, and you can change this later."
                )

                VStack(spacing: Theme.Spacing.s) {
                    ForEach(MeetingPreset.all) { preset in
                        presetRow(preset)
                    }

                    ForEach(customDays) { day in
                        Button {
                            editingDay = day
                        } label: {
                            HStack(spacing: Theme.Spacing.m) {
                                IconTile(.calendarBlank, fill: Tone.slate.pillFill, ink: Tone.slate.ink, size: 44, relativeTo: .headline)
                                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                                    Text(day.displayName)
                                        .font(.selahCardTitle)
                                        .foregroundStyle(.primary)
                                    SelahPill("\(day.weekdayName) at \(day.timeLabel)", icon: .clock, style: .soft(.slate))
                                }
                                Spacer(minLength: 0)
                                PIconView(.caretRight, size: 14, relativeTo: .footnote)
                                    .font(.selahLabelSmall.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                                    .accessibilityHidden(true)
                            }
                            .modifier(RowCard())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Edits this meeting day")
                    }

                    Button(action: addCustomDay) {
                        PLabel("Add another day", icon: .plus)
                    }
                    .buttonStyle(.selahSecondary(fullWidth: true))
                }
            }
            .padding(Theme.Spacing.l)
        }
    }

    // MARK: Page 3

    private func translationRow(_ translation: Translation) -> some View {
        let selected = profile.translation == translation
        return Button {
            profile.translation = translation
        } label: {
            HStack(spacing: Theme.Spacing.s) {
                Text(translation.fullName)
                    .font(.selahBody)
                    .foregroundStyle(.primary)
                SelahPill(translation.shortName, style: .neutral)
                Spacer(minLength: 0)
                CheckCircle(isOn: selected)
            }
            .modifier(RowCard(selected: selected))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(translation.fullName), \(translation.shortName)")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : [.isButton])
    }

    private var finalPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                IconTile(.bookOpen)
                header(
                    "Your Bible and reminders",
                    "Choose the translation you read most. You can switch any time in Settings."
                )

                VStack(spacing: Theme.Spacing.s) {
                    ForEach(Translation.allCases, id: \.self) { translation in
                        translationRow(translation)
                    }
                }
                .sensoryFeedback(.selection, trigger: profile.translation)

                HStack(alignment: .top, spacing: Theme.Spacing.m) {
                    IconTile(.bell, fill: Color(.systemBackground), ink: Theme.brandInk, size: 40, relativeTo: .headline)
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Text("Gentle reminders")
                            .font(.selahCardTitle)
                            .foregroundStyle(Theme.brandInk)
                        Text("Tehila can remind you to read your book each day and before your gatherings. It only sends reminders you set up. You can turn this off in Settings.")
                            .font(.selahLabel)
                            .foregroundStyle(Theme.brandInk.opacity(0.85))
                    }
                }
                .padding(Theme.Spacing.m)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.brandFill, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                .accessibilityElement(children: .combine)
            }
            .padding(Theme.Spacing.l)
        }
    }

    // MARK: Finish

    private func turnOnReminders() {
        isAsking = true
        Task {
            _ = await NotificationAccess.request()
            NotificationScheduler.shared.reschedule(context: modelContext)
            isAsking = false
            finish()
        }
    }

    private func finish() {
        profile.onboarded = true
        try? modelContext.save()
    }
}

#Preview {
    OnboardingView()
        .modelContainer(SampleData.container)
        .environment(AppRouter())
}
