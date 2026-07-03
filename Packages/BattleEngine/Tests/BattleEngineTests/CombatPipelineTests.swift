import XCTest
import BattleEngine
import TrinketCore
import TrinketContent

final class CombatPipelineTests: XCTestCase {
    // MARK: - Helpers

    private func makeContext(
        targetMaxHealth: Int = 50,
        targetPrimaryStats: PrimaryStats = PrimaryStats(),
        targetEffects: [ActiveEffect] = [],
        sourcePrimaryStats: PrimaryStats = PrimaryStats(),
        seed: UInt64 = 0
    ) -> BattleEngineContext {
        let target = CombatantFixtures.combatant(
            id: "target", role: .enemy, maxHealth: targetMaxHealth,
            primaryStats: targetPrimaryStats
        )
        let source = CombatantFixtures.combatant(
            id: "source", role: .hero, maxHealth: 50,
            primaryStats: sourcePrimaryStats
        )
        let roster = BattleRoster(
            hero: CombatantRuntime(combatant: source, initialActiveEffects: []),
            pet: CombatantRuntime(combatant: CombatantFixtures.combatant(id: "pet", role: .pet)),
            enemy: CombatantRuntime(combatant: target, initialActiveEffects: targetEffects)
        )
        return BattleEngineContext(
            roster: roster,
            rng: SeededRandomNumberGenerator(seed: seed),
            nextEffectID: 0,
            nextEventID: 0,
            events: [],
            gold: 0,
            initialGold: 0,
            build: BattleCombatBuild(hero: source, pet: target, heroModifiers: .zero, petModifiers: .zero)
        )
    }

    private var target: Combatant {
        CombatantFixtures.combatant(id: "target", role: .enemy, maxHealth: 50)
    }

    // MARK: - Dodge

    func testApplyDamageDodgeReturnsZeroWhenRollSucceeds() {
        // 100% dodge chance via agility
        let stats = PrimaryStats(agility: 140) // dodge chance = 0.05 + 140 * 0.005 = 0.75
        var context = makeContext(targetPrimaryStats: stats, seed: 0)
        let (lost, events) = CombatPipeline.applyDamage(10, to: context.roster.enemy.combatant, sourceActorID: "source", in: &context)
        XCTAssertEqual(lost, 0)
        XCTAssertTrue(events.contains { $0.effectKind == .dodgeApplied })
    }

    func testApplyDamageDodgeDoesNotTriggerWhenNoSourceActor() {
        var context = makeContext(seed: 0)
        let (lost, _) = CombatPipeline.applyDamage(10, to: context.roster.enemy.combatant, in: &context)
        XCTAssertGreaterThan(lost, 0)
    }

    func testApplyDamageDodgeDoesNotTriggerWhenApplyDodgeFalse() {
        var context = makeContext(seed: 0)
        let (lost, _) = CombatPipeline.applyDamage(10, to: context.roster.enemy.combatant, sourceActorID: "source", applyDodge: false, in: &context)
        XCTAssertGreaterThan(lost, 0)
    }

    // MARK: - Shield absorption

    func testApplyDamageShieldAbsorbsFully() {
        let shield = ActiveEffect(id: 1, effect: .shield(.block, 20, 3), remainingTicks: 3)
        var context = makeContext(targetEffects: [shield])
        let initial = context.roster.enemy.currentHealth
        let (lost, events) = CombatPipeline.applyDamage(10, to: context.roster.enemy.combatant, in: &context)
        XCTAssertEqual(lost, 0)
        XCTAssertEqual(context.roster.enemy.currentHealth, initial)
        XCTAssertTrue(events.contains { $0.effectKind == .shieldAbsorbed })
    }

    func testApplyDamageShieldAbsorbsPartially() {
        let shield = ActiveEffect(id: 1, effect: .shield(.block, 5, 3), remainingTicks: 3)
        var context = makeContext(targetEffects: [shield])
        let (lost, _) = CombatPipeline.applyDamage(10, to: context.roster.enemy.combatant, in: &context)
        XCTAssertGreaterThan(lost, 0)
        XCTAssertLessThan(lost, 10)
    }

    func testApplyDamageShieldRemovedWhenDepleted() {
        let shield = ActiveEffect(id: 1, effect: .shield(.block, 5, 3), remainingTicks: 3)
        var context = makeContext(targetEffects: [shield])
        _ = CombatPipeline.applyDamage(10, to: context.roster.enemy.combatant, in: &context)
        let effects = context.roster.enemy.activeEffects
        XCTAssertFalse(effects.contains { $0.id == 1 })
    }

    func testApplyDamageMultipleShieldsConsumedInOrder() {
        let s1 = ActiveEffect(id: 1, effect: .shield(.block, 5, 3), remainingTicks: 3)
        let s2 = ActiveEffect(id: 2, effect: .shield(.block, 10, 3), remainingTicks: 3)
        var context = makeContext(targetEffects: [s1, s2])
        let (lost, _) = CombatPipeline.applyDamage(12, to: context.roster.enemy.combatant, in: &context)
        // First shield absorbs 5, second absorbs 7, remaining 0 health lost from shield
        // Then damage: 12 - 5 - 7 = 0 dealt past shields
        // Wait: remaining starts at 12. s1 absorbs min(12,5)=5, remaining=7. s2 absorbs min(7,10)=7, remaining=0.
        XCTAssertEqual(lost, 0)
    }

    // MARK: - Mitigation

    func testApplyDamageMitigationReducesDamage() {
        let start = 20
        let mit = ActiveEffect(id: 1, effect: .mitigation(.armor, 0.25, 6), remainingTicks: 6)
        var context = makeContext(targetEffects: [mit])
        let (lost, _) = CombatPipeline.applyDamage(start, to: context.roster.enemy.combatant, in: &context)
        // 25% mitigation → 20 * 0.75 = 15
        XCTAssertEqual(lost, 15)
    }

    func testApplyDamageToughnessMitigationStacksWithArmor() {
        let stats = PrimaryStats(toughness: 50) // 50/(50+50) = 50% mitigation
        let mit = ActiveEffect(id: 1, effect: .mitigation(.armor, 0.25, 6), remainingTicks: 6)
        var context = makeContext(targetPrimaryStats: stats, targetEffects: [mit])
        let (lost, _) = CombatPipeline.applyDamage(20, to: context.roster.enemy.combatant, in: &context)
        // combined = min(1, 0.25 + 0.50) = 0.75
        // 20 * 0.25 = 5
        XCTAssertEqual(lost, 5)
    }

    // MARK: - Stat and item bonuses

    func testApplyDamageStatBonusAppliesForSource() {
        let stats = PrimaryStats(strength: 25) // 25/5 = 5 bonus
        var context = makeContext(sourcePrimaryStats: stats, seed: 0)
        let (lost, _) = CombatPipeline.applyDamage(10, to: context.roster.enemy.combatant, damageKeyword: .physical, sourceActorID: "source", in: &context)
        // 10 + 5 = 15
        XCTAssertEqual(lost, 15)
    }

    // MARK: - Leech

    func testApplyLeechFromDamageNoLeechEffectNoHeal() {
        var context = makeContext(seed: 0)
        _ = CombatPipeline.applyDamage(10, to: context.roster.enemy.combatant, sourceActorID: "source", in: &context)
        let events = CombatPipeline.applyLeechFromDamage(10, sourceActorID: "source", in: &context)
        XCTAssertTrue(events.isEmpty)
    }

    func testApplyLeechFromDamageWithLeechEffectHealsSource() {
        let leech = ActiveEffect(id: 1, effect: .leech(.leech, 0.20, 3), remainingTicks: 3)
        var context = makeContext()
        // Damage the hero so leech has room to heal
        context.roster.mutateRuntime(for: context.roster.hero.combatant) { $0.currentHealth = 30 }
        context.roster.setActiveEffects([leech], for: context.roster.hero.combatant)
        let before = context.roster.hero.currentHealth
        let events = CombatPipeline.applyLeechFromDamage(10, sourceActorID: "source", in: &context)
        XCTAssertFalse(events.isEmpty)
        XCTAssertGreaterThan(context.roster.hero.currentHealth, before)
    }

    // MARK: - Heal

    func testApplyHealRestoresHealth() {
        var context = makeContext(seed: 0)
        // Damage first, then heal
        _ = CombatPipeline.applyDamage(10, to: context.roster.enemy.combatant, in: &context)
        let before = context.roster.enemy.currentHealth
        CombatPipeline.applyHeal(5, to: context.roster.enemy.combatant, sourceActorID: nil, in: &context)
        XCTAssertEqual(context.roster.enemy.currentHealth, before + 5)
    }

    func testApplyHealCappedAtMaxHealth() {
        var context = makeContext(targetMaxHealth: 50, seed: 0)
        CombatPipeline.applyHeal(100, to: context.roster.enemy.combatant, sourceActorID: nil, in: &context)
        XCTAssertEqual(context.roster.enemy.currentHealth, 50)
    }

    // MARK: - Prevention buildup

    func testApplyPreventionBuildupAccumulatesAndTriggersPrevention() {
        var context = makeContext(seed: 0)
        // Low health target to hit threshold quickly
        // With PrimaryStats() agility=0, threshold = ceil(50 * 0.20 * 1.0) = 10
        // So 10+ buildup should trigger
        let events = CombatPipeline.applyPreventionBuildup(15, keyword: .stun, to: context.roster.enemy.combatant, sourceActorID: "source", in: &context)
        XCTAssertTrue(events.contains { $0.effectKind == .preventionTriggered })
        XCTAssertTrue(context.roster.enemy.activeEffects.contains(where: { if case .prevention = $0.effect { return true }; return false }))
    }

    func testApplyPreventionBuildupNoDuplicateWhenPreventionActive() {
        var context = makeContext(targetEffects: [
            ActiveEffect(id: 1, effect: .prevention(.stun, 2), remainingTicks: 2)
        ], seed: 0)
        let events = CombatPipeline.applyPreventionBuildup(15, keyword: .stun, to: context.roster.enemy.combatant, sourceActorID: "source", in: &context)
        XCTAssertTrue(events.isEmpty)
    }

    // MARK: - DoT damage

    func testApplyDoTDamageDealsDamage() {
        var context = makeContext(seed: 0)
        let (lost, _) = CombatPipeline.applyDoTDamage(10, keyword: .burn, to: context.roster.enemy.combatant, sourceActorID: nil, in: &context)
        XCTAssertGreaterThan(lost, 0)
    }

    func testApplyDoTDamageAppliesLeechWhenSourceActorPresent() {
        let leech = ActiveEffect(id: 1, effect: .leech(.leech, 1.0, 3), remainingTicks: 3)
        var context = makeContext(seed: 0)
        context.roster.mutateRuntime(for: context.roster.hero.combatant) { $0.currentHealth = 30 }
        context.roster.setActiveEffects([leech], for: context.roster.hero.combatant)
        let before = context.roster.hero.currentHealth
        let (lost, events) = CombatPipeline.applyDoTDamage(10, keyword: .burn, to: context.roster.enemy.combatant, sourceActorID: "source", in: &context)
        XCTAssertGreaterThan(lost, 0)
        XCTAssertGreaterThan(context.roster.hero.currentHealth, before)
        XCTAssertTrue(events.contains { $0.effectKind == .leechHeal })
    }

    func testApplyDamageTriggersLeechOnDirectHit() {
        let leech = ActiveEffect(id: 1, effect: .leech(.leech, 1.0, 3), remainingTicks: 3)
        var context = makeContext(seed: 0)
        context.roster.mutateRuntime(for: context.roster.hero.combatant) { $0.currentHealth = 30 }
        context.roster.setActiveEffects([leech], for: context.roster.hero.combatant)
        let before = context.roster.hero.currentHealth
        let (_, events) = CombatPipeline.applyDamage(
            10,
            to: context.roster.enemy.combatant,
            damageKeyword: .physical,
            sourceActorID: "source",
            in: &context
        )
        XCTAssertGreaterThan(context.roster.hero.currentHealth, before)
        XCTAssertTrue(events.contains { $0.effectKind == .leechHeal })
    }

    func testApplyDamageDoesNotLeechOnSelfDamage() {
        let leech = ActiveEffect(id: 1, effect: .leech(.leech, 1.0, 3), remainingTicks: 3)
        var context = makeContext(seed: 0)
        context.roster.mutateRuntime(for: context.roster.hero.combatant) { $0.currentHealth = 30 }
        context.roster.setActiveEffects([leech], for: context.roster.hero.combatant)
        let before = context.roster.hero.currentHealth
        let (_, events) = CombatPipeline.applyDamage(
            10,
            to: context.roster.hero.combatant,
            damageKeyword: .physical,
            sourceActorID: "source",
            in: &context
        )
        XCTAssertEqual(context.roster.hero.currentHealth, before - 10)
        XCTAssertFalse(events.contains { $0.effectKind == .leechHeal })
    }

    // MARK: - Prevention threshold and post-mitigation buildup

    func testPreventionThresholdUsesItemMaximumHealthBonus() {
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
            rng: SeededRandomNumberGenerator(seed: 0),
            nextEffectID: 0,
            nextEventID: 0,
            events: [],
            gold: 0,
            initialGold: 0,
            build: BattleCombatBuild(hero: source, pet: target, heroModifiers: .zero, petModifiers: .zero)
        )

        CombatPipeline.applyPreventionBuildup(1, keyword: .stun, to: target, sourceActorID: "source", in: &context)

        let buildup = context.roster.enemy.activeEffects.first { $0.effect.isPreventionBuildup }
        let threshold = buildup?.effect.preventionBuildupValues?.2
        let expected = target.primaryStats.preventionThreshold(baseMaxHealth: 100)
        XCTAssertEqual(threshold, expected)
    }

    func testStunBuildupUsesPostMitigationDamage() {
        let mit = ActiveEffect(id: 1, effect: .mitigation(.armor, 0.50, 6), remainingTicks: 6)
        var context = makeContext(targetMaxHealth: 100, targetEffects: [mit], seed: 0)
        _ = CombatPipeline.applyDamage(
            20,
            to: context.roster.enemy.combatant,
            damageKeyword: .stun,
            sourceActorID: "source",
            in: &context
        )

        let buildup = context.roster.enemy.activeEffects.first { $0.effect.isPreventionBuildup }
        let amount = buildup?.effect.preventionBuildupValues?.1
        XCTAssertEqual(amount, 10, "50% mitigation should halve stun buildup from 20 to 10")
    }

    // MARK: - Pipeline ordering

    func testDamageStepsRunInCanonicalOrder() {
        XCTAssertEqual(DamageSteps.canonicalNames, [
            "DodgeGate",
            "DamageBonus",
            "ShieldAbsorption",
            "Mitigation",
            "ItemReduction",
            "TakeDamage",
            "Leech",
            "PreventionBuildup"
        ])
    }
}
