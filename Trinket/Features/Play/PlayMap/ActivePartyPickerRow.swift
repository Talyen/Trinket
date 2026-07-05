import SwiftUI
import TrinketContent
import TrinketDesignSystem

struct ActivePartyPickerRow: View {
    let hero: Combatant
    let pet: Combatant
    let onHeroPicker: () -> Void
    let onPetPicker: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            CompactPartyButton(title: "Hero", combatant: hero, onSelect: onHeroPicker)
            CompactPartyButton(title: "Pet", combatant: pet, onSelect: onPetPicker)
        }
    }
}

struct CompactPartyButton: View {
    let title: String
    let combatant: Combatant
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                CombatantArtwork(combatant: combatant, variant: .card)
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: TrinketDesign.Corners.small, style: .continuous))

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(combatant.name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .trinketSurface(.denseRow)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("\(title) Party Picker")
        .accessibilityLabel("\(title), \(combatant.name)")
    }
}
