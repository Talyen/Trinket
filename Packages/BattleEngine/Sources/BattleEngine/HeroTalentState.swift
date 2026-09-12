import TrinketContent
import TrinketCore

enum TalentPreparation: Hashable {
    case bleedDamage
    case poisonDamage
    case doublePoison
    case ignorePhysicalBlock
    case stealGold
}

struct TalentActionFacts {
    var actorID: String
    var goldDamage = 0
    var blindingReduction = 0
}

struct HeroTalentCardFacts {
    var actorID: String
    var tier: AbilityTier
    var playSerial = 0
    var previousDamageKeywords: Set<Keyword> = []
    var removedDebuffs = 0
    var restoredHealth = false
    var restoredMana = false
    var grantedGold = false
    var preparedHeal = false
    var preparations: Set<TalentPreparation> = []
    var capturedPreparations = false
    var gildedDamage = 0
    var criticalGold: Bool?
}

struct HeroTalentHistory {
    var lastPlaySerial = -1
    var lastDamageKeywords: Set<Keyword> = []
    var lastGrantedGold = false
    var tiers: Set<AbilityTier> = []
    var playedStun = false
    var spentMana = false
    var preparedHeal = false
    var preparedGold = false
    var preparedPhysical = false
    var preparations: Set<TalentPreparation> = []
    var stolenGoldDamage = 0
    var blindingReduction = 0
    var dodgeGrowth = 0
    var falseOpening = false
}

struct HeroTalentState {
    var history: [String: HeroTalentHistory] = [:]
    var enemyTurnActive = false
    var healthLostDuringEnemyTurn: Set<String> = []
    var attackedDuringEnemyTurn: Set<String> = []
}
