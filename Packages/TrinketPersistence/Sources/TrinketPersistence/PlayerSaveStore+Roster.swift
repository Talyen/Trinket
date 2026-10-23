import Foundation
import TrinketContent
import TrinketCore

@MainActor
public extension PlayerSaveStore {
    @discardableResult
    func confirmStarterHero(_ heroID: String) -> SaveActionAttempt<Bool> {
        guard contentAccess.allowsCombatant(heroID),
              starterSelection.phase != .complete,
              GameContent.hero(matching: heroID) != nil
        else { return SaveActionAttempt(false) }
        return persistBatch(logging: "Failed to save starter Hero") { save in
            save.starterSelection = StarterSelectionState(
                phase: .chooseCompanion,
                heroID: heroID,
            )
        }
    }

    @discardableResult
    func completeStarterSelection(companionID: String) -> SaveActionAttempt<Bool> {
        let selection = starterSelection
        guard selection.phase == .chooseCompanion,
              let heroID = selection.heroID,
              contentAccess.allowsCombatant(heroID),
              contentAccess.allowsCombatant(companionID),
              GameContent.hero(matching: heroID) != nil,
              GameContent.companion(matching: companionID) != nil
        else { return SaveActionAttempt(false) }

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
    internal func mutateRoster(
        logging message: String = "Failed to persist roster edits",
        _ update: (inout PlayerRosterState) -> Void,
    ) -> SaveActionAttempt<Bool> {
        persistBatch(logging: message) { save in
            update(&save.roster)
        }
    }

    func unlockTalent(
        nodeID: String,
        treeID: String,
        for combatantID: String,
    ) -> SaveActionAttempt<RosterEditResult> {
        persistRosterEdit(logging: "Failed to unlock talent") { save in
            save.roster.applyTalentUnlock(nodeID: nodeID, treeID: treeID, for: combatantID, access: contentAccess)
        }
    }
}

@MainActor
extension PlayerSaveStore {
    private enum RosterEditRejection: Error {
        case unavailable
    }

    /// Rejections discard the candidate before graph/journal writes; only refused
    /// durable commits are retryable. Every interactive roster command uses this path.
    func persistRosterEdit(logging message: String, _ edit: (inout PlayerSave) -> Bool) -> SaveActionAttempt<RosterEditResult> {
        let result: SaveTransactionResult<Void, RosterEditRejection> = persistTransaction(logging: message) { save in
            edit(&save) ? .success(()) : .failure(.unavailable)
        }
        switch result {
        case .committed: return SaveActionAttempt(.committed)
        case .rejected: return SaveActionAttempt(.unavailable)
        case let .persistFailed(error): return SaveActionAttempt(.persistenceFailed, failure: error)
        }
    }
}
