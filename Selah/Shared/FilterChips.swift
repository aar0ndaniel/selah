import SwiftUI

/// Horizontal chip row. Selected chip is tinted glass.
struct FilterChips<Item: Hashable>: View {
    let items: [Item]
    @Binding var selection: Item
    let title: (Item) -> String

    var body: some View {
        ScrollView(.horizontal) {
            GlassEffectContainer(spacing: Theme.Spacing.xs) {
                HStack(spacing: Theme.Spacing.xs) {
                    ForEach(items, id: \.self) { item in
                        chip(for: item)
                    }
                }
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.vertical, Theme.Spacing.xxs)
            }
        }
        .scrollIndicators(.hidden)
        .sensoryFeedback(.selection, trigger: selection)
    }

    @ViewBuilder
    private func chip(for item: Item) -> some View {
        let isSelected = item == selection
        Button {
            selection = item
        } label: {
            if isSelected {
                chipLabel(item, isSelected: true)
                    .glassEffect(.regular.tint(.accentColor).interactive(), in: .capsule)
            } else {
                chipLabel(item, isSelected: false)
                    .glassEffect(.regular.interactive(), in: .capsule)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func chipLabel(_ item: Item, isSelected: Bool) -> some View {
        Text(title(item))
            .font(.subheadline.weight(isSelected ? .semibold : .regular))
            .padding(.horizontal, Theme.Spacing.m)
            .frame(minHeight: 44)
    }
}

private struct FilterChipsPreview: View {
    @State private var selection = "All"

    var body: some View {
        ZStack {
            AppBackground()
            FilterChips(items: ["All", "Study", "Services", "Personal"], selection: $selection) { $0 }
        }
    }
}

#Preview {
    FilterChipsPreview()
}
