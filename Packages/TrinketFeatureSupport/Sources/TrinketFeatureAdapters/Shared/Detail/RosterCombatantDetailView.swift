import SwiftUI
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
import TrinketFeatureSupport
import TrinketPersistence

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
        hidesNavigationBar: Bool = false,
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
                loadout: playerSave.roster.loadout(for: combatant),
                equipmentLoadout: playerSave.roster.equipmentLoadout(for: combatant),
                inventoryItems: playerSave.inventory.items,
                unlockedTalents: playerSave.roster.unlockedTalents(for: combatant),
                allowsEditing: playerSave.roster.isUnlocked(combatant) && playerSave.contentAccess.allowsCombatant(combatant.id),
                hapticsEnabled: hapticsEnabled,
                effectsVolume: effectsVolume,
                hidesNavigationBar: hidesNavigationBar,
                onEdit: { edit in
                    let saved = edit.apply(to: playerSave, for: combatant)
                    if !saved {
                        playerSave.retrySaveAction(key: "combatant-edit-\(combatant.id)") {
                            _ = edit.apply(to: playerSave, for: combatant)
                        }
                    }
                    return saved
                },
                onUnlockTalent: { node, tree in
                    let result = playerSave.unlockTalent(
                        nodeID: node.id,
                        treeID: tree.id,
                        for: combatant.id,
                    )
                    if result == .persistenceFailed {
                        playerSave.retrySaveAction(key: "combatant-talent-\(combatant.id)") {
                            _ = playerSave.unlockTalent(nodeID: node.id, treeID: tree.id, for: combatant.id)
                        }
                    }
                    return result
                },
            )
            .disabled(playerSave.isRetryingSaveAction)
        } else {
            ContentUnavailableView(
                kind == .hero ? "Hero Not Found" : "Companion Not Found",
                systemImage: "questionmark.circle",
            )
            .accessibilityIdentifier("Combatant Not Found")
        }
    }

    private func resolveCombatant() -> Combatant? {
        guard let base = GameContent.combatant(matching: combatantID) else {
            return nil
        }
        switch kind {
        case .hero:
            guard base.role == .hero else { return nil }
        case .companion:
            guard base.role == .companion else { return nil }
        }
        return playerSave.roster.configuredCombatant(base)
    }
}
