import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

extension TalentCatalogRoundTripTests {
    @Test func `random non damage rewards do not treat blocked damage or critical rolls as random`() throws {
        let nonDamage = Ability(
            id: "test-random-block",
            name: "Random Block",
            tier: .basic,
            outcomeBranches: [AbilityOutcomeBranch(effects: [.shield(.block, 1)])],
        )
        var battle = heroTalentBattle("wildcard_gold_t1_1", "wildcard_dodge_t1_1")
        try playHeroTalentCard(.block, in: &battle)
        #expect(battle.gold == 0)
        seedHeroTalentEffect(.shield(.block, 20), on: .enemy, in: &battle)
        try playHeroTalentCard(.cinderbloom, in: &battle)
        #expect(battle.gold == 0)
        try playHeroTalentCard(nonDamage, in: &battle)
        try playHeroTalentCard(nonDamage, in: &battle)
        #expect(battle.gold == 1)
        let hit = DamageResolutionState(
            amount: 1,
            combatant: battle.hero,
            sourceActorID: battle.enemy.id,
            damageKeyword: .physical,
            options: .directAbilityHit,
        )
        #expect(abs(DamagePipeline.dodgeChance(for: hit, in: battle) - 0.15) < 0.0001)
        battle.turnCount += 1
        _ = CombatTriggerEngine.startHeroTalentTurn(in: &battle)
        #expect(DamagePipeline.dodgeChance(for: hit, in: battle) == 0.10)
    }

    @Test func `house credit waits for A new card and improvised assault adds one physical point`() throws {
        var battle = heroTalentBattle("wildcard_gold_t1_2", "wildcard_physical_t1_2")
        let mixed = Ability(id: "test-random-mixed", name: "Random Mixture", tier: .skill, outcomeBranches: [
            AbilityOutcomeBranch(damageComponents: [DamageComponent(1, keyword: .holy)], effects: [.resourceGain(.gold, 1)]),
        ])
        try playHeroTalentCard(mixed, in: &battle)
        #expect(battle.gold == 1)
        try playHeroTalentCard(heroTalentGoldCard, in: &battle)
        #expect(battle.gold == 3)
        try playHeroTalentCard(heroTalentGoldCard, in: &battle)
        #expect(battle.gold == 4)
        let hits = Ability(
            id: "test-multiple-physical",
            name: "Two Hits",
            tier: .basic,
            damageComponents: [DamageComponent(1, keyword: .physical), DamageComponent(1, keyword: .physical)],
        )
        let events = try playHeroTalentCard(hits, in: &battle)
        let original = events.filter { $0.kind == .abilityDamage }
        #expect(original.count == 2)
        #expect(original[0].amount == (original[0].isCritical ? 2 : 1) + 1)
        #expect(original[1].amount == (original[1].isCritical ? 2 : 1))
    }

    @Test(arguments: ["alchemist_poison_t3_2", "wildcard_physical_t1_1"])
    func `typed chance rewards roll once and damage only the new point`(talent: String) throws {
        var successes = 0
        var freezeCount = 0
        for seed in UInt64(1) ... 48 {
            let ability: Ability = talent.hasPrefix("alchemist") ? .poisonDagger : .slash
            var baseline = heroTalentBattle(seed: seed)
            var enhanced = heroTalentBattle(talent, seed: seed)
            seedHeroTalentEffect(.burn(10), on: .enemy, in: &baseline)
            seedHeroTalentEffect(.burn(10), on: .enemy, in: &enhanced)
            try playHeroTalentCard(ability, in: &baseline)
            var expectedRNG = baseline.rng
            let expected = BattleChance.succeeds(probability: 0.25, using: &expectedRNG)
            let expectedFreeze = expected && talent.hasPrefix("wildcard") && !Bool.random(using: &expectedRNG)
            try playHeroTalentCard(ability, in: &enhanced)
            #expect(baseline.roster.enemy.currentHealth - enhanced.roster.enemy.currentHealth == (expected ? 1 : 0))
            #expect(talentPoints(.burn, on: .enemy, in: enhanced) == (expected && !expectedFreeze ? 11 : 10))
            if expected {
                successes += 1
            }
            if expectedFreeze {
                freezeCount += 1
            }
        }
        #expect(successes > 0 && successes < 48)
        if talent.hasPrefix("wildcard") {
            #expect(freezeCount > 0 && freezeCount < successes)
        }
    }

    @Test(arguments: [true, false])
    func `lucky break chooses equally among eligible outcomes`(needsHealth: Bool) throws {
        let skill = Ability(id: "test-empty-skill", name: "Empty Skill", tier: .skill)
        var outcomes: Set<String> = []
        for seed in UInt64(1) ... 32 {
            var battle = heroTalentBattle("wildcard_gold_t4_1", seed: seed)
            if needsHealth {
                battle.roster.mutateRuntime(for: battle.hero) { $0.currentHealth = 1 }
            }
            var expectedRNG = battle.rng
            let expected = Int.random(in: 0 ..< (needsHealth ? 3 : 2), using: &expectedRNG)
            let health = battle.roster.hero.currentHealth
            try playHeroTalentCard(skill, in: &battle)
            #expect(battle.gold == (expected == 0 ? 1 : 0))
            #expect(talentPoints(.shield, on: .hero, in: battle) == (expected == 1 ? 1 : 0))
            #expect(battle.roster.hero.currentHealth - health == (expected == 2 ? 1 : 0))
            outcomes.insert(String(expected))
            let after = (battle.gold, battle.roster.hero.currentHealth, talentPoints(.shield, on: .hero, in: battle))
            try playHeroTalentCard(skill, in: &battle)
            #expect(battle.gold == after.0 && battle.roster.hero.currentHealth == after.1)
            #expect(talentPoints(.shield, on: .hero, in: battle) == after.2)
        }
        #expect(outcomes.count == (needsHealth ? 3 : 2))
    }

    @Test func `dodges reward both owners without reactions triggering more rewards`() {
        var battle = heroTalentBattle("wildcard_dodge_t2_1", "wildcard_dodge_t2_2", "wildcard_dodge_t4_1")
        battle.roster.mutateRuntime(for: battle.companion) { $0.currentHealth = 1 }
        seedHeroTalentEffect(.shield(.block, 2), on: .enemy, in: &battle)
        for _ in 0 ..< 2 {
            seedHeroTalentEffect(.evadeNextHit, on: .hero, in: &battle)
            _ = battle.resolveDamage(DamageRequest(amount: 1, target: battle.hero, keyword: .physical, sourceActorID: battle.enemy.id))
            seedHeroTalentEffect(.evadeNextHit, on: .companion, in: &battle)
            _ = battle.resolveDamage(DamageRequest(amount: 1, target: battle.companion, keyword: .physical, sourceActorID: battle.enemy.id))
        }
        #expect(battle.roster.companion.currentHealth == 2)
        #expect(talentPoints(.thorns, on: .hero, in: battle) == 1)
        #expect(talentPoints(.shield, on: .enemy, in: battle) == 1)
    }

    @Test func `physical critical and frozen hits have separate once per turn rewards`() throws {
        var battle = heroTalentBattle("wildcard_dodge_t3_1", "wildcard_physical_t2_1", "wildcard_physical_t3_1")
        battle.roster.mutateRuntime(for: battle.hero) { $0.currentHealth = 1 }
        seedHeroTalentEffect(.burn(2), on: .hero, in: &battle)
        seedHeroTalentEffect(.poison(2), on: .hero, in: &battle)
        seedHeroTalentEffect(.controlMeter(.freeze, 20, 20), on: .enemy, in: &battle)
        seedHeroTalentEffect(.nextStrikeCritical, on: .hero, in: &battle)
        try playHeroTalentCard(heroTalentPhysicalCard, in: &battle)
        #expect(talentPoints(.burn, on: .hero, in: battle) == 1)
        #expect(talentPoints(.poison, on: .hero, in: battle) == 1)
        #expect(battle.roster.hero.currentHealth == 2)
        seedHeroTalentEffect(.nextStrikeCritical, on: .hero, in: &battle)
        try playHeroTalentCard(heroTalentPhysicalCard, in: &battle)
        #expect(talentPoints(.burn, on: .hero, in: battle) == 1)
        #expect(talentPoints(.poison, on: .hero, in: battle) == 1)
        #expect(battle.roster.hero.currentHealth == 2)
    }

    @Test func `blocked hits and broken block have distinct physical rewards`() throws {
        var blocked = heroTalentBattle("wildcard_dodge_t1_2", "wildcard_physical_t3_2")
        seedHeroTalentEffect(.shield(.block, 10), on: .enemy, in: &blocked)
        try playHeroTalentCard(heroTalentPhysicalCard, in: &blocked)
        #expect(talentPoints(.shield, on: .hero, in: blocked) == 1)
        let firstEnemyBlock = talentPoints(.shield, on: .enemy, in: blocked)
        #expect(firstEnemyBlock == 8 || firstEnemyBlock == 7)
        try playHeroTalentCard(heroTalentPhysicalCard, in: &blocked)
        #expect(talentPoints(.shield, on: .hero, in: blocked) == 1)
        var broken = heroTalentBattle("wildcard_physical_t2_2")
        broken.roster.mutateRuntime(for: broken.companion) { $0.currentHealth = 1 }
        seedHeroTalentEffect(.shield(.block, 1), on: .enemy, in: &broken)
        try playHeroTalentCard(heroTalentPhysicalCard, in: &broken)
        #expect(broken.roster.companion.currentHealth == 2)
    }

    @Test func `root passage ignores one block on only one poison component`() throws {
        var battle = heroTalentBattle("druid_poison_t3_1")
        seedHeroTalentEffect(.thorns(1), on: .companion, in: &battle)
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
        #expect(original[1].amount == (original[1].isCritical ? 1 : 0))
    }
}
