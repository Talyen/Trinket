import Foundation
import TrinketContent
import TrinketCore

public enum TalentUnlockResult: Equatable, Sendable {
    case unlocked
    case unavailable
    case persistenceFailed
}

@MainActor
public extension PlayerSaveStore {
    @discardableResult
    func confirmStarterHero(_ heroID: String) -> Bool {
        guard starterSelection.phase != .complete,
              GameContent.starterHeroIDs.contains(heroID)
        else { return false }
        return persistBatch(logging: "Failed to save starter Hero") { save in
            save.starterSelection = StarterSelectionState(
                phase: .chooseCompanion,
                heroID: heroID
            )
        }
    }

    @discardableResult
    func completeStarterSelection(companionID: String) -> Bool {
        let selection = starterSelection
        guard selection.phase == .chooseCompanion,
              let heroID = selection.heroID,
              GameContent.starterHeroIDs.contains(heroID),
              GameContent.starterCompanionIDs.contains(companionID)
        else { return false }

        return persistBatch(logging: "Failed to save starter party") { save in
            save.roster = PlayerRosterState(
                activeHeroID: heroID,
                activeCompanionID: companionID,
                unlockedHeroIDs: [heroID],
                unlockedCompanionIDs: [companionID],
                abilityLoadouts: [:],
                progressions: [heroID: .initial, companionID: .initial],
                equipmentLoadouts: [:],
                unlockedTalents: [:],
                gold: save.roster.gold
            )
            save.starterSelection = .complete
        }
    }

    @discardableResult
    func mutateRoster(
        logging message: String = "Failed to persist roster edits",
        _ update: (inout PlayerRosterState) -> Void
    ) -> Bool {
        persistBatch(logging: message) { save in
            var roster = save.roster
            update(&roster)
            save.roster = roster
        }
    }

    func unlockTalent(
        nodeID: String,
        treeID: String,
        for combatantID: String
    ) -> TalentUnlockResult {
        guard let config = CombatantTalentCatalog.allConfigs[combatantID],
              let tree = config.trees.first(where: { $0.id == treeID }),
              let node = tree.nodes.first(where: { $0.id == nodeID })
        else { return .unavailable }

        let unlocked = roster.unlockedTalents(for: combatantID)
        let points = roster.availableTalentPoints(for: combatantID)
        guard tree.canUnlock(
            node: node,
            unlockedNodeIDs: unlocked,
            availablePoints: points
        ) else { return .unavailable }

        let persisted = mutateRoster(logging: "Failed to unlock talent") { roster in
            _ = roster.unlockTalent(
                node: node,
                inTree: tree,
                for: combatantID
            )
        }
        return persisted ? .unlocked : .persistenceFailed
    }

    @discardableResult
    func setInventoryItems(_ items: [InventoryItem]) -> Bool {
        persistBatch(logging: "Failed to persist inventory edits") { save in
            var inventory = save.inventory
            inventory.items = items
            save.inventory = inventory
        }
    }
}
