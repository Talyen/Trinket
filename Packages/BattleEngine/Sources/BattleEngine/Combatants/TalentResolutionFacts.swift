import TrinketContent
import TrinketCore

enum TalentPreparation: Hashable, Sendable {
    case bleedDamage
    case doublePoison
    case ignorePhysicalBlock
}

struct TalentActionFacts {
    var actorID: String
    var goldDamage = 0
    var blindingReduction = 0
    var burnAttackLeech = false
    var empoweredByMana = false
    var arcaneBurst = false
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
