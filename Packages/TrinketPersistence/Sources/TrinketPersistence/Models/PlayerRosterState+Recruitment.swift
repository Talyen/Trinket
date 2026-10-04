import TrinketContent

public extension PlayerRosterState {
    var eligibleRecruitEventIDs: [String] {
        eligibleRecruitEventIDs(access: .fullGame)
    }

    func eligibleRecruitEventIDs(access: ContentAccessPolicy) -> [String] {
        GameContent.eligibleRecruitEvents(
            unlockedHeroIDs: unlockedHeroIDs, unlockedCompanionIDs: unlockedCompanionIDs, access: access,
        ).map(\.id)
    }
}
