import SwiftUI
import TrinketContent
import TrinketDesignSystem

struct AbilityDetailSheet: View {
    let ability: Ability

    var body: some View {
        NavigationStack {
            AbilityDetailView(ability: ability)
                .accessibilityIdentifier(AccessibilityID.Battle.abilityDetail)
        }
    }
}
