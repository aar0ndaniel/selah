import UIKit

/// The keyboard accessory of the note editor: bold, italic, underline, heading, bulleted list, numbered list, quote,
/// highlight and comment, and Done.
///
/// Plain controls on a plain bar (no custom blur): the keyboard under it already carries the system material.
/// Every button is 44 x 44pt and has a VoiceOver label. A toggle that is on shows a pale teal capsule behind an
/// ink-coloured icon and carries the `selected` accessibility trait, so the state is not told by colour alone.
/// The row of tools scrolls sideways on narrow phones; Done stays fixed at the right.
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

    static let barHeight: CGFloat = 52

    var onAction: ((Action) -> Void)?
    var onDone: (() -> Void)?

    private var buttons: [Action: UIButton] = [:]
    private var active: Set<Action> = []
    private var highlightEnabled = false
    private let scroll = UIScrollView()
    private let stack = UIStackView()
    private let doneButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: CGRect(x: 0, y: 0, width: frame.width, height: Self.barHeight))
        autoresizingMask = [.flexibleWidth]
        backgroundColor = .systemBackground
        build()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: Self.barHeight)
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
        let separator = UIView()
        separator.backgroundColor = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separator)

        var doneConfiguration = UIButton.Configuration.plain()
        doneConfiguration.title = "Done"
        doneConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12)
        doneButton.configuration = doneConfiguration
        doneButton.accessibilityLabel = "Done"
        doneButton.accessibilityHint = "Closes the keyboard."
        doneButton.accessibilityIdentifier = "format-done"
        doneButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        doneButton.setContentHuggingPriority(.required, for: .horizontal)
        doneButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(doneButton)

        scroll.showsHorizontalScrollIndicator = false
        scroll.alwaysBounceHorizontal = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scroll)

        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)

        for action in Action.allCases {
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
            stack.addArrangedSubview(button)
            buttons[action] = button
            style(action)
        }

        NSLayoutConstraint.activate([
            separator.topAnchor.constraint(equalTo: topAnchor),
            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5),

            doneButton.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -4),
            doneButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            doneButton.heightAnchor.constraint(equalToConstant: 44),
            doneButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),

            scroll.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 4),
            scroll.trailingAnchor.constraint(equalTo: doneButton.leadingAnchor),
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),

            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor)
        ])
    }

    private func style(_ action: Action) {
        guard let button = buttons[action] else { return }
        let selected = active.contains(action)
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(named: action.icon.assetName())?.withRenderingMode(.alwaysTemplate)
        configuration.cornerStyle = .capsule
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
        configuration.baseForegroundColor = selected ? (UIColor(named: "ToneTealInk") ?? .label) : .label
        configuration.background.backgroundColor = selected
            ? (UIColor(named: "ToneTealFill") ?? .secondarySystemFill)
            : .clear
        button.configuration = configuration
        button.isSelected = selected
        button.isEnabled = action != .highlight || highlightEnabled
        var traits: UIAccessibilityTraits = .button
        if selected { traits.insert(.selected) }
        button.accessibilityTraits = traits
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
