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
        seed: UInt64 = 1772
    ) -> BattleEngineContext {
        let target = CombatantFixtures.combatant(
            id: "target", role: .enemy, maxHealth: targetMaxHealth,
            primaryStats: targetPrimaryStats
        )
        let source = CombatantFixtures.combatant(
            id: "source", role: .hero, maxHealth: 50,
            primaryStats: sourcePrimaryStats
        )
        let pet = CombatantFixtures.combatant(id: "pet", role: .pet)
        let roster = BattleRoster(
            hero: CombatantRuntime(combatant: source, initialActiveEffects: []),
            pet: CombatantRuntime(combatant: pet),
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
            build: BattleCombatBuild(
                hero: source,
                pet: pet,
                enemy: target,
                heroModifiers: .zero,
                petModifiers: .zero
            )
        )
    }

    private var target: Combatant {
        CombatantFixtures.combatant(id: "target", role: .enemy, maxHealth: 50)
    }

    // MARK: - Dodge

    func testApplyDamageDodgeReturnsZeroWhenRollSucceeds() {
        // 100% dodge chance via agility
        let stats = PrimaryStats(agility: 140) // dodge chance = 0.05 + 140 * 0.005 = 0.75
        var context = makeContext(targetPrimaryStats: stats, seed: 1772)
        let (lost, events) = context.applyDamage(10, to: context.roster.enemy.combatant, sourceActorID: "source")
        XCTAssertEqual(lost, 0)
        XCTAssertTrue(events.contains { $0.effectKind == .dodgeApplied })
    }

    func testApplyDamageDodgeDoesNotTriggerWhenNoSourceActor() {
        var context = makeContext(seed: 1772)
        let (lost, _) = context.applyDamage(10, to: context.roster.enemy.combatant)
        XCTAssertGreaterThan(lost, 0)
    }

    func testApplyDamageDodgeDoesNotTriggerWhenApplyDodgeFalse() {
        var context = makeContext(seed: 1772)
        let (lost, _) = context.applyDamage(10, to: context.roster.enemy.combatant, sourceActorID: "source", applyDodge: false)
        XCTAssertGreaterThan(lost, 0)
    }

    // MARK: - Shield absorption

    func testApplyDamageShieldAbsorbsFully() {
        let shield = ActiveEffect(id: 1, effect: .shield(.block, 20, 3), remainingTicks: 3)
        var context = makeContext(targetEffects: [shield])
        let initial = context.roster.enemy.currentHealth
        let (lost, events) = context.applyDamage(10, to: context.roster.enemy.combatant)
        XCTAssertEqual(lost, 0)
        XCTAssertEqual(context.roster.enemy.currentHealth, initial)
        XCTAssertTrue(events.contains { $0.effectKind == .shieldAbsorbed })
    }

    func testApplyDamageShieldAbsorbsPartially() {
        let shield = ActiveEffect(id: 1, effect: .shield(.block, 5, 3), remainingTicks: 3)
        var context = makeContext(targetEffects: [shield])
        let (lost, _) = context.applyDamage(10, to: context.roster.enemy.combatant)
        XCTAssertGreaterThan(lost, 0)
        XCTAssertLessThan(lost, 10)
    }

    func testApplyDamageShieldRemovedWhenDepleted() {
        let shield = ActiveEffect(id: 1, effect: .shield(.block, 5, 3), remainingTicks: 3)
        var context = makeContext(targetEffects: [shield])
        _ = context.applyDamage(10, to: context.roster.enemy.combatant)
        let effects = context.roster.enemy.activeEffects
        XCTAssertFalse(effects.contains { $0.id == 1 })
    }

    func testApplyDamageMultipleShieldsConsumedInOrder() {
        let s1 = ActiveEffect(id: 1, effect: .shield(.block, 5, 3), remainingTicks: 3)
        let s2 = ActiveEffect(id: 2, effect: .shield(.block, 10, 3), remainingTicks: 3)
        var context = makeContext(targetEffects: [s1, s2])
        let (lost, _) = context.applyDamage(12, to: context.roster.enemy.combatant)
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
        let (lost, _) = context.applyDamage(start, to: context.roster.enemy.combatant)
        // 25% mitigation → 20 * 0.75 = 15
        XCTAssertEqual(lost, 15)
    }

    func testApplyDamageToughnessMitigationStacksWithArmor() {
        let stats = PrimaryStats(toughness: 50) // 50/(50+50) = 50% mitigation
        let mit = ActiveEffect(id: 1, effect: .mitigation(.armor, 0.25, 6), remainingTicks: 6)
        var context = makeContext(targetPrimaryStats: stats, targetEffects: [mit])
        let (lost, _) = context.applyDamage(20, to: context.roster.enemy.combatant)
        // combined = min(1, 0.25 + 0.50) = 0.75
        // 20 * 0.25 = 5
        XCTAssertEqual(lost, 5)
    }

    // MARK: - Stat and item bonuses

    func testApplyDamageStatBonusAppliesForSource() {
        let stats = PrimaryStats(strength: 25) // 25/5 = 5 bonus
        var context = makeContext(sourcePrimaryStats: stats, seed: 1772)
        let (lost, _) = context.applyDamage(10, to: context.roster.enemy.combatant, damageKeyword: .physical, sourceActorID: "source")
        // 10 + 5 = 15
        XCTAssertEqual(lost, 15)
    }

    // MARK: - Leech

    func testApplyLeechFromDamageNoLeechEffectNoHeal() {
        var context = makeContext(seed: 1772)
        _ = context.applyDamage(10, to: context.roster.enemy.combatant, sourceActorID: "source")
        let events = context.applyLeechFromDamage(10, sourceActorID: "source")
        XCTAssertTrue(events.isEmpty)
    }

    func testApplyLeechFromDamageWithLeechEffectHealsSource() {
        let leech = ActiveEffect(id: 1, effect: .leech(.leech, 0.20, 3), remainingTicks: 3)
        var context = makeContext()
        // Damage the hero so leech has room to heal
        context.roster.mutateRuntime(for: context.roster.hero.combatant) { $0.currentHealth = 30 }
        context.roster.setActiveEffects([leech], for: context.roster.hero.combatant)
        let before = context.roster.hero.currentHealth
        let events = context.applyLeechFromDamage(10, sourceActorID: "source")
        XCTAssertFalse(events.isEmpty)
        XCTAssertGreaterThan(context.roster.hero.currentHealth, before)
    }

    // MARK: - Heal

    func testApplyHealRestoresHealth() {
        var context = makeContext(seed: 1772)
        // Damage first, then heal
        _ = context.applyDamage(10, to: context.roster.enemy.combatant)
        let before = context.roster.enemy.currentHealth
        context.applyHeal(5, to: context.roster.enemy.combatant, sourceActorID: nil)
        XCTAssertEqual(context.roster.enemy.currentHealth, before + 5)
    }

    func testApplyHealCappedAtMaxHealth() {
        var context = makeContext(targetMaxHealth: 50, seed: 1772)
        context.applyHeal(100, to: context.roster.enemy.combatant, sourceActorID: nil)
        XCTAssertEqual(context.roster.enemy.currentHealth, 50)
    }

    // MARK: - Prevention buildup

    func testApplyControlMeterAccumulatesAndTriggersAtThreshold() {
        var context = makeContext(seed: 1772)
        let events = context.applyControlMeter(15, keyword: .stun, to: context.roster.enemy.combatant, sourceActorID: "source")
        XCTAssertTrue(events.contains { $0.effectKind == .controlTriggered })
        XCTAssertTrue(context.roster.enemy.activeEffects.contains(where: \.effect.isActionSkipPending))
    }

    func testApplyControlMeterNoDuplicateWhenSameKeywordSkipPending() {
        var context = makeContext(targetEffects: [
            ActiveEffect(id: 1, effect: .controlMeter(.stun, 10, 10), remainingTicks: 0)
        ], seed: 1772)
        let events = context.applyControlMeter(15, keyword: .stun, to: context.roster.enemy.combatant, sourceActorID: "source")
        XCTAssertTrue(events.isEmpty)
    }

    func testApplyControlMeterAllowsOtherKeywordWhileSkipPending() {
        var context = makeContext(targetEffects: [
            ActiveEffect(id: 1, effect: .controlMeter(.stun, 10, 10), remainingTicks: 0)
        ], seed: 1772)
        let target = context.roster.enemy.combatant
        let events = context.applyControlMeter(4, keyword: .freeze, to: target, sourceActorID: "source")
        XCTAssertTrue(events.isEmpty)
        let freezeMeter = context.roster.activeEffects(for: target).first {
            guard case let .controlMeter(keyword, amount, _) = $0.effect else { return false }
            return keyword == .freeze && amount == 4
        }
        XCTAssertNotNil(freezeMeter)
    }

    func testStunAndFreezeBuildupTrackedSeparatelyFromDamage() {
        var context = makeContext(seed: 1772)
        let target = context.roster.enemy.combatant
        _ = context.applyDamage(3, to: target, damageKeyword: .stun, sourceActorID: "source", applyDodge: false)
        _ = context.applyDamage(5, to: target, damageKeyword: .freeze, sourceActorID: "source", applyDodge: false)

        let stunMeter = context.roster.activeEffects(for: target).first {
            guard case let .controlMeter(keyword, amount, _) = $0.effect else { return false }
            return keyword == .stun && amount == 3
        }
        let freezeMeter = context.roster.activeEffects(for: target).first {
            guard case let .controlMeter(keyword, amount, _) = $0.effect else { return false }
            return keyword == .freeze && amount == 5
        }
        XCTAssertNotNil(stunMeter)
        XCTAssertNotNil(freezeMeter)
    }

    // MARK: - DoT damage

    func testApplyDoTDamageDealsDamage() {
        var context = makeContext(seed: 1772)
        let (lost, _) = context.applyDoTDamage(10, keyword: .burn, to: context.roster.enemy.combatant, sourceActorID: nil)
        XCTAssertGreaterThan(lost, 0)
    }

    func testApplyDoTDamageAppliesLeechWhenSourceActorPresent() {
        let leech = ActiveEffect(id: 1, effect: .leech(.leech, 1.0, 3), remainingTicks: 3)
        var context = makeContext(seed: 1772)
        context.roster.mutateRuntime(for: context.roster.hero.combatant) { $0.currentHealth = 30 }
        context.roster.setActiveEffects([leech], for: context.roster.hero.combatant)
        let before = context.roster.hero.currentHealth
        let (lost, events) = context.applyDoTDamage(10, keyword: .burn, to: context.roster.enemy.combatant, sourceActorID: "source")
        XCTAssertGreaterThan(lost, 0)
        XCTAssertGreaterThan(context.roster.hero.currentHealth, before)
        XCTAssertTrue(events.contains { $0.effectKind == .leechHeal })
    }

    func testApplyDamageTriggersLeechOnDirectHit() {
        let leech = ActiveEffect(id: 1, effect: .leech(.leech, 1.0, 3), remainingTicks: 3)
        var context = makeContext(seed: 1772)
        context.roster.mutateRuntime(for: context.roster.hero.combatant) { $0.currentHealth = 30 }
        context.roster.setActiveEffects([leech], for: context.roster.hero.combatant)
        let before = context.roster.hero.currentHealth
        let (_, events) = context.applyDamage(
            10,
            to: context.roster.enemy.combatant,
            damageKeyword: .physical,
            sourceActorID: "source"
        )
        XCTAssertGreaterThan(context.roster.hero.currentHealth, before)
        XCTAssertTrue(events.contains { $0.effectKind == .leechHeal })
    }

    func testApplyDamageDoesNotLeechOnSelfDamage() {
        let leech = ActiveEffect(id: 1, effect: .leech(.leech, 1.0, 3), remainingTicks: 3)
        var context = makeContext(seed: 1772)
        context.roster.mutateRuntime(for: context.roster.hero.combatant) { $0.currentHealth = 30 }
        context.roster.setActiveEffects([leech], for: context.roster.hero.combatant)
        let before = context.roster.hero.currentHealth
        let (_, events) = context.applyDamage(
            10,
            to: context.roster.hero.combatant,
            damageKeyword: .physical,
            sourceActorID: "source"
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
            rng: SeededRandomNumberGenerator(seed: 1772),
            nextEffectID: 0,
            nextEventID: 0,
            events: [],
            gold: 0,
            initialGold: 0,
            build: BattleCombatBuild(
                hero: source,
                pet: CombatantFixtures.combatant(id: "pet", role: .pet),
                enemy: target,
                heroModifiers: .zero,
                petModifiers: .zero
            )
        )

        context.applyControlMeter(1, keyword: .stun, to: target, sourceActorID: "source")

        let buildup = context.roster.enemy.activeEffects.first { $0.effect.isControlMeter }
        let threshold = buildup?.effect.controlMeterValues?.threshold
        let expected = target.primaryStats.controlMeterThreshold(baseMaxHealth: 100)
        XCTAssertEqual(threshold, expected)
    }

    func testStunBuildupUsesPostMitigationDamage() {
        let mit = ActiveEffect(id: 1, effect: .mitigation(.armor, 0.50, 6), remainingTicks: 6)
        var context = makeContext(targetMaxHealth: 100, targetEffects: [mit], seed: 1772)
        _ = context.applyDamage(
            20,
            to: context.roster.enemy.combatant,
            damageKeyword: .stun,
            sourceActorID: "source"
        )

        let buildup = context.roster.enemy.activeEffects.first { $0.effect.isControlMeter }
        let amount = buildup?.effect.controlMeterValues?.amount
        XCTAssertEqual(amount, 10, "50% mitigation should halve stun buildup from 20 to 10")
    }

    func testStunBuildupDoesNotApplyWhenShieldAbsorbsAllDamage() {
        let shield = ActiveEffect(id: 1, effect: .shield(.block, 20, 6), remainingTicks: 6)
        var context = makeContext(targetMaxHealth: 100, targetEffects: [shield], seed: 1772)
        let (lost, _) = context.applyDamage(
            5,
            to: context.roster.enemy.combatant,
            damageKeyword: .stun,
            sourceActorID: "source"
        )

        XCTAssertEqual(lost, 0)
        let buildup = context.roster.enemy.activeEffects.first { $0.effect.isControlMeter }
        XCTAssertNil(buildup, "Fully shielded hits should not build control meters")
    }

    // MARK: - Pipeline ordering

    func testDamageStepsRunInCanonicalOrder() {
        XCTAssertEqual(DamagePipeline.canonicalNames, [
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

    func testThornsRetaliationDoesNotRecurse() {
        let thorns = ActiveEffect(id: 1, effect: .thorns(.physical, 5, 6), remainingTicks: 6)
        var context = makeContext(
            targetMaxHealth: 200,
            targetEffects: [thorns],
            seed: 42
        )
        context.roster.setActiveEffects([thorns], for: context.roster.hero.combatant)

        let (_, events) = context.applyDamage(
            10,
            to: context.roster.enemy.combatant,
            damageKeyword: .physical,
            sourceActorID: context.roster.hero.combatant.id,
            applyDodge: false
        )

        let thornsTriggers = events.filter { $0.effectKind == .thornsTriggered }
        XCTAssertEqual(thornsTriggers.count, 1)
    }
}
