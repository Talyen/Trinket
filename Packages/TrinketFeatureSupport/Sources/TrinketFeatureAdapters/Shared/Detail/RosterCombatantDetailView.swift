import SwiftUI
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
import TrinketFeatureSupport
import TrinketPersistence

public struct RosterCombatantDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PlayerSaveStore.self) private var playerSave
    @Environment(\.playSFX) private var playSFX
    @Environment(\.scenePhase) private var scenePhase

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
                    let result = playerSave.performSaveAction(key: "combatant-edit-\(combatant.id)") { _ in
                        playerSave.editCombatant(edit, for: combatant.id)
                    }
                    return result == .committed
                },
                onUnlockTalent: { node, tree in
                    unlockTalent(node: node, tree: tree, for: combatant.id)
                },
            )
            .disabled(playerSave.isRetryingSaveAction)
        } else {
            Color.clear.onAppear { dismiss() }
        }
    }

    private func unlockTalent(node: TalentNode, tree: TalentTree, for id: String) -> RosterEditResult {
        playerSave.performSaveAction(key: "combatant-talent-\(id)") { _ -> RosterEditResult in
            let result = playerSave.unlockTalent(nodeID: node.id, treeID: tree.id, for: id)
            switch result {
            case .committed:
                if scenePhase == .active {
                    playSFX(SFXID.talentUnlock, effectsVolume)
                }
            case .persistenceFailed, .unavailable:
                break
            }
            return result
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
