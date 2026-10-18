import SwiftUI

struct EmptyState: View {
    let title: String
    let systemImage: String
    var message: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            if let message { Text(message) }
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

#Preview {
    EmptyState(
        title: "No notes yet",
        systemImage: "note.text",
        message: "Notes you write will show up here.",
        actionTitle: "New note",
        action: {}
    )
}
