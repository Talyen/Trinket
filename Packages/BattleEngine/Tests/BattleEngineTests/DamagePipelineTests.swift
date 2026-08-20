import BattleEngine
import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport

struct DamagePipelineTests {
    private func makeContext(seed: UInt64 = BattleTestFixtures.deterministicNonCriticalSeed) -> BattleState {
        let target = CombatantFixtures.combatant(id: "target", role: .enemy, maxHealth: 50)
        let source = CombatantFixtures.combatant(id: "source", role: .hero, maxHealth: 50)
        return BattleStateTestFactory.makeBattle(
            hero: source,
            companion: CombatantFixtures.combatant(id: "companion", role: .companion),
            enemy: target,
            rngSeed: seed,
            dealOpeningHand: false
        )
    }

    @Test func healthCostIgnoresBlockBuffer() throws {
        var context = makeContext(seed: BattleTestFixtures.deterministicNonCriticalSeed)
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

        let outcome = context.resolveDamage(
            .directAbilityHit(
                amount: 10,
                target: target,
                keyword: .physical,
                sourceActorID: "source"
            )
        )

        try #expect(outcome.healthLost == 0)
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
                ActiveEffect(id: 1, effect: .onHitDamage(.freeze, 2), remainingTurns: 0),
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
            if case .onHitDamage = $0.effect {
                return true
            }
            return false
        }))
    }

    @Test func onHitDamageRetaliatesWithTheWardKeyword() throws {
        var context = makeContext(seed: 2)
        let defender = context.roster.enemy.combatant
        let attacker = context.roster.hero.combatant
        context.roster.setActiveEffects(
            [
                ActiveEffect(id: 1, effect: .onHitDamage(.holy, 6), remainingTurns: 0),
                ActiveEffect(id: 2, effect: .shield(.block, 50), remainingTurns: 0),
            ],
            for: defender
        )

        let attackerHealthBefore = context.roster.health(for: attacker)
        _ = context.resolveDamage(
            .directAbilityHit(
                amount: 10,
                target: defender,
                keyword: .physical,
                sourceActorID: attacker.id
            )
        )
        try #expect(context.roster.health(for: attacker) == attackerHealthBefore - 6)
    }

    @Test func stackedOnHitWardsBothConsumeAndCanKill() throws {
        var context = makeContext(seed: 2)
        let defender = context.roster.enemy.combatant
        let attacker = context.roster.hero.combatant
        context.roster.setActiveEffects(
            [
                ActiveEffect(id: 1, effect: .onHitDamage(.holy, 20), remainingTurns: 0),
                ActiveEffect(id: 2, effect: .onHitDamage(.bleed, 4), remainingTurns: 0),
                ActiveEffect(id: 3, effect: .shield(.block, 50), remainingTurns: 0),
            ],
            for: defender
        )
        let attackerHealthBefore = context.roster.health(for: attacker)
        _ = context.resolveDamage(
            .directAbilityHit(
                amount: 10,
                target: defender,
                keyword: .physical,
                sourceActorID: attacker.id
            )
        )
        try #expect(context.roster.health(for: attacker) == attackerHealthBefore - 24)
        try #expect(!(context.roster.activeEffects(for: defender).contains {
            if case .onHitDamage = $0.effect {
                return true
            }
            return false
        }))
    }
}
