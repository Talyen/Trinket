public extension AppState {
    func synchronizePurchaseAccess() {
        guard fullGame.ownership != .checking, fullGame.ownership != .unverified,
              !play.isGameplayActive else { return }
        playerSave.contentAccess = fullGame.ownership.access
        if preparedContentAccess != playerSave.contentAccess {
            play.battleLaunch.keepPreparedRuns([])
            preparedContentAccess = playerSave.contentAccess
        }
        _ = playerSave.reconcileAccessibleParty()
    }
}
