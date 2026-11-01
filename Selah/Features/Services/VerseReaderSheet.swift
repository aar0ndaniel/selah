import SwiftUI
import SwiftData

/// A verse or passage attached to a sermon or Bible class, shown in full for reading. The list row cuts it to three
/// lines; this is where it can be read to the end. Reading only, so a sheet (editors are full pages).
struct VerseReaderSheet: View {
    let verse: VerseRef

    @Environment(\.dismiss) private var dismiss

    private var reference: String { "\(verse.reference) (\(verse.translation.shortName))" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    SelahPill(reference, icon: .bookOpen, style: .accent)
                    Text(verse.textSnapshot.isEmpty ? "No text was saved for this verse." : verse.textSnapshot)
                        .font(.selahVerseLarge)
                        .lineSpacing(6)
                        .foregroundStyle(verse.textSnapshot.isEmpty ? .secondary : .primary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Theme.Spacing.l)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background { AppBackground() }
            .navigationTitle(verse.reference)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ShareLink(item: "\(verse.textSnapshot) \u{2014} \(reference)") {
                        Image(picon: .export)
                    }
                    .accessibilityLabel("Share verse")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    VerseReaderSheet(
        verse: VerseRef(
            book: "Philippians",
            chapter: 4,
            verseStart: 6,
            verseEnd: 7,
            textSnapshot: "Be careful for nothing; but in every thing by prayer and supplication with thanksgiving let your requests be made known unto God. And the peace of God, which passeth all understanding, shall keep your hearts and minds through Christ Jesus."
        )
    )
}
