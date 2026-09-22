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
                    VStack(alignment: .leading, spacing: TrinketDesign.Spacing.tight) {
                        HStack(spacing: TrinketDesign.Spacing.small) {
                            GameIconImage(modifier.style.icon)
                                .symbolRenderingMode(.hierarchical)
                                .accessibilityHidden(true)
                            Text(balanced: modifier.title.uppercased()).trinketFittedText()
                        }
                        .trinketTypography(.body)
                        .bold()
                        .foregroundStyle(modifier.style.color)
                        .trinketOnArtText(.title)
                        KeywordDescriptionText(text: modifier.description)
                            .trinketTypography(.body)
                            .trinketOnArtText(.eyebrow)
                            .fixedSize(horizontal: false, vertical: true)
                    }
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
