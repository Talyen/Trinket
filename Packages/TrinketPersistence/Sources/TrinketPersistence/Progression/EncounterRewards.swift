import TrinketContent
import TrinketCore

/// Completion has one payout authority: the battle's settled reveal, or an
/// encounter reward resolved against the current save. Settled rewards never
/// enter loot generation or apply current bonuses a second time.
enum EncounterRewards {
    case settled(BattleRewardSettlement, encounterLevel: Int)
    case unsettled(EncounterRewardOverrides)

    func encounterLevel(or fallback: @autoclosure () -> Int) -> Int {
        switch self {
        case let .settled(_, level): level
        case let .unsettled(overrides): overrides.enemyEncounterLevel ?? fallback()
        }
    }

    func resolve(generating: (EncounterRewardOverrides) -> BattleRewardSettlement) -> BattleRewardSettlement {
        switch self {
        case let .settled(award, _): award
        case let .unsettled(overrides): generating(overrides)
        }
    }
}

/// Overrides belong only to encounters without a settled battle award.
struct EncounterRewardOverrides {
    var battleGold = BattleGoldFlow()
    var materialRewards: [ResourceAmount]?
    var rewardItem: InventoryItem?
    var loot: BattleLootResult?
    var enemyEncounterLevel: Int?
}
