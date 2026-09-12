import SwiftUI
import TrinketContent
import TrinketCore
import TrinketFeatureContracts
import TrinketFeatureSupport
import TrinketPersistence

public struct RosterCombatantDetailView: View {
    @Environment(PlayerSaveStore.self) private var playerSave
    @State private var persistenceFailure: String?

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
                    reportSaveResult(edit.apply(to: playerSave, for: combatant))
                },
                onUnlockTalent: { node, tree in
                    let result = playerSave.unlockTalent(
                        nodeID: node.id,
                        treeID: tree.id,
                        for: combatant.id,
                    )
                    if result == .persistenceFailed {
                        _ = reportSaveResult(false)
                    }
                    return result
                },
            )
            .trinketFailureAlert("Couldn't Save Changes", message: $persistenceFailure)
        } else {
            ContentUnavailableView(
                kind == .hero ? "Hero Not Found" : "Companion Not Found",
                systemImage: "questionmark.circle",
            )
            .accessibilityIdentifier("Combatant Not Found")
        }
    }

    private func reportSaveResult(_ saved: Bool) -> Bool {
        if !saved {
            persistenceFailure = "Your changes weren't saved. Try again."
        }
        return saved
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
