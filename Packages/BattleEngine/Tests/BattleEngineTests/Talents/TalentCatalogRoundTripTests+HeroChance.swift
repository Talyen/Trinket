import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

extension TalentCatalogRoundTripTests {
    @Test func `prismatic edge gets one chance across all hits of a card`() throws {
        let attack = Ability(
            id: "prismatic-pair",
            name: "Physical Pair",
            tier: .basic,
            damageComponents: [DamageComponent(1), DamageComponent(1)],
            criticalChanceBonus: -1,
        )
        for seed in UInt64(1) ... 16 {
            var battle = heroTalentBattle("wildcard_physical_t1_1", seed: seed)
            var expectedRNG = battle.rng
            let succeeds = BattleChance.succeeds(probability: 0.10, using: &expectedRNG)
            if succeeds {
                _ = Bool.random(using: &expectedRNG)
            }
            let before = battle.roster.enemy.currentHealth
            try playHeroTalentCard(attack, in: &battle)
            #expect(before - battle.roster.enemy.currentHealth == 2 + (succeeds ? 3 : 0))
            #expect(battle.rng.next() == expectedRNG.next())
        }
    }

    @Test func `root passage ignores enemy block on every poison component`() throws {
        var battle = heroTalentBattle("druid_poison_t3_1")
        seedHeroTalentEffect(.shield(.block, 1), on: .enemy, in: &battle)
        let hits = Ability(
            id: "test-two-poisons",
            name: "Two Poisons",
            tier: .basic,
            damageComponents: [DamageComponent(1, keyword: .poison), DamageComponent(1, keyword: .poison)],
        )
        let events = try playHeroTalentCard(hits, in: &battle)
        let original = events.filter { $0.kind == .abilityDamage }
        #expect(original[0].amount == (original[0].isCritical ? 2 : 1))
        #expect(original[1].amount == (original[1].isCritical ? 2 : 1))
        #expect(talentPoints(.shield, on: .enemy, in: battle) == 1)
    }

    @Test func `improving odds grows on connected dodgeable attacks including block and resets on dodge`() {
        var battle = heroTalentBattle("wildcard_dodge_t3_2")
        seedHeroTalentEffect(.shield(.block, 1000), on: .hero, in: &battle)
        var exceededFive = false
        for _ in 0 ..< 60 {
            let previous = battle.heroTalents.history[battle.hero.id]?.dodgeGrowth ?? 0
            let outcome = battle.resolveDamage(DamageRequest(
                amount: 1, target: battle.hero, keyword: .physical, sourceActorID: battle.enemy.id,
                options: DamageOperation.attack(tier: .skill, scaling: .flat, accuracy: .normal),
            ))
            let growth = battle.heroTalents.history[battle.hero.id]?.dodgeGrowth ?? 0
            #expect(growth == (outcome.flags.contains(.dodged) ? 0 : previous + 5))
            #expect(outcome.healthLost == 0)
            exceededFive = exceededFive || growth > 5
            #expect(DamagePipeline.dodgeChance(for: battle.hero, attackerID: battle.enemy.id, in: battle) <= 0.75)
        }
        #expect(exceededFive)
        let before = battle.heroTalents.history[battle.hero.id]?.dodgeGrowth
        _ = battle.resolveDamage(DamageRequest(
            amount: 1, target: battle.hero, keyword: .physical, sourceActorID: battle.enemy.id,
            options: DamageOperation.attack(tier: .skill, scaling: .statsAndItems, accuracy: .unavoidable),
        ))
        #expect(battle.heroTalents.history[battle.hero.id]?.dodgeGrowth == before)
    }

    @Test func `blind spot refreshes and covers every physical hit of only the next owned card`() throws {
        var battle = heroTalentBattle("wildcard_dodge_t4_1")
        seedHeroTalentEffect(.shield(.block, 30), on: .enemy, in: &battle)
        for _ in 0 ..< 2 {
            seedHeroTalentEffect(.evadeNextHit, on: .hero, in: &battle)
            _ = battle.resolveDamage(DamageRequest(amount: 1, target: battle.hero, keyword: .physical, sourceActorID: battle.enemy.id))
        }
        try playHeroTalentCard(.block, in: &battle)
        try playHeroTalentCard(.stab, owner: .companion, in: &battle)
        let block = talentPoints(.shield, on: .enemy, in: battle)
        let doubleHit = Ability(
            id: "physical-pair",
            name: "Physical Pair",
            tier: .basic,
            damageComponents: [DamageComponent(1), DamageComponent(1)],
        )
        let events = try playHeroTalentCard(doubleHit, in: &battle)
        #expect(events.filter { $0.kind == .abilityDamage }.allSatisfy { $0.amount > 0 })
        #expect(talentPoints(.shield, on: .enemy, in: battle) == block)
        try playHeroTalentCard(.stab, in: &battle)
        #expect(talentPoints(.shield, on: .enemy, in: battle) < block)
    }
}
