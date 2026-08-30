import BattleEngine
import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport

struct CombatPipelineTests {
    private func makeContext(
        targetMaxHealth: Int = 50,
        targetPrimaryStats: PrimaryStats = PrimaryStats(),
        targetEffects: [ActiveEffect] = [],
        sourcePrimaryStats: PrimaryStats = PrimaryStats(),
        heroModifiers: CombatModifierProfile = .zero,
        seed: UInt64 = BattleTestFixtures.deterministicNonCriticalSeed,
    ) -> BattleState {
        BattleTestFixtures.makePipelineContext(
            targetMaxHealth: targetMaxHealth,
            targetPrimaryStats: targetPrimaryStats,
            targetEffects: targetEffects,
            sourcePrimaryStats: sourcePrimaryStats,
            heroModifiers: heroModifiers,
            seed: seed,
        )
    }

    private var target: Combatant {
        CombatantFixtures.combatant(id: "target", role: .enemy, maxHealth: 50)
    }

    @Test func `apply damage dodge respects chance and skip flags`() throws {
        let stats = PrimaryStats(agility: 280)
        let target = CombatantFixtures.combatant(
            id: "target", role: .hero, maxHealth: 50, primaryStats: stats,
        )
        let source = CombatantFixtures.combatant(id: "source", role: .enemy, maxHealth: 50)
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion)
        var context = BattleTestFixtures.makeContext(
            hero: target,
            companion: companion,
            enemy: source,
            seed: BattleTestFixtures.deterministicNonCriticalSeed,
            nextEffectID: 0,
            nextEventID: 0,
        )
        let (lost, events) = context.applyTestDamage(10, to: target, sourceActorID: "source")
        try #expect(lost == 0)
        try #expect(events.contains { $0.effectKind == .dodgeApplied })

        var noSourceContext = makeContext(seed: BattleTestFixtures.deterministicNonCriticalSeed)
        let (lostWithoutSource, _) = noSourceContext.applyTestDamage(10, to: noSourceContext.roster.enemy.combatant)
        try #expect(lostWithoutSource > 0)

        var disabledContext = makeContext(seed: BattleTestFixtures.deterministicNonCriticalSeed)
        let (lostWithDodgeDisabled, _) = disabledContext.applyTestDamage(
            10,
            to: disabledContext.roster.enemy.combatant,
            sourceActorID: "source",
            applyDodge: false,
        )
        try #expect(lostWithDodgeDisabled > 0)
    }

    @Test func `enemy dodge chance uses compressed contest`() throws {
        let falloff = PrimaryStats.enemyDodgeFalloffConstant
        let context = makeContext(
            targetPrimaryStats: PrimaryStats(agility: 20),
            sourcePrimaryStats: PrimaryStats(agility: 0),
        )
        var state = DamageResolutionState(
            amount: 1,
            combatant: context.roster.enemy.combatant,
            sourceActorID: "source",
            damageKeyword: .physical,
            options: DamageOptions(applyStatBonus: false, applyItemBonus: false, applyDodge: true),
        )

        let chance = DamagePipeline.dodgeChance(for: state, in: context)
        let expectedBase = context.roster.enemy.combatant.primaryStats.contestedDodgeChance(againstAttackerAgility: 0)
        try #expect(abs(chance - expectedBase / (1 + falloff * expectedBase)) < 0.0001)
    }

    @Test func `apply damage shield absorption preserves source actor ID`() throws {
        let shield = ActiveEffect(
            id: 1,
            effect: .shield(.block, 10),
            remainingTurns: 3,
            sourceActorID: "caster",
        )
        var context = makeContext(targetEffects: [shield])
        _ = context.applyTestDamage(4, to: context.roster.enemy.combatant)

        let updatedShield = context.roster.enemy.activeEffects.first { $0.id == 1 }
        try #expect(updatedShield?.sourceActorID == "caster")
        if case let .shield(_, buffer) = updatedShield?.effect {
            try #expect(buffer == 6)
        } else {
            Issue.record("Expected partial shield to remain")
        }
    }

    @Test func `apply damage stat bonus applies for source`() throws {
        let stats = PrimaryStats(strength: 80)
        var context = makeContext(sourcePrimaryStats: stats, seed: BattleTestFixtures.deterministicNonCriticalSeed)
        let (lost, _) = context.applyTestDamage(10, to: context.roster.enemy.combatant, keyword: .physical, sourceActorID: "source")
        try #expect(lost == 15)
    }

    @Test func `stun and freeze buildup tracked separately from damage`() throws {
        var context = makeContext(seed: BattleTestFixtures.deterministicNonCriticalSeed)
        let target = context.roster.enemy.combatant
        _ = context.applyTestDamage(3, to: target, keyword: .stun, sourceActorID: "source", applyDodge: false)
        _ = context.applyTestDamage(5, to: target, keyword: .freeze, sourceActorID: "source", applyDodge: false)

        let stunMeter = context.roster.activeEffects(for: target).first {
            guard case let .controlMeter(keyword, amount, _) = $0.effect else { return false }
            return keyword == .stun && amount == 3
        }
        let freezeMeter = context.roster.activeEffects(for: target).first {
            guard case let .controlMeter(keyword, amount, _) = $0.effect else { return false }
            return keyword == .freeze && amount == 5
        }
        _ = try #require(stunMeter)
        _ = try #require(freezeMeter)
    }

    @Test(arguments: ["dot", "direct", "self"] as [String])
    func `apply damage leech matrix`(mode: String) throws {
        var context = makeContext(
            heroModifiers: mode == "dot"
                ? CombatModifierProfile(
                    triggers: CombatTraitTriggers(dot: DotTriggers(burnDamageLeech: true)),
                )
                : CombatModifierProfile(),
            seed: BattleTestFixtures.deterministicNonCriticalSeed,
        )
        context.roster.mutateRuntime(for: context.roster.hero.combatant) { $0.currentHealth = 30 }
        let before = context.roster.hero.currentHealth
        let abilityHasLeech = mode != "dot"

        switch mode {
        case "dot":
            let (lost, events) = context.applyTestDoTDamage(
                10,
                keyword: .burn,
                to: context.roster.enemy.combatant,
                sourceActorID: "source",
            )
            try #expect(lost > 0)
            try #expect(context.roster.hero.currentHealth > before)
            try #expect(events.contains { $0.effectKind == .leechHeal })
        case "direct":
            let (_, events) = context.applyTestDamage(
                10,
                to: context.roster.enemy.combatant,
                keyword: .physical,
                sourceActorID: "source",
                abilityHasLeech: abilityHasLeech,
            )
            try #expect(context.roster.hero.currentHealth > before)
            try #expect(events.contains { $0.effectKind == .leechHeal })
        case "self":
            let expectedLoss = context.paced(10, sourceActorID: "source")
            let (_, events) = context.applyTestDamage(
                10,
                to: context.roster.hero.combatant,
                keyword: .physical,
                sourceActorID: "source",
                abilityHasLeech: abilityHasLeech,
            )
            try #expect(context.roster.hero.currentHealth == before - expectedLoss)
            try #expect(!(events.contains { $0.effectKind == .leechHeal }))
        default:
            Issue.record("Unexpected leech mode \(mode)")
        }
    }

    @Test func `prevention threshold uses item maximum health bonus`() throws {
        let target = CombatantFixtures.combatant(id: "target", role: .enemy, maxHealth: 50)
        let source = CombatantFixtures.combatant(id: "source", role: .hero, maxHealth: 50)
        let roster = BattleRoster(
            hero: CombatantRuntime(combatant: source, initialActiveEffects: []),
            companion: CombatantRuntime(combatant: CombatantFixtures.combatant(id: "companion", role: .companion)),
            enemy: CombatantRuntime(
                combatant: target,
                initialActiveEffects: [],
                maximumHealthBonus: 50,
            ),
        )
        var context = BattleState(
            roster: roster,
            rng: SeededRandomNumberGenerator(seed: BattleTestFixtures.deterministicNonCriticalSeed),
            nextEffectID: 0,
            nextEventID: 0,
            events: [],
            gold: 0,
            initialGold: 0,
            heroModifiers: .zero,
            companionModifiers: .zero,
            enemyModifiers: .zero,
        )

        context.applyControlMeter(1, keyword: .stun, to: target, sourceActorID: "source")

        let buildup = context.roster.enemy.activeEffects.first(where: \.effect.isControlMeter)
        let threshold = buildup?.effect.controlMeterValues?.threshold
        let expected = target.primaryStats.controlMeterThreshold(baseMaxHealth: 100)
        try #expect(threshold == expected)
    }

    @Test(arguments: [true, false])
    func `stun buildup tracks post mitigation and shield absorbed hits`(useShield: Bool) throws {
        if useShield {
            let shield = ActiveEffect(id: 1, effect: .shield(.block, 20), remainingTurns: 6)
            var context = makeContext(targetMaxHealth: 100, targetEffects: [shield], seed: BattleTestFixtures.deterministicNonCriticalSeed)
            let (lost, _) = context.applyTestDamage(
                5,
                to: context.roster.enemy.combatant,
                keyword: .stun,
                sourceActorID: "source",
            )

            try #expect(lost == 0)
            let stunMeter = context.roster.enemy.activeEffects.first {
                guard case let .controlMeter(keyword, amount, _) = $0.effect else { return false }
                return keyword == .stun && amount == 5
            }
            _ = try #require(stunMeter, "Fully shielded stun hits still charge control meters")
        } else {
            var context = makeContext(
                targetMaxHealth: 100,
                targetPrimaryStats: PrimaryStats(toughness: 15),
                seed: BattleTestFixtures.deterministicNonCriticalSeed,
            )
            _ = context.applyTestDamage(
                20,
                to: context.roster.enemy.combatant,
                keyword: .stun,
                sourceActorID: "source",
            )

            let buildup = context.roster.enemy.activeEffects.first(where: \.effect.isControlMeter)
            let amount = buildup?.effect.controlMeterValues?.amount
            try #expect(amount == 17)
        }
    }

    @Test func `critical hit is absorbed by shield before health`() throws {
        let shield = ActiveEffect(id: 1, effect: .shield(.block, 20), remainingTurns: 6)
        var context = makeContext(targetMaxHealth: 100, targetEffects: [shield], seed: BattleTestFixtures.deterministicNonCriticalSeed)
        let outcome = context.resolveDamage(
            DamageRequest(
                amount: 5,
                target: context.roster.enemy.combatant,
                keyword: .physical,
                sourceActorID: "source",
                options: DamageOptions(applyDodge: false, abilityCriticalChanceBonus: 1.0),
            ),
        )

        try #expect(outcome.isCritical)
        try #expect(outcome.healthLost == 0, "Crit should multiply before shields absorb the final amount")
        let remainingBuffer = context.roster.enemy.activeEffects.compactMap { active -> Int? in
            guard case let .shield(_, buffer) = active.effect else { return nil }
            return buffer
        }.first
        try #expect(remainingBuffer == 10, "5 damage crit to 10 should consume 10 shield")
    }

    @Test(arguments: [Keyword.block, .dodge, .purge, .gold, .mana])
    func `non crittable keywords never critical even with ability bonus`(keyword: Keyword) throws {
        var context = makeContext(seed: BattleTestFixtures.deterministicNonCriticalSeed)
        let before = context.roster.enemy.currentHealth
        let outcome = context.resolveDamage(
            DamageRequest(
                amount: 5,
                target: context.roster.enemy.combatant,
                keyword: keyword,
                sourceActorID: "source",
                options: DamageOptions(applyDodge: false, abilityCriticalChanceBonus: 1.0),
            ),
        )
        try #expect(!outcome.isCritical, "\(keyword.rawValue)")
        try #expect(outcome.healthLost == 5, "\(keyword.rawValue)")
        try #expect(context.roster.enemy.currentHealth == before - 5, "\(keyword.rawValue)")
    }

    @Test func `guaranteed critical if enemy buffed bypasses soft cap`() throws {
        let buff = ActiveEffect(id: 1, effect: .shield(.block, 2), remainingTurns: 6)
        var context = makeContext(targetEffects: [buff], seed: 1)
        let outcome = context.resolveDamage(
            DamageRequest(
                amount: 5,
                target: context.roster.enemy.combatant,
                keyword: .holy,
                sourceActorID: "source",
                options: DamageOptions(
                    applyDodge: false,
                    guaranteedCriticalIfEnemyBuffed: true,
                ),
            ),
        )
        try #expect(outcome.isCritical)
    }

    @Test func `thorns retaliation does not recurse`() throws {
        let thorns = ActiveEffect(id: 1, effect: .thorns(5), remainingTurns: 0)
        var context = makeContext(
            targetMaxHealth: 200,
            targetEffects: [thorns],
            seed: 42,
        )

        let (_, events) = context.applyTestDamage(
            10,
            to: context.roster.enemy.combatant,
            keyword: .physical,
            sourceActorID: context.roster.hero.combatant.id,
            applyDodge: false,
        )

        let thornsTriggers = events.filter { $0.effectKind == .thornsTriggered }
        try #expect(thornsTriggers.count == 1)
        try #expect(!context.roster.activeEffects(for: context.roster.enemy.combatant).contains {
            if case .thorns = $0.effect {
                return true
            }
            return false
        })
    }

    @Test func `mutual thorns consume without ping pong`() throws {
        let defenderThorns = ActiveEffect(id: 1, effect: .thorns(4), remainingTurns: 0)
        let attackerThorns = ActiveEffect(id: 2, effect: .thorns(4), remainingTurns: 0)
        var context = makeContext(
            targetMaxHealth: 200,
            targetEffects: [defenderThorns],
            seed: 42,
        )
        context.roster.setActiveEffects([attackerThorns], for: context.roster.hero.combatant)

        let (_, events) = context.applyTestDamage(
            10,
            to: context.roster.enemy.combatant,
            keyword: .physical,
            sourceActorID: context.roster.hero.combatant.id,
            applyDodge: false,
        )

        let thornsTriggers = events.filter { $0.effectKind == .thornsTriggered }
        try #expect(thornsTriggers.count == 1)
        try #expect(!context.roster.activeEffects(for: context.roster.enemy.combatant).contains {
            if case .thorns = $0.effect {
                return true
            }
            return false
        })
        try #expect(context.roster.activeEffects(for: context.roster.hero.combatant).contains {
            if case .thorns = $0.effect {
                return true
            }
            return false
        })
    }
}
