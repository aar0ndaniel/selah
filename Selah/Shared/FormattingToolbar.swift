import UIKit

/// The keyboard accessory of the note editor, drawn as a floating capsule above the keyboard.
///
/// The accessory itself is a plain, fully transparent `UIView` (not a `UIInputView`, which would draw the grey
/// keyboard-coloured strip). Inside it a capsule (inset 12pt from the sides, 8pt above the keyboard, 52pt high)
/// holds the tools in groups with thin dividers: Bold, Italic, Underline | Heading, Quote | Bulleted list,
/// Numbered list | Highlight and comment. A round Done button is pinned at the trailing end; the tools scroll
/// sideways on narrow phones. The capsule is a solid white (dark: #2C2C2E) fill with a soft shadow in light
/// mode and a hairline in dark mode. Every button is 44 x 44pt with a 20pt icon and a VoiceOver label. A toggle
/// that is on shows its icon in BrandInk on a BrandFill rounded square, carries the `selected` trait and has the
/// accessibility value "On", so the state is not told by colour alone.
@MainActor
final class FormattingToolbar: UIView {
    enum Action: Int, CaseIterable {
        case bold, italic, underline, heading, bullet, numbered, quote, highlight

        var icon: PIcon {
            switch self {
            case .bold: return .textB
            case .italic: return .textItalic
            case .underline: return .textUnderline
            case .heading: return .textH
            case .bullet: return .listBullets
            case .numbered: return .listNumbers
            case .quote: return .quotes
            case .highlight: return .highlighter
            }
        }

        var label: String {
            switch self {
            case .bold: return "Bold"
            case .italic: return "Italic"
            case .underline: return "Underline"
            case .heading: return "Heading"
            case .bullet: return "Bulleted list"
            case .numbered: return "Numbered list"
            case .quote: return "Quote"
            case .highlight: return "Highlight and comment"
            }
        }

        var hint: String? {
            switch self {
            case .highlight: return "Highlights the selected words and lets you add a comment."
            default: return nil
            }
        }

        var identifier: String {
            switch self {
            case .bold: return "format-bold"
            case .italic: return "format-italic"
            case .underline: return "format-underline"
            case .heading: return "format-heading"
            case .bullet: return "format-bullets"
            case .numbered: return "format-numbers"
            case .quote: return "format-quote"
            case .highlight: return "format-highlight"
            }
        }
    }

    static let capsuleHeight: CGFloat = 52
    private static let topInset: CGFloat = 6
    private static let bottomInset: CGFloat = 8
    private static let sideInset: CGFloat = 12
    static let barHeight: CGFloat = capsuleHeight + topInset + bottomInset

    /// The tools in the order they appear, split into groups that get a divider between them.
    static let groups: [[Action]] = [
        [.bold, .italic, .underline],
        [.heading, .quote],
        [.bullet, .numbered],
        [.highlight]
    ]

    var onAction: ((Action) -> Void)?
    var onDone: (() -> Void)?

    private var buttons: [Action: UIButton] = [:]
    private var active: Set<Action> = []
    private var highlightEnabled = false
    private let capsule = UIView()
    private let scroll = UIScrollView()
    private let stack = UIStackView()
    private let doneButton = UIButton(type: .system)
    private let doneDivider = UIView()

    override init(frame: CGRect) {
        super.init(frame: CGRect(x: 0, y: 0, width: frame.width, height: Self.barHeight))
        autoresizingMask = [.flexibleWidth]
        backgroundColor = .clear
        isOpaque = false
        build()
        applyAppearance()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: FormattingToolbar, _) in
            view.applyAppearance()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: Self.barHeight)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        capsule.layer.shadowPath = UIBezierPath(
            roundedRect: capsule.bounds,
            cornerRadius: Self.capsuleHeight / 2
        ).cgPath
    }

    /// Only the capsule takes touches; the transparent strip around it lets them through.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit === self ? nil : hit
    }

    // MARK: State

    /// Shows which toggles are on and whether the highlight button can be used.
    func update(active: Set<Action>, highlightEnabled: Bool) {
        guard active != self.active || highlightEnabled != self.highlightEnabled else { return }
        self.active = active
        self.highlightEnabled = highlightEnabled
        for action in Action.allCases {
            style(action)
        }
    }

    // MARK: Build

    private func build() {
        capsule.layer.cornerRadius = Self.capsuleHeight / 2
        capsule.layer.cornerCurve = .continuous
        capsule.translatesAutoresizingMaskIntoConstraints = false
        addSubview(capsule)

        var doneConfiguration = UIButton.Configuration.plain()
        doneConfiguration.image = Self.icon(.x)
        doneConfiguration.cornerStyle = .capsule
        doneConfiguration.baseForegroundColor = .label
        doneConfiguration.background.backgroundColor = UIColor(named: "BrandFill") ?? .tertiarySystemFill
        doneConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
        doneButton.configuration = doneConfiguration
        doneButton.accessibilityLabel = "Done"
        doneButton.accessibilityHint = "Closes the keyboard."
        doneButton.accessibilityIdentifier = "format-done"
        doneButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        capsule.addSubview(doneButton)

        doneDivider.backgroundColor = .separator
        doneDivider.isAccessibilityElement = false
        doneDivider.translatesAutoresizingMaskIntoConstraints = false
        capsule.addSubview(doneDivider)

        scroll.showsHorizontalScrollIndicator = false
        scroll.alwaysBounceHorizontal = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        capsule.addSubview(scroll)

        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)

        for (index, group) in Self.groups.enumerated() {
            if index > 0 {
                stack.addArrangedSubview(makeDivider())
            }
            let row = UIStackView()
            row.axis = .horizontal
            row.alignment = .center
            row.spacing = 2
            for action in group {
                let button = UIButton(type: .system)
                button.tag = action.rawValue
                button.accessibilityLabel = action.label
                button.accessibilityHint = action.hint
                button.accessibilityIdentifier = action.identifier
                button.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
                button.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    button.widthAnchor.constraint(equalToConstant: 44),
                    button.heightAnchor.constraint(equalToConstant: 44)
                ])
                row.addArrangedSubview(button)
                buttons[action] = button
                style(action)
            }
            stack.addArrangedSubview(row)
        }

        NSLayoutConstraint.activate([
            capsule.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: Self.sideInset),
            capsule.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -Self.sideInset),
            capsule.topAnchor.constraint(equalTo: topAnchor, constant: Self.topInset),
            capsule.heightAnchor.constraint(equalToConstant: Self.capsuleHeight),

            doneButton.trailingAnchor.constraint(equalTo: capsule.trailingAnchor, constant: -4),
            doneButton.centerYAnchor.constraint(equalTo: capsule.centerYAnchor),
            doneButton.widthAnchor.constraint(equalToConstant: 44),
            doneButton.heightAnchor.constraint(equalToConstant: 44),

            doneDivider.trailingAnchor.constraint(equalTo: doneButton.leadingAnchor, constant: -6),
            doneDivider.centerYAnchor.constraint(equalTo: capsule.centerYAnchor),
            doneDivider.widthAnchor.constraint(equalToConstant: 1),
            doneDivider.heightAnchor.constraint(equalToConstant: 24),

            scroll.leadingAnchor.constraint(equalTo: capsule.leadingAnchor, constant: 10),
            scroll.trailingAnchor.constraint(equalTo: doneDivider.leadingAnchor, constant: -6),
            scroll.topAnchor.constraint(equalTo: capsule.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: capsule.bottomAnchor),

            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor)
        ])
    }

    private func makeDivider() -> UIView {
        let divider = UIView()
        divider.backgroundColor = .separator
        divider.isAccessibilityElement = false
        divider.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            divider.widthAnchor.constraint(equalToConstant: 1),
            divider.heightAnchor.constraint(equalToConstant: 24)
        ])
        return divider
    }

    /// Soft shadow in light mode, hairline in dark mode (shadows are invisible on dark backgrounds).
    private func applyAppearance() {
        let dark = traitCollection.userInterfaceStyle == .dark
        // White in light mode (no grey), the iOS raised dark grey in dark mode.
        capsule.backgroundColor = dark ? UIColor(red: 44 / 255, green: 44 / 255, blue: 46 / 255, alpha: 1) : .white
        capsule.layer.shadowColor = UIColor.black.cgColor
        capsule.layer.shadowOpacity = dark ? 0 : 0.14
        capsule.layer.shadowRadius = 12
        capsule.layer.shadowOffset = CGSize(width: 0, height: 4)
        capsule.layer.borderWidth = dark ? 1 / traitCollection.displayScale : 0
        capsule.layer.borderColor = UIColor.separator.resolvedColor(with: traitCollection).cgColor
    }

    /// A template image drawn at exactly 20 x 20pt.
    private static func icon(_ icon: PIcon) -> UIImage? {
        guard let source = UIImage(named: icon.assetName()) else { return nil }
        let size = CGSize(width: 20, height: 20)
        return UIGraphicsImageRenderer(size: size).image { _ in
            source.draw(in: CGRect(origin: .zero, size: size))
        }.withRenderingMode(.alwaysTemplate)
    }

    private func style(_ action: Action) {
        guard let button = buttons[action] else { return }
        let selected = active.contains(action)
        var configuration = UIButton.Configuration.plain()
        configuration.image = Self.icon(action.icon)
        configuration.cornerStyle = .fixed
        configuration.background.cornerRadius = 12
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
        configuration.baseForegroundColor = selected ? (UIColor(named: "BrandInk") ?? .label) : .label
        configuration.background.backgroundColor = selected
            ? (UIColor(named: "BrandFill") ?? .secondarySystemFill)
            : .clear
        button.configuration = configuration
        button.isSelected = selected
        button.isEnabled = action != .highlight || highlightEnabled
        var traits: UIAccessibilityTraits = .button
        if selected { traits.insert(.selected) }
        button.accessibilityTraits = traits
        button.accessibilityValue = selected ? "On" : nil
    }

    // MARK: Actions

    @objc private func buttonTapped(_ sender: UIButton) {
        guard let action = Action(rawValue: sender.tag) else { return }
        onAction?(action)
    }

    @objc private func doneTapped() {
        onDone?()
    }
}
