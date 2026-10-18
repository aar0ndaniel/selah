import SwiftUI

/// Placeholder sheet shown when a + action fires before its feature exists.
struct ComingSoonSheet: View {
    let title: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            EmptyState(
                title: "Coming soon",
                systemImage: "hammer",
                message: "This part of Selah is still being built."
            )
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    ComingSoonSheet(title: "New note")
}
