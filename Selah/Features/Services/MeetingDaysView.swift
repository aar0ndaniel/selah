import SwiftUI
import SwiftData

// MARK: - Display helpers

extension MeetingDay {
    /// "Tuesday"
    var weekdayName: String {
        let symbols = Calendar.current.weekdaySymbols
        guard weekday >= 1, weekday <= symbols.count else { return "" }
        return symbols[weekday - 1]
    }

    /// "Tue"
    var shortWeekdayName: String {
        let symbols = Calendar.current.shortWeekdaySymbols
        guard weekday >= 1, weekday <= symbols.count else { return "" }
        return symbols[weekday - 1]
    }

    /// "18:30"
    var timeLabel: String {
        String(format: "%02d:%02d", hour, minute)
    }

    /// Name to show; falls back to the weekday when the name is empty.
    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? weekdayName : trimmed
    }

    /// "Tue · Bible study 18:30"
    var chipLabel: String {
        "\(shortWeekdayName) · \(displayName) \(timeLabel)"
    }

    /// Sort order for lists: by weekday, then time.
    static func scheduleOrder(_ lhs: MeetingDay, _ rhs: MeetingDay) -> Bool {
        if lhs.weekday != rhs.weekday { return lhs.weekday < rhs.weekday }
        if lhs.hour != rhs.hour { return lhs.hour < rhs.hour }
        return lhs.minute < rhs.minute
    }
}

private func reminderText(_ minutes: Int) -> String {
    switch minutes {
    case 0: return "No reminder"
    case 60: return "1 hour before"
    case 120: return "2 hours before"
    default: return "\(minutes) minutes before"
    }
}

// MARK: - List

/// Lists the weekly meetings. Standalone: the caller supplies the NavigationStack
/// (Services shows it in a sheet; Settings pushes it).
struct MeetingDaysView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var days: [MeetingDay]
    @State private var editing: MeetingDay?

    private var sortedDays: [MeetingDay] { days.sorted(by: MeetingDay.scheduleOrder) }

    var body: some View {
        List {
            if days.isEmpty {
                Section {
                    EmptyState(
                        title: "No meeting days",
                        icon: .calendarPlus,
                        message: "Add the days you meet, like Sunday worship or Tuesday Bible study.",
                        actionTitle: "Add a meeting day",
                        action: addDay
                    )
                    .listRowBackground(Color.clear)
                }
            } else {
                Section {
                    ForEach(sortedDays) { day in
                        Button {
                            editing = day
                        } label: {
                            row(for: day)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: delete)
                } footer: {
                    Text("Changing your meeting days never changes services you have already recorded.")
                }
            }
        }
        .navigationTitle("Meeting days")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !days.isEmpty {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: addDay) {
                    Image(picon: .plus)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Add meeting day")
            }
        }
        .navigationDestination(item: $editing) { day in
            MeetingDayEditor(day: day)
        }
    }

    private func row(for day: MeetingDay) -> some View {
        HStack(spacing: Theme.Spacing.s) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(day.displayName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("\(day.weekdayName) at \(day.timeLabel)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(day.isActive ? reminderText(day.reminderMinutesBefore) : "Off")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            PIconView(.caretRight, size: 14, relativeTo: .footnote)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(day.displayName), \(day.weekdayName) at \(day.timeLabel). "
                + (day.isActive ? reminderText(day.reminderMinutesBefore) : "Off")
        )
        .accessibilityHint("Edits this meeting day")
        .accessibilityAddTraits(.isButton)
    }

    private func addDay() {
        let day = MeetingDay(
            weekday: 1,
            hour: 9,
            minute: 0,
            name: "New meeting",
            reminderMinutesBefore: ReminderDefaults.serviceMinutes
        )
        modelContext.insert(day)
        NotificationScheduler.shared.reschedule(context: modelContext)
        editing = day
    }

    private func delete(at offsets: IndexSet) {
        let current = sortedDays
        for index in offsets {
            modelContext.delete(current[index])
        }
        NotificationScheduler.shared.reschedule(context: modelContext)
    }
}

// MARK: - Editor

struct MeetingDayEditor: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var day: MeetingDay

    private static let baseReminders = [0, 15, 30, 60, 120]

    private var reminderOptions: [Int] {
        var options = Self.baseReminders
        if !options.contains(day.reminderMinutesBefore) {
            options.append(day.reminderMinutesBefore)
            options.sort()
        }
        return options
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: day.hour, minute: day.minute, second: 0, of: Date()
                ) ?? Date()
            },
            set: { newValue in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                day.hour = parts.hour ?? day.hour
                day.minute = parts.minute ?? day.minute
                NotificationScheduler.shared.reschedule(context: modelContext)
            }
        )
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $day.name)
                    .textInputAutocapitalization(.sentences)
                Picker("Day", selection: $day.weekday) {
                    ForEach(1...7, id: \.self) { weekday in
                        Text(Calendar.current.weekdaySymbols[weekday - 1]).tag(weekday)
                    }
                }
                DatePicker("Time", selection: timeBinding, displayedComponents: .hourAndMinute)
            }

            Section {
                Picker("Remind me", selection: $day.reminderMinutesBefore) {
                    ForEach(reminderOptions, id: \.self) { minutes in
                        Text(reminderText(minutes)).tag(minutes)
                    }
                }
                Toggle("Active", isOn: $day.isActive)
            } footer: {
                Text("Changing this never changes services you have already recorded.")
            }
        }
        .navigationTitle(day.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: day.weekday) { _, _ in
            NotificationScheduler.shared.reschedule(context: modelContext)
        }
        .onChange(of: day.reminderMinutesBefore) { _, _ in
            NotificationScheduler.shared.reschedule(context: modelContext)
        }
        .onChange(of: day.isActive) { _, _ in
            NotificationScheduler.shared.reschedule(context: modelContext)
        }
        .onChange(of: day.name) { _, _ in
            NotificationScheduler.shared.reschedule(context: modelContext)
        }
    }
}

#Preview("Meeting days") {
    NavigationStack {
        MeetingDaysView()
    }
    .modelContainer(SampleData.container)
    .environment(AppRouter())
}

#Preview("Editor") {
    NavigationStack {
        MeetingDayEditor(day: MeetingDay(weekday: 3, hour: 18, minute: 30, name: "Bible study"))
    }
    .modelContainer(SampleData.container)
    .environment(AppRouter())
}
