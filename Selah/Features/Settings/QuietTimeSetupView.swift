import SwiftUI
import SwiftData
import UIKit

/// Guided setup for quiet time. iOS does not let an app silence the phone, so the user makes a Focus and a few
/// Shortcuts automations; Selah supplies the intents, a Focus filter and these instructions.
/// A full page pushed from Settings. Each step has a tick the user can set, remembered in UserDefaults.
struct QuietTimeSetupView: View {
    @Query private var meetingDays: [MeetingDay]
    @Query(sort: \ReadingPlan.bookName) private var plans: [ReadingPlan]

    private let quiet = QuietIntentRouter.shared

    @State private var settingsMessage: String?
    @State private var shortcutsMessage: String?
    @State private var tryCount = 0

    private var scheduleItems: [QuietScheduleItem] {
        let meetings = meetingDays.map { ServiceMeetingSnapshot($0) }
        let reading = plans
            .filter { $0.status == .reading }
            .flatMap { plan in
                plan.reminders.map { QuietReadingTime(bookName: plan.bookName, hour: $0.hour, minute: $0.minute) }
            }
        return QuietScheduleBuilder.items(meetings: meetings, reading: reading)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                intro
                stepOne
                stepTwo
                stepThree
                stepFour
                stepFive
            }
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.bottom, Theme.Spacing.l)
        }
        .background { AppBackground() }
        .navigationTitle("Quiet time")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.success, trigger: tryCount)
    }

    // MARK: Intro

    private var intro: some View {
        ToneCard(tone: .slate, padding: Theme.Spacing.m) {
            HStack(alignment: .top, spacing: Theme.Spacing.s) {
                PIconView(.moon, filled: true, size: 28, relativeTo: .title3)
                    .foregroundStyle(Tone.slate.ink)
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Selah can't silence your phone by itself. iOS lets you do it with a Focus. Set it up once and it turns on by itself.")
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text("It takes about five minutes. Nothing here needs an account.")
                        .font(.subheadline)
                        .foregroundStyle(Tone.slate.inkSecondary)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: Steps

    private var stepOne: some View {
        QuietStepCard(number: 1, title: "Create a Selah Focus", icon: .bellSlash) {
            QuietBullets(lines: [
                "Go to Settings, then Focus.",
                "Tap +, then Custom, and name it Selah.",
                "Under Silence notifications, choose who can still reach you: nobody, or only calls from Favourites.",
                "Tap Customize screens, then Home Screen, and pick a page without social apps."
            ])
            Text("The button below opens Selah's own page in Settings. Tap Settings at the top left to go back one level, then choose Focus.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button {
                Task { await open(URL(string: UIApplication.openSettingsURLString)) { settingsMessage = "Couldn't open Settings. Open it from your Home Screen." } }
            } label: {
                Label("Open Settings", picon: .arrowSquareOut)
            }
            .buttonStyle(.selahSecondary())
            if let settingsMessage {
                QuietInlineMessage(text: settingsMessage)
            }
        }
    }

    private var stepTwo: some View {
        QuietStepCard(number: 2, title: "Add the Selah filter", icon: .gear) {
            QuietBullets(lines: [
                "In Settings, go to Focus and open Selah.",
                "Tap Focus filters, then Add filter, then Selah.",
                "Under Open to, choose Today, Study session or Service notes. Selah opens there when the Focus is on."
            ])
            Text("If Selah isn't in the list, open Selah once and try again.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var stepThree: some View {
        QuietStepCard(number: 3, title: "Turn it on when you open Selah", icon: .moon) {
            QuietBullets(lines: [
                "Open Shortcuts, tap Automation, then +.",
                "Choose App, pick Selah, and choose Is Opened.",
                "Choose Run Immediately.",
                "Add the action Set Focus. Set it to Selah, Turn On.",
                "Optional: make a second automation for Is Closed that turns the Selah Focus off."
            ])
            Button {
                Task { await open(URL(string: "shortcuts://")) { shortcutsMessage = "Couldn't open Shortcuts. Open it from your Home Screen." } }
            } label: {
                Label("Open Shortcuts", picon: .arrowSquareOut)
            }
            .buttonStyle(.selahSecondary())
            if let shortcutsMessage {
                QuietInlineMessage(text: shortcutsMessage)
            }
        }
    }

    private var stepFour: some View {
        let items = scheduleItems
        return QuietStepCard(number: 4, title: "Turn it on at your service and study times", icon: .clock) {
            if items.isEmpty {
                Text("You have no meeting days or reading reminders yet. Add them and your times will be listed here.")
                    .font(.subheadline)
                NavigationLink {
                    MeetingDaysView()
                } label: {
                    Label("Meeting days", picon: .calendarBlank)
                }
                .buttonStyle(.selahSecondary())
            } else {
                Text("Make one automation for each time below.")
                    .font(.subheadline)
                QuietBullets(lines: [
                    "In Shortcuts, tap Automation, then +, then Time of Day.",
                    "Set the time shown, then choose Weekly and the day, or Daily.",
                    "Choose Run Immediately.",
                    "Add the Selah action shown for that time, then add Set Focus: Selah, Turn On. Choose how long it stays on."
                ])
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    ForEach(items) { item in
                        scheduleRow(item)
                    }
                }
            }
        }
    }

    private func scheduleRow(_ item: QuietScheduleItem) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            SelahPill(
                item.whenText,
                icon: .clock,
                style: .soft(item.kind == .service ? .slate : .sage)
            )
            Text(item.title)
                .font(.selahHeadline)
            Text("Add \"\(item.actionName)\", then Set Focus: Selah.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.s)
        .background(
            Color(.systemBackground),
            in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.label). Add \(item.actionName), then Set Focus: Selah.")
    }

    private var stepFive: some View {
        QuietStepCard(number: 5, title: "Try it", icon: .sun) {
            Text("Start quiet time now to see what it does. A card will show on Today.")
                .font(.subheadline)
            Button {
                quiet.startQuietTime()
                tryCount += 1
            } label: {
                Text("Start quiet time")
            }
            .buttonStyle(.selahPrimaryFull)
            if quiet.isQuietTimeOn {
                QuietTimeBanner(onEnd: { quiet.endQuietTime() })
                Text("This card now shows on Today.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Text("You can also ask Siri: \"Start quiet time in Selah\".")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Opening other apps

    /// Opens a URL; calls `onFail` on the main actor when iOS refuses.
    private func open(_ url: URL?, onFail: @MainActor () -> Void) async {
        guard let url else {
            onFail()
            return
        }
        let opened = await UIApplication.shared.open(url, options: [:])
        if !opened { onFail() }
    }
}

// MARK: - Pieces

/// One numbered step: number badge, serif title with a Phosphor icon, a tick the user sets, and the step's content.
private struct QuietStepCard<Content: View>: View {
    let number: Int
    let title: String
    let icon: PIcon
    private let content: Content

    @AppStorage private var isDone: Bool
    @ScaledMetric(relativeTo: .headline) private var badgeSize: CGFloat = 32

    init(number: Int, title: String, icon: PIcon, @ViewBuilder content: () -> Content) {
        self.number = number
        self.title = title
        self.icon = icon
        self.content = content()
        _isDone = AppStorage(wrappedValue: false, "quiet.step.\(number)")
    }

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                HStack(alignment: .top, spacing: Theme.Spacing.s) {
                    Text("\(number)")
                        .font(.selahStatSmall)
                        .foregroundStyle(Theme.brandInk)
                        .frame(width: badgeSize, height: badgeSize)
                        .background(Theme.brandFill, in: Circle())
                        .accessibilityHidden(true)

                    Label {
                        Text(title)
                            .font(.selahHeadline)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        PIconView(icon, size: 20, relativeTo: .headline)
                            .foregroundStyle(Theme.brandInk)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityLabel("Step \(number), \(title)")

                    Button {
                        isDone.toggle()
                    } label: {
                        PIconView(.checkCircle, filled: isDone, size: 28, relativeTo: .title2)
                            .foregroundStyle(isDone ? Color.accentColor : Color.secondary)
                            .frame(minWidth: Theme.minTapTarget, minHeight: Theme.minTapTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Step \(number) done")
                    .accessibilityValue(isDone ? "On" : "Off")
                    .accessibilityAddTraits(.isToggle)
                    .sensoryFeedback(.selection, trigger: isDone)
                }

                content
            }
        }
    }
}

/// Short instructions as bullet lines that wrap under the text, not under the bullet.
private struct QuietBullets: View {
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            ForEach(lines.indices, id: \.self) { index in
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
                    Text("\u{2022}")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text(lines[index])
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A small inline note for something that went wrong (no alert needed).
private struct QuietInlineMessage: View {
    let text: String

    var body: some View {
        PLabel(text, icon: .warningCircle, size: 16, textStyle: .footnote)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        QuietTimeSetupView()
    }
    .environment(AppRouter())
    .modelContainer(SampleData.container)
}
