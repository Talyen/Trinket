import TrinketContent

public extension PlayerRosterState {
    var eligibleRecruitEventIDs: [String] {
        eligibleRecruitEventIDs(access: .fullGame)
    }

    func eligibleRecruitEventIDs(access: ContentAccessPolicy) -> [String] {
        GameContent.recruitEvents.compactMap { event in
            guard let combatantID = event.unlockCombatantID,
                  access.allowsCombatant(combatantID),
                  !unlockedHeroIDs.contains(combatantID),
                  !unlockedCompanionIDs.contains(combatantID)
            else { return nil }
            return event.id
        }
    }
}
