import BattleEngine
import Testing
import TrinketContent
import TrinketCore

struct BattleOpeningHandTests {
    @Test func `opening hand uses shuffled tiers and one copy per loadout ability`() {
        var observedTiers: Set<AbilityTier> = []
        for seed: UInt64 in 0 ..< 12 {
            let battle = BattleStateTestFactory.makeBattleWithAbilities(
                heroAbilities: [.maul, .smite, .hemorrhage],
                companionAbilities: [.bash, .serratedEdge, .bloodthorn],
                rngSeed: seed,
            )
            #expect(battle.hand.count == 3)
            #expect(battle.hand.buffer.isEmpty)
            #expect(battle.hand.cards.map(\.owner) == [.hero, .companion, .hero])
            observedTiers.formUnion(battle.hand.cards.map(\.ability.tier))
            let heroCards = battle.heroDeck.abilities + battle.hand.cards.filter { $0.owner == .hero }.map(\.ability)
            let companionCards = battle.companionDeck.abilities + battle.hand.cards.filter { $0.owner == .companion }.map(\.ability)
            #expect(Set(heroCards.map(\.id)) == Set([Ability.maul.id, Ability.smite.id, Ability.hemorrhage.id]))
            #expect(heroCards.count == 3)
            #expect(companionCards.count == 3)
            if observedTiers == [.basic, .skill, .ultimate] {
                break
            }
        }
        #expect(observedTiers == [.basic, .skill, .ultimate])
    }
}
