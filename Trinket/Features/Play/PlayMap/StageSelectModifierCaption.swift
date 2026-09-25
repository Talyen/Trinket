import SwiftUI
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureSupport

struct StageSelectModifierCaption: View {
    let modifiers: [ModifierCaptionPresentation]

    var body: some View {
        if !modifiers.isEmpty {
            VStack(alignment: .leading, spacing: TrinketDesign.Spacing.small) {
                ForEach(modifiers) { modifier in
                    StageSelectModifierLine(modifier: modifier)
                }
            }
            .padding(.horizontal, TrinketDesign.Spacing.medium)
            .padding(.top, TrinketDesign.Spacing.extraLarge)
            .padding(.bottom, TrinketDesign.Spacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .allowsHitTesting(false)
        }
    }
}

struct StageSelectModifierLine: View {
    let modifier: ModifierCaptionPresentation

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: TrinketDesign.Spacing.small) {
            GameIconImage(modifier.style.icon)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(modifier.style.color)
                .accessibilityHidden(true)
            KeywordDescriptionText(text: modifier.description)
                .fixedSize(horizontal: false, vertical: true)
                .trinketOnArtText(.eyebrow)
        }
        .trinketTypography(.body)
        .accessibilityElement(children: .combine)
    }
}
