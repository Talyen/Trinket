public extension AppState {
    /// Reconciles the StoreKit ownership snapshot into the player save.
    /// Called by the app shell (content views and the app entry point) after
    /// purchase, restoration, or foregrounding — never from within a battle or
    /// encounter flow. Reconciliation is deferred while gameplay is active, and
    /// prepared battles are dropped when access changes since warms may
    /// reference newly locked content; activation re-checks access and fails
    /// closed regardless.
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
