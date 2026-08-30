import SwiftUI
import TrinketContent
import TrinketDesignSystem

public struct AbilityDetailView: View {
    private enum Action {
        case none
        case primaryAction(
            title: String,
            accessibilityID: String?,
            onAction: () -> Void,
        )
    }

    let ability: Ability
    private let action: Action

    public init(ability: Ability) {
        self.ability = ability
        action = .none
    }

    public init(
        ability: Ability,
        primaryActionTitle: String,
        primaryActionAccessibilityID: String? = nil,
        onPrimaryAction: @escaping () -> Void,
    ) {
        self.ability = ability
        action = .primaryAction(
            title: primaryActionTitle,
            accessibilityID: primaryActionAccessibilityID,
            onAction: onPrimaryAction,
        )
    }

    public var body: some View {
        DetailHeroScrollShell(
            title: ability.name,
            header: { baseHeight, overscroll in
                DetailHeroHeader(
                    eyebrow: ability.tier.rawValue.uppercased(),
                    title: ability.name,
                    baseHeight: baseHeight,
                    overscroll: overscroll,
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
                    VStack(alignment: .leading, spacing: TrinketDesign.Metrics.smallSpacing) {
                        DetailTraitRow(description: ability.summary)
                    }
                }
            },
        )
        .safeAreaInset(edge: .bottom) {
            if case let .primaryAction(title, accessibilityID, onAction) = action {
                DetailPrimaryActionFooter(
                    title: title,
                    accessibilityIdentifier: accessibilityID,
                    action: onAction,
                )
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
