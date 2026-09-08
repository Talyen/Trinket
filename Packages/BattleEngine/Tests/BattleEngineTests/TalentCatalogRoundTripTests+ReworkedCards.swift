import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

extension TalentCatalogRoundTripTests {
    @Test func `converted poison increases the existing hit without duplicating equipment bonuses`() throws {
        var profile = CombatantTalentCatalog.profile(for: ["alchemist_poison_t4_1"])
        profile.damageDealtBonus[.poison] = 3
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleStateTestFactory.makeBattleWithAbilities(heroModifiers: profile, dealOpeningHand: false)
        battle.appliesFightPacing = false
        seedHeroTalentEffect(.poison(7), on: .hero, in: &battle, source: .enemy)
        let events = try playHeroTalentCard(.causticJab, in: &battle)
        #expect(events.filter { $0.kind == .abilityDamage }.map(\.amount) == [11])
        #expect(talentPoints(.poison, on: .enemy, in: battle) == 8)
        #expect(talentPoints(.poison, on: .hero, in: battle) == 0)
    }

    @Test(arguments: [Ability.steal, .bountyShot, .blackjack, .tithe])
    func `authored theft cards preserve gilded claws through outcome resolution`(ability: Ability) throws {
        var battle = capstoneBattle(companion: ["lizard_scout_gold_t3_2"])
        var stolen = 0
        for _ in 0 ..< 8 {
            seedHeroTalentEffect(.controlMeter(.stun, 40, 40), on: .enemy, in: &battle)
            seedHeroTalentEffect(.marked(3, 6), on: .enemy, in: &battle)
            let events = try playHeroTalentCard(ability, owner: .companion, in: &battle)
            stolen = events.filter { $0.effectKind == .resourceGain && $0.keyword == .gold }.reduce(0) { $0 + $1.amount }
            if stolen > 0 {
                break
            }
        }
        #expect(stolen > 0)
        #expect(battle.heroTalents.history[battle.companion.id]?.stolenGoldDamage == stolen)
        ActiveEffectMutation.removeMatching(from: battle.enemy, in: &battle) { $0.kind == .marked }
        let next = try playHeroTalentCard(.stab, owner: .companion, in: &battle)
        let hit = try #require(next.first { $0.kind == .abilityDamage && $0.keyword == .physical })
        #expect(hit.amount == (2 + stolen) * (hit.isCritical ? 2 : 1))
    }

    @Test func `critical gold rolls once per card and theft does not trigger attack critical rewards`() throws {
        var outcomes: Set<Bool> = []
        let goldCard = Ability(id: "two-gold-gains", name: "Two Gold Gains", tier: .skill, targetedEffects: [
            TargetedEffect(.resourceGain(.gold, 1)), TargetedEffect(.resourceGain(.gold, 3)),
        ], stealsGold: true)
        for seed in UInt64(1) ... 48 {
            var battle = heroTalentBattle("wildcard_gold_t3_2", "lizard_scout_gold_t3_2", "rogue_gold_t4_1", seed: seed)
            var expectedRNG = battle.rng
            let chance = CriticalChanceEngine.chance(actorID: battle.hero.id, defender: battle.enemy, in: battle)
            let critical = BattleChance.succeeds(probability: chance, using: &expectedRNG)
            let events = try playHeroTalentCard(goldCard, in: &battle)
            let gold = events.filter { $0.effectKind == .resourceGain && $0.keyword == .gold }
            #expect(gold.map(\.isCritical) == [critical, critical])
            #expect(gold.map(\.amount) == (critical ? [2, 6] : [1, 3]))
            #expect(battle.heroTalents.history[battle.hero.id]?.stolenGoldDamage == battle.gold)
            #expect(!events.contains { $0.abilityName == "Bounty Blade" })
            #expect(battle.rng.next() == expectedRNG.next())
            outcomes.insert(critical)
        }
        #expect(outcomes == [false, true])
    }

    @Test func `improving odds grows on connected dodgeable attacks including block and resets on dodge`() {
        var battle = heroTalentBattle("wildcard_dodge_t3_2")
        seedHeroTalentEffect(.shield(.block, 1000), on: .hero, in: &battle)
        var exceededFive = false
        for _ in 0 ..< 60 {
            let previous = battle.heroTalents.history[battle.hero.id]?.dodgeGrowth ?? 0
            let outcome = battle.resolveDamage(DamageRequest(
                amount: 1, target: battle.hero, keyword: .physical, sourceActorID: battle.enemy.id,
                options: DamageOptions(applyStatBonus: false, applyItemBonus: false, isAttackHit: true),
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
            options: DamageOptions(applyDodge: false, isAttackHit: true),
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

    @Test func `unstable culture rewards natural enemy poison expiry without accumulating multipliers`() throws {
        var battle = heroTalentBattle("alchemist_poison_t3_2")
        for _ in 0 ..< 2 {
            seedHeroTalentEffect(.poison(1), on: .enemy, in: &battle)
            _ = EffectTurnEngine.advanceAll(context: &battle)
        }
        try playHeroTalentCard(.causticJab, in: &battle)
        #expect(talentPoints(.poison, on: .enemy, in: battle) == 2)
        try playHeroTalentCard(.causticJab, in: &battle)
        #expect(talentPoints(.poison, on: .enemy, in: battle) == 3)
        let cleanseEnemy = Ability(id: "enemy-cleanse", name: "Cleanse Enemy", tier: .skill, targetedEffects: [
            TargetedEffect(.cleanse(.poison), target: .enemy),
        ])
        try playHeroTalentCard(cleanseEnemy, in: &battle)
        try playHeroTalentCard(.causticJab, in: &battle)
        #expect(talentPoints(.poison, on: .enemy, in: battle) == 1)
        ActiveEffectMutation.removeMatching(from: battle.enemy, in: &battle) { $0.kind == .poison }
        seedHeroTalentEffect(.poison(1), on: .hero, in: &battle)
        _ = EffectTurnEngine.advanceAll(context: &battle)
        try playHeroTalentCard(.causticJab, in: &battle)
        #expect(talentPoints(.poison, on: .enemy, in: battle) == 1)
    }

    @Test func `a cleansing attack cannot consume its own perfect purity even when replayed`() throws {
        var battle = heroTalentBattle("alchemist_cleanse_t4_1", "wizard_mana_t3_2")
        seedHeroTalentEffect(.poison(2), on: .hero, in: &battle, source: .enemy)
        let cleansingHit = Ability(
            id: "cleansing-hit", name: "Cleansing Hit", tier: .skill,
            damageComponents: [DamageComponent(1)],
            targetedEffects: [TargetedEffect(.cleanse(nil), target: .actor)],
        )
        let repeated = try playHeroTalentCard(cleansingHit, in: &battle)
        #expect(repeated.count { $0.kind == .abilityDamage && $0.keyword == .physical } == 2)
        #expect(!repeated.contains { $0.kind == .abilityDamage && $0.keyword == .poison })
        let next = try playHeroTalentCard(.stab, in: &battle)
        #expect(next.count { $0.kind == .abilityDamage && $0.keyword == .poison } == 1)
        #expect(talentPoints(.poison, on: .enemy, in: battle) == 2)
    }
}
