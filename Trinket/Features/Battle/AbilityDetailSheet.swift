import SwiftUI
import TrinketContent
import TrinketDesignSystem

struct AbilityDetailSheetItem: Identifiable {
    let ability: Ability

    var id: String { ability.id }
}

struct AbilityDetailSheet: View {
    let ability: Ability

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text(ability.name)
                    .font(.title2.weight(.semibold))
                Text(ability.tier.rawValue)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(ability.summary)
                    .font(.body)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .navigationTitle("Ability")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
