import SwiftUI
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureSupport

struct StageSelectModifierCaption: View {
    let modifiers: [LabyrinthModifierDefinition]

    var body: some View {
        if !modifiers.isEmpty {
            VStack(alignment: .leading, spacing: TrinketDesign.Spacing.small) {
                ForEach(modifiers) { modifier in
                    VStack(alignment: .leading, spacing: TrinketDesign.Spacing.tight) {
                        HStack(spacing: TrinketDesign.Spacing.small) {
                            GameIconImage(LabyrinthModifierPresentation.style(for: modifier).icon)
                                .symbolRenderingMode(.hierarchical)
                                .accessibilityHidden(true)
                            Text(balanced: modifier.title.uppercased()).trinketFittedText()
                        }
                        .trinketTypography(.secondaryBody)
                        .bold()
                        .foregroundStyle(LabyrinthModifierPresentation.style(for: modifier).color)
                        .trinketOnArtText(.title)
                        KeywordDescriptionText(text: modifier.effect.description)
                            .trinketTypography(.secondaryBody)
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
