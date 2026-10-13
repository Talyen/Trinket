import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

extension TalentCatalogRoundTripTests {
    @Test(arguments: [UInt64(1), 2, 3, 4])
    func `loaded strike shares an attack roll without amplifying raw damage`(seed: UInt64) throws {
        let attack = Ability(
            id: "loaded-pair", name: "Physical Pair", tier: .basic,
            damageComponents: [DamageComponent(5), DamageComponent(5)], criticalChanceBonus: -1,
        )
        var battle = heroTalentBattle("wildcard_physical_t1_2", seed: seed)
        let events = try playHeroTalentCard(attack, in: &battle)
        let hits = events.filter { $0.kind == .abilityDamage }
        #expect(hits.count == 2)
        #expect(hits[0].amount == hits[1].amount)
        #expect([3, 10].contains(hits[0].amount))

        let raw = battle.resolveTestDamage(5, options: .reaction())
        #expect(raw.healthLost == 5)
        let periodic = battle.resolveDamage(.doTTick(
            amount: 5, target: battle.enemy, keyword: .physical, sourceActorID: battle.hero.id,
        ))
        #expect(periodic.healthLost == 5)
    }

    @Test func `loaded strike counterattack rolls independently of its parent action`() {
        var battle = heroTalentBattle("wildcard_physical_t1_2", seed: 7)
        var expectedRNG = battle.rng
        let parent = Bool.random(using: &expectedRNG)
        let counter = Bool.random(using: &expectedRNG)
        let action = BattleActionContext(actor: battle.hero, in: battle)
        battle.resolution.beginAction(action, origin: .ability)
        #expect(battle.resolution.loadedStrikeDouble(for: battle.hero.id, using: &battle.rng) == parent)
        battle.resolution.beginAction(action, origin: .counterattack)
        #expect(battle.resolution.loadedStrikeDouble(for: battle.hero.id, using: &battle.rng) == counter)
        battle.resolution.endAction()
        #expect(battle.resolution.loadedStrikeDouble(for: battle.hero.id, using: &battle.rng) == parent)
        battle.resolution.endAction()
        #expect(battle.rng.next() == expectedRNG.next())
    }

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
            let previous = battle.roster.combatant(for: battle.hero.id)?.talents.history.dodgeGrowth ?? 0
            let outcome = battle.resolveTestDamage(
                1,
                from: .enemy,
                to: .hero,
                options: DamageOperation.attack(scaling: .flat),
            )
            let growth = battle.roster.combatant(for: battle.hero.id)?.talents.history.dodgeGrowth ?? 0
            #expect(growth == (outcome.flags.contains(.dodged) ? 0 : previous + 5))
            #expect(outcome.healthLost == 0)
            exceededFive = exceededFive || growth > 5
            #expect(DamagePipeline.dodgeChance(for: battle.hero, attackerID: battle.enemy.id, in: battle) <= 0.75)
        }
        #expect(exceededFive)
        let before = battle.roster.combatant(for: battle.hero.id)?.talents.history.dodgeGrowth
        _ = battle.resolveTestDamage(
            1,
            from: .enemy,
            to: .hero,
            options: DamageOperation.attack(accuracy: .unavoidable),
        )
        #expect(battle.roster.combatant(for: battle.hero.id)?.talents.history.dodgeGrowth == before)
    }

    @Test func `blind spot refreshes and covers every physical hit of only the next owned card`() throws {
        var battle = heroTalentBattle("wildcard_dodge_t4_1")
        seedHeroTalentEffect(.shield(.block, 30), on: .enemy, in: &battle)
        for _ in 0 ..< 2 {
            seedHeroTalentEffect(.evadeNextHit, on: .hero, in: &battle)
            _ = battle.resolveTestDamage(1, from: .enemy, to: .hero)
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
