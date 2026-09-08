import TrinketContent

@MainActor
public extension PlayerSaveStore {
    @discardableResult
    func reconcileAccessibleParty() -> Bool {
        guard starterSelection.phase == .complete else { return true }
        let policy = contentAccess
        let heroAllowed = policy.allowsCombatant(roster.activeHeroID)
        let companionAllowed = policy.allowsCombatant(roster.activeCompanionID)
        guard !heroAllowed || !companionAllowed else { return true }
        return mutateRoster(logging: "Failed to preserve an accessible party") { roster in
            if !heroAllowed {
                let id = roster.heroes.first { policy.allowsCombatant($0.id) }?.id ?? PlayerRosterState.starterHeroID
                _ = roster.unlockHero(id: id)
                roster.activeHeroID = id
            }
            if !companionAllowed {
                let id = roster.companions.first { policy.allowsCombatant($0.id) }?.id ?? PlayerRosterState.starterCompanionID
                _ = roster.unlockCompanion(id: id)
                roster.activeCompanionID = id
            }
        }
    }
}
