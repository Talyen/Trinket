import SwiftUI
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
import TrinketFeatureSupport
import TrinketPersistence

/// Editable roster combatant detail wired from the player save.
/// Lives in Shared so `State/` does not construct feature/shared views.
public struct RosterCombatantDetailView: View {
    @Environment(PlayerSaveStore.self) private var appState

    let kind: CombatantDetailContext.Kind
    let combatantID: String
    let hapticsEnabled: Bool
    let effectsVolume: Double
    var hidesNavigationBar = false

    /// Avoid re-scanning the catalog + configured roster on every parent invalidation.
    @State private var resolvedCombatant: Combatant?

    public init(
        kind: CombatantDetailContext.Kind,
        combatantID: String,
        hapticsEnabled: Bool,
        effectsVolume: Double,
        hidesNavigationBar: Bool = false
    ) {
        self.kind = kind
        self.combatantID = combatantID
        self.hapticsEnabled = hapticsEnabled
        self.effectsVolume = effectsVolume
        self.hidesNavigationBar = hidesNavigationBar
    }

    public var body: some View {
        let combatant = resolvedCombatant ?? resolveCombatant()
        if let combatant {
            CombatantDetailPane(
                combatant: combatant,
                progression: appState.roster.progression(for: combatant),
                loadout: Binding(
                    get: { appState.roster.loadout(for: combatant) },
                    set: { newValue in
                        var updated = appState.roster
                        updated.setLoadout(newValue, for: combatant)
                        appState.roster = updated
                    }
                ),
                equipmentLoadout: Binding(
                    get: { appState.roster.equipmentLoadout(for: combatant) },
                    set: { newValue in
                        var updated = appState.roster
                        updated.setEquipmentLoadout(newValue, for: combatant)
                        appState.roster = updated
                    }
                ),
                inventoryItems: Binding(
                    get: { appState.inventory.items },
                    set: { newItems in
                        var updated = appState.inventory
                        updated.items = newItems
                        appState.inventory = updated
                    }
                ),
                unlockedTalents: Binding(
                    get: { appState.roster.unlockedTalents(for: combatant) },
                    set: { newTalents in
                        var updated = appState.roster
                        updated.setUnlockedTalents(newTalents, for: combatant)
                        appState.roster = updated
                    }
                ),
                allowsEditing: appState.roster.isUnlocked(combatant),
                hapticsEnabled: hapticsEnabled,
                effectsVolume: effectsVolume,
                hidesNavigationBar: hidesNavigationBar,
                onUnlockTalent: { node, tree in
                    var updated = appState.roster
                    _ = updated.unlockTalent(node: node, inTree: tree, for: combatant.id)
                    appState.roster = updated
                },
                onResetTalents: {
                    var updated = appState.roster
                    updated.resetTalents(for: combatant.id)
                    appState.roster = updated
                }
            )
            .onAppear {
                if resolvedCombatant == nil {
                    resolvedCombatant = combatant
                }
            }
        } else {
            ContentUnavailableView(
                kind == .hero ? "Hero Not Found" : "Companion Not Found",
                systemImage: "questionmark.circle"
            )
            .accessibilityIdentifier("Combatant Not Found")
        }
    }

    private func resolveCombatant() -> Combatant? {
        let catalog: [Combatant] = switch kind {
        case .hero:
            GameContent.heroes
        case .companion:
            GameContent.companions
        }
        return appState.roster
            .configuredCombatants(catalog)
            .first(where: { $0.id == combatantID })
    }
}
