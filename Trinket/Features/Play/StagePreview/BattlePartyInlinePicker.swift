import SwiftUI
import TrinketAppState
import TrinketBattleFeature
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureSupport
import TrinketPersistence

enum BattlePartySlot: String {
    case hero
    case companion

    var title: String {
        rawValue.capitalized
    }

    var sectionTitle: String {
        switch self {
        case .hero: "Heroes"
        case .companion: "Companions"
        }
    }

    func combatants(in roster: PlayerRosterState) -> [Combatant] {
        switch self {
        case .hero: roster.heroes
        case .companion: roster.companions
        }
    }

    func selectedID(in roster: PlayerRosterState) -> String {
        switch self {
        case .hero: roster.activeHero.id
        case .companion: roster.activeCompanion.id
        }
    }

    func select(_ combatant: Combatant, in roster: inout PlayerRosterState) {
        switch self {
        case .hero:
            roster.setActiveHero(combatant)
        case .companion:
            roster.setActiveCompanion(combatant)
        }
    }

    static func isEligible(_ combatant: Combatant, for spire: SpireDefinition?) -> Bool {
        guard let spire else { return true }
        return SpireAttunement.matches(combatant, spire: spire)
    }

    func orderedCombatants(in roster: PlayerRosterState, spire: SpireDefinition?) -> [Combatant] {
        let selectedID = selectedID(in: roster)
        let combatants = combatants(in: roster)
        guard let selected = combatants.first(where: { $0.id == selectedID }) else {
            return combatants.filter { Self.isEligible($0, for: spire) }
        }

        let eligibleAlternatives = combatants.filter {
            $0.id != selectedID && Self.isEligible($0, for: spire)
        }
        return [selected] + eligibleAlternatives
    }
}

/// Journey's shared, single-sheet party editor.
struct StageBattlePartyPickerSheet: View {
    @Environment(OptionsStore.self) private var options
    @Environment(PlayerSaveStore.self) private var playerSave
    @Environment(\.dismiss) private var dismiss

    @State private var selectionFeedbackTrigger = 0

    let spire: SpireDefinition?

    init(spire: SpireDefinition? = nil) {
        self.spire = spire
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: TrinketDesign.Metrics.sectionSpacing) {
                    partyShelf(for: .hero)
                    partyShelf(for: .companion)
                }
                .padding(.top, TrinketDesign.Metrics.compactContentTopPadding)
                .padding(.bottom, TrinketDesign.Metrics.sectionSpacing)
            }
            .navigationTitle("Party")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .accessibilityIdentifier(AccessibilityID.Play.battlePartyDone)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(partyPickerAccessibilityID)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .trinketSensoryFeedback(
            .selection,
            trigger: selectionFeedbackTrigger,
            enabled: options.hapticsEnabled
        )
    }

    private func partyShelf(for slot: BattlePartySlot) -> some View {
        let shelfCombatants = Array(
            orderedCombatants(for: slot).prefix(TrinketDesign.Metrics.collectionShelfPreviewLimit)
        )

        return CategoryBrowseShelf(
            title: slot.sectionTitle,
            sectionAccessibilityIdentifier: AccessibilityID.Play.battlePartyShelf(for: slot.title),
            shelfContentIdentity: shelfCombatants.map(\.id).joined(separator: ","),
            shelfAnimation: .spring(response: 0.35, dampingFraction: 1)
        ) {
            BattlePartySlotGridView(slot: slot, spire: spire)
        } content: {
            ForEach(shelfCombatants) { combatant in
                partyOption(combatant, for: slot)
            }
        }
    }

    private func partyOption(_ combatant: Combatant, for slot: BattlePartySlot) -> some View {
        let selected = combatant.id == slot.selectedID(in: playerSave.roster)
        let eligible = BattlePartySlot.isEligible(combatant, for: spire)

        return Button {
            guard !selected, eligible else { return }
            select(combatant, for: slot)
        } label: {
            CombatantCard(
                combatant: combatant,
                showsName: false,
                isSelected: selected
            )
            .collectionShelfCardWidth()
        }
        .trinketQuietTapButtonStyle()
        .disabled(!eligible)
        .accessibilityIdentifier(
            AccessibilityID.Play.battlePartyOption(
                for: slot.title,
                combatantID: combatant.id
            )
        )
        .accessibilityValue(selected ? "Selected" : "Available")
    }

    private func select(_ combatant: Combatant, for slot: BattlePartySlot) {
        var roster = playerSave.roster
        slot.select(combatant, in: &roster)
        playerSave.roster = roster
        selectionFeedbackTrigger += 1
    }

    private func orderedCombatants(for slot: BattlePartySlot) -> [Combatant] {
        slot.orderedCombatants(in: playerSave.roster, spire: spire)
    }

    private var partyPickerAccessibilityID: String {
        if let spire {
            return AccessibilityID.Play.spirePartyPickerSheet(spire.id.rawValue)
        }
        return AccessibilityID.Play.stagePartyPickerSheet
    }
}

/// Full-grid party slot picker pushed from a shelf header.
private struct BattlePartySlotGridView: View {
    @Environment(OptionsStore.self) private var options
    @Environment(PlayerSaveStore.self) private var playerSave

    @State private var selectionFeedbackTrigger = 0

    let slot: BattlePartySlot
    let spire: SpireDefinition?

    var body: some View {
        OptionPickerGrid(
            items: orderedCombatants,
            isSelected: { $0.id == slot.selectedID(in: playerSave.roster) },
            isEligible: { BattlePartySlot.isEligible($0, for: spire) },
            onSelect: select,
            accessibilityIdentifier: { combatant in
                AccessibilityID.Play.battlePartyOption(
                    for: slot.title,
                    combatantID: combatant.id
                )
            },
            accessibilityValue: { combatant in
                combatant.id == slot.selectedID(in: playerSave.roster) ? "Selected" : "Available"
            },
            card: { combatant, isSelected in
                CombatantCard(
                    combatant: combatant,
                    isSelected: isSelected
                )
            }
        )
        .navigationTitle(slot.sectionTitle)
        .navigationBarTitleDisplayMode(.inline)
        .trinketSensoryFeedback(
            .selection,
            trigger: selectionFeedbackTrigger,
            enabled: options.hapticsEnabled
        )
    }

    private var orderedCombatants: [Combatant] {
        slot.orderedCombatants(in: playerSave.roster, spire: spire)
    }

    private func select(_ combatant: Combatant) {
        guard combatant.id != slot.selectedID(in: playerSave.roster) else { return }
        var roster = playerSave.roster
        slot.select(combatant, in: &roster)
        playerSave.roster = roster
        selectionFeedbackTrigger += 1
    }
}
