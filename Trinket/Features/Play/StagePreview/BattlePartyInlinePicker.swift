import SwiftUI
import TrinketContent
import TrinketDesignSystem
import TrinketPersistence

enum BattlePartySlot: String, Identifiable {
    case hero
    case companion

    var id: String {
        rawValue
    }

    var title: String {
        rawValue.capitalized
    }

    var controlAccessibilityID: String {
        switch self {
        case .hero: AccessibilityID.Play.battlePartyHeroControl
        case .companion: AccessibilityID.Play.battlePartyCompanionControl
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
        return combatant.keywordProfile.contains(aspect.keyword)
    }
}

/// Compact Hero + Companion selection placed directly above a battle CTA.
struct BattlePartyInlinePicker: View {
    @Environment(AppState.self) private var appState

    let aspect: AspectDefinition?

    @State private var presentedSlot: BattlePartySlot?

    init(aspect: AspectDefinition? = nil) {
        self.aspect = aspect
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Metrics.smallSpacing) {
            HStack(spacing: TrinketDesign.Metrics.smallSpacing) {
                slotButton(.hero, combatant: appState.roster.activeHero)
                slotButton(.companion, combatant: appState.roster.activeCompanion)
            }

            if let aspect {
                attunementLine(for: aspect)
            }
        }
        .sheet(item: $presentedSlot) { slot in
            BattleCombatantPickerSheet(
                slot: slot,
                combatants: slot.combatants(in: appState.roster),
                selectedID: slot.selectedID(in: appState.roster),
                aspect: aspect,
                onSelect: { combatant in
                    select(combatant, for: slot)
                }
            )
        }
        .disabled(appState.battle.activeBattle != nil)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Play.battlePartyInlinePicker)
    }

    private func slotButton(_ slot: BattlePartySlot, combatant: Combatant) -> some View {
        Button {
            presentedSlot = slot
        } label: {
            HStack(spacing: TrinketDesign.Metrics.smallSpacing) {
                CombatantArtwork(combatant: combatant, variant: .card)
                    .frame(width: 38, height: 48)
                    .clipShape(TrinketDesign.cardShape)

                VStack(alignment: .leading, spacing: 2) {
                    Text(slot.title)
                        .trinketTypography(.badge)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(combatant.name)
                        .trinketTypography(.cardTitle)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .allowsTightening(true)
                }
                .layoutPriority(1)

                Spacer(minLength: 2)

                Image(systemName: "chevron.right")
                    .trinketTypography(.eyebrow)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .trinketSurface(.secondary)
            .clipShape(TrinketDesign.cardShape)
        }
        .trinketQuietTapButtonStyle()
        .accessibilityIdentifier(slot.controlAccessibilityID)
    }

    @ViewBuilder
    private func attunementLine(for aspect: AspectDefinition) -> some View {
        let status = AspectAttunement.evaluate(
            hero: appState.roster.activeHero,
            companion: appState.roster.activeCompanion,
            aspect: aspect
        )

        Text(status.message)
            .trinketTypography(.footnote)
            .foregroundStyle(status.isReady ? Color.secondary : TrinketDesign.Colors.warning)
            .padding(.horizontal, TrinketDesign.Metrics.extraSmallSpacing)
    }

    private func select(_ combatant: Combatant, for slot: BattlePartySlot) {
        guard BattlePartySlot.isEligible(combatant, for: aspect) else { return }

        var updatedRoster = appState.roster
        slot.select(combatant, in: &updatedRoster)
        appState.roster = updatedRoster
    }
}

/// Native party-slot picker that expands from its card grid into combatant detail.
struct BattleCombatantPickerSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let slot: BattlePartySlot
    let combatants: [Combatant]
    let selectedID: String
    let aspect: AspectDefinition?
    let onSelect: (Combatant) -> Void

    @State private var selectedCombatant: Combatant?
    @State private var selectionFeedbackTrigger = 0
    @Namespace private var zoomNamespace

    var body: some View {
        NavigationStack {
            BattlePartyOptionsGrid(
                slot: slot,
                combatants: combatants,
                selectedID: selectedID,
                aspect: aspect,
                zoomNamespace: zoomNamespace,
                onOpenDetail: { combatant in
                    selectedCombatant = combatant
                }
            )
            .navigationTitle("Choose \(slot.title)")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $selectedCombatant) { combatant in
                BattlePartyCombatantDetail(
                    slot: slot,
                    combatant: combatant,
                    onSelect: {
                        onSelect(combatant)
                        selectionFeedbackTrigger += 1
                        dismiss()
                    }
                )
                .navigationTransition(.zoom(sourceID: combatant.id, in: zoomNamespace))
            }
        }
        .accessibilityIdentifier(AccessibilityID.Play.battlePartyPickerSheet(for: slot.title))
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .trinketSensoryFeedback(
            .selection,
            trigger: selectionFeedbackTrigger,
            enabled: appState.options.hapticsEnabled
        )
    }
}

/// Journey's compact, single-sheet party editor.
struct StageBattlePartyPickerSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var presentedSlot: BattlePartySlot?
    @State private var selectedCombatant: Combatant?
    @State private var selectionFeedbackTrigger = 0
    @Namespace private var zoomNamespace

    var body: some View {
        NavigationStack {
            Group {
                if let presentedSlot {
                    BattlePartyOptionsGrid(
                        slot: presentedSlot,
                        combatants: presentedSlot.combatants(in: appState.roster),
                        selectedID: presentedSlot.selectedID(in: appState.roster),
                        aspect: nil,
                        zoomNamespace: zoomNamespace,
                        onOpenDetail: { combatant in
                            selectedCombatant = combatant
                        }
                    )
                } else {
                    partySlots
                }
            }
            .navigationTitle(presentedSlot == nil ? "Party" : "Choose \(presentedSlot?.title ?? "")")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $selectedCombatant) { combatant in
                if let presentedSlot {
                    BattlePartyCombatantDetail(
                        slot: presentedSlot,
                        combatant: combatant,
                        onSelect: {
                            select(combatant, for: presentedSlot)
                            selectedCombatant = nil
                            self.presentedSlot = nil
                        }
                    )
                    .navigationTransition(.zoom(sourceID: combatant.id, in: zoomNamespace))
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Play.stagePartyPickerSheet)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .trinketSensoryFeedback(
            .selection,
            trigger: selectionFeedbackTrigger,
            enabled: appState.options.hapticsEnabled
        )
    }

    private var partySlots: some View {
        ScrollView {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: TrinketDesign.Metrics.largeSpacing) {
                    partySlot(.hero, combatant: appState.roster.activeHero)
                    partySlot(.companion, combatant: appState.roster.activeCompanion)
                }
                .frame(maxWidth: 240)
                .frame(maxWidth: .infinity)
            } else {
                HStack(alignment: .top, spacing: TrinketDesign.Metrics.mediumSpacing) {
                    partySlot(.hero, combatant: appState.roster.activeHero)
                    partySlot(.companion, combatant: appState.roster.activeCompanion)
                }
            }
        }
        .padding(TrinketDesign.Metrics.contentMargin)
    }

    private func partySlot(_ slot: BattlePartySlot, combatant: Combatant) -> some View {
        Button {
            presentedSlot = slot
        } label: {
            TrinketDesign.cardShape
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .overlay {
                    ZStack(alignment: .bottomLeading) {
                        CombatantArtwork(combatant: combatant, variant: .card)

                        VStack(alignment: .leading, spacing: TrinketDesign.Metrics.extraSmallSpacing) {
                            Text(slot.title)
                                .trinketTypography(.badge)
                                .trinketOnArtText(.eyebrow)
                            Text(combatant.name)
                                .trinketTypography(.cardTitle)
                                .trinketOnArtText(.title)
                                .lineLimit(2)
                                .minimumScaleFactor(0.75)
                        }
                        .padding(TrinketDesign.Metrics.mediumSpacing)
                    }
                }
                .clipShape(TrinketDesign.cardShape)
                .trinketCardSurface()
        }
        .trinketQuietTapButtonStyle()
        .accessibilityIdentifier(slot.controlAccessibilityID)
        .accessibilityLabel("\(slot.title), \(combatant.name)")
        .accessibilityHint("Choose a different \(slot.title.lowercased())")
    }

    private func select(_ combatant: Combatant, for slot: BattlePartySlot) {
        var roster = appState.roster
        slot.select(combatant, in: &roster)
        appState.roster = roster
        selectionFeedbackTrigger += 1
    }
}

private struct BattlePartyOptionsGrid: View {
    let slot: BattlePartySlot
    let combatants: [Combatant]
    let selectedID: String
    let aspect: AspectDefinition?
    var zoomNamespace: Namespace.ID?
    let onOpenDetail: (Combatant) -> Void

    private var orderedCombatants: [Combatant] {
        guard let selected = combatants.first(where: { $0.id == selectedID }) else {
            return combatants
        }
        return [selected] + combatants.filter { $0.id != selectedID }
    }

    var body: some View {
        OptionPickerGrid(
            items: orderedCombatants,
            isSelected: { combatant in
                combatant.id == selectedID
            },
            isEligible: { combatant in
                BattlePartySlot.isEligible(combatant, for: aspect)
            },
            onSelect: onOpenDetail,
            accessibilityIdentifier: { combatant in
                AccessibilityID.Play.battlePartyOption(for: slot.title, combatantName: combatant.name)
            },
            accessibilityValue: { combatant in
                combatant.id == selectedID ? "Selected" : "Available"
            },
            zoomNamespace: zoomNamespace,
            card: { combatant, isSelected in
                CombatantCard(
                    combatant: combatant,
                    isSelected: isSelected
                )
            }
        )
    }
}

private struct BattlePartyCombatantDetail: View {
    @Environment(AppState.self) private var appState

    let slot: BattlePartySlot
    let combatant: Combatant
    let onSelect: () -> Void

    var body: some View {
        CombatantDetailPane(
            combatant: combatant,
            progression: appState.roster.progression(for: combatant),
            loadout: .constant(combatant.abilityLoadout),
            equipmentLoadout: .constant(appState.roster.equipmentLoadout(for: combatant)),
            inventoryState: .constant(appState.inventory),
            allowsEditing: false
        )
        .accessibilityIdentifier(AccessibilityID.Play.battlePartyDetail(combatant.id))
        .safeAreaInset(edge: .bottom) {
            Button("Select \(slot.title)", action: onSelect)
                .frame(maxWidth: .infinity)
                .trinketPrimaryActionButton()
                .accessibilityIdentifier(
                    AccessibilityID.Play.selectBattlePartyOption(
                        for: slot.title,
                        combatantID: combatant.id
                    )
                )
                .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
                .padding(.vertical, TrinketDesign.Metrics.mediumSpacing)
        }
    }
}
