import SwiftUI
import TrinketContent
import TrinketDesignSystem

enum BattlePartySlot: String, Identifiable {
    case hero
    case pet

    var id: String {
        rawValue
    }

    var title: String {
        rawValue.capitalized
    }

    var role: Combatant.Role {
        switch self {
        case .hero: .hero
        case .pet: .pet
        }
    }

    var controlAccessibilityID: String {
        switch self {
        case .hero: AccessibilityID.Play.battlePartyHeroControl
        case .pet: AccessibilityID.Play.battlePartyPetControl
        }
    }
}

/// Compact Hero + Pet selection placed directly above a battle CTA.
struct BattlePartyInlinePicker: View {
    @Environment(AppState.self) private var appState

    let aspect: AspectDefinition?
    let accentColor: Color

    @State private var presentedSlot: BattlePartySlot?

    init(
        aspect: AspectDefinition? = nil,
        accentColor: Color = .accentColor
    ) {
        self.aspect = aspect
        self.accentColor = accentColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Metrics.smallSpacing) {
            HStack(spacing: TrinketDesign.Metrics.smallSpacing) {
                slotButton(.hero, combatant: appState.roster.activeHero)
                slotButton(.pet, combatant: appState.roster.activePet)
            }

            if let aspect {
                attunementLine(for: aspect)
            }
        }
        .sheet(item: $presentedSlot) { slot in
            BattleCombatantPickerSheet(
                slot: slot,
                combatants: combatants(for: slot),
                selectedID: selectedID(for: slot),
                aspect: aspect,
                accentColor: accentColor,
                onSelect: { combatant in
                    select(combatant, for: slot)
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .disabled(appState.battle.activeBattle != nil)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Play.battlePartyInlinePicker)
    }

    private func slotButton(_ slot: BattlePartySlot, combatant: Combatant) -> some View {
        Button {
            presentedSlot = slot
        } label: {
            HStack(spacing: 8) {
                CombatantArtwork(combatant: combatant, variant: .card)
                    .frame(width: 38, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: TrinketDesign.Corners.small, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(slot.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(combatant.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 2)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .trinketSurface(.secondary)
            .clipShape(TrinketDesign.cardShape)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(slot.controlAccessibilityID)
        .accessibilityLabel(slot.title + ", " + combatant.name)
        .accessibilityValue(combatant.name)
        .accessibilityHint("Choose a different " + slot.title.lowercased())
    }

    @ViewBuilder
    private func attunementLine(for aspect: AspectDefinition) -> some View {
        let status = AspectAttunement.evaluate(
            hero: appState.roster.activeHero,
            pet: appState.roster.activePet,
            aspect: aspect
        )

        Text(status.message)
            .font(.footnote)
            .foregroundStyle(status.isReady ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.orange))
            .padding(.horizontal, 4)
    }

    private func combatants(for slot: BattlePartySlot) -> [Combatant] {
        switch slot {
        case .hero: appState.roster.heroes
        case .pet: appState.roster.pets
        }
    }

    private func selectedID(for slot: BattlePartySlot) -> String {
        switch slot {
        case .hero: appState.roster.activeHero.id
        case .pet: appState.roster.activePet.id
        }
    }

    private func select(_ combatant: Combatant, for slot: BattlePartySlot) {
        guard isEligible(combatant) else { return }

        var updatedRoster = appState.roster.current
        switch slot {
        case .hero:
            updatedRoster.setActiveHero(combatant)
        case .pet:
            updatedRoster.setActivePet(combatant)
        }
        appState.roster.current = updatedRoster
    }

    private func isEligible(_ combatant: Combatant) -> Bool {
        guard let aspect else { return true }
        return combatant.keywordProfile.contains(aspect.keyword)
    }
}

/// Native medium-height replacement picker for one party slot.
struct BattleCombatantPickerSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let slot: BattlePartySlot
    let combatants: [Combatant]
    let selectedID: String
    let aspect: AspectDefinition?
    let accentColor: Color
    let onSelect: (Combatant) -> Void

    @State private var selectionFeedbackTrigger = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 104), spacing: 12)],
                    spacing: 12
                ) {
                    ForEach(combatants) { combatant in
                        optionButton(combatant)
                    }
                }
                .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
                .padding(.vertical, TrinketDesign.Metrics.mediumSpacing)
            }
            .trinketScreenBackground(.modal)
            .accessibilityIdentifier(AccessibilityID.Play.battlePartyPickerSheet(for: slot.title))
            .navigationTitle("Choose \(slot.title)")
            .navigationBarTitleDisplayMode(.inline)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Play.battlePartyPickerSheet(for: slot.title))
        .trinketSensoryFeedback(
            .selection,
            trigger: selectionFeedbackTrigger,
            enabled: appState.options.hapticsEnabled
        )
    }

    private func optionButton(_ combatant: Combatant) -> some View {
        let eligible = isEligible(combatant)
        let selected = combatant.id == selectedID

        return Button {
            guard eligible else { return }
            onSelect(combatant)
            selectionFeedbackTrigger += 1
            dismiss()
        } label: {
            VStack(spacing: 6) {
                CombatantArtwork(combatant: combatant, variant: .card)
                    .frame(maxWidth: .infinity)
                    // UIStyleCheck: allow - Compact picker thumbnails use a fixed visual height.
                    .frame(height: 88)
                    .clipShape(TrinketDesign.cardShape)

                Text(combatant.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    // UIStyleCheck: allow - Reserve label space so grid cards stay aligned.
                    .frame(minHeight: 34)
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .trinketSurface(.card)
            .clipShape(TrinketDesign.cardShape)
            .overlay {
                TrinketDesign.cardShape
                    .strokeBorder(
                        selected ? accentColor : Color.clear,
                        lineWidth: selected ? 3 : 0
                    )
            }
            .opacity(eligible ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .disabled(!eligible)
        .accessibilityIdentifier(
            AccessibilityID.Play.battlePartyOption(for: slot.title, combatantName: combatant.name)
        )
        .accessibilityLabel(combatant.name + " " + slot.title.lowercased())
        .accessibilityValue(selected ? "Selected" : (eligible ? "Available" : "Not attuned"))
    }

    private func isEligible(_ combatant: Combatant) -> Bool {
        guard let aspect else { return true }
        return combatant.keywordProfile.contains(aspect.keyword)
    }
}
