import SwiftUI

/// Where Selah's content comes from and the licences it is used under: the Bible translations, Hymnary.org lyrics,
/// the fonts and the icons. A plain inset grouped list; the long MIT text sits in a native disclosure row.
struct CreditsView: View {
    @State private var showIconLicence = false

    private static let phosphorLicence: String = {
        guard let url = Bundle.main.url(forResource: "Phosphor-LICENSE", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else { return "MIT License. Copyright (c) 2023 Phosphor Icons." }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }()

    var body: some View {
        List {
            Section {
                credit("King James Version (KJV)", "Public domain.")
                credit("American Standard Version (ASV, 1901)", "Public domain.")
                credit(
                    "World English Bible (WEB)",
                    "Public domain, from eBible.org. \u{201C}World English Bible\u{201D} is a trademark of eBible.org."
                )
                credit("Berean Standard Bible (BSB)", "Public domain, released by Berean Bible.")
            } header: {
                Text("Bible translations")
            }

            Section {
                credit(
                    "Hymnary.org",
                    "Hymn search and lyrics. Selah only shows lyrics Hymnary.org marks as free to display. Other songs keep the lyrics you type, on this iPhone only."
                )
            } header: {
                Text("Songs")
            }

            Section {
                credit("DM Sans", "Copyright 2014 The DM Sans Project Authors. SIL Open Font License 1.1.")
                credit("Space Grotesk", "Copyright 2020 The Space Grotesk Project Authors. SIL Open Font License 1.1.")
            } header: {
                Text("Fonts")
            }

            Section {
                credit("Phosphor Icons", "Copyright (c) 2023 Phosphor Icons. MIT License.")
                DisclosureGroup("Licence text", isExpanded: $showIconLicence) {
                    Text(Self.phosphorLicence)
                        .font(.selahLabelSmall)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .padding(.vertical, Theme.Spacing.xxs)
                }
                .font(.selahBody)
            } header: {
                Text("Icons")
            }

            Section {
                credit("Mascot and streak art", "Made for Selah.")
            } header: {
                Text("Artwork")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Credits and licences")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func credit(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text(title)
                .font(.selahBody.weight(.semibold))
            Text(detail)
                .font(.selahLabel)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, Theme.Spacing.xxs)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        CreditsView()
    }
}
