import SwiftUI

/// Empty or "nothing found" state built on `ContentUnavailableView`, with a Phosphor icon.
struct EmptyState: View {
    let title: String
    let icon: PIcon
    var message: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        ContentUnavailableView {
            Label {
                Text(title)
            } icon: {
                PIconView(icon, size: 48, relativeTo: .largeTitle)
            }
        } description: {
            if let message { Text(message) }
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.selahPrimary)
            }
        }
    }
}

#Preview {
    EmptyState(
        title: "No notes yet",
        icon: .note,
        message: "Notes you write will show up here.",
        actionTitle: "New note",
        action: {}
    )
}
