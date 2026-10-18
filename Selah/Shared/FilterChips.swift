import SwiftUI

/// Horizontal chip row. Selected chip is a filled accent capsule; the others are quiet slate pills.
/// Plain fills, not glass: chips are content controls, and glass is reserved for the navigation layer.
struct FilterChips<Item: Hashable>: View {
    let items: [Item]
    @Binding var selection: Item
    let title: (Item) -> String

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(items, id: \.self) { item in
                    chip(for: item)
                }
            }
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, Theme.Spacing.xxs)
        }
        .scrollIndicators(.hidden)
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func chip(for item: Item) -> some View {
        let isSelected = item == selection
        return Button {
            selection = item
        } label: {
            Text(title(item))
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color(.systemBackground) : Tone.slate.ink)
                .padding(.horizontal, Theme.Spacing.m)
                .frame(minHeight: Theme.minTapTarget)
                .background(
                    isSelected ? Color.accentColor : Tone.slate.fill,
                    in: Capsule()
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct FilterChipsPreview: View {
    @State private var selection = "All"

    var body: some View {
        FilterChips(items: ["All", "Study", "Services", "Personal"], selection: $selection) { $0 }
    }
}

#Preview {
    FilterChipsPreview()
}
