import XCTest
import BattleEngine
import TrinketCore
import TrinketContent

final class DoTDamageTests: XCTestCase {
    private func makeContext(
        sourceStats: PrimaryStats = PrimaryStats(),
        heroModifiers: CombatModifierProfile = .zero,
        seed: UInt64 = 0
    ) -> BattleEngineContext {
        let target = CombatantFixtures.combatant(id: "target", role: .enemy, maxHealth: 100)
        let source = CombatantFixtures.combatant(
            id: "source", role: .hero, maxHealth: 50, primaryStats: sourceStats
        )
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
            build: BattleCombatBuild(
                hero: source,
                pet: target,
                heroModifiers: heroModifiers,
                petModifiers: .zero
            )
        )
    }

    func testResolveTickStoresBasePotencyOnStack() {
        var context = makeContext()
        _ = DoTApplicator.applyDecayingDoT(
            keyword: .burn,
            potency: 4,
            to: context.roster.enemy.combatant,
            sourceActorID: "source",
            dealImmediateDamage: false,
            in: &context
        )
        let potency = context.roster.enemy.activeEffects.first { $0.keyword == .burn }?.effect.potency
        XCTAssertEqual(potency, 4)
    }

    func testResolveTickAppliesStatBonusAtDamageTime() {
        let stats = PrimaryStats(intellect: 20) // +4 burn
        var context = makeContext(sourceStats: stats)
        let outcome = DoTDamage.resolveTick(
            basePotency: 4,
            keyword: .burn,
            target: context.roster.enemy.combatant,
            sourceActorID: "source",
            in: &context
        )
        XCTAssertEqual(outcome.healthLost, 8)
        XCTAssertTrue(outcome.events.contains { $0.kind == .status && $0.amount == 8 })
    }

    func testResolveTickAppliesItemDamageDealtBonus() {
        var modifiers = CombatModifierProfile.zero
        modifiers.damageDealtBonus[.burn] = 3
        var context = makeContext(heroModifiers: modifiers)
        let outcome = DoTDamage.resolveTick(
            basePotency: 4,
            keyword: .burn,
            target: context.roster.enemy.combatant,
            sourceActorID: "source",
            in: &context
        )
        XCTAssertEqual(outcome.healthLost, 7)
    }

    func testResolveTickIncludesStatusEventWhenDamageDealt() {
        var context = makeContext()
        let outcome = DoTDamage.resolveTick(
            basePotency: 5,
            keyword: .burn,
            target: context.roster.enemy.combatant,
            sourceActorID: "source",
            in: &context
        )
        XCTAssertTrue(outcome.events.contains { $0.kind == .status && $0.keyword == .burn })
    }
}
