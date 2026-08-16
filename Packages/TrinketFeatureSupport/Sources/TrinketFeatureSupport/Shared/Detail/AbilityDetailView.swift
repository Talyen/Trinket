import SwiftUI
import TrinketContent
import TrinketDesignSystem

public struct AbilityDetailView: View {
    let ability: Ability
    var primaryActionTitle: String?
    var primaryActionAccessibilityID: String?
    var onPrimaryAction: (() -> Void)?

    @ScaledMetric(relativeTo: .title) private var placeholderIconSize =
        TrinketDesign.Metrics.cardPlaceholderIconPointSize

    public init(
        ability: Ability,
        primaryActionTitle: String? = nil,
        primaryActionAccessibilityID: String? = nil,
        onPrimaryAction: (() -> Void)? = nil
    ) {
        self.ability = ability
        self.primaryActionTitle = primaryActionTitle
        self.primaryActionAccessibilityID = primaryActionAccessibilityID
        self.onPrimaryAction = onPrimaryAction
    }

    public var body: some View {
        DetailHeroScrollShell(title: ability.name) { baseHeight, overscroll in
            DetailHeroHeader(
                eyebrow: ability.tier.rawValue.uppercased(),
                title: ability.name,
                baseHeight: baseHeight,
                overscroll: overscroll
            ) {
                abilityArtwork
            }
            .accessibilityIdentifier(AccessibilityID.LoadoutPicker.abilityDetail(ability.id))
        } bodyContent: {
            DetailSection(
                "Traits",
                sectionID: AccessibilityID.Battle.abilityDetailEffect
            ) {
                VStack(alignment: .leading, spacing: TrinketDesign.Metrics.smallSpacing) {
                    DetailTraitRow(description: ability.summary)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let primaryActionTitle, let onPrimaryAction {
                Button(primaryActionTitle) {
                    onPrimaryAction()
                }
                .frame(maxWidth: .infinity)
                .trinketPrimaryActionButton()
                .trinketCenteredPrimaryAction()
                .accessibilityIdentifier(primaryActionAccessibilityID ?? primaryActionTitle)
                .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
                .padding(.vertical, TrinketDesign.Metrics.mediumSpacing)
            }
        }
    }

    @ViewBuilder
    private var abilityArtwork: some View {
        if let artReference = ability.artReference {
            Image.preparedAsset(artReference, displaySize: .full)
                .resizable()
                .interpolation(.medium)
                .aspectRatio(contentMode: .fill)
                .clipped()
                .decorativePreparedArtwork()
        } else {
            let style = TrinketDesign.CardPlaceholderStyle.ability
            ZStack {
                style.color.opacity(0.18)

                Image(systemName: style.symbolName)
                    .font(.system(size: placeholderIconSize, weight: .semibold))
                    .foregroundStyle(style.color)
                    .symbolRenderingMode(.hierarchical)
            }
        }
    }
}
