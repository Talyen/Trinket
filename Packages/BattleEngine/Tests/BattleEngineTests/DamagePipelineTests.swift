import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

struct DamagePipelineTests {
    private func makeContext(
        seed: UInt64 = BattleTestFixtures.deterministicNonCriticalSeed,
        heroModifiers: CombatModifierProfile = .zero
    ) -> BattleState {
        let target = CombatantFixtures.combatant(id: "target", role: .enemy, maxHealth: 50)
        let source = CombatantFixtures.combatant(id: "source", role: .hero, maxHealth: 50)
        return BattleStateTestFactory.makeBattle(
            hero: source,
            companion: CombatantFixtures.combatant(id: "companion", role: .companion),
            enemy: target,
            heroModifiers: heroModifiers,
            rngSeed: seed,
            dealOpeningHand: false
        )
    }

    @Test func healthCostIgnoresDamagePrevention() throws {
        var context = makeContext(
            seed: BattleTestFixtures.deterministicNonCriticalSeed,
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(
                gold: GoldTriggers(goldAbsorbsDamage: true)
            ))
        )
        let hero = context.roster.hero.combatant
        context.gold = 5
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
        try #expect(context.gold == 5)
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

        var fatalContext = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.combatant(id: "fatal-hero", role: .hero, maxHealth: 2),
            companion: CombatantFixtures.combatant(id: "guard", role: .companion, maxHealth: 20),
            enemy: CombatantFixtures.combatant(id: "fatal-target", role: .enemy),
            companionModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(
                block: BlockTriggers(companionFatalDamageRedirectBlock: 10)
            )),
            dealOpeningHand: false
        )
        let fatalHero = fatalContext.roster.hero.combatant
        let companion = fatalContext.roster.companion.combatant
        let companionHealth = fatalContext.roster.health(for: companion)

        let fatalOutcome = fatalContext.resolveDamage(DamageRequest(
            amount: 2,
            target: fatalHero,
            keyword: .physical,
            sourceActorID: fatalHero.id,
            options: .healthCost
        ))

        try #expect(fatalOutcome.healthLost == 2)
        try #expect(fatalContext.roster.health(for: fatalHero) == 1)
        try #expect(fatalContext.roster.isDeathsDoorActive(for: fatalHero))
        try #expect(fatalContext.roster.health(for: companion) == companionHealth)
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

    @Test func damageAfterDodgeSurvivesDoTTickAndAppliesOnDirectHit() throws {
        let heroCombatant = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 50,
            abilities: [
                Ability(
                    id: "strike",
                    name: "Strike",
                    tier: .basic,
                    directDamage: 1,
                    damageKeyword: .physical
                ),
            ]
        )
        let enemyCombatant = BattleTestFixtures.passiveEnemy(maxHealth: 100)
        var context = BattleTestFixtures.makeContext(
            hero: heroCombatant,
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: enemyCombatant,
            seed: 2
        )
        context.roster.mutateRuntime(for: heroCombatant) { $0.pendingDamageAfterDodge = 3 }

        let dotLost = DoTDamage.resolveTurnDamage(
            basePotency: 1,
            keyword: .burn,
            target: enemyCombatant,
            sourceActorID: heroCombatant.id,
            in: &context
        ).healthLost
        try #expect(dotLost == 1)
        try #expect(context.roster.runtime(for: heroCombatant)?.pendingDamageAfterDodge == 3)

        let directLost = context.resolveDamage(
            DamageRequest(
                amount: 1,
                target: enemyCombatant,
                keyword: .physical,
                sourceActorID: heroCombatant.id,
                options: DamageOptions(
                    applyStatBonus: false,
                    applyItemBonus: true,
                    applyDodge: false,
                    qualifiesForAmbush: true,
                    isAttackHit: true
                )
            )
        ).healthLost
        try #expect(directLost == 4)
        try #expect(context.roster.runtime(for: heroCombatant)?.pendingDamageAfterDodge == 0)
    }

    @Test func poisonDamagePercentScalesDamageAfterFlatBonuses() throws {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero)
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy)
        var context = BattleTestFixtures.makeContext(
            hero: hero,
            companion: companion,
            enemy: enemy,
            heroModifiers: CombatModifierProfile(modifiers: [
                .damageDealt(.poison, 2),
                .poisonDamageDealtPercent(0.2),
            ]),
            seed: 0,
            nextEffectID: 0,
            nextEventID: 0
        )

        let outcome = context.resolveDamage(.doTTick(
            amount: 10,
            target: enemy,
            keyword: .poison,
            sourceActorID: hero.id
        ))

        try #expect(outcome.healthLost == 14)
    }
}

struct EnemyOutgoingReductionDamageTests {
    @Test func frozenEnemyDealsReducedDamage() throws {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 50)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 50)
        var context = BattleStateTestFactory.makeBattle(
            hero: hero,
            companion: CombatantFixtures.combatant(id: "companion", role: .companion),
            enemy: enemy,
            activeEnemyEffects: [
                ActiveEffect(
                    id: 1,
                    effect: .controlMeter(.freeze, 1, 1),
                    remainingTurns: BattleTiming.controlStatusLingerTurns
                ),
            ],
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(
                mitigation: MitigationTriggers(frozenEnemyDamageReductionFlat: 3)
            )),
            dealOpeningHand: false
        )

        let outcome = context.resolveDamage(
            DamageRequest(amount: 10, target: hero, keyword: .physical, sourceActorID: "enemy")
        )

        try #expect(outcome.healthLost == 7)
    }

    @Test func debuffedAttackingEnemyHasDamageReduced() throws {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 50)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 50)
        var context = BattleStateTestFactory.makeBattle(
            hero: hero,
            companion: CombatantFixtures.combatant(id: "companion", role: .companion),
            enemy: enemy,
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .damageReductionPercent(0.25, 2), remainingTurns: 2),
            ],
            dealOpeningHand: false
        )

        let outcome = context.resolveDamage(
            DamageRequest(amount: 10, target: hero, keyword: .physical, sourceActorID: "enemy")
        )

        try #expect(outcome.healthLost == 8)
    }

    @Test func frozenHeroDoesNotReduceIncomingEnemyDamage() throws {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 50)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 50)
        var context = BattleStateTestFactory.makeBattle(
            hero: hero,
            companion: CombatantFixtures.combatant(id: "companion", role: .companion),
            enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(
                    id: 1,
                    effect: .controlMeter(.freeze, 1, 1),
                    remainingTurns: BattleTiming.controlStatusLingerTurns
                ),
            ],
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(
                mitigation: MitigationTriggers(frozenEnemyDamageReductionFlat: 3)
            )),
            dealOpeningHand: false
        )

        let outcome = context.resolveDamage(
            DamageRequest(amount: 10, target: hero, keyword: .physical, sourceActorID: "enemy")
        )

        try #expect(outcome.healthLost == 10)
    }
}
