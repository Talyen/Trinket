import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

extension TalentCatalogRoundTripTests {
    @Test(arguments: [(UInt64(1), Keyword?.none), (7, .freeze), (23, .burn)])
    func `Prismatic Edge copies committed damage and shares one elemental roll per attack`(seed: UInt64, keyword: Keyword?) {
        var profile = CombatantTalentCatalog.profile(for: ["wildcard_physical_t1_1"])
        profile.triggers.criticalChanceBonus = -1
        profile.damageDealtBonus = [.physical: 2, .burn: 100, .freeze: 100]
        profile.outgoingDamagePercent = 0.5
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroModifiers: profile, dealOpeningHand: false, appliesFightPacing: false,
        )
        DefensePoolEngine.set(2, on: battle.enemy, in: &battle)
        battle.rng = SeededRandomNumberGenerator(seed: seed)
        var expectedRNG = battle.rng
        if BattleChance.succeeds(probability: 0.10, using: &expectedRNG) {
            #expect((Bool.random(using: &expectedRNG) ? Keyword.freeze : .burn) == keyword)
        } else {
            #expect(keyword == nil)
        }
        let events = battle.performTestAction(Ability(
            id: "prismatic-pair", name: "Physical Pair", tier: .basic,
            damageComponents: [DamageComponent(2), DamageComponent(2)], criticalChanceBonus: -1,
        ))
        #expect(events.filter { $0.kind == .abilityDamage && $0.keyword == .physical }.map(\.amount) == [3, 5])
        let procs = events.filter { $0.kind == .abilityDamage && $0.abilityName == "Prismatic Edge" }
        #expect(procs.map(\.amount) == (keyword == nil ? [] : [3, 5]))
        #expect(procs.allSatisfy { $0.keyword == keyword && $0.actorID == battle.hero.id })
        #expect(battle.health(of: battle.enemy) == (keyword == nil ? 92 : 84))
        #expect(CombatTriggerEngine.totalPotency(of: .burn, on: battle.enemy, in: battle) == (keyword == .burn ? 8 : 0))
        let freeze = battle.activeEffects(of: battle.enemy).compactMap { active -> Int? in
            if case let .controlMeter(.freeze, amount, _) = active.effect {
                return amount
            }
            return nil
        }.reduce(0, +)
        #expect(freeze == (keyword == .freeze ? 8 : 0))
        #expect(battle.rng.next() == expectedRNG.next())
    }

    @Test func `Prismatic Edge cannot turn blocked attacks or ongoing damage into elemental hits`() {
        var profile = CombatantTalentCatalog.profile(for: ["wildcard_physical_t1_1"])
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroModifiers: profile, dealOpeningHand: false, appliesFightPacing: false,
        )
        DefensePoolEngine.set(2, on: battle.enemy, in: &battle)
        battle.rng = SeededRandomNumberGenerator(seed: 23)
        var expectedRNG = battle.rng
        _ = battle.performTestAction(Ability(
            id: "blocked-prismatic", name: "Blocked Attack", tier: .basic,
            damageComponents: [DamageComponent(2)], criticalChanceBonus: -1,
        ))
        #expect(battle.health(of: battle.enemy) == 100)
        let tick = battle.resolveTestDamage(2, keyword: .physical, options: .resolvedPeriodic)
        #expect(tick.healthLost == 2)
        #expect(battle.activeEffects(of: battle.enemy).isEmpty)
        #expect(battle.rng.next() == expectedRNG.next())
    }

    @Test(arguments: [false, true], [false, true])
    func `legacy conditional Physical bonus applies once even against both statuses`(burning: Bool, frozen: Bool) {
        var profile = CombatModifierProfile.withTriggers { $0.physicalAttackDamageVsBurningOrFrozenFlat = 1 }
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroModifiers: profile, dealOpeningHand: false, appliesFightPacing: false,
        )
        if burning {
            battle.insertEffect(.burn(1), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 0)
        }
        if frozen {
            battle.insertEffect(.controlMeter(.freeze, 20, 20), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 2)
        }
        let events = battle.performTestAction(Ability(
            id: "prismatic-test", name: "Physical Attack", tier: .basic,
            damageComponents: [DamageComponent(2, keyword: .physical), DamageComponent(2, keyword: .physical)],
            criticalChanceBonus: -1,
        ))
        #expect(battle.health(of: battle.enemy) == (burning || frozen ? 94 : 96))
        #expect(events.filter { $0.kind == .abilityDamage }.map(\.keyword) == [.physical, .physical])
        #expect(CombatTriggerEngine.totalPotency(of: .burn, on: battle.enemy, in: battle) == (burning ? 1 : 0))
        let tick = battle.resolveTestDamage(2, keyword: .physical, options: .resolvedPeriodic)
        #expect(tick.healthLost == 2)
    }

    @Test(arguments: [0, 2, 4], [BattleParticipant.hero, .companion])
    func `thorn shedding adds bounded poison only to its owners retaliation`(block: Int, defender: BattleParticipant) {
        var battle = capstoneBattle(hero: ["druid_poison_t4_1"])
        seedHeroTalentEffect(.thorns(4), on: defender, in: &battle)
        DefensePoolEngine.set(block, on: battle.enemy, in: &battle)
        let before = battle.roster.enemy.currentHealth
        let outcome = battle.recordingResult { context in context.resolveTestDamage(
            1,
            to: context.roster[defender].combatant,
            keyword: .physical,
            sourceActorID: context.enemy.id,
            options: .attack(scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        ) }
        let poison = defender == .hero && block < 4 ? 1 : 0
        #expect(before - battle.roster.enemy.currentHealth == 4 - block + poison)
        #expect(talentPoints(.poison, on: .enemy, in: battle) == poison)
        #expect(talentPoints(.thorns, on: defender, in: battle) == 0)
        #expect(outcome.events.filter { $0.effectKind == .thornsTriggered }.reduce(0) { $0 + $1.amount } == 4 - block)
        seedHeroTalentEffect(.thorns(8), on: defender, in: &battle)
        _ = battle.resolveTestDamage(
            1,
            to: battle.roster[defender].combatant,
            keyword: .physical,
            sourceActorID: battle.enemy.id,
            options: .attack(scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        )
        #expect(talentPoints(.poison, on: .enemy, in: battle) == (defender == .hero ? 1 : 0))
    }

    @Test(arguments: [0, 1, 2])
    func `venomous skin damages the attacker before attaching poison`(block: Int) {
        var battle = capstoneBattle(companion: ["lizard_scout_poison_t1_2"])
        DefensePoolEngine.set(block, on: battle.enemy, in: &battle)
        let before = battle.roster.enemy.currentHealth
        _ = battle.resolveTestDamage(
            1,
            from: .enemy,
            to: .companion,
            options: .attack(scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        )
        #expect(before - battle.roster.enemy.currentHealth == (block == 0 ? 1 : 0))
        #expect(talentPoints(.poison, on: .enemy, in: battle) == (block == 0 ? 1 : 0))
        #expect(talentPoints(.shield, on: .enemy, in: battle) == max(0, block - 1))
    }
}
