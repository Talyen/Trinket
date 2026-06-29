import SwiftUI

struct CombatantCollectionDetailSelection: Identifiable, Hashable {
    enum Kind: Hashable {
        case hero
        case pet
    }

    let kind: Kind
    let combatantID: String

    var id: String {
        "\(kind)-\(combatantID)"
    }
}

struct CombatantCollectionDetailSheet: View {
    @Environment(AppState.self) private var appState
    let selection: CombatantCollectionDetailSelection

    var body: some View {
        let rosterState = appState.roster.current
        let inventoryState = appState.inventory.current
        let combatants = rosterState.configuredCombatants(sourceCombatants)

        if let combatant = combatants.first(where: { $0.id == selection.combatantID }) {
            CombatantCollectionDetailView(
                combatant: combatant,
                progression: rosterState.progression(for: combatant),
                inventoryState: inventoryState,
                loadout: loadoutBinding(for: combatant, in: rosterState),
                equipmentLoadout: equipmentLoadoutBinding(for: combatant, in: rosterState),
                navigationChrome: .hidden
            )
        } else {
            ContentUnavailableView(missingTitle, systemImage: "questionmark.circle")
        }
    }

    private var sourceCombatants: [Combatant] {
        switch selection.kind {
        case .hero:
            GameContent.heroes
        case .pet:
            GameContent.pets
        }
    }

    private var missingTitle: String {
        switch selection.kind {
        case .hero:
            "Hero Not Found"
        case .pet:
            "Pet Not Found"
        }
    }

    private func loadoutBinding(for combatant: Combatant, in rosterState: PlayerRosterState) -> Binding<AbilityLoadout> {
        Binding {
            rosterState.loadout(for: combatant)
        } set: { newValue in
            var updated = appState.roster.current
            updated.setLoadout(newValue, for: combatant)
            appState.roster.current = updated
        }
    }

    private func equipmentLoadoutBinding(
        for combatant: Combatant,
        in rosterState: PlayerRosterState
    ) -> Binding<EquipmentLoadout> {
        Binding {
            rosterState.equipmentLoadout(for: combatant)
        } set: { newValue in
            var updated = appState.roster.current
            updated.setEquipmentLoadout(newValue, for: combatant)
            appState.roster.current = updated
        }
    }
}
