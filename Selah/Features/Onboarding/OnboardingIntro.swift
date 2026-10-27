import SwiftUI
import UIKit

/// The first thing a new user sees: three short story pages that lead with what makes Tehila different (hymns,
/// services, study), each with a Selah scene and a small piece of the real app floating over it, like an App Store
/// screenshot. Skippable from every page (HIG 8.1); "Get started" goes on to the setup steps.
struct OnboardingIntro: View {
    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0

    private let pages = IntroPage.all

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Skip", action: onDone)
                    .buttonStyle(.selahTertiary)
                    .accessibilityIdentifier("intro-skip")
            }
            .padding(.horizontal, Theme.Spacing.m)

            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, item in
                    IntroPageView(page: item)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(reduceMotion ? nil : .default, value: page)

            VStack(spacing: Theme.Spacing.m) {
                HStack(spacing: 6) {
                    ForEach(pages.indices, id: \.self) { index in
                        Capsule()
                            .fill(index == page ? Theme.accent : Theme.accent.opacity(0.2))
                            .frame(width: index == page ? 22 : 8, height: 8)
                    }
                }
                .animation(reduceMotion ? nil : .spring(duration: 0.3), value: page)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Page \(page + 1) of \(pages.count)")

                Button {
                    if page < pages.count - 1 {
                        withAnimation(reduceMotion ? nil : .default) { page += 1 }
                    } else {
                        onDone()
                    }
                } label: {
                    Text(page < pages.count - 1 ? "Continue" : "Get started")
                }
                .buttonStyle(.selahPrimaryFull)
                .accessibilityIdentifier("intro-continue")
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.bottom, Theme.Spacing.m)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
    }
}

// MARK: - Content

/// One story page: the feature in a word, an outcome headline, a line of detail, Selah's scene and the live preview.
struct IntroPage: Sendable {
    enum Preview: Sendable { case songs, services, study }

    let eyebrow: String
    let title: String
    let detail: String
    /// `Onboarding-<scene>` from Selah's art; until it arrives a soft tint with Selah doing the activity.
    let scene: String
    let fallback: MascotActivity
    let preview: Preview

    static let all: [IntroPage] = [
        IntroPage(
            eyebrow: "Songs",
            title: "Sing every hymn by heart",
            detail: "Look up hymns by name, keep the lyrics with you, and practise them line by line before Sunday.",
            scene: "songs",
            fallback: .headset,
            preview: .songs
        ),
        IntroPage(
            eyebrow: "Services",
            title: "Never lose a sermon again",
            detail: "Sermons, Bible classes and songs from every service, kept together and easy to find later.",
            scene: "services",
            fallback: .praying,
            preview: .services
        ),
        IntroPage(
            eyebrow: "Study",
            title: "One book of the Bible, a few days at a time",
            detail: "Pick a book, choose your days, and keep your streak glowing as you go.",
            scene: "study",
            fallback: .reading,
            preview: .study
        )
    ]
}

// MARK: - Page

private struct IntroPageView: View {
    let page: IntroPage

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .bottom) {
                    scene
                        .frame(maxWidth: .infinity)
                        .frame(height: typeSize.isAccessibilitySize ? 220 : 340)
                        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    preview
                        .padding(.horizontal, Theme.Spacing.l)
                        .offset(y: 36)
                }
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.bottom, 36 + Theme.Spacing.l)

                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    Text(page.eyebrow)
                        .font(.selahLabel.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                    Text(page.title)
                        .font(.custom(SelahFontFamily.display, size: 30, relativeTo: .largeTitle).weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text(page.detail)
                        .font(.selahBody)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, Theme.Spacing.l)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    @ViewBuilder
    private var scene: some View {
        if let art = UIImage(named: "Onboarding-\(page.scene)") {
            Image(uiImage: art)
                .resizable()
                .scaledToFill()
                .accessibilityHidden(true)
        } else {
            ZStack {
                LinearGradient(colors: [Theme.brandFill, Theme.card], startPoint: .top, endPoint: .bottom)
                if page.preview == .study, let buddy = UIImage(named: "Streak-lit-coral") {
                    Image(uiImage: buddy)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                        .offset(y: -30)
                } else {
                    MascotView(activity: page.fallback, animated: false)
                        .frame(width: 200, height: 200)
                        .offset(y: -30)
                }
            }
            .accessibilityHidden(true)
        }
    }

    // MARK: Previews of the real app

    @ViewBuilder
    private var preview: some View {
        Group {
            switch page.preview {
            case .songs: songsPreview
            case .services: servicesPreview
            case .study: studyPreview
            }
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.tint(Theme.glassTint), in: .rect(cornerRadius: 22))
        .accessibilityHidden(true)
    }

    private var songsPreview: some View {
        HStack(spacing: Theme.Spacing.s) {
            MascotTile(activity: .headset, size: 48)
            VStack(alignment: .leading, spacing: 6) {
                Text("Amazing grace")
                    .font(.selahCardTitle)
                HStack(spacing: 6) {
                    SelahPill("Hymn 245", style: .neutral)
                    SelahPill("Lyrics", icon: .textAlignLeft, style: .soft(.mint))
                }
            }
            Spacer(minLength: 0)
            Text("Practise")
                .font(.selahLabelSmall.weight(.semibold))
                .foregroundStyle(Theme.onAccent)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Theme.accent, in: Capsule())
        }
    }

    private var servicesPreview: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Sunday worship")
                .font(.selahCardTitle)
            Text("Hope that holds \u{00B7} Pastor Ama")
                .font(.selahLabel)
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                SelahPill("Sermon", icon: .bookOpen, style: .accent)
                SelahPill("Bible class", icon: .users, style: .neutral)
                SelahPill("Song", icon: .musicNotes, style: .neutral)
            }
        }
    }

    private var studyPreview: some View {
        HStack(spacing: Theme.Spacing.m) {
            if let flame = UIImage(named: "StreakFlame") {
                Image(uiImage: flame)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("7 days streak \u{00B7} Study")
                    .font(.selahCardTitle)
                HStack(spacing: 6) {
                    ForEach(0..<7, id: \.self) { day in
                        Circle()
                            .fill(day < 6 ? Theme.accent : Theme.accent.opacity(0.18))
                            .frame(width: 14, height: 14)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }
}

#Preview {
    OnboardingIntro {}
}
