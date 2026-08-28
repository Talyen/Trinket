import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

struct HealingEngineTests {
    private func makeContext(seed: UInt64 = BattleTestFixtures.deterministicNonCriticalSeed) -> BattleState {
        BattleTestFixtures.makePipelineContext(seed: seed)
    }

    @Test(arguments: [true, false])
    func resolveHealEmitsEventsOnlyForInstantHealPolicy(emitsEvent: Bool) throws {
        var context = makeContext(seed: BattleTestFixtures.deterministicNonCriticalSeed)
        if !emitsEvent {
            _ = context.applyTestDamage(10, to: context.roster.enemy.combatant)
        }
        let target = context.roster.enemy.combatant
        let outcome = HealingEngine.resolveHeal(
            HealRequest(
                amount: emitsEvent ? 3 : 5,
                target: target,
                sourceActorID: emitsEvent ? "source" : nil,
                logAs: emitsEvent
                    ? .instantHeal(
                        actorName: "Hero",
                        abilityName: "Heal",
                        keyword: .health
                    )
                    : .silent
            ),
            in: &context
        )
        if emitsEvent {
            try #expect(outcome.events.count == 1)
            try #expect(outcome.events.first?.effectKind == .instantHeal)
            try #expect(outcome.events.first?.amount == outcome.healthRestored)
        } else {
            try #expect(outcome.healthRestored > 0)
            try #expect(outcome.events.isEmpty)
        }
    }

    @Test func leechFromDamageHealsAndSetsLeechedFlag() throws {
        var context = makeContext(seed: BattleTestFixtures.deterministicNonCriticalSeed)
        context.roster.mutateRuntime(for: context.roster.hero.combatant) { $0.currentHealth = 30 }
        let before = context.roster.hero.currentHealth
        let outcome = HealingEngine.leechFromDamage(
            10,
            sourceActorID: "source",
            abilityHasLeech: true,
            in: &context
        )
        try #expect(outcome.flags.contains(.leeched))
        try #expect(context.roster.hero.currentHealth > before)
        try #expect(outcome.healthRestored == context.roster.hero.currentHealth - before)
        try #expect(outcome.events.first?.amount == outcome.healthRestored)
    }

    @Test func keywordDamageLeechHealsAtAbilityPercent() throws {
        var context = BattleTestFixtures.makePipelineContext(
            heroModifiers: CombatModifierProfile(
                triggers: CombatTraitTriggers(
                    dot: DotTriggers(
                        poisonDamageLeech: true
                    )
                )
            ),
            seed: BattleTestFixtures.deterministicNonCriticalSeed
        )
        context.roster.mutateRuntime(for: context.roster.hero.combatant) { $0.currentHealth = 20 }

        let outcome = HealingEngine.leechFromDamage(
            10,
            sourceActorID: "source",
            damageKeyword: .poison,
            in: &context
        )

        try #expect(outcome.healthRestored == 5)
        try #expect(context.roster.hero.currentHealth == 25)
    }

    @Test func abilityLeechHealsHalfOfDamageDealt() throws {
        var context = makeContext(seed: BattleTestFixtures.deterministicNonCriticalSeed)
        context.roster.mutateRuntime(for: context.roster.hero.combatant) { $0.currentHealth = 30 }
        let before = context.roster.hero.currentHealth
        let outcome = HealingEngine.leechFromDamage(
            10,
            sourceActorID: "source",
            abilityHasLeech: true,
            in: &context
        )
        try #expect(outcome.flags.contains(.leeched))
        try #expect(outcome.healthRestored == 5)
        try #expect(context.roster.hero.currentHealth == before + 5)
    }

    @Test func bloodLinkRoutesOverhealToCompanionAndEmitsLeechEvent() throws {
        var context = BattleTestFixtures.makePipelineContext(
            heroModifiers: CombatModifierProfile(
                triggers: CombatTraitTriggers(
                    healing: HealingTriggers(leechOverhealTransfersToCompanion: true)
                )
            ),
            seed: BattleTestFixtures.deterministicNonCriticalSeed
        )
        context.roster.mutateRuntime(for: context.roster.companion.combatant) { $0.currentHealth = 10 }

        let outcome = HealingEngine.leechFromDamage(
            10,
            sourceActorID: "source",
            abilityHasLeech: true,
            in: &context
        )

        try #expect(outcome.healthRestored == 5)
        try #expect(context.roster.companion.currentHealth == 15)
        let leechEvent = outcome.events.first { $0.effectKind == .leechHeal }
        try #expect(leechEvent?.targetID == context.roster.companion.id)
        try #expect(leechEvent?.amount == 5)
    }

    @Test func bloodLinkIntoFullHealthCompanionProducesNoLeechOutcome() throws {
        var context = BattleTestFixtures.makePipelineContext(
            heroModifiers: CombatModifierProfile(
                triggers: CombatTraitTriggers(
                    healing: HealingTriggers(leechOverhealTransfersToCompanion: true)
                )
            ),
            seed: BattleTestFixtures.deterministicNonCriticalSeed
        )

        let outcome = HealingEngine.leechFromDamage(
            10,
            sourceActorID: "source",
            abilityHasLeech: true,
            in: &context
        )

        try #expect(outcome.healthRestored == 0)
        try #expect(outcome.events.isEmpty)
        try #expect(!outcome.flags.contains(.leeched))
    }

    @Test func leechFromDamageDoesNotReviveDefeatedSource() throws {
        var context = makeContext(seed: BattleTestFixtures.deterministicNonCriticalSeed)
        context.roster.mutateRuntime(for: context.roster.hero.combatant) { $0.currentHealth = 0 }
        let outcome = HealingEngine.leechFromDamage(
            10,
            sourceActorID: "source",
            abilityHasLeech: true,
            in: &context
        )
        try #expect(outcome.healthRestored == 0)
        try #expect(context.roster.hero.currentHealth == 0)
    }

    @Test func resolveHealIgnoresDefeatedTarget() throws {
        var context = makeContext(seed: BattleTestFixtures.deterministicNonCriticalSeed)
        context.roster.mutateRuntime(for: context.roster.enemy.combatant) { $0.currentHealth = 0 }
        let outcome = HealingEngine.resolveHeal(
            HealRequest(amount: 5, target: context.roster.enemy.combatant, logAs: .silent),
            in: &context
        )
        try #expect(outcome.healthRestored == 0)
        try #expect(context.roster.enemy.currentHealth == 0)
    }

    @Test func healFromOneHPWhileDeathsDoorActive() throws {
        var context = makeContext(seed: BattleTestFixtures.deterministicNonCriticalSeed)
        let hero = context.roster.hero.combatant
        context.roster.mutateRuntime(for: hero) { $0.currentHealth = 1 }
        context.prependEffect(.deathsDoor, to: hero, remainingTurns: BattleTiming.deathsDoorDurationTurns)

        let outcome = HealingEngine.resolveHeal(
            HealRequest(amount: 10, target: hero, logAs: .silent),
            in: &context
        )

        try #expect(outcome.healthRestored > 0)
        try #expect(context.roster.health(for: hero) > 1)
        try #expect(context.roster.isDeathsDoorActive(for: hero))
    }

    @Test func healDoesNotRemoveDeathsDoorEffect() throws {
        var context = makeContext(seed: BattleTestFixtures.deterministicNonCriticalSeed)
        let hero = context.roster.hero.combatant
        context.roster.mutateRuntime(for: hero) {
            $0.currentHealth = 1
            $0.hasConsumedDeathsDoor = true
        }
        context.prependEffect(.deathsDoor, to: hero, remainingTurns: BattleTiming.deathsDoorDurationTurns)

        _ = HealingEngine.resolveHeal(
            HealRequest(amount: 20, target: hero, logAs: .silent),
            in: &context
        )

        try #expect(context.roster.isDeathsDoorActive(for: hero))
        try #expect(context.roster.hasConsumedDeathsDoor(for: hero))
    }

    @Test func instantHealCanCriticalWithWisdom() throws {
        let source = CombatantFixtures.combatant(
            id: "source",
            role: .hero,
            maxHealth: 50,
            primaryStats: PrimaryStats(wisdom: 20)
        )
        let target = CombatantFixtures.combatant(id: "target", role: .enemy, maxHealth: 50)
        var context = BattleTestFixtures.makeContext(
            hero: source,
            companion: CombatantFixtures.combatant(id: "companion", role: .companion),
            enemy: target,
            nextEffectID: 0,
            nextEventID: 0
        )
        context.roster.mutateRuntime(for: target) { $0.currentHealth = 10 }

        context.roster.setActiveEffects(
            [ActiveEffect(id: 1, effect: .criticalChanceBonus(1.0, 6), remainingTurns: 6)],
            for: source
        )

        let outcome = HealingEngine.resolveHeal(
            HealRequest(
                amount: 5,
                target: target,
                sourceActorID: "source",
                logAs: .instantHeal(
                    actorName: "Hero",
                    abilityName: "Heal",
                    keyword: .health
                )
            ),
            in: &context
        )

        try #expect(outcome.isCritical)
        try #expect(outcome.healthRestored == 10)
        try #expect(outcome.events.first?.isCritical == true)
        try #expect(outcome.events.first?.amount == 10)
    }

    @Test func leechHealCanCriticalWithWisdom() throws {
        var context = BattleTestFixtures.makePipelineContext(
            sourcePrimaryStats: PrimaryStats(wisdom: 20),
            seed: BattleTestFixtures.deterministicNonCriticalSeed
        )
        let source = context.roster.hero.combatant
        context.roster.setActiveEffects(
            [ActiveEffect(id: 1, effect: .criticalChanceBonus(1.0, 6), remainingTurns: 6)],
            for: source
        )
        context.roster.mutateRuntime(for: source) { $0.currentHealth = 20 }

        let outcome = HealingEngine.leechFromDamage(
            10,
            sourceActorID: "source",
            abilityHasLeech: true,
            in: &context
        )
        try #expect(outcome.isCritical)
        try #expect(outcome.flags.contains(.leeched))
        try #expect(outcome.healthRestored == 12)
        try #expect(outcome.events.first?.isCritical == true)
        try #expect(outcome.events.first?.keyword == .leech)
    }

    @Test func silentHealsDoNotRollCritical() throws {
        var context = makeContext(seed: 1)
        context.turnCount = 0
        context.roster.mutateRuntime(for: context.roster.hero.combatant) { $0.currentHealth = 45 }
        context.roster.mutateRuntime(for: context.roster.companion.combatant) { $0.currentHealth = 45 }
        context.roster.mutateRuntime(for: context.roster.enemy.combatant) { $0.currentHealth = 45 }
        context.roster.setActiveEffects(
            [ActiveEffect(id: 1, effect: .criticalChanceBonus(1.0, 6), remainingTurns: 6)],
            for: context.roster.hero.combatant
        )
        let outcome = HealingEngine.resolveHeal(
            HealRequest(
                amount: 5,
                target: context.roster.hero.combatant,
                sourceActorID: "source",
                logAs: .silent
            ),
            in: &context
        )
        try #expect(!outcome.isCritical)
        try #expect(outcome.healthRestored == 5)
    }

    @Test func healOverTimeOnHealArmsHoTButTickDoesNotRearm() throws {
        let healing = HealingTriggers(healOverTimeOnHealTurns: 3, healOverTimeOnHealAmount: 2)
        var context = BattleTestFixtures.makePipelineContext(
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(healing: healing)),
            seed: BattleTestFixtures.deterministicNonCriticalSeed
        )
        let source = context.roster.hero.combatant
        let target = context.roster.enemy.combatant
        context.roster.mutateRuntime(for: target) { $0.currentHealth = 10 }

        _ = HealingEngine.resolveHeal(
            HealRequest(
                amount: 3,
                target: target,
                sourceActorID: source.id,
                logAs: .instantHeal(actorName: source.name, abilityName: "Blessing of Dawn", keyword: .health)
            ),
            in: &context
        )
        let armed = try #require(context.roster.runtime(for: target))
        #expect(armed.healOverTimeAmount == 2)
        #expect(armed.healOverTimeTurnsRemaining == 3)

        context.roster.mutateRuntime(for: target) { $0.currentHealth = 10 }
        _ = HealingEngine.resolveHeal(
            HealRequest(
                amount: 1,
                target: target,
                sourceActorID: source.id,
                logAs: .instantHeal(actorName: source.name, abilityName: "Lingering Blessing", keyword: .health),
                isHoTTick: true
            ),
            in: &context
        )
        let afterTick = try #require(context.roster.runtime(for: target))
        #expect(afterTick.healOverTimeAmount == 2)
        #expect(afterTick.healOverTimeTurnsRemaining == 3)
    }
}
