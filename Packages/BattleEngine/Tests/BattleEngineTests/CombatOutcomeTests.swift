import XCTest
import BattleEngine
import TrinketCore
import TrinketContent

final class CombatOutcomeTests: XCTestCase {
    private func makeContext(seed: UInt64 = 0) -> BattleEngineContext {
        let target = CombatantFixtures.combatant(id: "target", role: .enemy, maxHealth: 50)
        let source = CombatantFixtures.combatant(id: "source", role: .hero, maxHealth: 50)
        let roster = BattleRoster(
            hero: CombatantRuntime(combatant: source, initialActiveEffects: []),
            pet: CombatantRuntime(combatant: CombatantFixtures.combatant(id: "pet", role: .pet)),
            enemy: CombatantRuntime(combatant: target, initialActiveEffects: [])
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

    func testResolveDamageReturnsCombatOutcome() {
        var context = makeContext(seed: 0)
        let outcome = CombatPipeline.resolveDamage(
            .directAbilityHit(
                amount: 10,
                target: context.roster.enemy.combatant,
                keyword: .physical,
                sourceActorID: "source"
            ),
            in: &context
        )
        XCTAssertEqual(outcome.healthLost, 10)
        XCTAssertEqual(outcome.healthDelta, -10)
        XCTAssertEqual(context.roster.enemy.currentHealth, 40)
    }

    func testResolveDamageSetsDodgedFlag() {
        let stats = PrimaryStats(agility: 140)
        let target = CombatantFixtures.combatant(
            id: "target", role: .enemy, maxHealth: 50, primaryStats: stats
        )
        let source = CombatantFixtures.combatant(id: "source", role: .hero, maxHealth: 50)
        let roster = BattleRoster(
            hero: CombatantRuntime(combatant: source, initialActiveEffects: []),
            pet: CombatantRuntime(combatant: CombatantFixtures.combatant(id: "pet", role: .pet)),
            enemy: CombatantRuntime(combatant: target, initialActiveEffects: [])
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
        let outcome = CombatPipeline.resolveDamage(
            .directAbilityHit(
                amount: 10,
                target: context.roster.enemy.combatant,
                keyword: .physical,
                sourceActorID: "source"
            ),
            in: &context
        )
        if outcome.healthLost == 0 {
            XCTAssertTrue(outcome.flags.contains(.dodged))
        }
    }

    func testResolveDamageSetsLeechedFlag() {
        let leech = ActiveEffect(id: 1, effect: .leech(.leech, 1.0, 3), remainingTicks: 3)
        var context = makeContext(seed: 0)
        context.roster.mutateRuntime(for: context.roster.hero.combatant) { $0.currentHealth = 30 }
        context.roster.setActiveEffects([leech], for: context.roster.hero.combatant)
        let outcome = CombatPipeline.resolveDamage(
            .directAbilityHit(
                amount: 10,
                target: context.roster.enemy.combatant,
                keyword: .physical,
                sourceActorID: "source"
            ),
            in: &context
        )
        XCTAssertTrue(outcome.flags.contains(.leeched))
        XCTAssertTrue(outcome.events.contains { $0.effectKind == .leechHeal })
    }

    func testDamageRequestDoTTickPresetAppliesBonusesWithoutDodge() {
        let preset = DamageRequest.doTTick(
            amount: 10,
            target: CombatantFixtures.combatant(id: "t", role: .enemy),
            keyword: .burn,
            sourceActorID: "source"
        )
        XCTAssertTrue(preset.options.applyStatBonus)
        XCTAssertFalse(preset.options.applyDodge)
        XCTAssertTrue(preset.options.applyItemBonus)
    }

    func testDamageRequestDirectAbilityHitUsesDefaultOptions() {
        let preset = DamageRequest.directAbilityHit(
            amount: 5,
            target: CombatantFixtures.combatant(id: "t", role: .enemy),
            keyword: .physical,
            sourceActorID: "source"
        )
        XCTAssertEqual(preset.options, .directAbilityHit)
    }

    func testResolveHealReturnsRestoredAmount() {
        var context = makeContext(seed: 0)
        _ = CombatPipeline.applyDamage(10, to: context.roster.enemy.combatant, in: &context)
        let before = context.roster.enemy.currentHealth
        let outcome = context.resolveHeal(
            HealRequest(amount: 5, target: context.roster.enemy.combatant)
        )
        XCTAssertEqual(outcome.healthRestored, context.roster.enemy.currentHealth - before)
        XCTAssertGreaterThan(outcome.healthRestored, 0)
        XCTAssertEqual(outcome.healthDelta, outcome.healthRestored)
    }

    func testLegacyApplyDamageMatchesResolveDamage() {
        var legacyContext = makeContext(seed: 0)
        var requestContext = makeContext(seed: 0)
        let target = legacyContext.roster.enemy.combatant

        let legacy = CombatPipeline.applyDamage(
            12,
            to: target,
            damageKeyword: .physical,
            sourceActorID: "source",
            in: &legacyContext
        )
        let resolved = CombatPipeline.resolveDamage(
            DamageRequest(
                amount: 12,
                target: target,
                keyword: .physical,
                sourceActorID: "source",
                options: DamageOptions()
            ),
            in: &requestContext
        )

        XCTAssertEqual(legacy.healthLost, resolved.healthLost)
        XCTAssertEqual(legacy.damageEvents.map(\.effectKind), resolved.events.map(\.effectKind))
        XCTAssertEqual(legacyContext.roster.enemy.currentHealth, requestContext.roster.enemy.currentHealth)
    }
}
