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
            AbilityDetailView(ability: ability)
                .accessibilityIdentifier(AccessibilityID.Battle.abilityDetail)
        }
    }
}
