import SwiftUI
import SwiftData

/// First-launch setup: three short pages, skippable on every page (HIG rule 8.1).
struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    var body: some View {
        ZStack {
            AppBackground()
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

    func matches(_ day: MeetingDay) -> Bool {
        day.weekday == weekday && day.hour == hour && day.minute == minute && day.name == name
    }
}

/// Large decorative symbol. Sized with `@ScaledMetric` so it grows with Dynamic Type; hidden from VoiceOver.
private struct OnboardingIcon: View {
    let icon: PIcon
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 56

    var body: some View {
        Image(picon: icon)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size, alignment: .leading)
            .foregroundStyle(.tint)
            .accessibilityHidden(true)
    }
}

// MARK: - Pages

private struct OnboardingPages: View {
    @Bindable var profile: UserProfile

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var days: [MeetingDay]

    @State private var page = 0
    @State private var editingDay: MeetingDay?
    /// Deleted after the editor sheet is gone so nothing reads a deleted model.
    @State private var dayToRemove: MeetingDay?
    @State private var isAsking = false

    private let lastPage = 2

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Skip", action: finish)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .padding(.horizontal, Theme.Spacing.m)

            TabView(selection: $page) {
                welcomePage.tag(0)
                meetingPage.tag(1)
                finalPage.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

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

    // MARK: Bottom bar

    @ViewBuilder
    private var bottomBar: some View {
        VStack(spacing: Theme.Spacing.xs) {
            if page < lastPage {
                Button {
                    withAnimation(reduceMotion ? nil : .default) { page += 1 }
                } label: {
                    Text("Next")
                        .frame(maxWidth: .infinity, minHeight: 32)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                Button {
                    turnOnReminders()
                } label: {
                    Text("Turn on reminders")
                        .frame(maxWidth: .infinity, minHeight: 32)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isAsking)

                Button("Not now", action: finish)
                    .frame(minHeight: 44)
            }
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.bottom, Theme.Spacing.m)
    }

    // MARK: Page 1

    private var welcomePage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                OnboardingIcon(icon: .book)
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Welcome to Selah")
                        .font(.largeTitle.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                    Text("A quiet place for your Bible study and your notes from worship services. Everything stays on this iPhone.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: Theme.Spacing.s) {
                    field("Your name", text: $profile.name, content: .givenName)
                    field("Your congregation", text: $profile.congregation, content: nil)
                }
            }
            .padding(Theme.Spacing.l)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func field(_ title: String, text: Binding<String>, content: UITextContentType?) -> some View {
        TextField(title, text: text)
            .textContentType(content)
            .textInputAutocapitalization(.words)
            .padding(Theme.Spacing.m)
            .frame(minHeight: 48)
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
            )
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

    private var meetingPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                OnboardingIcon(icon: .calendarBlank)
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("When do you meet?")
                        .font(.largeTitle.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                    Text("Pick the gatherings you go to. Today will show the next one, and you can change this later.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: Theme.Spacing.xs) {
                    ForEach(MeetingPreset.all) { preset in
                        Toggle(isOn: Binding(
                            get: { isOn(preset) },
                            set: { setPreset(preset, on: $0) }
                        )) {
                            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                                Text(preset.name).font(.headline)
                                Text(preset.detail)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(Theme.Spacing.m)
                        .frame(minHeight: 56)
                        .background(
                            Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                        )
                    }

                    ForEach(customDays) { day in
                        Button {
                            editingDay = day
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                                    Text(day.displayName)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text("\(day.weekdayName) at \(day.timeLabel)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                PIconView(.caretRight, size: 14, relativeTo: .footnote)
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                                    .accessibilityHidden(true)
                            }
                            .padding(Theme.Spacing.m)
                            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                            .background(
                                Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Edits this meeting day")
                    }

                    Button(action: addCustomDay) {
                        PLabel("Add another day", icon: .plus)
                            .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
            .padding(Theme.Spacing.l)
        }
    }

    // MARK: Page 3

    private var finalPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                OnboardingIcon(icon: .bellRinging)
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Your Bible and reminders")
                        .font(.largeTitle.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                    Text("Choose the translation you read most. You can switch any time in Settings.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: Theme.Spacing.xs) {
                    ForEach(Translation.allCases, id: \.self) { translation in
                        Button {
                            profile.translation = translation
                        } label: {
                            HStack {
                                Text("\(translation.fullName) (\(translation.shortName))")
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                Spacer(minLength: 0)
                                if profile.translation == translation {
                                    PIconView(.check, size: 20)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.tint)
                                        .accessibilityHidden(true)
                                }
                            }
                            .padding(Theme.Spacing.m)
                            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                            .background(
                                Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(profile.translation == translation ? .isSelected : [])
                    }
                }
                .sensoryFeedback(.selection, trigger: profile.translation)

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Gentle reminders")
                        .font(.headline)
                    Text("Selah can remind you to read your book each day and before your gatherings. It only sends reminders you set up. You can turn this off in Settings.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
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
