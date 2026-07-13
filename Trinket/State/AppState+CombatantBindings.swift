import SwiftUI
import TrinketContent
import TrinketCore
import TrinketPersistence

extension AppState {
    @ViewBuilder
    func rosterCombatantDetail(
        kind: CombatantDetailContext.Kind,
        combatantID: String,
        hidesNavigationBar: Bool = false
    ) -> some View {
        let catalog: [Combatant] = switch kind {
        case .hero:
            GameContent.heroes
        case .companion:
            GameContent.companions
        }

        if let combatant = roster
            .configuredCombatants(catalog)
            .first(where: { $0.id == combatantID }) {
            CombatantDetailPane(
                combatant: combatant,
                progression: roster.progression(for: combatant),
                loadout: Binding(
                    get: { self.roster.loadout(for: combatant) },
                    set: { newValue in
                        var updated = self.roster
                        updated.setLoadout(newValue, for: combatant)
                        self.roster = updated
                    }
                ),
                equipmentLoadout: Binding(
                    get: { self.roster.equipmentLoadout(for: combatant) },
                    set: { newValue in
                        var updated = self.roster
                        updated.setEquipmentLoadout(newValue, for: combatant)
                        self.roster = updated
                    }
                ),
                inventoryState: Binding(
                    get: { self.inventory },
                    set: { self.inventory = $0 }
                ),
                allowsEditing: roster.isUnlocked(combatant),
                hidesNavigationBar: hidesNavigationBar
            )
        } else {
            ContentUnavailableView(
                kind == .hero ? "Hero Not Found" : "Companion Not Found",
                systemImage: "questionmark.circle"
            )
            .accessibilityIdentifier("Combatant Not Found")
        }
    }
}
