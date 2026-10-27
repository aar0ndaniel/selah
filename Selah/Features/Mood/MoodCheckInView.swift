import SwiftUI
import SwiftData
import UIKit

/// The daily check-in, a full page: "How are you feeling today, <name>?", a large mascot showing the chosen mood,
/// chevrons and a swipe to change it, chips to pick one directly, and an optional note.
///
/// Opened by `RootTabView` once a day (see `MoodCheckInLogic`) and from the mood row on Today. Saving a second time
/// on the same day updates today's entry instead of adding another.
struct MoodCheckInView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Query private var profiles: [UserProfile]
    @Query(sort: \MoodEntry.date, order: .reverse) private var entries: [MoodEntry]
    @AppStorage(MoodCheckInLogic.skippedKey) private var skippedAt: Double = 0

    @State private var mood: MascotMood = .joyful
    @State private var note = ""
    @State private var loaded = false
    @FocusState private var noteFocused: Bool
    @ScaledMetric(relativeTo: .largeTitle) private var mascotSide: CGFloat = 220

    private var name: String { profiles.first?.name ?? "" }

    private var todayEntry: MoodEntry? {
        entries.first { Calendar.current.isDateInToday($0.date) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                header
                mascot
                selector
                chips
                noteField
            }
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.top, Theme.Spacing.l)
            .padding(.bottom, Theme.Spacing.m)
        }
        .scrollDismissesKeyboard(.interactively)
        .background { AppBackground() }
        .safeAreaInset(edge: .bottom, spacing: 0) { actions }
        .task {
            guard !loaded else { return }
            if let today = todayEntry {
                mood = today.mood
                note = today.note
            }
            loaded = true
        }
        // No haptic for the first value read from an existing entry.
        .sensoryFeedback(.selection, trigger: mood) { _, _ in loaded }
        .onChange(of: note) { _, newValue in
            if newValue.count > 280 { note = String(newValue.prefix(280)) }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(MoodCheckInLogic.headline(name: name))
                .font(.selahDisplay)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("mood-title")
            Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide).hour().minute()))
                .font(.selahLabel)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Mascot and selector

    private var mascot: some View {
        MascotView(mood: mood)
            .frame(width: min(mascotSide, 280), height: min(mascotSide, 280))
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        if value.translation.width < -40 {
                            shift(1)
                        } else if value.translation.width > 40 {
                            shift(-1)
                        }
                    }
            )
            .accessibilityHidden(true)
    }

    private var selector: some View {
        HStack(spacing: Theme.Spacing.m) {
            stepButton(.caretLeft, label: "Previous mood") { shift(-1) }
            Text(mood.title)
                .font(.selahTitle)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
            stepButton(.caretRight, label: "Next mood") { shift(1) }
        }
        // One adjustable control for VoiceOver: swipe up or down to change the mood. The chips below pick directly.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Mood")
        .accessibilityValue(mood.title)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: shift(1)
            case .decrement: shift(-1)
            @unknown default: break
            }
        }
        .accessibilityIdentifier("mood-selector")
    }

    private func stepButton(_ icon: PIcon, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            PIconView(icon, size: 20)
                .foregroundStyle(Theme.brandInk)
                .frame(width: 48, height: 48)
                .background(Theme.brandFill, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var chips: some View {
        PillFlowLayout(spacing: Theme.Spacing.xs) {
            ForEach(MascotMood.allCases, id: \.self) { item in
                chip(item)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func chip(_ item: MascotMood) -> some View {
        let isSelected = item == mood
        return Button {
            select(item)
        } label: {
            Text(item.title)
                .font(Font.selahLabel.weight(isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? Theme.onAccent : Tone.slate.ink)
                .padding(.horizontal, Theme.Spacing.m)
                .frame(minHeight: Theme.minTapTarget)
                .background(
                    isSelected ? Color.accentColor : Tone.slate.pillFill,
                    in: Capsule()
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: Note

    private var noteField: some View {
        TextField("Anything on your heart?", text: $note, axis: .vertical)
            .font(.selahBody)
            .lineLimit(1...3)
            .focused($noteFocused)
            .padding(Theme.Spacing.m)
            .frame(minHeight: Theme.minTapTarget)
            // White field on the grey page, like a Settings row.
            .background(
                Theme.card,
                in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
            )
            .accessibilityIdentifier("mood-note")
    }

    // MARK: Actions

    private var actions: some View {
        VStack(spacing: Theme.Spacing.xxs) {
            Button("Save", action: save)
                .buttonStyle(.selahPrimaryFull)
                .accessibilityIdentifier("mood-save")
            Button("Not now", action: notNow)
                .buttonStyle(.selahTertiary)
                .accessibilityIdentifier("mood-not-now")
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.xs)
        .background(Color(.systemGroupedBackground))
    }

    private func select(_ item: MascotMood) {
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) {
            mood = item
        }
    }

    private func shift(_ delta: Int) {
        select(mood.shifted(by: delta))
    }

    private func save() {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if let today = todayEntry {
            today.mood = mood
            today.note = trimmed
        } else {
            modelContext.insert(MoodEntry(date: Date(), mood: mood, note: trimmed))
        }
        try? modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }

    private func notNow() {
        skippedAt = Date().timeIntervalSince1970
        dismiss()
    }
}

#Preview {
    MoodCheckInView()
        .modelContainer(SampleData.container)
}
