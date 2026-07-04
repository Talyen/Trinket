import XCTest
import BattleEngine
import TrinketCore
import TrinketContent

final class BattleTurnEngineTests: XCTestCase {
    private func makeContext(
        actorEffects: [ActiveEffect] = [],
        seed: UInt64 = 1772
    ) -> (context: BattleEngineContext, matchup: BattleMatchup) {
        let hero = CombatantFixtures.combatant(
            id: "hero",
            role: .hero,
            actionIntervalTicks: 2,
            abilities: [.slash]
        )
        let pet = CombatantFixtures.combatant(id: "pet", role: .pet, actionIntervalTicks: 100)
        let enemy = CombatantFixtures.combatant(
            id: "enemy",
            role: .enemy,
            actionIntervalTicks: 2,
            abilities: [.slash]
        )
        let roster = BattleRoster(
            hero: CombatantRuntime(combatant: hero, initialActiveEffects: []),
            pet: CombatantRuntime(combatant: pet, initialActiveEffects: []),
            enemy: CombatantRuntime(combatant: enemy, initialActiveEffects: actorEffects)
        )
        let context = BattleEngineContext(
            roster: roster,
            rng: SeededRandomNumberGenerator(seed: seed),
            nextEffectID: 1,
            nextEventID: 0,
            events: [],
            gold: 0,
            initialGold: 0,
            build: BattleCombatBuild(hero: hero, pet: pet, heroModifiers: .zero, petModifiers: .zero)
        )
        return (context, BattleMatchup(hero: hero, pet: pet, enemy: enemy))
    }

    func testConsumeActionSkipEmitsControlActionSkippedAndRemovesEffect() {
        var (context, _) = makeContext(actorEffects: [
            ActiveEffect(id: 1, effect: .controlMeter(.stun, 10, 10), remainingTicks: 0)
        ])
        let enemy = context.roster.enemy.combatant

        let events = BattleTurnEngine.consumeActionSkip(for: enemy, context: &context)

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].effectKind, .controlActionSkipped)
        XCTAssertEqual(events[0].keyword, .stun)
        XCTAssertFalse(context.roster.hasPendingActionSkip(for: enemy, keyword: .stun))
    }

    func testConsumeActionSkipRecordsActionForScheduling() {
        var (context, _) = makeContext(actorEffects: [
            ActiveEffect(id: 1, effect: .controlMeter(.stun, 10, 10), remainingTicks: 0)
        ])
        let enemy = context.roster.enemy.combatant
        let before = context.runtime(for: enemy).actionCount

        _ = BattleTurnEngine.consumeActionSkip(for: enemy, context: &context)

        XCTAssertEqual(context.runtime(for: enemy).actionCount, before + 1)
        XCTAssertEqual(context.actionCount, 1)
    }

    func testActPerformsAbilityWhenNoSkipPending() {
        var (context, matchup) = makeContext()
        let enemy = context.roster.enemy.combatant

        let events = BattleTurnEngine.act(actor: enemy, matchup: matchup, context: &context)

        XCTAssertTrue(events.contains { $0.kind == .ability })
        XCTAssertFalse(events.contains { $0.effectKind == .controlActionSkipped })
    }
}
