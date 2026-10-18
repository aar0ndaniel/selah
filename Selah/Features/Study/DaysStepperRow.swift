import SwiftUI

/// "Days" with an editable number and a stepper, limited to 1...365.
/// Used by Add book and Edit plan.
struct DaysStepperRow: View {
    @Binding var days: Int
    var title: String = "Days"

    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            Text(title)
            Spacer(minLength: Theme.Spacing.xs)
            TextField(title, value: $days, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .font(.selahStatSmall)
                .focused($focused)
                .frame(minWidth: 56, maxWidth: 80, minHeight: Theme.minTapTarget)
                .accessibilityLabel("Number of days")
            Stepper(title, value: $days, in: 1...365)
                .labelsHidden()
        }
        .onChange(of: days) { _, newValue in
            let clamped = StudyActions.clampedDays(newValue)
            if clamped != newValue { days = clamped }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focused = false }
            }
        }
    }
}

/// A short list of day counts to tap. The selected one is a filled accent pill; the rest are quiet slate pills.
struct DayQuickPicks: View {
    struct Pick: Identifiable {
        let id: String
        let title: String
        let days: Int
        var isEnabled: Bool = true
    }

    let picks: [Pick]
    @Binding var days: Int

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 96), spacing: Theme.Spacing.xs)],
            alignment: .leading,
            spacing: Theme.Spacing.xs
        ) {
            ForEach(picks) { pick in
                let isSelected = pick.isEnabled && days == pick.days
                Button {
                    days = pick.days
                } label: {
                    Text(pick.title)
                        .font(.selahLabel.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(isSelected ? Color(.systemBackground) : Tone.slate.ink)
                        .padding(.horizontal, Theme.Spacing.s)
                        .padding(.vertical, Theme.Spacing.xs)
                        .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget)
                        .background(isSelected ? Color.accentColor : Tone.slate.pillFill, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!pick.isEnabled)
                .opacity(pick.isEnabled ? 1 : 0.4)
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
        .sensoryFeedback(.selection, trigger: days)
    }
}
