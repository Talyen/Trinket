import SwiftUI
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
import TrinketFeatureSupport
import TrinketPersistence

/// Editable roster combatant detail wired from the player save.
/// Lives in Shared so `State/` does not construct feature/shared views.
public struct RosterCombatantDetailView: View {
    @Environment(PlayerSaveStore.self) private var playerSave

    let kind: CombatantDetailContext.Kind
    let combatantID: String
    let hapticsEnabled: Bool
    let effectsVolume: Double
    var hidesNavigationBar = false

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
        let combatant = resolveCombatant()
        if let combatant {
            CombatantDetailPane(
                combatant: combatant,
                progression: playerSave.roster.progression(for: combatant),
                loadout: Binding(
                    get: { playerSave.roster.loadout(for: combatant) },
                    set: { newValue in
                        persistRoster {
                            $0.setLoadout(newValue, for: combatant)
                        }
                    }
                ),
                equipmentLoadout: Binding(
                    get: { playerSave.roster.equipmentLoadout(for: combatant) },
                    set: { newValue in
                        persistRoster {
                            $0.setEquipmentLoadout(newValue, for: combatant)
                        }
                    }
                ),
                inventoryItems: Binding(
                    get: { playerSave.inventory.items },
                    set: { newItems in
                        playerSave.inventory.items = newItems
                    }
                ),
                unlockedTalents: Binding(
                    get: { playerSave.roster.unlockedTalents(for: combatant) },
                    set: { newTalents in
                        persistRoster {
                            $0.setUnlockedTalents(newTalents, for: combatant)
                        }
                    }
                ),
                allowsEditing: playerSave.roster.isUnlocked(combatant),
                hapticsEnabled: hapticsEnabled,
                effectsVolume: effectsVolume,
                hidesNavigationBar: hidesNavigationBar,
                onUnlockTalent: { node, tree in
                    persistRoster {
                        _ = $0.unlockTalent(node: node, inTree: tree, for: combatant.id)
                    }
                },
                onResetTalents: {
                    persistRoster {
                        $0.resetTalents(for: combatant.id)
                    }
                }
            )
        } else {
            ContentUnavailableView(
                kind == .hero ? "Hero Not Found" : "Companion Not Found",
                systemImage: "questionmark.circle"
            )
            .accessibilityIdentifier("Combatant Not Found")
        }
    }

    private func persistRoster(_ update: (inout PlayerRosterState) -> Void) {
        var copy = playerSave.roster
        update(&copy)
        playerSave.roster = copy
    }

    private func resolveCombatant() -> Combatant? {
        let catalog: [Combatant] = switch kind {
        case .hero:
            GameContent.heroes
        case .companion:
            GameContent.companions
        }
        return playerSave.roster
            .configuredCombatants(catalog)
            .first(where: { $0.id == combatantID })
    }
}
