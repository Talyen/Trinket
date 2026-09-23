import TrinketContent
import TrinketCore

enum TalentPreparation: Hashable {
    case bleedDamage
    case doublePoison
    case ignorePhysicalBlock
}

struct TalentActionFacts {
    var actorID: String
    var goldDamage = 0
    var blindingReduction = 0
}

package struct HeroTalentCardFacts {
    var actorID: String
    var playSerial = 0
    var didCriticalHit = false
    var standardDeviationDouble: Bool?
    var preparations: Set<TalentPreparation> = []
    var capturedPreparations = false
    var gildedDamage = 0
}

struct HeroTalentHistory {
    var spentMana = false
    var preparations: Set<TalentPreparation> = []
    var stolenGoldDamage = 0
    var blindingReduction = 0
    var dodgeGrowth = 0
}

struct HeroTalentState {
    var history: [String: HeroTalentHistory] = [:]
}
