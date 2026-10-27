import SwiftUI
import TrinketAppState
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
        case .hero: String(localized: L10n.ui_stagebattlepartypickersheet_heroes_04329)
        case .companion: String(localized: L10n.ui_stagebattlepartypickersheet_companions_ea125)
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

    static func isEligible(_ combatant: Combatant, access: ContentAccessPolicy) -> Bool {
        access.allowsCombatant(combatant.id)
    }

    func orderedCombatants(in roster: PlayerRosterState) -> [Combatant] {
        let selectedID = selectedID(in: roster)
        let combatants = combatants(in: roster)
        guard let selected = combatants.first(where: { $0.id == selectedID }) else {
            return combatants
        }
        return [selected] + combatants.filter { $0.id != selectedID }
    }

    /// Resolves a captured selected-first ID ordering against the live roster.
    /// Both the shelf and the grid share the ordering captured once per
    /// presentation so selection changes animate emphasis without reordering.
    func resolveCombatants(ids: [String], in roster: PlayerRosterState) -> [Combatant] {
        let current = Dictionary(uniqueKeysWithValues: combatants(in: roster).lazy.map { ($0.id, $0) })
        return ids.compactMap { current[$0] }
    }
}

/// Shared persist path for shelf and grid selection. Guards, roster mutation,
/// retry registration, and feedback use one ordering so the two surfaces
/// cannot diverge on eligibility or save-failure handling.
@MainActor
private func attemptPartySelection(
    _ combatant: Combatant,
    for slot: BattlePartySlot,
    playerSave: PlayerSaveStore,
    onSelected: @escaping () -> Void,
) {
    playerSave.performSaveAction(key: "party-\(slot.title)") { _ in
        guard BattlePartySlot.isEligible(combatant, access: playerSave.contentAccess) else { return SaveActionAttempt(()) }
        guard combatant.id != slot.selectedID(in: playerSave.roster) else { return SaveActionAttempt(()) }
        let result = switch slot {
        case .hero: playerSave.selectParty(heroID: combatant.id)
        case .companion: playerSave.selectParty(companionID: combatant.id)
        }
        return result.map { value in
            if value == .committed {
                onSelected()
            }
        }
    }
}

struct StageBattlePartyPickerSheet: View {
    @Environment(PlayerSaveStore.self) private var playerSave

    let spire: SpireDefinition?

    init(spire: SpireDefinition? = nil) {
        self.spire = spire
    }

    var body: some View {
        StageBattlePartyPickerContent(spire: spire, roster: playerSave.roster)
    }
}

private struct StageBattlePartyPickerContent: View {
    @Environment(OptionsStore.self) private var options
    @Environment(PlayerSaveStore.self) private var playerSave
    @Environment(\.dismiss) private var dismiss

    @State private var selectionFeedbackTrigger = 0
    @State private var combatantOrder: [BattlePartySlot: [String]]

    let spire: SpireDefinition?

    init(spire: SpireDefinition?, roster: PlayerRosterState) {
        self.spire = spire
        _combatantOrder = State(initialValue: Dictionary(uniqueKeysWithValues: [BattlePartySlot.hero, .companion].map {
            ($0, $0.orderedCombatants(in: roster).map(\.id))
        }))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: TrinketDesign.Layout.sectionSpacing) {
                    partyShelf(for: .hero)
                    partyShelf(for: .companion)
                }
                .padding(.top, TrinketDesign.Layout.compactContentTopPadding)
                .padding(.bottom, TrinketDesign.Layout.sectionSpacing)
            }
            .navigationTitle(Text(L10n.ui_stagebattlepartypickersheet_party_dfa82))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: L10n.ui_stagebattlepartypickersheet_done_11a67)) {
                        dismiss()
                    }
                    .accessibilityIdentifier(AccessibilityID.Play.battlePartyDone)
                }
            }
        }
        .accessibilityIdentifier(partyPickerAccessibilityID)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .trinketSensoryFeedback(
            .selection,
            trigger: selectionFeedbackTrigger,
            enabled: options.hapticsEnabled,
        )
        .disabled(playerSave.isRetryingSaveAction)
        .interactiveDismissDisabled(playerSave.isRetryingSaveAction)
    }

    private func partyShelf(for slot: BattlePartySlot) -> some View {
        let allCombatants = orderedCombatants(for: slot)
        let shelfCombatants = Array(
            allCombatants.prefix(TrinketDesign.Layout.collectionShelfPreviewLimit),
        )

        return CategoryBrowseShelf(
            title: slot.sectionTitle,
            sectionAccessibilityIdentifier: AccessibilityID.Play.battlePartyShelf(for: slot.title),
            totalCount: allCombatants.count,
            artworkNames: shelfCombatants.compactMap { $0.artReference?.thumbnailImageName ?? $0.artReference?.imageName },
        ) {
            BattlePartySlotGridView(slot: slot, combatantIDs: combatantOrder[slot] ?? [])
        } content: {
            ForEach(shelfCombatants) { combatant in
                partyOption(combatant, for: slot)
            }
        }
    }

    private func partyOption(_ combatant: Combatant, for slot: BattlePartySlot) -> some View {
        let selected = combatant.id == slot.selectedID(in: playerSave.roster)
        let eligible = BattlePartySlot.isEligible(combatant, access: playerSave.contentAccess)

        return Button {
            select(combatant, for: slot)
        } label: {
            CombatantCard(
                combatant: combatant,
                isLocked: !eligible,
                showsName: false,
                isSelected: selected,
            )
            .trinketCollectionShelfCardWidth()
        }
        .trinketArtworkCardButtonStyle()
        .disabled(!eligible)
        .gameAccessibilityLabel(combatant.name)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(
            AccessibilityID.Play.battlePartyOption(
                for: slot.title,
                combatantID: combatant.id,
            ),
        )
    }

    private func select(_ combatant: Combatant, for slot: BattlePartySlot) {
        attemptPartySelection(
            combatant,
            for: slot,
            playerSave: playerSave,
            onSelected: { selectionFeedbackTrigger += 1 },
        )
    }

    private func orderedCombatants(for slot: BattlePartySlot) -> [Combatant] {
        slot.resolveCombatants(ids: combatantOrder[slot] ?? [], in: playerSave.roster)
    }

    private var partyPickerAccessibilityID: String {
        if let spire {
            return AccessibilityID.Play.spirePartyPickerSheet(spire.id.rawValue)
        }
        return AccessibilityID.Play.stagePartyPickerSheet
    }
}

private struct BattlePartySlotGridView: View {
    @Environment(OptionsStore.self) private var options
    @Environment(PlayerSaveStore.self) private var playerSave

    @State private var selectionFeedbackTrigger = 0

    let slot: BattlePartySlot
    let combatantIDs: [String]

    var body: some View {
        OptionPickerGrid(
            items: orderedCombatants,
            isSelected: { $0.id == slot.selectedID(in: playerSave.roster) },
            isEligible: {
                BattlePartySlot.isEligible($0, access: playerSave.contentAccess)
            },
            onSelect: select,
            accessibilityIdentifier: { combatant in
                AccessibilityID.Play.battlePartyOption(
                    for: slot.title,
                    combatantID: combatant.id,
                )
            },
            artworkNameProvider: { $0.artReference?.thumbnailImageName ?? $0.artReference?.imageName },
            card: { combatant, isSelected in
                CombatantCard(
                    combatant: combatant,
                    isLocked: !BattlePartySlot.isEligible(combatant, access: playerSave.contentAccess),
                    isSelected: isSelected,
                )
            },
        )
        .navigationTitle(slot.sectionTitle)
        .navigationBarTitleDisplayMode(.inline)
        .trinketSensoryFeedback(
            .selection,
            trigger: selectionFeedbackTrigger,
            enabled: options.hapticsEnabled,
        )
        .disabled(playerSave.isRetryingSaveAction)
        .interactiveDismissDisabled(playerSave.isRetryingSaveAction)
    }

    private var orderedCombatants: [Combatant] {
        slot.resolveCombatants(ids: combatantIDs, in: playerSave.roster)
    }

    private func select(_ combatant: Combatant) {
        attemptPartySelection(
            combatant,
            for: slot,
            playerSave: playerSave,
            onSelected: { selectionFeedbackTrigger += 1 },
        )
    }
}
