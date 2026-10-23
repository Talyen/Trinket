import TrinketContent

@MainActor
public extension PlayerSaveStore {
    /// Called only after runtime installation succeeds. Its source capability is
    /// generation-bound; quiet retries never hold up card input.
    func recordBattleEncounter(_ claim: BattleRewardClaim) {
        guard let enemyID = claim.enemyID, claim.isCurrent(in: self),
              library.isReadable, !library.progress.encounteredEnemyIDs.contains(enemyID) else { return }
        performSaveAction(key: "library-encounter-\(enemyID)") { [weak self] _ in
            guard let self, claim.isCurrent(in: self), library.isReadable else { return SaveActionAttempt(()) }
            let result: SaveTransactionResult<Void, Never> = persistTransaction(logging: "Failed to record enemy discovery") { save in
                save.library.encounter(enemyID)
                return .success(())
            }
            return SaveActionAttempt((), failure: result.persistenceError)
        }
    }
}
