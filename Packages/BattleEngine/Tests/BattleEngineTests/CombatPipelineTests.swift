import BattleEngine
import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport

struct CombatPipelineTests {
    // MARK: - Helpers

    private func makeContext(
        targetMaxHealth: Int = 50,
        targetPrimaryStats: PrimaryStats = PrimaryStats(),
        targetEffects: [ActiveEffect] = [],
        sourcePrimaryStats: PrimaryStats = PrimaryStats(),
        seed: UInt64 = BattleTestFixtures.deterministicNonCriticalSeed
    ) -> BattleEngineContext {
        BattleTestFixtures.makePipelineContext(
            targetMaxHealth: targetMaxHealth,
            targetPrimaryStats: targetPrimaryStats,
            targetEffects: targetEffects,
            sourcePrimaryStats: sourcePrimaryStats,
            seed: seed
        )
    }

    private var target: Combatant {
        CombatantFixtures.combatant(id: "target", role: .enemy, maxHealth: 50)
    }

    // MARK: - Dodge

    @Test func applyDamageDodgeRespectsChanceAndSkipFlags() throws {
        // Cap dodge via agility: 0.05 + 280 * 0.0025 = 0.75
        let stats = PrimaryStats(agility: 280)
        var context = makeContext(targetPrimaryStats: stats, seed: 1772)
        let (lost, events) = context.applyTestDamage(10, to: context.roster.enemy.combatant, sourceActorID: "source")
        try #expect(lost == 0)
        try #expect(events.contains { $0.effectKind == .dodgeApplied })

        var noSourceContext = makeContext(seed: 1772)
        let (lostWithoutSource, _) = noSourceContext.applyTestDamage(10, to: noSourceContext.roster.enemy.combatant)
        try #expect(lostWithoutSource > 0)

        var disabledContext = makeContext(seed: 1772)
        let (lostWithDodgeDisabled, _) = disabledContext.applyTestDamage(
            10,
            to: disabledContext.roster.enemy.combatant,
            sourceActorID: "source",
            applyDodge: false
        )
        try #expect(lostWithDodgeDisabled > 0)
    }

    // MARK: - Shield absorption

    @Test func applyDamageShieldAbsorptionPreservesSourceActorID() throws {
        let shield = ActiveEffect(
            id: 1,
            effect: .shield(.block, 10),
            remainingTicks: 3,
            sourceActorID: "caster"
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

    // MARK: - Stat and item bonuses

    @Test func applyDamageStatBonusAppliesForSource() throws {
        let stats = PrimaryStats(strength: 25) // 25/5 = 5 bonus
        var context = makeContext(sourcePrimaryStats: stats, seed: 1772)
        let (lost, _) = context.applyTestDamage(10, to: context.roster.enemy.combatant, keyword: .physical, sourceActorID: "source")
        // 10 + 5 = 15
        try #expect(lost == 15)
    }

    // MARK: - Leech

    @Test func applyLeechFromDamageRequiresLeechSource() throws {
        var withoutLeech = makeContext(seed: 1772)
        _ = withoutLeech.applyTestDamage(10, to: withoutLeech.roster.enemy.combatant, sourceActorID: "source")
        try #expect(withoutLeech.applyLeechFromDamage(10, sourceActorID: "source").isEmpty)

        var withAbilityLeech = makeContext()
        withAbilityLeech.roster.mutateRuntime(for: withAbilityLeech.roster.hero.combatant) { $0.currentHealth = 30 }
        let beforeAbility = withAbilityLeech.roster.hero.currentHealth
        let abilityEvents = withAbilityLeech.applyLeechFromDamage(
            10,
            sourceActorID: "source",
            abilityHasLeech: true
        )
        try #expect(!(abilityEvents.isEmpty))
        try #expect(withAbilityLeech.roster.hero.currentHealth == beforeAbility + 5)

        let leech = ActiveEffect(id: 1, effect: .leech(.leech, 0.20, 3), remainingTicks: 3)
        var withEffect = makeContext()
        withEffect.roster.mutateRuntime(for: withEffect.roster.hero.combatant) { $0.currentHealth = 30 }
        withEffect.roster.setActiveEffects([leech], for: withEffect.roster.hero.combatant)
        let beforeEffect = withEffect.roster.hero.currentHealth
        let effectEvents = withEffect.applyLeechFromDamage(10, sourceActorID: "source")
        try #expect(!(effectEvents.isEmpty))
        try #expect(withEffect.roster.hero.currentHealth > beforeEffect)
    }

    // MARK: - Prevention buildup

    @Test func stunAndFreezeBuildupTrackedSeparatelyFromDamage() throws {
        var context = makeContext(seed: 1772)
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

    // MARK: - DoT damage

    @Test(arguments: ["dot", "direct", "self"] as [String])
    func applyDamageLeechMatrix(mode: String) throws {
        let leech = ActiveEffect(id: 1, effect: .leech(.leech, 1.0, 3), remainingTicks: 3)
        var context = makeContext(seed: 1772)
        context.roster.mutateRuntime(for: context.roster.hero.combatant) { $0.currentHealth = 30 }
        context.roster.setActiveEffects([leech], for: context.roster.hero.combatant)
        let before = context.roster.hero.currentHealth

        switch mode {
        case "dot":
            let (lost, events) = context.applyTestDoTDamage(
                10,
                keyword: .burn,
                to: context.roster.enemy.combatant,
                sourceActorID: "source"
            )
            try #expect(lost > 0)
            try #expect(context.roster.hero.currentHealth > before)
            try #expect(events.contains { $0.effectKind == .leechHeal })
        case "direct":
            let (_, events) = context.applyTestDamage(
                10,
                to: context.roster.enemy.combatant,
                keyword: .physical,
                sourceActorID: "source"
            )
            try #expect(context.roster.hero.currentHealth > before)
            try #expect(events.contains { $0.effectKind == .leechHeal })
        case "self":
            let (_, events) = context.applyTestDamage(
                10,
                to: context.roster.hero.combatant,
                keyword: .physical,
                sourceActorID: "source"
            )
            try #expect(context.roster.hero.currentHealth == before - 10)
            try #expect(!(events.contains { $0.effectKind == .leechHeal }))
        default:
            Issue.record("Unexpected leech mode \(mode)")
        }
    }

    // MARK: - Prevention threshold and post-mitigation buildup

    @Test func preventionThresholdUsesItemMaximumHealthBonus() throws {
        let target = CombatantFixtures.combatant(id: "target", role: .enemy, maxHealth: 50)
        let source = CombatantFixtures.combatant(id: "source", role: .hero, maxHealth: 50)
        let roster = BattleRoster(
            hero: CombatantRuntime(combatant: source, initialActiveEffects: []),
            companion: CombatantRuntime(combatant: CombatantFixtures.combatant(id: "companion", role: .companion)),
            enemy: CombatantRuntime(
                combatant: target,
                initialActiveEffects: [],
                maximumHealthBonus: 50
            )
        )
        var context = BattleEngineContext(
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

        context.applyControlMeter(1, keyword: .stun, to: target, sourceActorID: "source")

        let buildup = context.roster.enemy.activeEffects.first(where: \.effect.isControlMeter)
        let threshold = buildup?.effect.controlMeterValues?.threshold
        let expected = target.primaryStats.controlMeterThreshold(baseMaxHealth: 100)
        try #expect(threshold == expected)
    }

    @Test(arguments: [true, false])
    func stunBuildupTracksPostMitigationAndShieldAbsorbedHits(useShield: Bool) throws {
        if useShield {
            let shield = ActiveEffect(id: 1, effect: .shield(.block, 20), remainingTicks: 6)
            var context = makeContext(targetMaxHealth: 100, targetEffects: [shield], seed: 1772)
            let (lost, _) = context.applyTestDamage(
                5,
                to: context.roster.enemy.combatant,
                keyword: .stun,
                sourceActorID: "source"
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
                seed: 1772
            )
            _ = context.applyTestDamage(
                20,
                to: context.roster.enemy.combatant,
                keyword: .stun,
                sourceActorID: "source"
            )

            let buildup = context.roster.enemy.activeEffects.first(where: \.effect.isControlMeter)
            let amount = buildup?.effect.controlMeterValues?.amount
            // Toughness mitigation 3 vs 20 → remaining 17 for stun buildup
            try #expect(amount == 17)
        }
    }

    @Test func criticalHitIsAbsorbedByShieldBeforeHealth() throws {
        let shield = ActiveEffect(id: 1, effect: .shield(.block, 20), remainingTicks: 6)
        var context = makeContext(targetMaxHealth: 100, targetEffects: [shield], seed: 1772)
        let outcome = context.resolveDamage(
            DamageRequest(
                amount: 5,
                target: context.roster.enemy.combatant,
                keyword: .physical,
                sourceActorID: "source",
                options: DamageOptions(applyDodge: false, abilityCriticalChanceBonus: 1.0)
            )
        )

        try #expect(outcome.isCritical)
        try #expect(outcome.healthLost == 0, "Crit should multiply before shields absorb the final amount")
        let remainingBuffer = context.roster.enemy.activeEffects.compactMap { active -> Int? in
            guard case let .shield(_, buffer) = active.effect else { return nil }
            return buffer
        }.first
        try #expect(remainingBuffer == 10, "5 damage crit to 10 should consume 10 shield")
    }

    @Test func nonCrittableKeywordsNeverCriticalEvenWithAbilityBonus() throws {
        for keyword: Keyword in [.block, .dodge, .purge, .gold, .mana] {
            var context = makeContext(seed: 1772)
            let before = context.roster.enemy.currentHealth
            let outcome = context.resolveDamage(
                DamageRequest(
                    amount: 5,
                    target: context.roster.enemy.combatant,
                    keyword: keyword,
                    sourceActorID: "source",
                    options: DamageOptions(applyDodge: false, abilityCriticalChanceBonus: 1.0)
                )
            )
            try #expect(!outcome.isCritical, "\(keyword.rawValue)")
            try #expect(outcome.healthLost == 5, "\(keyword.rawValue)")
            try #expect(context.roster.enemy.currentHealth == before - 5, "\(keyword.rawValue)")
        }
    }

    @Test func guaranteedCriticalIfEnemyBuffedBypassesSoftCap() throws {
        let buff = ActiveEffect(id: 1, effect: .shield(.block, 2), remainingTicks: 6)
        // Seed whose first crit roll is in the 0.75...1.0 band that the soft cap
        // would reject — guaranteed path must still crit.
        var context = makeContext(targetEffects: [buff], seed: 1)
        let outcome = context.resolveDamage(
            DamageRequest(
                amount: 5,
                target: context.roster.enemy.combatant,
                keyword: .holy,
                sourceActorID: "source",
                options: DamageOptions(
                    applyDodge: false,
                    guaranteedCriticalIfEnemyBuffed: true
                )
            )
        )
        try #expect(outcome.isCritical)
    }

    // MARK: - Pipeline ordering

    @Test func thornsRetaliationDoesNotRecurse() throws {
        let thorns = ActiveEffect(id: 1, effect: .thorns(.physical, 5, 6), remainingTicks: 6)
        var context = makeContext(
            targetMaxHealth: 200,
            targetEffects: [thorns],
            seed: 42
        )
        context.roster.setActiveEffects([thorns], for: context.roster.hero.combatant)

        let (_, events) = context.applyTestDamage(
            10,
            to: context.roster.enemy.combatant,
            keyword: .physical,
            sourceActorID: context.roster.hero.combatant.id,
            applyDodge: false
        )

        let thornsTriggers = events.filter { $0.effectKind == .thornsTriggered }
        try #expect(thornsTriggers.count == 1)
    }
}
