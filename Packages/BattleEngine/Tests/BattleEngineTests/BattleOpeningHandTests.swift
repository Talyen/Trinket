import BattleEngine
import Testing
import TrinketContent
import TrinketCore

struct BattleOpeningHandTests {
    private func makeBattle(
        heroAbilities: [Ability],
        companionAbilities: [Ability],
        rngSeed: UInt64
    ) -> BattleState {
        BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: heroAbilities,
            companionAbilities: companionAbilities,
            rngSeed: rngSeed
        )
    }

    @Test func openingHandGuaranteesBasicPerOwnerPlusOneSkill() throws {
        var skillOwners: Set<BattleParticipant> = []
        for seed: UInt64 in 0 ..< 24 {
            let battle = makeBattle(
                heroAbilities: [.maul, .smite, .hemorrhage],
                companionAbilities: [.bash, .serratedEdge, .bloodthorn],
                rngSeed: seed
            )
            #expect(battle.hand.count == BattleHand.maxSize)
            try #expect(battle.handBuffer.isEmpty)

            let heroBasics = battle.hand.cards.filter { $0.owner == .hero && $0.ability.tier == .basic }
            let companionBasics = battle.hand.cards.filter { $0.owner == .companion && $0.ability.tier == .basic }
            try #expect(heroBasics.count == 1)
            try #expect(companionBasics.count == 1)

            let skills = battle.hand.cards.filter { $0.ability.tier == .skill }
            try #expect(skills.count == 1)
            try skillOwners.insert(#require(skills.first?.owner))

            let heroHandCount = battle.hand.cards.count(where: { $0.owner == .hero })
            let companionHandCount = battle.hand.cards.count(where: { $0.owner == .companion })
            try #expect(battle.heroDeck.count == 3 - heroHandCount)
            try #expect(battle.companionDeck.count == 3 - companionHandCount)
        }
        try #expect(skillOwners == [.hero, .companion])
    }
}
