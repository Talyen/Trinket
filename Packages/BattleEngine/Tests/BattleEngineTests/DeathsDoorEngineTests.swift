import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct DeathsDoorEngineTests {
    @Test func `Death's Door duration saturates when its bonus reaches the integer limit`() throws {
        var profile = CombatModifierProfile.zero
        profile.triggers.deathsDoorDurationBonusTurns = Int.max
        var battle = makeContext(heroHP: 1, heroModifiers: profile)

        _ = battle.resolveTestDamage(2, from: .enemy, to: .hero, options: .reaction())

        #expect(battle.health(of: battle.hero) == 1)
        let door = try #require(battle.activeEffects(of: battle.hero).first { $0.effect.kind == .deathsDoor })
        #expect(door.remainingTurns == Int.max)
    }

    @Test func `a fully Sapped Phoenix Gift cannot suppress Deaths Door protection`() {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            heroEffects: [ActiveEffect(id: 1, effect: .healingReductionPercent(1, 2), remainingTurns: 2)],
            heroHealth: 0,
            companionModifiers: CombatantTalentCatalog.profile(for: ["phoenix_health_t3_1"]),
        )
        let events = battle.recordingEvents { battle in await DeathsDoorEngine.resolveAfterDamage(to: battle.hero, in: &battle) }
        #expect(battle.health(of: battle.hero) == 1)
        #expect(battle.roster.isDeathsDoorActive(for: battle.hero))
        #expect(events.contains { $0.effectKind == .deathsDoorTriggered })
    }

    private func makeContext(
        heroHP: Int = 10,
        companionHP: Int = 10,
        enemyHP: Int = 50,
        heroModifiers: CombatModifierProfile = .zero,
    ) -> BattleState {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 50)
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 50)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: enemyHP)
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero,
            companion: companion,
            enemy: enemy,
            heroModifiers: heroModifiers,
        )
        battle.roster.hero.currentHealth = heroHP
        battle.roster.companion.currentHealth = companionHP
        battle.roster.enemy.currentHealth = enemyHP
        return battle
    }

    @Test func `trigger on first lethal hit`() throws {
        var context = makeContext(heroHP: 5)
        let hero = context.roster.hero.combatant
        let outcome = context.recordingResult { context in context.resolveTestDamage(
            40,
            to: hero,
            options: .attack(scaling: .flat, accuracy: .unavoidable),
        ) }

        try #expect(outcome.value.healthLost == 5)
        try #expect(context.roster.health(for: hero) == 1)
        try #expect(context.roster.hasConsumedDeathsDoor(for: hero))
        try #expect(context.roster.isDeathsDoorActive(for: hero))
        try #expect(
            context.roster.activeEffects(for: hero).first?.remainingTurns == BattleTiming.deathsDoorDurationTurns,
        )
        try #expect(outcome.events.contains(effectKind: .deathsDoorTriggered, keyword: .deathsDoor))
    }

    @Test func `enemy never triggers`() throws {
        var context = makeContext(enemyHP: 5)
        let enemy = context.roster.enemy.combatant
        _ = context.resolveTestDamage(
            5,
            to: enemy,
            options: .attack(scaling: .flat, accuracy: .unavoidable),
        )

        try #expect(context.roster.health(for: enemy) == 0)
        try #expect(!(context.roster.isDeathsDoorActive(for: enemy)))
    }

    @Test func `protection clamps to one while active`() throws {
        var context = makeContext(heroHP: 5)
        let hero = context.roster.hero.combatant
        _ = context.resolveTestDamage(5, to: hero, options: .attack(scaling: .flat, accuracy: .unavoidable))
        _ = context.resolveTestDamage(20, to: hero, options: .attack(scaling: .flat, accuracy: .unavoidable))

        try #expect(context.roster.health(for: hero) == 1)
        try #expect(context.roster.isDeathsDoorActive(for: hero))
    }

    @Test func `expiry round do T does not kill until the following round`() {
        var context = makeContext(heroHP: 5)
        let hero = context.roster.hero.combatant
        _ = context.resolveTestDamage(5, to: hero, options: .attack(scaling: .flat, accuracy: .unavoidable))
        var effects = context.roster.activeEffects(for: hero)
        let burnID = (effects.map(\.id).max() ?? 0) + 1
        effects.append(ActiveEffect(id: burnID, effect: .burn(8), remainingTurns: 0, sourceActorID: context.enemy.id))
        context.roster.setActiveEffects(effects, for: hero)

        for _ in 0 ..< BattleTiming.deathsDoorDurationTurns {
            _ = context.endTurn()
        }

        #expect(context.roster.health(for: hero) == 1)
        #expect(context.roster.hero.isAlive)
        #expect(!context.roster.isDeathsDoorActive(for: hero))
        #expect(context.roster.runtime(for: hero)?.deathsDoorExpiredAtTurn == context.turnCount)

        _ = context.endTurn()
        #expect(context.roster.health(for: hero) == 0)
        #expect(!context.roster.hero.isAlive)
    }

    @Test func `second wind does not preempt deaths door on lethal hit`() throws {
        var context = makeContext(
            heroHP: 5,
            heroModifiers: CombatModifierProfile.withTriggers {
                $0.onceBelowHealthPercentThreshold = 0.25
                $0.onceBelowHealthPercentHeal = 3
            },
        )
        let hero = context.roster.hero.combatant
        let events = context.recordingResult { observation in observation.resolveTestDamage(
            5,
            to: hero,
            options: .attack(scaling: .flat, accuracy: .unavoidable),
        ) }.events

        try #expect(context.roster.health(for: hero) == 1)
        try #expect(context.roster.hasConsumedDeathsDoor(for: hero))
        try #expect(events.contains(effectKind: .deathsDoorTriggered, keyword: .deathsDoor))
        try #expect(!events.contains { $0.abilityName == "Second Wind" })
        try #expect(!(context.roster.runtime(for: hero)?.hasTriggeredSecondWind ?? true))
    }

    @Test func `hero and companion proc independently`() throws {
        var context = makeContext(heroHP: 3, companionHP: 3)
        let hero = context.roster.hero.combatant
        let companion = context.roster.companion.combatant

        _ = context.resolveTestDamage(3, to: hero, options: .attack(scaling: .flat, accuracy: .unavoidable))
        _ = context.resolveTestDamage(3, to: companion, options: .attack(scaling: .flat, accuracy: .unavoidable))

        try #expect(context.roster.hasConsumedDeathsDoor(for: hero))
        try #expect(context.roster.hasConsumedDeathsDoor(for: companion))
        try #expect(context.roster.isDeathsDoorActive(for: hero))
        try #expect(context.roster.isDeathsDoorActive(for: companion))
    }

    @Test func `block only revive does not trigger without health`() throws {
        var context = makeContext(
            heroHP: 5,
            heroModifiers: CombatModifierProfile.withTriggers { $0.onceDeathReviveBlock = 10 },
        )
        let hero = context.roster.hero.combatant
        _ = context.resolveTestDamage(10, to: hero, options: .attack(scaling: .flat, accuracy: .unavoidable))

        try #expect(context.roster.health(for: hero) == 1)
        try #expect(context.roster.hasConsumedDeathsDoor(for: hero))
        try #expect(context.roster.isDeathsDoorActive(for: hero))
        try #expect(context.roster.runtime(for: hero)?.hasTriggeredDeathRevive == false)
    }

    @Test func `effect inserted at front of active effects`() throws {
        var context = makeContext(heroHP: 5)
        let hero = context.roster.hero.combatant
        context.roster.setActiveEffects(
            [ActiveEffect(id: 1, effect: .burn(2), remainingTurns: 0)],
            for: hero,
        )

        _ = context.resolveTestDamage(5, to: hero, options: .attack(scaling: .flat, accuracy: .unavoidable))

        let effects = context.roster.activeEffects(for: hero)
        try #expect(effects.count == 2)
        try #expect(effects.first?.effect.kind == .deathsDoor)
    }

    @Test func `do T tick triggers deaths door`() throws {
        var context = makeContext(heroHP: 2)
        let hero = context.roster.hero.combatant
        let outcome = context.recordingResult { context in await context.resolveDoTTick(
            basePotency: 3,
            keyword: .burn,
            target: hero,
            sourceActorID: "enemy",
        ) }

        try #expect(outcome.value.healthLost > 0)
        try #expect(context.roster.health(for: hero) == 1)
        try #expect(outcome.events.contains(effectKind: .deathsDoorTriggered, keyword: .deathsDoor))
    }

    @Test func `phoenix survival benefits wait for deaths door expiry`() throws {
        let phoenix = try BattleTestFixtures.catalogBuild(
            combatantID: "phoenix",
            talents: "phoenix_health_t2_1", "phoenix_deathsdoor_t2_2",
        )
        var modifiers = phoenix.modifiers
        // Keep this expiry test independent of the draw sequence's critical rolls.
        modifiers.triggers.criticalChanceBonus = -0.10
        var battle = BattleStateTestFactory.makeBattle(
            companion: phoenix.combatant,
            enemy: CombatantFixtures.passiveEnemy(),
            companionModifiers: modifiers, appliesFightPacing: false,
        )
        battle.roster.hero.currentHealth = 1
        battle.roster.companion.currentHealth = 1
        let companion = battle.roster.companion.combatant

        let entryEvents = battle.recordingResult { context in context.resolveTestDamage(
            1, to: companion, options: .attack(scaling: .flat, accuracy: .unavoidable),
        ) }.events

        #expect(battle.roster.hero.currentHealth == 1)
        #expect(battle.roster.companion.currentHealth == 1)
        #expect(battle.roster.companion.talents.timed.damage.amount == 0)
        #expect(!entryEvents.contains { $0.abilityName == "Afterglow" })

        var expiryEvents: [ActionEvent] = []
        for _ in 0 ..< BattleTiming.deathsDoorDurationTurns {
            expiryEvents.append(contentsOf: battle.endTurn().events)
        }

        #expect(!battle.roster.isDeathsDoorActive(for: companion))
        #expect(battle.roster.hero.currentHealth == 5)
        #expect(battle.roster.companion.currentHealth == 5)
        #expect(battle.roster.companion.talents.pending.doubleNextAttackAfterDeathsDoor)
        #expect(expiryEvents.contains { $0.abilityName == "Afterglow" })
    }

    @Test(arguments: [(3, 10, [7]), (12, 12, [])])
    func `endless legion raises health to floor only when below floor`(
        initialHealth: Int, expectedHealth: Int, expectedHeals: [Int],
    ) {
        var context = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 50),
            heroHealth: initialHealth,
            heroModifiers: CombatModifierProfile.withTriggers { $0.deathsDoorExpiredHealFlat = 10 },
        )
        let hero = context.roster.hero.combatant
        let events = context.recordingEvents { context in await DeathsDoorEngine.afterDeathsDoorExpired(on: hero, in: &context) }
        #expect(context.roster.health(for: hero) == expectedHealth)
        #expect(events.filter { $0.effectKind == .instantHeal }.map(\.amount) == expectedHeals)
    }

    @Test(arguments: [BattleParticipant.hero, .companion])
    func `guardian archive restores either party member on deaths door entry`(owner: BattleParticipant) throws {
        let owl = try BattleTestFixtures.catalogBuild(
            combatantID: "library_owl", talents: "library_owl_health_t3_1",
        )
        var battle = BattleStateTestFactory.makeBattle(
            companion: owl.combatant,
            companionModifiers: owl.modifiers,
            rngSeed: 2, appliesFightPacing: false,
        )
        let target = battle.roster[owner].combatant
        battle.roster.mutateRuntime(for: target) { $0.currentHealth = 1 }
        battle.insertEffect(.poison(8), to: target, sourceID: battle.roster.enemy.id, remainingTurns: 0)

        _ = battle.resolveTestDamage(1, to: target, options: .attack(scaling: .flat, accuracy: .unavoidable))

        #expect(battle.roster.health(for: target) == min(9, battle.roster.maxHealth(for: target)))
        #expect(battle.roster.activeEffects(for: target).contains { $0.effect.isRemovableDebuff })
    }
}
