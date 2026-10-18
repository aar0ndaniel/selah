import SwiftUI
import SwiftData
import PhotosUI

/// Edit a book's plan: days, start date, reminders, banner image and card colour.
/// Changes apply as you make them; Done closes the sheet.
struct EditPlanSheet: View {
    @Bindable var plan: ReadingPlan

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var newReminderTime = ReminderDefaults.readingTime()
    @State private var pickerItem: PhotosPickerItem?
    @State private var bannerFailed = false

    private var sortedReminders: [ReadingReminder] {
        plan.reminders.sorted { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
    }

    private var startDateBinding: Binding<Date> {
        Binding(
            get: { plan.startDate ?? Date() },
            set: { plan.startDate = $0 }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                planSection
                remindersSection
                bannerSection
                colourSection
            }
            .scrollContentBackground(.hidden)
            .background { AppBackground() }
            .navigationTitle("Edit plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                loadBanner(from: item)
            }
            .alert("Couldn't use that photo", isPresented: $bannerFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Try a different photo.")
            }
        }
        .presentationDetents([.large])
    }

    // MARK: Plan

    private var planSection: some View {
        Section {
            DaysStepperRow(days: $plan.plannedDays)
            if plan.startDate != nil {
                DatePicker("Start date", selection: startDateBinding, displayedComponents: .date)
                    .frame(minHeight: Theme.minTapTarget)
            } else {
                Button("Start reading today") {
                    StudyActions.startReading(plan)
                }
                .buttonStyle(.selahTertiary)
            }
        } header: {
            Text("Plan")
        } footer: {
            Text(StudyActions.planLine(for: plan))
        }
    }

    // MARK: Reminders

    private var remindersSection: some View {
        Section {
            ForEach(sortedReminders) { reminder in
                let time = StudyActions.timeText(hour: reminder.hour, minute: reminder.minute)
                HStack {
                    PLabel(time, icon: .bell)
                    Spacer()
                    Button {
                        StudyActions.deleteReminder(reminder, in: modelContext)
                    } label: {
                        PIconView(.trash, size: 20)
                            .foregroundStyle(.red)
                            .frame(width: Theme.minTapTarget, height: Theme.minTapTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove reminder at \(time)")
                }
                .frame(minHeight: Theme.minTapTarget)
            }

            DatePicker("New reminder", selection: $newReminderTime, displayedComponents: .hourAndMinute)
                .frame(minHeight: Theme.minTapTarget)
            Button("Add reminder") {
                let parts = Calendar.current.dateComponents([.hour, .minute], from: newReminderTime)
                StudyActions.addReminder(
                    to: plan,
                    hour: parts.hour ?? 7,
                    minute: parts.minute ?? 0,
                    in: modelContext
                )
            }
            .buttonStyle(.selahTertiary)
        } header: {
            Text("Reminders")
        } footer: {
            if plan.reminders.isEmpty {
                Text("No reminders yet.")
            }
        }
    }

    // MARK: Banner

    private var bannerSection: some View {
        Section {
            if let data = plan.bannerData {
                BannerImageView(data: data, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
                    .listRowInsets(EdgeInsets(top: Theme.Spacing.xs, leading: Theme.Spacing.m, bottom: Theme.Spacing.xs, trailing: Theme.Spacing.m))
            }
            PhotosPicker(selection: $pickerItem, matching: .images) {
                PLabel(plan.bannerData == nil ? "Choose a photo" : "Change photo", icon: .image)
                    .frame(minHeight: Theme.minTapTarget, alignment: .leading)
            }
            if plan.bannerData != nil {
                Button(role: .destructive) {
                    plan.bannerData = nil
                } label: {
                    Text("Remove banner")
                        .frame(minHeight: Theme.minTapTarget, alignment: .leading)
                }
            }
        } header: {
            Text("Banner image")
        } footer: {
            Text("Shown at the top of the book page.")
        }
    }

    // MARK: Colour

    private var colourSection: some View {
        Section {
            ToneSwatchPicker(selection: $plan.tone)
                .padding(.vertical, Theme.Spacing.xxs)
        } header: {
            Text("Card colour")
        }
    }

    private func loadBanner(from item: PhotosPickerItem) {
        Task { @MainActor in
            defer { pickerItem = nil }
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let jpeg = BannerImage.jpegData(from: data) else {
                bannerFailed = true
                return
            }
            plan.bannerData = jpeg
        }
    }
}

private struct EditPlanSheetPreview: View {
    @Query(sort: \ReadingPlan.bookName) private var plans: [ReadingPlan]

    var body: some View {
        if let plan = plans.first(where: { $0.status == .reading }) ?? plans.first {
            EditPlanSheet(plan: plan)
        }
    }
}

#Preview {
    EditPlanSheetPreview()
        .modelContainer(SampleData.container)
        .environment(AppRouter())
}
