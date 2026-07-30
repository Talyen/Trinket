import BattleEngine
import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport

struct DamagePipelineTests {
    private let expectedStepNames = [
        "DodgeGate",
        "CriticalGate",
        "DamageBonus",
        "FightPacing",
        "MarkedBonus",
        "ItemReduction",
        "CriticalMultiply",
        "Mitigation",
        "ShieldAbsorption",
        "TakeDamage",
        "MarkedConsume",
        "DeathsDoor",
        "Leech",
        "ControlMeter",
        "ReactiveOnHit",
        "HolyReaction",
        "StunReaction",
        "BurnReaction",
        "CriticalReaction",
    ]

    private func makeContext(seed: UInt64 = 1772) -> BattleState {
        let target = CombatantFixtures.combatant(id: "target", role: .enemy, maxHealth: 50)
        let source = CombatantFixtures.combatant(id: "source", role: .hero, maxHealth: 50)
        let roster = BattleRoster(
            hero: CombatantRuntime(combatant: source, initialActiveEffects: []),
            companion: CombatantRuntime(combatant: CombatantFixtures.combatant(id: "companion", role: .companion)),
            enemy: CombatantRuntime(combatant: target, initialActiveEffects: [])
        )
        return BattleState(
            roster: roster,
            rng: SeededRandomNumberGenerator(seed: seed),
            nextEffectID: 0,
            nextEventID: 0,
            events: [],
            gold: 0,
            initialGold: 0,
            heroModifiers: .zero,
            companionModifiers: .zero,
            enemyModifiers: .zero
        )
    }

    @Test func executedStepNamesMatchCanonicalOrderForFullHit() throws {
        try #expect(DamagePipeline.canonicalNames == expectedStepNames)

        var context = makeContext(seed: 1772)
        let executed = DamagePipeline.executedStepNames(
            for: .directAbilityHit(
                amount: 10,
                target: context.roster.enemy.combatant,
                keyword: .physical,
                sourceActorID: "source"
            ),
            in: &context
        )
        try #expect(executed == expectedStepNames)
        try #expect(executed == DamagePipeline.canonicalNames)
    }

    @Test func executedStepNamesShortCircuitAfterDodge() throws {
        // Player-capped defender so contested high agi can reach the 75% soft cap (enemies cannot).
        let stats = PrimaryStats(agility: 280)
        let target = CombatantFixtures.combatant(
            id: "target", role: .hero, maxHealth: 50, primaryStats: stats
        )
        let source = CombatantFixtures.combatant(id: "source", role: .enemy, maxHealth: 50)
        let roster = BattleRoster(
            hero: CombatantRuntime(combatant: target, initialActiveEffects: []),
            companion: CombatantRuntime(combatant: CombatantFixtures.combatant(id: "companion", role: .companion)),
            enemy: CombatantRuntime(combatant: source, initialActiveEffects: [])
        )
        var context = BattleState(
            roster: roster,
            rng: SeededRandomNumberGenerator(seed: 1772),
            nextEffectID: 0,
            nextEventID: 0,
            events: [],
            gold: 0,
            initialGold: 0,
            heroModifiers: .zero,
            companionModifiers: .zero,
            enemyModifiers: .zero
        )

        let executed = DamagePipeline.executedStepNames(
            for: .directAbilityHit(
                amount: 10,
                target: target,
                keyword: .physical,
                sourceActorID: "source"
            ),
            in: &context
        )

        try #expect(executed == ["DodgeGate"], "High agility defender should dodge and short-circuit")
    }

    @Test func healthCostSkipsAttackPipelineSteps() throws {
        var context = makeContext(seed: 1772)
        let hero = context.roster.hero.combatant
        let executed = DamagePipeline.executedStepNames(
            for: DamageRequest(
                amount: 2,
                target: hero,
                keyword: .physical,
                sourceActorID: hero.id,
                options: .healthCost
            ),
            in: &context
        )
        try #expect(executed == ["TakeDamage", "DeathsDoor"])
    }

    @Test func healthCostIgnoresBlockBuffer() throws {
        var context = makeContext(seed: 1772)
        let hero = context.roster.hero.combatant
        context.roster.setActiveEffects(
            [ActiveEffect(id: 1, effect: .shield(.block, 20), remainingTurns: 6)],
            for: hero
        )
        let healthBefore = context.roster.health(for: hero)

        let outcome = context.resolveDamage(
            DamageRequest(
                amount: 2,
                target: hero,
                keyword: .physical,
                sourceActorID: hero.id,
                options: .healthCost
            )
        )

        try #expect(outcome.healthLost == 2)
        try #expect(context.roster.health(for: hero) == healthBefore - 2)
        let shield = context.roster.activeEffects(for: hero).first {
            if case .shield = $0.effect {
                return true
            }
            return false
        }
        guard case let .shield(_, buffer) = shield?.effect else {
            Issue.record("Block should remain after a self health cost")
            return
        }
        try #expect(buffer == 20)
        try #expect(!(outcome.events.contains { $0.effectKind == .shieldAbsorbed }))
    }

    @Test func evadeNextHitForcesDodgeAndConsumesBuff() throws {
        var context = makeContext(seed: 1)
        let target = context.roster.enemy.combatant
        context.roster.setActiveEffects(
            [ActiveEffect(id: 1, effect: .evadeNextHit, remainingTurns: 0)],
            for: target
        )
        let healthBefore = context.roster.health(for: target)

        let executed = DamagePipeline.executedStepNames(
            for: .directAbilityHit(
                amount: 10,
                target: target,
                keyword: .physical,
                sourceActorID: "source"
            ),
            in: &context
        )

        try #expect(executed == ["DodgeGate"])
        try #expect(context.roster.health(for: target) == healthBefore)
        try #expect(!(context.roster.activeEffects(for: target).contains {
            if case .evadeNextHit = $0.effect {
                return true
            }
            return false
        }))
    }

    @Test func nextStrikeCriticalDoesNotAffectDoTTicks() throws {
        var context = makeContext(seed: 1)
        let source = context.roster.hero.combatant
        let target = context.roster.enemy.combatant
        context.roster.setActiveEffects(
            [ActiveEffect(id: 1, effect: .nextStrikeCritical, remainingTurns: 0)],
            for: source
        )

        let outcome = context.resolveDamage(
            .doTTick(
                amount: 4,
                target: target,
                keyword: .burn,
                sourceActorID: source.id
            )
        )

        try #expect(!outcome.isCritical)
        try #expect(context.roster.activeEffects(for: source).contains {
            if case .nextStrikeCritical = $0.effect {
                return true
            }
            return false
        })
    }

    @Test func freezeNextAttackerIgnoresDoTAndFiresOnBlockedAttack() throws {
        var context = makeContext(seed: 1)
        let defender = context.roster.enemy.combatant
        let attacker = context.roster.hero.combatant
        context.roster.setActiveEffects(
            [
                ActiveEffect(id: 1, effect: .freezeNextAttacker, remainingTurns: 0),
                ActiveEffect(id: 2, effect: .shield(.block, 50), remainingTurns: 0),
            ],
            for: defender
        )

        _ = context.resolveDamage(
            .doTTick(
                amount: 3,
                target: defender,
                keyword: .burn,
                sourceActorID: attacker.id
            )
        )
        try #expect(context.roster.activeEffects(for: defender).contains {
            if case .freezeNextAttacker = $0.effect {
                return true
            }
            return false
        })
        try #expect(!(context.roster.activeEffects(for: attacker).contains {
            if case let .controlMeter(keyword, _, _) = $0.effect {
                return keyword == .freeze
            }
            return false
        }))

        let healthBefore = context.roster.health(for: defender)
        _ = context.resolveDamage(
            .directAbilityHit(
                amount: 10,
                target: defender,
                keyword: .physical,
                sourceActorID: attacker.id
            )
        )
        try #expect(context.roster.health(for: defender) == healthBefore)
        try #expect(!(context.roster.activeEffects(for: defender).contains {
            if case .freezeNextAttacker = $0.effect {
                return true
            }
            return false
        }))
        try #expect(context.roster.activeEffects(for: attacker).contains {
            if case let .controlMeter(keyword, _, _) = $0.effect {
                return keyword == .freeze
            }
            return false
        })
    }

    @Test func freezeOnHitDealsFreezeRetaliationOnBlockedAttack() throws {
        var context = makeContext(seed: 2)
        let defender = context.roster.enemy.combatant
        let attacker = context.roster.hero.combatant
        context.roster.setActiveEffects(
            [
                ActiveEffect(id: 1, effect: .freezeOnHit(2), remainingTurns: 0),
                ActiveEffect(id: 2, effect: .shield(.block, 50), remainingTurns: 0),
            ],
            for: defender
        )

        let attackerHealthBefore = context.roster.health(for: attacker)
        let healthBefore = context.roster.health(for: defender)
        _ = context.resolveDamage(
            .directAbilityHit(
                amount: 10,
                target: defender,
                keyword: .physical,
                sourceActorID: attacker.id
            )
        )
        try #expect(context.roster.health(for: defender) == healthBefore)
        try #expect(context.roster.health(for: attacker) == attackerHealthBefore - 2)
        try #expect(!(context.roster.activeEffects(for: defender).contains {
            if case .freezeOnHit = $0.effect {
                return true
            }
            return false
        }))
    }
}
