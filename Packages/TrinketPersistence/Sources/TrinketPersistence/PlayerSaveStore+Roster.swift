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
        guard contentAccess.allowsCombatant(heroID),
              starterSelection.phase != .complete,
              GameContent.hero(matching: heroID) != nil
        else { return false }
        return persistBatch(logging: "Failed to save starter Hero") { save in
            save.starterSelection = StarterSelectionState(
                phase: .chooseCompanion,
                heroID: heroID,
            )
        }
    }

    @discardableResult
    func completeStarterSelection(companionID: String) -> Bool {
        let selection = starterSelection
        guard selection.phase == .chooseCompanion,
              let heroID = selection.heroID,
              contentAccess.allowsCombatant(heroID),
              contentAccess.allowsCombatant(companionID),
              GameContent.hero(matching: heroID) != nil,
              GameContent.companion(matching: companionID) != nil
        else { return false }

        return persistBatch(logging: "Failed to save starter party") { save in
            let previous = save.roster
            save.roster = PlayerRosterState(
                activeHeroID: heroID,
                activeCompanionID: companionID,
                unlockedHeroIDs: [heroID],
                unlockedCompanionIDs: [companionID],
                abilityLoadouts: previous.abilityLoadouts.filter { $0.key == heroID || $0.key == companionID },
                progressions: [heroID: .initial, companionID: .initial],
                equipmentLoadouts: previous.equipmentLoadouts.filter { $0.key == heroID || $0.key == companionID },
                unlockedTalents: previous.unlockedTalents.filter { $0.key == heroID || $0.key == companionID },
                gold: previous.gold,
            )
            save.starterSelection = .complete
        }
    }

    @discardableResult
    func mutateRoster(
        logging message: String = "Failed to persist roster edits",
        _ update: (inout PlayerRosterState) -> Void,
    ) -> Bool {
        persistBatch(logging: message) { save in
            update(&save.roster)
        }
    }

    func unlockTalent(
        nodeID: String,
        treeID: String,
        for combatantID: String,
    ) -> TalentUnlockResult {
        guard let config = CombatantTalentCatalog.configIfAvailable(for: combatantID),
              let tree = config.tree(matching: treeID),
              let node = tree.node(matching: nodeID)
        else { return .unavailable }

        let unlocked = roster.unlockedTalents(for: combatantID)
        let points = roster.availableTalentPoints(for: combatantID)
        guard tree.canUnlock(
            node: node,
            unlockedNodeIDs: unlocked,
            availablePoints: points,
        ) else { return .unavailable }

        let persisted = mutateRoster(logging: "Failed to unlock talent") { roster in
            _ = roster.unlockTalent(
                node: node,
                inTree: tree,
                for: combatantID,
            )
        }
        return persisted ? .unlocked : .persistenceFailed
    }
}
