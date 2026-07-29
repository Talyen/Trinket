import BattleEngine
import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport

struct DeathsDoorEngineTests {
    private func makeContext(
        heroHP: Int = 10,
        companionHP: Int = 10,
        enemyHP: Int = 50,
        heroModifiers: CombatModifierProfile = .zero
    ) -> BattleState {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 50)
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 50)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: enemyHP)
        let roster = BattleRoster(
            hero: CombatantRuntime(combatant: hero, initialHealth: heroHP),
            companion: CombatantRuntime(combatant: companion, initialHealth: companionHP),
            enemy: CombatantRuntime(combatant: enemy)
        )
        return BattleState(
            roster: roster,
            rng: SeededRandomNumberGenerator(seed: 1772),
            nextEffectID: 1,
            nextEventID: 0,
            events: [],
            gold: 0,
            initialGold: 0,
            heroModifiers: heroModifiers,
            companionModifiers: .zero,
            enemyModifiers: .zero
        )
    }

    @Test func triggerOnFirstLethalHit() throws {
        var context = makeContext(heroHP: 5)
        let hero = context.roster.hero.combatant
        let (lost, events) = context.applyTestDamage(
            40,
            to: hero,
            applyStatBonus: false,
            applyItemBonus: false,
            applyDodge: false
        )

        try #expect(lost == 5)
        try #expect(context.roster.health(for: hero) == 1)
        try #expect(context.roster.hasConsumedDeathsDoor(for: hero))
        try #expect(context.roster.isDeathsDoorActive(for: hero))
        try #expect(
            context.roster.activeEffects(for: hero).first?.remainingTurns == BattleTiming.deathsDoorDurationTurns
        )
        try #expect(events.contains(effectKind: .deathsDoorTriggered, keyword: .deathsDoor))
    }

    @Test func enemyNeverTriggers() throws {
        var context = makeContext(enemyHP: 5)
        let enemy = context.roster.enemy.combatant
        _ = context.applyTestDamage(
            5,
            to: enemy,
            applyStatBonus: false,
            applyItemBonus: false,
            applyDodge: false
        )

        try #expect(context.roster.health(for: enemy) == 0)
        try #expect(!(context.roster.isDeathsDoorActive(for: enemy)))
    }

    @Test func protectionClampsToOneWhileActive() throws {
        var context = makeContext(heroHP: 5)
        let hero = context.roster.hero.combatant
        _ = context.applyTestDamage(5, to: hero, applyStatBonus: false, applyItemBonus: false, applyDodge: false)
        _ = context.applyTestDamage(20, to: hero, applyStatBonus: false, applyItemBonus: false, applyDodge: false)

        try #expect(context.roster.health(for: hero) == 1)
        try #expect(context.roster.isDeathsDoorActive(for: hero))
    }

    @Test(arguments: [true, false])
    func expiryGraceClampsSameTickThenKillsOnLaterTick(advanceTickBeforeSecondHit: Bool) throws {
        var context = makeContext(heroHP: 5)
        let hero = context.roster.hero.combatant
        _ = context.applyTestDamage(5, to: hero, applyStatBonus: false, applyItemBonus: false, applyDodge: false)

        var effects = context.roster.activeEffects(for: hero)
        for _ in 0 ..< BattleTiming.deathsDoorDurationTurns {
            let result = EffectTurnEngine.advanceEffects(effects, target: hero, context: &context)
            effects = result.updated
        }
        context.roster.setActiveEffects(effects, for: hero)

        if advanceTickBeforeSecondHit {
            // Expiry grace only lasts through the tick that removed Death's Door.
            context.turnCount += 1
            context.roster.mutateRuntime(for: hero) { $0.deathsDoorExpiredAtTurn = nil }
            try #expect(!(context.roster.isDeathsDoorActive(for: hero)))
            _ = context.applyTestDamage(5, to: hero, applyStatBonus: false, applyItemBonus: false, applyDodge: false)
            try #expect(context.roster.health(for: hero) == 0)
            try #expect(!(context.roster.hero.isAlive))
        } else {
            try #expect(!(context.roster.isDeathsDoorActive(for: hero)))
            try #expect(context.roster.runtime(for: hero)?.deathsDoorExpiredAtTurn == context.turnCount)
            _ = context.applyTestDamage(5, to: hero, applyStatBonus: false, applyItemBonus: false, applyDodge: false)
            try #expect(context.roster.health(for: hero) == 1)
            try #expect(context.roster.hero.isAlive)
        }
    }

    @Test func secondWindDoesNotPreemptDeathsDoorOnLethalHit() throws {
        var context = makeContext(
            heroHP: 5,
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(onceBelowHealthPercentThreshold: 0.25, onceBelowHealthPercentHeal: 3))
        )
        let hero = context.roster.hero.combatant
        let (_, events) = context.applyTestDamage(
            5,
            to: hero,
            applyStatBonus: false,
            applyItemBonus: false,
            applyDodge: false
        )

        try #expect(context.roster.health(for: hero) == 1)
        try #expect(context.roster.hasConsumedDeathsDoor(for: hero))
        try #expect(events.contains(effectKind: .deathsDoorTriggered, keyword: .deathsDoor))
        try #expect(!events.contains { $0.abilityName == "Second Wind" })
        try #expect(!(context.roster.runtime(for: hero)?.hasTriggeredSecondWind ?? true))
    }

    @Test func heroAndCompanionProcIndependently() throws {
        var context = makeContext(heroHP: 3, companionHP: 3)
        let hero = context.roster.hero.combatant
        let companion = context.roster.companion.combatant

        _ = context.applyTestDamage(3, to: hero, applyStatBonus: false, applyItemBonus: false, applyDodge: false)
        _ = context.applyTestDamage(3, to: companion, applyStatBonus: false, applyItemBonus: false, applyDodge: false)

        try #expect(context.roster.hasConsumedDeathsDoor(for: hero))
        try #expect(context.roster.hasConsumedDeathsDoor(for: companion))
        try #expect(context.roster.isDeathsDoorActive(for: hero))
        try #expect(context.roster.isDeathsDoorActive(for: companion))
    }

    @Test func effectInsertedAtFrontOfActiveEffects() throws {
        var context = makeContext(heroHP: 5)
        let hero = context.roster.hero.combatant
        context.roster.setActiveEffects(
            [ActiveEffect(id: 1, effect: .burn(2), remainingTurns: 0)],
            for: hero
        )

        _ = context.applyTestDamage(5, to: hero, applyStatBonus: false, applyItemBonus: false, applyDodge: false)

        let effects = context.roster.activeEffects(for: hero)
        try #expect(effects.count == 2)
        try #expect(effects.first?.effect.kind == .deathsDoor)
    }

    @Test func doTTickTriggersDeathsDoor() throws {
        // Start at 2 HP so a 3-potency tick remains lethal after catch-up (−1 while enemy HP% leads).
        var context = makeContext(heroHP: 2)
        let hero = context.roster.hero.combatant
        let outcome = context.resolveDoTTick(
            basePotency: 3,
            keyword: .burn,
            target: hero,
            sourceActorID: "enemy"
        )

        try #expect(outcome.healthLost > 0)
        try #expect(context.roster.health(for: hero) == 1)
        try #expect(outcome.events.contains(effectKind: .deathsDoorTriggered, keyword: .deathsDoor))
    }
}
