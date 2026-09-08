public extension AppState {
    func synchronizePurchaseAccess() {
        playerSave.contentAccess = fullGame.ownership.access
        guard fullGame.ownership != .checking, fullGame.ownership != .unverified,
              !play.isGameplayActive else { return }
        if preparedContentAccess != playerSave.contentAccess {
            play.battleLaunch.keepPreparedRuns([])
            preparedContentAccess = playerSave.contentAccess
        }
        _ = playerSave.reconcileAccessibleParty()
    }
}
