import SwiftUI
import TrinketContent
import TrinketDesignSystem
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

    static func isEligible(_ combatant: Combatant, for aspect: AspectDefinition?) -> Bool {
        guard let aspect else { return true }
        return AspectAttunement.matches(combatant, aspect: aspect)
    }
}

/// Journey's shared, single-sheet party editor.
struct StageBattlePartyPickerSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var selectionFeedbackTrigger = 0

    let aspect: AspectDefinition?

    init(aspect: AspectDefinition? = nil) {
        self.aspect = aspect
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
            enabled: appState.options.hapticsEnabled
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
            BattlePartySlotGridView(slot: slot, aspect: aspect)
        } content: {
            ForEach(shelfCombatants) { combatant in
                partyOption(combatant, for: slot)
            }
        }
    }

    private func partyOption(_ combatant: Combatant, for slot: BattlePartySlot) -> some View {
        let selected = combatant.id == slot.selectedID(in: appState.roster)
        let eligible = BattlePartySlot.isEligible(combatant, for: aspect)

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
        var roster = appState.roster
        slot.select(combatant, in: &roster)
        appState.roster = roster
        selectionFeedbackTrigger += 1
    }

    private func orderedCombatants(for slot: BattlePartySlot) -> [Combatant] {
        let roster = appState.roster
        let selectedID = slot.selectedID(in: roster)
        let combatants = slot.combatants(in: roster)
        guard let selected = combatants.first(where: { $0.id == selectedID }) else {
            return combatants.filter { BattlePartySlot.isEligible($0, for: aspect) }
        }

        let eligibleAlternatives = combatants.filter {
            $0.id != selectedID && BattlePartySlot.isEligible($0, for: aspect)
        }
        return [selected] + eligibleAlternatives
    }

    private var partyPickerAccessibilityID: String {
        if let aspect {
            return AccessibilityID.Play.aspectPartyPickerSheet(aspect.id.rawValue)
        }
        return AccessibilityID.Play.stagePartyPickerSheet
    }
}

/// Full-grid party slot picker pushed from a shelf header.
private struct BattlePartySlotGridView: View {
    @Environment(AppState.self) private var appState

    @State private var selectionFeedbackTrigger = 0

    let slot: BattlePartySlot
    let aspect: AspectDefinition?

    var body: some View {
        OptionPickerGrid(
            items: orderedCombatants,
            isSelected: { $0.id == slot.selectedID(in: appState.roster) },
            isEligible: { BattlePartySlot.isEligible($0, for: aspect) },
            onSelect: select,
            accessibilityIdentifier: { combatant in
                AccessibilityID.Play.battlePartyOption(
                    for: slot.title,
                    combatantID: combatant.id
                )
            },
            accessibilityValue: { combatant in
                combatant.id == slot.selectedID(in: appState.roster) ? "Selected" : "Available"
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
            enabled: appState.options.hapticsEnabled
        )
    }

    private var orderedCombatants: [Combatant] {
        let roster = appState.roster
        let selectedID = slot.selectedID(in: roster)
        let combatants = slot.combatants(in: roster)
        guard let selected = combatants.first(where: { $0.id == selectedID }) else {
            return combatants.filter { BattlePartySlot.isEligible($0, for: aspect) }
        }

        let eligibleAlternatives = combatants.filter {
            $0.id != selectedID && BattlePartySlot.isEligible($0, for: aspect)
        }
        return [selected] + eligibleAlternatives
    }

    private func select(_ combatant: Combatant) {
        guard combatant.id != slot.selectedID(in: appState.roster) else { return }
        var roster = appState.roster
        slot.select(combatant, in: &roster)
        appState.roster = roster
        selectionFeedbackTrigger += 1
    }
}
