import SwiftUI
import TrinketContent
import TrinketPersistence

struct CombatantCollectionDetailSelection: Identifiable, Hashable {
    enum Kind: Hashable {
        case hero
        case pet
    }

    enum Source: Hashable {
        case collection(kind: Kind, combatantID: String)
        case battleSnapshot(CombatantCardDetail)
    }

    let source: Source

    init(kind: Kind, combatantID: String) {
        source = .collection(kind: kind, combatantID: combatantID)
    }

    init(battleSnapshot: CombatantCardDetail) {
        source = .battleSnapshot(battleSnapshot)
    }

    var id: String {
        switch source {
        case let .collection(kind, combatantID):
            "\(kind)-\(combatantID)"
        case let .battleSnapshot(detail):
            "battle-\(detail.combatant.id)"
        }
    }
}

struct CombatantCollectionDetailSheet: View {
    @Environment(AppState.self) private var appState
    let selection: CombatantCollectionDetailSelection

    var body: some View {
        switch selection.source {
        case let .collection(kind, combatantID):
            collectionDetail(kind: kind, combatantID: combatantID)
        case let .battleSnapshot(detail):
            battleDetail(detail)
        }
    }

    @ViewBuilder
    private func collectionDetail(kind: CombatantCollectionDetailSelection.Kind, combatantID: String) -> some View {
        let rosterState = appState.roster.current
        let inventoryState = appState.inventory.current
        let combatants = rosterState.configuredCombatants(sourceCombatants(for: kind))

        if let combatant = combatants.first(where: { $0.id == combatantID }) {
            CombatantCollectionDetailView(
                combatant: combatant,
                progression: rosterState.progression(for: combatant),
                inventoryState: inventoryState,
                loadout: loadoutBinding(for: combatant, in: rosterState),
                equipmentLoadout: equipmentLoadoutBinding(for: combatant, in: rosterState),
                allowsEditing: rosterState.isUnlocked(combatant),
                navigationChrome: .hidden
            )
        } else {
            ContentUnavailableView(missingTitle(for: kind), systemImage: "questionmark.circle")
                .accessibilityIdentifier("Combatant Not Found")
        }
    }

    private func battleDetail(_ detail: CombatantCardDetail) -> some View {
        CombatantCollectionDetailView(
            combatant: detail.combatant,
            progression: detail.progression,
            inventoryState: detail.inventoryState,
            loadout: .constant(detail.combatant.abilityLoadout),
            equipmentLoadout: .constant(detail.equipmentLoadout),
            allowsEditing: false,
            battleHealth: detail.health,
            activeEffectSummaries: detail.activeEffectSummaries,
            navigationChrome: .hidden
        )
    }

    private func sourceCombatants(for kind: CombatantCollectionDetailSelection.Kind) -> [Combatant] {
        switch kind {
        case .hero:
            GameContent.heroes
        case .pet:
            GameContent.pets
        }
    }

    private func missingTitle(for kind: CombatantCollectionDetailSelection.Kind) -> String {
        switch kind {
        case .hero:
            "Hero Not Found"
        case .pet:
            "Pet Not Found"
        }
    }

    private func loadoutBinding(for combatant: Combatant, in _: PlayerRosterState) -> Binding<AbilityLoadout> {
        Binding {
            appState.roster.current.loadout(for: combatant)
        } set: { newValue in
            var updated = appState.roster.current
            updated.setLoadout(newValue, for: combatant)
            appState.roster.current = updated
        }
    }

    private func equipmentLoadoutBinding(
        for combatant: Combatant,
        in _: PlayerRosterState
    ) -> Binding<EquipmentLoadout> {
        Binding {
            appState.roster.current.equipmentLoadout(for: combatant)
        } set: { newValue in
            var updated = appState.roster.current
            updated.setEquipmentLoadout(newValue, for: combatant)
            appState.roster.current = updated
        }
    }
}
