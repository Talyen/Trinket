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

    @Test func applyDamageDodgeReturnsZeroWhenRollSucceeds() throws {
        // 100% dodge chance via agility
        let stats = PrimaryStats(agility: 140) // dodge chance = 0.05 + 140 * 0.005 = 0.75
        var context = makeContext(targetPrimaryStats: stats, seed: 1772)
        let (lost, events) = context.applyTestDamage(10, to: context.roster.enemy.combatant, sourceActorID: "source")
        try #expect(lost == 0)
        try #expect(events.contains { $0.effectKind == .dodgeApplied })
    }

    @Test func applyDamageDodgeDoesNotTriggerWhenNoSourceActor() throws {
        var context = makeContext(seed: 1772)
        let (lost, _) = context.applyTestDamage(10, to: context.roster.enemy.combatant)
        try #expect(lost > 0)
    }

    @Test func applyDamageDodgeDoesNotTriggerWhenApplyDodgeFalse() throws {
        var context = makeContext(seed: 1772)
        let (lost, _) = context.applyTestDamage(10, to: context.roster.enemy.combatant, sourceActorID: "source", applyDodge: false)
        try #expect(lost > 0)
    }

    // MARK: - Shield absorption

    @Test func applyDamageShieldAbsorbsFully() throws {
        let shield = ActiveEffect(id: 1, effect: .shield(.block, 20), remainingTicks: 3)
        var context = makeContext(targetEffects: [shield])
        let initial = context.roster.enemy.currentHealth
        let (lost, events) = context.applyTestDamage(10, to: context.roster.enemy.combatant)
        try #expect(lost == 0)
        try #expect(context.roster.enemy.currentHealth == initial)
        try #expect(events.contains { $0.effectKind == .shieldAbsorbed })
    }

    @Test func applyDamageShieldAbsorbsPartially() throws {
        let shield = ActiveEffect(id: 1, effect: .shield(.block, 5), remainingTicks: 3)
        var context = makeContext(targetEffects: [shield])
        let (lost, _) = context.applyTestDamage(10, to: context.roster.enemy.combatant)
        try #expect(lost > 0)
        try #expect(lost < 10)
    }

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

    @Test func applyDamageShieldRemovedWhenDepleted() throws {
        let shield = ActiveEffect(id: 1, effect: .shield(.block, 5), remainingTicks: 3)
        var context = makeContext(targetEffects: [shield])
        _ = context.applyTestDamage(10, to: context.roster.enemy.combatant)
        let effects = context.roster.enemy.activeEffects
        try #expect(!(effects.contains { $0.id == 1 }))
    }

    @Test func applyDamageSingleBlockPoolAbsorbsFully() throws {
        let block = ActiveEffect(id: 1, effect: .shield(.block, 15), remainingTicks: 0)
        var context = makeContext(targetEffects: [block])
        let (lost, _) = context.applyTestDamage(12, to: context.roster.enemy.combatant)
        try #expect(lost == 0)
        let remaining = context.roster.enemy.activeEffects.compactMap { active -> Int? in
            guard case let .shield(_, buffer) = active.effect else { return nil }
            return buffer
        }.first
        try #expect(remaining == 3)
    }

    // MARK: - Mitigation

    @Test func applyDamageMitigationReducesDamage() throws {
        let start = 20
        let mit = ActiveEffect(id: 1, effect: .mitigation(.armor, 2), remainingTicks: 0)
        var context = makeContext(targetEffects: [mit])
        let (lost, _) = context.applyTestDamage(start, to: context.roster.enemy.combatant)
        // Flat Armor 2, capped at floor(20/2)=10 → reduce by 2 → 18
        try #expect(lost == 18)
    }

    @Test func applyDamageToughnessMitigationStacksWithArmor() throws {
        let stats = PrimaryStats(toughness: 50) // armorEffectivenessBonus = 10
        let mit = ActiveEffect(id: 1, effect: .mitigation(.armor, 2), remainingTicks: 0)
        var context = makeContext(targetPrimaryStats: stats, targetEffects: [mit])
        let (lost, _) = context.applyTestDamage(20, to: context.roster.enemy.combatant)
        // effective Armor 12, capped at floor(20/2)=10 → reduce by 10 → 10
        try #expect(lost == 10)
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

    @Test func applyLeechFromDamageNoLeechEffectNoHeal() throws {
        var context = makeContext(seed: 1772)
        _ = context.applyTestDamage(10, to: context.roster.enemy.combatant, sourceActorID: "source")
        let events = context.applyLeechFromDamage(10, sourceActorID: "source")
        try #expect(events.isEmpty)
    }

    @Test func applyLeechFromDamageWithLeechEffectHealsSource() throws {
        let leech = ActiveEffect(id: 1, effect: .leech(.leech, 0.20, 3), remainingTicks: 3)
        var context = makeContext()
        // Damage the hero so leech has room to heal
        context.roster.mutateRuntime(for: context.roster.hero.combatant) { $0.currentHealth = 30 }
        context.roster.setActiveEffects([leech], for: context.roster.hero.combatant)
        let before = context.roster.hero.currentHealth
        let events = context.applyLeechFromDamage(10, sourceActorID: "source")
        try #expect(!(events.isEmpty))
        try #expect(context.roster.hero.currentHealth > before)
    }

    @Test func applyLeechFromDamageWithAbilityKeywordHealsSource() throws {
        var context = makeContext()
        context.roster.mutateRuntime(for: context.roster.hero.combatant) { $0.currentHealth = 30 }
        let before = context.roster.hero.currentHealth
        let events = context.applyLeechFromDamage(10, sourceActorID: "source", abilityHasLeech: true)
        try #expect(!(events.isEmpty))
        try #expect(context.roster.hero.currentHealth == before + 5)
    }

    // MARK: - Heal

    @Test func applyHealRestoresHealth() throws {
        var context = makeContext(seed: 1772)
        // Damage first, then heal
        _ = context.applyTestDamage(10, to: context.roster.enemy.combatant)
        let before = context.roster.enemy.currentHealth
        context.applyTestHeal(5, to: context.roster.enemy.combatant, sourceActorID: nil)
        try #expect(context.roster.enemy.currentHealth == before + 5)
    }

    @Test func applyHealCappedAtMaxHealth() throws {
        var context = makeContext(targetMaxHealth: 50, seed: 1772)
        context.applyTestHeal(100, to: context.roster.enemy.combatant, sourceActorID: nil)
        try #expect(context.roster.enemy.currentHealth == 50)
    }

    // MARK: - Prevention buildup

    @Test func applyControlMeterAccumulatesAndTriggersAtThreshold() throws {
        var context = makeContext(seed: 1772)
        let events = context.applyControlMeter(15, keyword: .stun, to: context.roster.enemy.combatant, sourceActorID: "source")
        try #expect(events.contains { $0.effectKind == .controlTriggered })
        try #expect(context.roster.enemy.activeEffects.contains(where: \.effect.isActionSkipPending))
    }

    @Test func applyControlMeterNoDuplicateWhenSameKeywordSkipPending() throws {
        var context = makeContext(targetEffects: [
            ActiveEffect(id: 1, effect: .controlMeter(.stun, 10, 10), remainingTicks: 0)
        ], seed: 1772)
        let events = context.applyControlMeter(15, keyword: .stun, to: context.roster.enemy.combatant, sourceActorID: "source")
        try #expect(events.isEmpty)
    }

    @Test func applyControlMeterAllowsOtherKeywordWhileSkipPending() throws {
        var context = makeContext(targetEffects: [
            ActiveEffect(id: 1, effect: .controlMeter(.stun, 10, 10), remainingTicks: 0)
        ], seed: 1772)
        let target = context.roster.enemy.combatant
        let events = context.applyControlMeter(4, keyword: .freeze, to: target, sourceActorID: "source")
        try #expect(events.isEmpty)
        let freezeMeter = context.roster.activeEffects(for: target).first {
            guard case let .controlMeter(keyword, amount, _) = $0.effect else { return false }
            return keyword == .freeze && amount == 4
        }
        _ = try #require(freezeMeter)
    }

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

    @Test func applyDoTDamageDealsDamage() throws {
        var context = makeContext(seed: 1772)
        let (lost, _) = context.applyTestDoTDamage(10, keyword: .burn, to: context.roster.enemy.combatant, sourceActorID: nil)
        try #expect(lost > 0)
    }

    @Test func applyDoTDamageAppliesLeechWhenSourceActorPresent() throws {
        let leech = ActiveEffect(id: 1, effect: .leech(.leech, 1.0, 3), remainingTicks: 3)
        var context = makeContext(seed: 1772)
        context.roster.mutateRuntime(for: context.roster.hero.combatant) { $0.currentHealth = 30 }
        context.roster.setActiveEffects([leech], for: context.roster.hero.combatant)
        let before = context.roster.hero.currentHealth
        let (lost, events) = context.applyTestDoTDamage(10, keyword: .burn, to: context.roster.enemy.combatant, sourceActorID: "source")
        try #expect(lost > 0)
        try #expect(context.roster.hero.currentHealth > before)
        try #expect(events.contains { $0.effectKind == .leechHeal })
    }

    @Test func applyDamageTriggersLeechOnDirectHit() throws {
        let leech = ActiveEffect(id: 1, effect: .leech(.leech, 1.0, 3), remainingTicks: 3)
        var context = makeContext(seed: 1772)
        context.roster.mutateRuntime(for: context.roster.hero.combatant) { $0.currentHealth = 30 }
        context.roster.setActiveEffects([leech], for: context.roster.hero.combatant)
        let before = context.roster.hero.currentHealth
        let (_, events) = context.applyTestDamage(
            10,
            to: context.roster.enemy.combatant,
            keyword: .physical,
            sourceActorID: "source"
        )
        try #expect(context.roster.hero.currentHealth > before)
        try #expect(events.contains { $0.effectKind == .leechHeal })
    }

    @Test func applyDamageDoesNotLeechOnSelfDamage() throws {
        let leech = ActiveEffect(id: 1, effect: .leech(.leech, 1.0, 3), remainingTicks: 3)
        var context = makeContext(seed: 1772)
        context.roster.mutateRuntime(for: context.roster.hero.combatant) { $0.currentHealth = 30 }
        context.roster.setActiveEffects([leech], for: context.roster.hero.combatant)
        let before = context.roster.hero.currentHealth
        let (_, events) = context.applyTestDamage(
            10,
            to: context.roster.hero.combatant,
            keyword: .physical,
            sourceActorID: "source"
        )
        try #expect(context.roster.hero.currentHealth == before - 10)
        try #expect(!(events.contains { $0.effectKind == .leechHeal }))
    }

    // MARK: - Prevention threshold and post-mitigation buildup

    @Test func preventionThresholdUsesItemMaximumHealthBonus() throws {
        let target = CombatantFixtures.combatant(id: "target", role: .enemy, maxHealth: 50)
        let source = CombatantFixtures.combatant(id: "source", role: .hero, maxHealth: 50)
        let roster = BattleRoster(
            hero: CombatantRuntime(combatant: source, initialActiveEffects: []),
            pet: CombatantRuntime(combatant: CombatantFixtures.combatant(id: "pet", role: .pet)),
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
            petModifiers: .zero,
            enemyModifiers: .zero
        )

        context.applyControlMeter(1, keyword: .stun, to: target, sourceActorID: "source")

        let buildup = context.roster.enemy.activeEffects.first { $0.effect.isControlMeter }
        let threshold = buildup?.effect.controlMeterValues?.threshold
        let expected = target.primaryStats.controlMeterThreshold(baseMaxHealth: 100)
        try #expect(threshold == expected)
    }

    @Test func stunBuildupUsesPostMitigationDamage() throws {
        let mit = ActiveEffect(id: 1, effect: .mitigation(.armor, 3), remainingTicks: 0)
        var context = makeContext(targetMaxHealth: 100, targetEffects: [mit], seed: 1772)
        _ = context.applyTestDamage(
            20,
            to: context.roster.enemy.combatant,
            keyword: .stun,
            sourceActorID: "source"
        )

        let buildup = context.roster.enemy.activeEffects.first { $0.effect.isControlMeter }
        let amount = buildup?.effect.controlMeterValues?.amount
        // Flat Armor 3 vs 20 → remaining 17 for stun buildup
        try #expect(amount == 17)
    }

    @Test func stunBuildupAppliesWhenShieldAbsorbsAllDamage() throws {
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
    }

    @Test func criticalHitIsAbsorbedByShieldBeforeHealth() throws {
        let shield = ActiveEffect(id: 1, effect: .shield(.block, 20), remainingTicks: 6)
        var context = makeContext(targetMaxHealth: 100, targetEffects: [shield], seed: 1772)
        let (lost, events) = context.applyTestDamage(
            5,
            to: context.roster.enemy.combatant,
            keyword: .physical,
            sourceActorID: "source",
            applyDodge: false,
            abilityCriticalChanceBonus: 1.0
        )

        try #expect(events.contains { $0.effectKind == .criticalApplied })
        try #expect(lost == 0, "Crit should multiply before shields absorb the final amount")
        let remainingBuffer = context.roster.enemy.activeEffects.compactMap { active -> Int? in
            guard case let .shield(_, buffer) = active.effect else { return nil }
            return buffer
        }.first
        try #expect(remainingBuffer == 10, "5 damage crit to 10 should consume 10 shield")
    }

    // MARK: - Pipeline ordering

    @Test func damageStepsRunInCanonicalOrder() throws {
        try #expect(DamagePipeline.canonicalNames == [
            "DodgeGate",
            "CriticalGate",
            "DamageBonus",
            "Hexmark",
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
            "ReactiveOnHit"
        ])
    }

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
