import SwiftUI

/// Phosphor icons (MIT, https://github.com/phosphor-icons/core), bundled as template SVG image sets in
/// Assets.xcassets/Icons. Regular weight is the idle look, fill weight is the selected / on look.
///
/// Raw values are the Phosphor icon names. The asset names are "ph-<name>" and "ph-<name>-fill".
/// Each SVG has a 24pt intrinsic size (set when imported), so an unsized `Image(picon:)` in a menu or tab bar is the
/// right size; use `PIconView` anywhere the icon should scale with Dynamic Type.
enum PIcon: String, CaseIterable, Sendable {
    // Tabs
    case sun
    case house
    case bookOpen = "book-open"
    case church
    case note
    case notebook

    // Actions
    case plus
    case plusCircle = "plus-circle"
    case check
    case checkCircle = "check-circle"
    case x
    case xCircle = "x-circle"
    case trash
    case pencilSimple = "pencil-simple"
    case notePencil = "note-pencil"
    case export
    case uploadSimple = "upload-simple"
    case downloadSimple = "download-simple"
    case cloudArrowUp = "cloud-arrow-up"
    case cloudArrowDown = "cloud-arrow-down"
    case shareNetwork = "share-network"
    case dotsThree = "dots-three"
    case magnifyingGlass = "magnifying-glass"
    case gear
    case cursorText = "cursor-text"

    // Content
    case star
    case pushPin = "push-pin"
    case pushPinSlash = "push-pin-slash"
    case bookmarkSimple = "bookmark-simple"
    case book
    case quotes
    case musicNotes = "music-notes"
    case image
    case palette
    case chatCircle = "chat-circle"
    case highlighter
    case filePdf = "file-pdf"
    case textAlignLeft = "text-align-left"
    case chartBar = "chart-bar"
    case info
    case warningCircle = "warning-circle"
    case hammer

    // People, time, streaks
    case userCircle = "user-circle"
    case users
    case calendarBlank = "calendar-blank"
    case calendarCheck = "calendar-check"
    case calendarPlus = "calendar-plus"
    case clock
    case bell
    case bellRinging = "bell-ringing"
    case flame
    case moon
    case bellSlash = "bell-slash"
    case deviceMobile = "device-mobile"
    case arrowSquareOut = "arrow-square-out"

    // Formatting toolbar
    case textB = "text-b"
    case textItalic = "text-italic"
    case textUnderline = "text-underline"
    case textH = "text-h"
    case listBullets = "list-bullets"
    case listNumbers = "list-numbers"

    // Navigation
    case caretDown = "caret-down"
    case caretUp = "caret-up"
    case caretRight = "caret-right"
    case caretLeft = "caret-left"
    case arrowRight = "arrow-right"
    case arrowLeft = "arrow-left"
    case funnelSimple = "funnel-simple"
    case arrowsDownUp = "arrows-down-up"
    case play
    case sparkle

    /// Asset catalog name of the regular or fill variant.
    func assetName(filled: Bool = false) -> String {
        "ph-" + rawValue + (filled ? "-fill" : "")
    }
}

extension Image {
    /// A Phosphor icon as a template image at its intrinsic 24pt size. Tinted by `foregroundStyle`.
    init(picon: PIcon, filled: Bool = false) {
        self.init(picon.assetName(filled: filled))
    }
}

extension Label where Title == Text, Icon == Image {
    /// A label with a Phosphor icon, for menus, list rows and toolbars.
    init(_ title: String, picon: PIcon, filled: Bool = false) {
        self.init {
            Text(title)
        } icon: {
            Image(picon: picon, filled: filled)
        }
    }
}

/// A title with a Phosphor icon that scales with Dynamic Type. Use it for inline content (cards, rows, captions);
/// use `Label(_:picon:)` inside menus, context menus, swipe actions and toolbars, where the system wants a plain `Image`.
struct PLabel: View {
    let title: String
    let icon: PIcon
    var filled: Bool = false
    var size: CGFloat = 20
    var textStyle: Font.TextStyle = .body

    init(_ title: String, icon: PIcon, filled: Bool = false, size: CGFloat = 20, textStyle: Font.TextStyle = .body) {
        self.title = title
        self.icon = icon
        self.filled = filled
        self.size = size
        self.textStyle = textStyle
    }

    var body: some View {
        Label {
            Text(title)
        } icon: {
            PIconView(icon, filled: filled, size: size, relativeTo: textStyle)
        }
    }
}

/// A Phosphor icon that scales with Dynamic Type. Decorative by default (hidden from VoiceOver), because it
/// normally sits beside text; pass `label` when the icon alone carries meaning.
struct PIconView: View {
    private let icon: PIcon
    private let filled: Bool
    private let label: String?
    @ScaledMetric private var scaledSize: CGFloat

    /// - Parameters:
    ///   - size: size in points at the default text size; grows and shrinks with `textStyle`.
    ///   - textStyle: the text style the size is relative to.
    init(
        _ icon: PIcon,
        filled: Bool = false,
        size: CGFloat = 20,
        relativeTo textStyle: Font.TextStyle = .body,
        label: String? = nil
    ) {
        self.icon = icon
        self.filled = filled
        self.label = label
        _scaledSize = ScaledMetric(wrappedValue: size, relativeTo: textStyle)
    }

    var body: some View {
        Image(picon: icon, filled: filled)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: scaledSize, height: scaledSize)
            .accessibilityHidden(label == nil)
            .accessibilityLabel(label ?? "")
    }
}

#Preview("Icons") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: Theme.Spacing.s)], spacing: Theme.Spacing.m) {
            ForEach(PIcon.allCases, id: \.self) { icon in
                VStack(spacing: Theme.Spacing.xxs) {
                    HStack(spacing: Theme.Spacing.xs) {
                        PIconView(icon, size: 24)
                        PIconView(icon, filled: true, size: 24)
                    }
                    .foregroundStyle(Color.accentColor)
                    Text(icon.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
        }
        .padding(Theme.Spacing.m)
    }
}
