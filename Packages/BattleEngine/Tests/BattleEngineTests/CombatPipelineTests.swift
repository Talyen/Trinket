import Testing
import BattleEngine
import TrinketCore
import TrinketContent

@Suite
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

    @Test func applyDamageDodgeReturnsZeroWhenRollSucceeds() {
        // 100% dodge chance via agility
        let stats = PrimaryStats(agility: 140) // dodge chance = 0.05 + 140 * 0.005 = 0.75
        var context = makeContext(targetPrimaryStats: stats, seed: 1772)
        let (lost, events) = context.applyTestDamage(10, to: context.roster.enemy.combatant, sourceActorID: "source")
        #expect(lost == 0)
        #expect(events.contains { $0.effectKind == .dodgeApplied })
    }

    @Test func applyDamageDodgeDoesNotTriggerWhenNoSourceActor() {
        var context = makeContext(seed: 1772)
        let (lost, _) = context.applyTestDamage(10, to: context.roster.enemy.combatant)
        #expect(lost > 0)
    }

    @Test func applyDamageDodgeDoesNotTriggerWhenApplyDodgeFalse() {
        var context = makeContext(seed: 1772)
        let (lost, _) = context.applyTestDamage(10, to: context.roster.enemy.combatant, sourceActorID: "source", applyDodge: false)
        #expect(lost > 0)
    }

    // MARK: - Shield absorption

    @Test func applyDamageShieldAbsorbsFully() {
        let shield = ActiveEffect(id: 1, effect: .shield(.block, 20, 3), remainingTicks: 3)
        var context = makeContext(targetEffects: [shield])
        let initial = context.roster.enemy.currentHealth
        let (lost, events) = context.applyTestDamage(10, to: context.roster.enemy.combatant)
        #expect(lost == 0)
        #expect(context.roster.enemy.currentHealth == initial)
        #expect(events.contains { $0.effectKind == .shieldAbsorbed })
    }

    @Test func applyDamageShieldAbsorbsPartially() {
        let shield = ActiveEffect(id: 1, effect: .shield(.block, 5, 3), remainingTicks: 3)
        var context = makeContext(targetEffects: [shield])
        let (lost, _) = context.applyTestDamage(10, to: context.roster.enemy.combatant)
        #expect(lost > 0)
        #expect(lost < 10)
    }

    @Test func applyDamageShieldAbsorptionPreservesSourceActorID() {
        let shield = ActiveEffect(
            id: 1,
            effect: .shield(.block, 10, 3),
            remainingTicks: 3,
            sourceActorID: "caster"
        )
        var context = makeContext(targetEffects: [shield])
        _ = context.applyTestDamage(4, to: context.roster.enemy.combatant)

        let updatedShield = context.roster.enemy.activeEffects.first { $0.id == 1 }
        #expect(updatedShield?.sourceActorID == "caster")
        if case let .shield(_, buffer, _) = updatedShield?.effect {
            #expect(buffer == 6)
        } else {
            Issue.record("Expected partial shield to remain")
        }
    }

    @Test func applyDamageShieldRemovedWhenDepleted() {
        let shield = ActiveEffect(id: 1, effect: .shield(.block, 5, 3), remainingTicks: 3)
        var context = makeContext(targetEffects: [shield])
        _ = context.applyTestDamage(10, to: context.roster.enemy.combatant)
        let effects = context.roster.enemy.activeEffects
        #expect(!(effects.contains { $0.id == 1 }))
    }

    @Test func applyDamageMultipleShieldsConsumedInOrder() {
        let s1 = ActiveEffect(id: 1, effect: .shield(.block, 5, 3), remainingTicks: 3)
        let s2 = ActiveEffect(id: 2, effect: .shield(.block, 10, 3), remainingTicks: 3)
        var context = makeContext(targetEffects: [s1, s2])
        let (lost, _) = context.applyTestDamage(12, to: context.roster.enemy.combatant)
        // First shield absorbs 5, second absorbs 7, remaining 0 health lost from shield
        // Then damage: 12 - 5 - 7 = 0 dealt past shields
        // Wait: remaining starts at 12. s1 absorbs min(12,5)=5, remaining=7. s2 absorbs min(7,10)=7, remaining=0.
        #expect(lost == 0)
    }

    // MARK: - Mitigation

    @Test func applyDamageMitigationReducesDamage() {
        let start = 20
        let mit = ActiveEffect(id: 1, effect: .mitigation(.armor, 0.25, 6), remainingTicks: 6)
        var context = makeContext(targetEffects: [mit])
        let (lost, _) = context.applyTestDamage(start, to: context.roster.enemy.combatant)
        // 25% mitigation → 20 * 0.75 = 15
        #expect(lost == 15)
    }

    @Test func applyDamageToughnessMitigationStacksWithArmor() {
        let stats = PrimaryStats(toughness: 50) // 50/(50+50) = 50% mitigation
        let mit = ActiveEffect(id: 1, effect: .mitigation(.armor, 0.25, 6), remainingTicks: 6)
        var context = makeContext(targetPrimaryStats: stats, targetEffects: [mit])
        let (lost, _) = context.applyTestDamage(20, to: context.roster.enemy.combatant)
        // combined = min(1, 0.25 + 0.50) = 0.75
        // 20 * 0.25 = 5
        #expect(lost == 5)
    }

    // MARK: - Stat and item bonuses

    @Test func applyDamageStatBonusAppliesForSource() {
        let stats = PrimaryStats(strength: 25) // 25/5 = 5 bonus
        var context = makeContext(sourcePrimaryStats: stats, seed: 1772)
        let (lost, _) = context.applyTestDamage(10, to: context.roster.enemy.combatant, keyword: .physical, sourceActorID: "source")
        // 10 + 5 = 15
        #expect(lost == 15)
    }

    // MARK: - Leech

    @Test func applyLeechFromDamageNoLeechEffectNoHeal() {
        var context = makeContext(seed: 1772)
        _ = context.applyTestDamage(10, to: context.roster.enemy.combatant, sourceActorID: "source")
        let events = context.applyLeechFromDamage(10, sourceActorID: "source")
        #expect(events.isEmpty)
    }

    @Test func applyLeechFromDamageWithLeechEffectHealsSource() {
        let leech = ActiveEffect(id: 1, effect: .leech(.leech, 0.20, 3), remainingTicks: 3)
        var context = makeContext()
        // Damage the hero so leech has room to heal
        context.roster.mutateRuntime(for: context.roster.hero.combatant) { $0.currentHealth = 30 }
        context.roster.setActiveEffects([leech], for: context.roster.hero.combatant)
        let before = context.roster.hero.currentHealth
        let events = context.applyLeechFromDamage(10, sourceActorID: "source")
        #expect(!(events.isEmpty))
        #expect(context.roster.hero.currentHealth > before)
    }

    // MARK: - Heal

    @Test func applyHealRestoresHealth() {
        var context = makeContext(seed: 1772)
        // Damage first, then heal
        _ = context.applyTestDamage(10, to: context.roster.enemy.combatant)
        let before = context.roster.enemy.currentHealth
        context.applyTestHeal(5, to: context.roster.enemy.combatant, sourceActorID: nil)
        #expect(context.roster.enemy.currentHealth == before + 5)
    }

    @Test func applyHealCappedAtMaxHealth() {
        var context = makeContext(targetMaxHealth: 50, seed: 1772)
        context.applyTestHeal(100, to: context.roster.enemy.combatant, sourceActorID: nil)
        #expect(context.roster.enemy.currentHealth == 50)
    }

    // MARK: - Prevention buildup

    @Test func applyControlMeterAccumulatesAndTriggersAtThreshold() {
        var context = makeContext(seed: 1772)
        let events = context.applyControlMeter(15, keyword: .stun, to: context.roster.enemy.combatant, sourceActorID: "source")
        #expect(events.contains { $0.effectKind == .controlTriggered })
        #expect(context.roster.enemy.activeEffects.contains(where: \.effect.isActionSkipPending))
    }

    @Test func applyControlMeterNoDuplicateWhenSameKeywordSkipPending() {
        var context = makeContext(targetEffects: [
            ActiveEffect(id: 1, effect: .controlMeter(.stun, 10, 10), remainingTicks: 0)
        ], seed: 1772)
        let events = context.applyControlMeter(15, keyword: .stun, to: context.roster.enemy.combatant, sourceActorID: "source")
        #expect(events.isEmpty)
    }

    @Test func applyControlMeterAllowsOtherKeywordWhileSkipPending() throws {
        var context = makeContext(targetEffects: [
            ActiveEffect(id: 1, effect: .controlMeter(.stun, 10, 10), remainingTicks: 0)
        ], seed: 1772)
        let target = context.roster.enemy.combatant
        let events = context.applyControlMeter(4, keyword: .freeze, to: target, sourceActorID: "source")
        #expect(events.isEmpty)
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

    @Test func applyDoTDamageDealsDamage() {
        var context = makeContext(seed: 1772)
        let (lost, _) = context.applyTestDoTDamage(10, keyword: .burn, to: context.roster.enemy.combatant, sourceActorID: nil)
        #expect(lost > 0)
    }

    @Test func applyDoTDamageAppliesLeechWhenSourceActorPresent() {
        let leech = ActiveEffect(id: 1, effect: .leech(.leech, 1.0, 3), remainingTicks: 3)
        var context = makeContext(seed: 1772)
        context.roster.mutateRuntime(for: context.roster.hero.combatant) { $0.currentHealth = 30 }
        context.roster.setActiveEffects([leech], for: context.roster.hero.combatant)
        let before = context.roster.hero.currentHealth
        let (lost, events) = context.applyTestDoTDamage(10, keyword: .burn, to: context.roster.enemy.combatant, sourceActorID: "source")
        #expect(lost > 0)
        #expect(context.roster.hero.currentHealth > before)
        #expect(events.contains { $0.effectKind == .leechHeal })
    }

    @Test func applyDamageTriggersLeechOnDirectHit() {
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
        #expect(context.roster.hero.currentHealth > before)
        #expect(events.contains { $0.effectKind == .leechHeal })
    }

    @Test func applyDamageDoesNotLeechOnSelfDamage() {
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
        #expect(context.roster.hero.currentHealth == before - 10)
        #expect(!(events.contains { $0.effectKind == .leechHeal }))
    }

    // MARK: - Prevention threshold and post-mitigation buildup

    @Test func preventionThresholdUsesItemMaximumHealthBonus() {
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
        #expect(threshold == expected)
    }

    @Test func stunBuildupUsesPostMitigationDamage() {
        let mit = ActiveEffect(id: 1, effect: .mitigation(.armor, 0.50, 6), remainingTicks: 6)
        var context = makeContext(targetMaxHealth: 100, targetEffects: [mit], seed: 1772)
        _ = context.applyTestDamage(
            20,
            to: context.roster.enemy.combatant,
            keyword: .stun,
            sourceActorID: "source"
        )

        let buildup = context.roster.enemy.activeEffects.first { $0.effect.isControlMeter }
        let amount = buildup?.effect.controlMeterValues?.amount
        #expect(amount == 10, "50% mitigation should halve stun buildup from 20 to 10")
    }

    @Test func stunBuildupDoesNotApplyWhenShieldAbsorbsAllDamage() {
        let shield = ActiveEffect(id: 1, effect: .shield(.block, 20, 6), remainingTicks: 6)
        var context = makeContext(targetMaxHealth: 100, targetEffects: [shield], seed: 1772)
        let (lost, _) = context.applyTestDamage(
            5,
            to: context.roster.enemy.combatant,
            keyword: .stun,
            sourceActorID: "source"
        )

        #expect(lost == 0)
        let buildup = context.roster.enemy.activeEffects.first { $0.effect.isControlMeter }
        #expect(buildup, "Fully shielded hits should not build control meters" == nil)
    }

    // MARK: - Pipeline ordering

    @Test func damageStepsRunInCanonicalOrder() {
        #expect(DamagePipeline.canonicalNames == [
            "DodgeGate",
            "CriticalGate",
            "DamageBonus",
            "MarkedBonus",
            "Mitigation",
            "ItemReduction",
            "ShieldAbsorption",
            "CriticalMultiply",
            "TakeDamage",
            "MarkedConsume",
            "DeathsDoor",
            "Leech",
            "ControlMeter",
            "ReactiveOnHit"
        ])
    }

    @Test func thornsRetaliationDoesNotRecurse() {
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
        #expect(thornsTriggers.count == 1)
    }
}
