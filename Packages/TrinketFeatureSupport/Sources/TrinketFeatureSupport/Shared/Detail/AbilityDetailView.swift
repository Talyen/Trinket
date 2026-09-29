import SwiftUI
import TrinketContent
import TrinketDesignSystem

public struct AbilityDetailView: View {
    let ability: Ability
    private let primaryAction: DetailPrimaryAction?

    public init(ability: Ability) {
        self.ability = ability
        primaryAction = nil
    }

    public init(
        ability: Ability,
        primaryActionTitle: String,
        primaryActionAccessibilityID: String? = nil,
        onPrimaryAction: @escaping () -> Void,
    ) {
        self.ability = ability
        primaryAction = DetailPrimaryAction(
            title: primaryActionTitle,
            accessibilityIdentifier: primaryActionAccessibilityID,
            action: onPrimaryAction,
        )
    }

    public var body: some View {
        DetailHeroScrollShell(
            title: ability.name,
            header: { baseHeight in
                DetailHeroHeader(
                    eyebrow: ability.tier.rawValue.uppercased(),
                    title: ability.name,
                    baseHeight: baseHeight,
                ) {
                    abilityArtwork
                }
                .accessibilityIdentifier(AccessibilityID.LoadoutPicker.abilityDetail(ability.id))
            },
            bodyContent: {
                DetailSection(
                    "Traits",
                    sectionID: AccessibilityID.Battle.abilityDetailEffect,
                ) {
                    VStack(alignment: .leading, spacing: TrinketDesign.Spacing.small) {
                        DetailTraitRow(description: ability.summary)
                    }
                }
            },
        )
        .safeAreaInset(edge: .bottom) {
            if let primaryAction {
                DetailPrimaryActionFooter(primaryAction: primaryAction)
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
            PlaceholderArtwork(.ability)
        }
    }
}
