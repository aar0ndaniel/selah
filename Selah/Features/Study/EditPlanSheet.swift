import SwiftUI
import SwiftData
import PhotosUI

/// Edit a study: its title and description, days, start date, reminders, picture and card colour.
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
                studySection
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

    // MARK: Study

    private var studySection: some View {
        Section {
            TextField("Title, for example Calling of mankind", text: $plan.title)
                .font(.selahBody)
                .frame(minHeight: Theme.minTapTarget)
            TextField("A short description", text: $plan.summary, axis: .vertical)
                .font(.selahBody)
                .lineLimit(2...4)
                .frame(minHeight: Theme.minTapTarget)
        } header: {
            Text("Study")
        } footer: {
            Text("Shown on the Study card and at the top of the book page. Leave the title empty to use \(plan.bookName).")
        }
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
            let pictures = StudyIllustration.available
            if !pictures.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.s) {
                        ForEach(pictures) { picture in
                            illustrationChoice(picture)
                        }
                    }
                    .padding(.vertical, Theme.Spacing.xxs)
                }
                .listRowInsets(EdgeInsets(top: Theme.Spacing.xs, leading: Theme.Spacing.m, bottom: Theme.Spacing.xs, trailing: Theme.Spacing.m))
            }
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
                    Text("Remove photo")
                        .frame(minHeight: Theme.minTapTarget, alignment: .leading)
                }
            }
        } header: {
            Text("Picture")
        } footer: {
            Text("Shown on the Study card. A photo is used instead of a picture when you choose one.")
        }
    }

    private func illustrationChoice(_ picture: StudyIllustration) -> some View {
        let selected = plan.illustration == picture && plan.bannerData == nil
        return Button {
            plan.illustration = plan.illustration == picture ? nil : picture
        } label: {
            Group {
                if let image = picture.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .frame(width: 88, height: 88)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                    .strokeBorder(selected ? Theme.accent : Color.clear, lineWidth: 3)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(picture.title)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
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
