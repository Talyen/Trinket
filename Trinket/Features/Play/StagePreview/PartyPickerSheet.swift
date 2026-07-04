import SwiftUI

struct PartyPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let kind: PartyPickerKind
    let combatants: [Combatant]
    let onSelect: (Combatant) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(combatants) { combatant in
                        Button {
                            onSelect(combatant)
                            dismiss()
                        } label: {
                            PartyPickerCombatantCard(combatant: combatant)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("\(combatant.name) party option")
                    }
                }
                .padding(TrinketDesign.Metrics.contentMargin)
            }
            .background(TrinketDesign.Colors.appBackground)
            .navigationTitle("Choose \(kind.rawValue)")
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier(kind.accessibilityIdentifier)
        }
    }
}

private struct PartyPickerCombatantCard: View {
    let combatant: Combatant

    var body: some View {
        VStack(spacing: 8) {
            TrinketDesign.cardShape
                .fill(Color(.tertiarySystemBackground).opacity(0.35))
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .overlay {
                    CombatantArtwork(combatant: combatant, variant: .card)
                        .clipShape(TrinketDesign.cardShape)
                }

            Text(combatant.name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 4)
                .trinketCardLabelSpace()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(combatant.name) card")
    }
}
