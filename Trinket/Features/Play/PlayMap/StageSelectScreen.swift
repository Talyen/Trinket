import SwiftUI
import TrinketDesignSystem
import TrinketFeatureSupport

struct StageSelectScreen<HeroArt: View, Content: View>: View {
    let eyebrow: String?
    let title: String
    let subtitle: String?
    var heroModifier: ModifierCaptionPresentation?
    let titleAccessibilityIdentifier: String?
    var subtitleAccessibilityIdentifier: String = ""
    @ViewBuilder let heroArt: () -> HeroArt
    @ViewBuilder let content: () -> Content

    var body: some View {
        DetailHeroScrollShell(
            title: title,
            heroHeightPolicy: .cinematicLandscape,
        ) { baseHeight in
            DetailHeroHeader(
                eyebrow: eyebrow,
                title: title,
                titleAccessibilityIdentifier: titleAccessibilityIdentifier,
                baseHeight: baseHeight,
                horizontalPadding: TrinketDesign.Layout.contentMargin,
                bottomPadding: TrinketDesign.Spacing.large,
            ) {
                heroArt()
            } footer: {
                if let heroModifier {
                    StageSelectModifierLine(modifier: heroModifier)
                        .accessibilityIdentifier(subtitleAccessibilityIdentifier)
                } else if let subtitle {
                    Text(subtitle)
                        .accessibilityIdentifier(subtitleAccessibilityIdentifier)
                        .trinketTypography(.secondaryBody)
                        .trinketOnArtText(.eyebrow)
                }
            }
        } bodyContent: {
            content()
        }
    }
}

struct StageSelectCompletionPanel: View {
    let title: String
    let description: String
    let buttonTitle: String
    let tint: Color
    let accessibilityIdentifier: String
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: TrinketDesign.Spacing.large) {
            ContentUnavailableView(
                title,
                systemImage: "checkmark.seal.fill",
                description: Text(description),
            )

            Button(buttonTitle, action: onBack)
                .frame(maxWidth: .infinity)
                .trinketPrimaryActionButton(
                    tint: tint,
                    accessibilityIdentifier: accessibilityIdentifier,
                )
                .trinketCenteredPrimaryAction()
        }
        .padding(.horizontal, TrinketDesign.Layout.contentMargin)
        .padding(.vertical, TrinketDesign.Spacing.large)
    }
}
