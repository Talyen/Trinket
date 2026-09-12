import Foundation
import TrinketContent
import TrinketCore

public extension RewardSettlementInputs {
    init(save: PlayerSave, hero: Combatant, companion: Combatant, at date: Date = Date()) {
        var homestead = save.homestead
        homestead.settleProduction(at: date, roster: save.roster)
        self.init(
            gold: save.roster.gold,
            reservedGold: PlayerRosterState.reservedGold(from: homestead.pendingProduction),
            goldLimit: PlayerRosterState.maxGoldBalance,
            heroProgression: save.roster.progression(for: hero),
            companionProgression: save.roster.progression(for: companion),
            productionDate: homestead.lastProductionAt,
        )
    }
}

public extension RewardExperiencePolicy {
    static func encounterAward(encounterLevel: Int, roster: PlayerRosterState, percent: Int = 0) -> Int {
        encounterAward(
            encounterLevel: encounterLevel,
            hero: roster.progression(for: roster.activeHero), companion: roster.progression(for: roster.activeCompanion),
            percent: percent,
        )
    }

    static func sharedAward(_ amount: Int, roster: PlayerRosterState) -> Int {
        sharedAward(amount, hero: roster.progression(for: roster.activeHero), companion: roster.progression(for: roster.activeCompanion))
    }
}
