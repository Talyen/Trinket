import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct DoTArithmeticBoundaryTests {
    @Test(arguments: [Keyword.burn, .poison])
    func `attaching potency to an amplified capped pool preserves the cap`(keyword: Keyword) {
        var battle = BattleTestFixtures.makePipelineContext()
        battle.appendEffect(
            .decayingDoT(keyword: keyword, potency: Int.max / 2 + 1),
            to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 0,
        )
        _ = EffectHandlersTestSupport.dispatch(
            .multiplyDoT(keyword, 2), source: battle.hero, target: battle.enemy, battle: &battle,
        )

        _ = CombatExecutor.run { await DoTApplicator.applyDecayingDoT(
            keyword: keyword, potency: 1, to: battle.enemy,
            sourceActorID: battle.companion.id, application: .attached, in: &battle,
        ) }

        let effects = battle.activeEffects(of: battle.enemy)
        #expect(effects.count == 1)
        #expect(effects.first?.effect.potency == Int.max)
        #expect(effects.first?.sourceActorID == battle.hero.id)
    }

    @Test(arguments: [Keyword.burn, .poison])
    func `live growth at capped potency preserves the cap`(keyword: Keyword) {
        var battle = BattleTestFixtures.makePipelineContext(heroModifiers: .init(triggers: CombatTraitTriggers(
            dot: DotTriggers(poisonDecayIncreaseChance: 1, burnIncreaseChancePercent: 1),
        )))
        let progression = DecayingDoTProgression(
            type: keyword == .burn ? .burn : .poison,
            sourceActorID: battle.hero.id, target: battle.enemy, in: battle,
        )

        #expect(progression.turnPotency(from: Int.max, using: &battle.rng) == Int.max)
    }

    @Test(arguments: [Keyword.burn, .bleed])
    func `DoT details saturate the combined potency of multiple stacks`(keyword: Keyword) throws {
        let effects = [Int.max, 1].enumerated().map { index, potency in
            ActiveEffect(
                id: index,
                effect: keyword == .burn ? .burn(potency) : .bleed(potency),
                remainingTurns: keyword == .bleed ? 1 : 0,
            )
        }

        let summary = try #require(EffectSummaryBuilder.build(for: effects).first)

        #expect(summary.text.contains("\(Int.max) \(keyword.rawValue)"))
    }

    @Test(arguments: [Keyword.burn, .bleed])
    func `detonation of capped potency resolves lethal damage without overflowing`(keyword: Keyword) {
        var battle = BattleTestFixtures.makePipelineContext()
        battle.appliesFightPacing = false
        battle.appendEffect(
            keyword == .burn ? .burn(Int.max) : .bleed(Int.max),
            to: battle.enemy, sourceID: battle.hero.id,
            remainingTurns: keyword == .bleed ? 1 : 0,
        )
        let healthBefore = battle.health(of: battle.enemy)

        let outcome = EffectHandlersTestSupport.dispatch(
            .detonateDoT(keyword, 3), source: battle.hero, target: battle.enemy, battle: &battle,
        )

        #expect(outcome.didApply)
        #expect(battle.health(of: battle.enemy) == 0)
        #expect(outcome.events.first { $0.kind == .status && $0.keyword == keyword }?.amount == healthBefore)
        #expect(!battle.roster.hasAffliction(keyword, on: battle.enemy))
    }
}
