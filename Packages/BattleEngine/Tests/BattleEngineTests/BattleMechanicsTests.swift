import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct BattleMechanicsTests {
    @Test func `mutual knockout is a defeat without victory Gold`() {
        let gold = CombatModifierProfile.withTriggers { $0.victoryGoldFlat = 4 }
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 10),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 10),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 10),
            heroEffects: [ActiveEffect(id: 1, effect: .thorns(1), remainingTurns: 0)],
            heroHealth: 1, companionHealth: 0, enemyHealth: 1,
            heroModifiers: gold, companionModifiers: gold, appliesFightPacing: false,
        )
        battle.roster.mutateRuntime(for: battle.hero) { $0.hasConsumedDeathsDoor = true }

        _ = battle.resolveTestDamage(1, from: .enemy, to: .hero, options: .attack(accuracy: .unavoidable))
        battle.appendDefeatMilestonesIfNeeded()

        #expect(battle.isPartyDefeated && battle.isEnemyDefeated)
        #expect(BattleSimulationOutcome.resolve(isPartyDefeated: true, isEnemyDefeated: true) == .defeat)
        #expect(battle.gold == 0)
    }

    @Test(arguments: [
        (true, true, BattleSimulationOutcome.defeat),
        (true, false, .defeat),
        (false, true, .victory),
        (false, false, nil),
    ])
    func `resolves party and enemy defeat combinations`(
        isPartyDefeated: Bool,
        isEnemyDefeated: Bool,
        expected: BattleSimulationOutcome?,
    ) {
        #expect(
            BattleSimulationOutcome.resolve(
                isPartyDefeated: isPartyDefeated,
                isEnemyDefeated: isEnemyDefeated,
            ) == expected,
        )
    }

    @Test func `a defeated ally does not grant victory Gold`() {
        let gold = CombatModifierProfile.withTriggers { $0.victoryGoldFlat = 4 }
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 10),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 10),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 10),
            companionHealth: 0, enemyHealth: 0,
            companionModifiers: gold,
        )

        battle.appendDefeatMilestonesIfNeeded()

        #expect(battle.isEnemyDefeated && !battle.isPartyDefeated)
        #expect(battle.gold == 0)
    }

    @Test func `advancing a copied battle expires talent bonuses without changing the original`() {
        var battle = BattleStateTestFactory.makeMinimalBattle()
        battle.roster.hero.talents.battle.damageBonus = 2
        battle.roster.hero.talents.pending.nextAttackHolyBonus = 4
        battle.roster.hero.talents.turn.cleansedKeywordProtection = [.burn]
        battle.roster.hero.talents.timed.dodge = .init(amount: 0.3, expiresAtTurn: 2)
        battle.roster.hero.talents.timed.damage = .init(amount: 0.5, expiresAtTurn: 1)
        let original = battle.roster.hero
        var preview = battle

        _ = preview.endTurn()

        #expect(preview.roster.hero.talents.turn.cleansedKeywordProtection.isEmpty)
        #expect(preview.roster.hero.talents.timed.damage.amount == 0)
        #expect(preview.roster.hero.talents.timed.dodge.amount == 0.3)
        _ = preview.endTurn()
        #expect(preview.roster.hero.talents.timed.dodge.amount == 0)
        #expect(preview.roster.hero.talents.pending.nextAttackHolyBonus == 4)
        #expect(preview.roster.hero.talents.battle.damageBonus == 2)
        #expect(battle.roster.hero == original)
    }

    @Test(arguments: [DamageOperation.periodic, .reaction()])
    func `repeating nonattack damage preserves attack resources and rewards`(operation: DamageOperation) {
        var profile = CombatModifierProfile.zero
        profile.triggers.onAttackStealGold = 2
        var battle = BattleTestFixtures.makePipelineContext(heroModifiers: profile, appliesFightPacing: false)
        battle.roster.hero.talents.pending.nextAttackHolyBonus = 3
        let result = battle.resolveTestDamage(4, options: operation.repeated())
        #expect(result.healthLost == 4)
        #expect(battle.roster.enemy.currentHealth == 46)
        #expect(battle.roster.hero.talents.pending.nextAttackHolyBonus == 3)
        #expect(battle.gold == 0)
    }

    @Test(arguments: [(0, 2), (50, 5)])
    func `Marked waits for an attack and is consumed even when Block absorbs the hit`(block: Int, bonus: Int) {
        var context = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.combatant(id: "hero", role: .hero),
            companion: CombatantFixtures.combatant(id: "companion", role: .companion),
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 30),
            enemyEffects: [ActiveEffect(id: 2, effect: .marked(bonus, 6), remainingTurns: 6, sourceActorID: "hero")],
            nextEffectID: 3,
        )
        if block == 0 {
            let dot = context.resolveDamage(.doTTick(amount: 3, target: context.enemy, keyword: .burn, sourceActorID: context.hero.id))
            #expect(dot.healthLost == 3)
            #expect(context.roster.activeEffects(for: context.enemy).contains { $0.effect.kind == .marked })
        } else {
            context.roster.enemy.activeEffects.insert(
                ActiveEffect(id: 1, effect: .shield(.block, block), remainingTurns: 6, sourceActorID: context.hero.id), at: 0,
            )
        }
        let outcome = context.recordingResult { context in await context.resolveDamage(.directAbilityHit(
            amount: 3,
            target: context.enemy,
            keyword: .physical,
            sourceActorID: context.hero.id,
        )) }
        #expect(outcome.value.healthLost == (block == 0 ? 5 : 0))
        #expect(!context.roster.activeEffects(for: context.enemy).contains { $0.effect.kind == .marked })
        if block > 0 {
            #expect(outcome.events.contains { $0.effectKind == .markedConsumed })
        }
    }

    @Test func `next strike critical guarantees crit and consumes`() throws {
        let ability = Ability(
            id: "test-crit-strike",
            name: "Test Crit Strike",
            tier: .basic,
            damageComponents: [DamageComponent(2, keyword: .physical)],
        )
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, abilities: [ability])
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 100)
        var context = BattleStateTestFactory.makeMinimalBattle(
            hero: hero,
            companion: companion,
            enemy: enemy,
            heroEffects: [ActiveEffect(id: 1, effect: .nextStrikeCritical, remainingTurns: 0)],
            nextEffectID: 2,
            nextEventID: 0,
        )
        let events = context.recordingEvents { context in await BattleTurnEngine.performAction(
            ability: ability,
            actor: hero,
            abilityTarget: context.enemy,
            context: &context,
        ) }

        let damageEvent = try #require(events.first { $0.kind == .abilityDamage })
        #expect(damageEvent.isCritical)
        #expect(!(context.roster.activeEffects(for: hero).contains {
            $0.effect.kind == .nextStrikeCritical
        }))
    }

    @Test func `corrosive venom strips block before the poison packet is absorbed`() {
        let venom = CombatModifierProfile.withTriggers { $0.poisonStripsBlockBeforeHealth = 1 }
        let hero = CombatantFixtures.passiveHero(maxHealth: 30)

        var blocking = BattleStateTestFactory.makeMinimalBattle(
            hero: hero,
            companion: CombatantFixtures.passiveCompanion(maxHealth: 30),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 30),
            heroEffects: [ActiveEffect(id: 1, effect: .shield(.block, 1), remainingTurns: 0)],
            enemyModifiers: venom,
            nextEffectID: 2, appliesFightPacing: false,
        )

        // The strip lands before absorption, so a packet larger than the
        // defender's Block reaches Health in full.
        let penetrated = blocking.resolveTestDamage(5, from: .enemy, to: .hero, keyword: .poison, options: .attack(accuracy: .unavoidable))
        #expect(penetrated.healthLost == 5)
        #expect(BattleTestFixtures.shieldPoints(for: blocking.hero, in: blocking) == 0)

        var absorbed = BattleStateTestFactory.makeMinimalBattle(
            hero: hero,
            companion: CombatantFixtures.passiveCompanion(maxHealth: 30),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 30),
            heroEffects: [ActiveEffect(id: 1, effect: .shield(.block, 10), remainingTurns: 0)],
            enemyModifiers: venom,
            nextEffectID: 2, appliesFightPacing: false,
        )

        let stopped = absorbed.resolveTestDamage(3, from: .enemy, to: .hero, keyword: .poison, options: .attack(accuracy: .unavoidable))
        #expect(stopped.healthLost == 0)
        // Absorb 3, strip 1: Block drops by exactly absorbed + strip.
        #expect(BattleTestFixtures.shieldPoints(for: absorbed.hero, in: absorbed) == 6)
    }
}
