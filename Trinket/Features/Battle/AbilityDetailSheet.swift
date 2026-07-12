import SwiftUI
import TrinketContent
import TrinketDesignSystem

struct AbilityDetailSheetItem: Identifiable {
    let ability: Ability

    var id: String {
        ability.id
    }
}

struct AbilityDetailSheet: View {
    let ability: Ability

    var body: some View {
        NavigationStack {
            DetailHeroScrollShell(title: ability.name) { baseHeight, overscroll in
                AbilityHeroHeader(
                    ability: ability,
                    baseHeight: baseHeight,
                    overscroll: overscroll
                )
                .accessibilityIdentifier(AccessibilityID.Battle.abilityDetail)
            } bodyContent: {
                DetailSection(
                    "Effect",
                    sectionID: AccessibilityID.Battle.abilityDetailEffect
                ) {
                    KeywordDescriptionText(text: ability.summary)
                        .trinketTypography(.secondaryBody)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
