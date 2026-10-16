import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct DoTAmplificationProtectionTests {
    @Test(arguments: [Keyword.burn, .poison, .bleed], [false, true])
    func `legacy amplification respects Perfect Purity without consuming Fae Ward`(
        keyword: Keyword,
        protected: Bool,
    ) {
        var battle = BattleTestFixtures.makePipelineContext(
            heroModifiers: .withTriggers { $0.blockFirstDebuffPerTurn = true },
        )
        let target = battle.hero
        let before = [
            ActiveEffect(id: 90, effect: Self.dot(keyword, potency: 2), remainingTurns: 2, sourceActorID: battle.enemy.id),
            ActiveEffect(id: 91, effect: Self.dot(keyword, potency: 3), remainingTurns: 1, sourceActorID: battle.companion.id),
        ]
        battle.roster.setActiveEffects(before, for: target)
        battle.roster.mutateRuntime(for: target) { $0.talents.turn.negativeStatusImmune = protected }

        let outcome = EffectHandlersTestSupport.dispatch(
            .multiplyDoT(keyword, 2), source: battle.enemy, target: target, battle: &battle,
        )

        let after = battle.activeEffects(of: target)
        #expect(outcome.didApply == !protected)
        #expect(after.map(\.effect.potency) == (protected ? [2, 3] : [4, 6]))
        #expect(after.map(\.id) == before.map(\.id))
        #expect(after.map(\.sourceActorID) == before.map(\.sourceActorID))
        #expect(after.map(\.remainingTurns) == before.map(\.remainingTurns))
        #expect(!battle.roster.hero.talents.turn.blockedFaeWard)
        if protected {
            #expect(outcome.events.isEmpty)
        } else {
            #expect(outcome.events.first { $0.effectKind == .dotAmplified }?.amount == 10)
        }
    }

    private static func dot(_ keyword: Keyword, potency: Int) -> Effect {
        keyword == .bleed ? .bleed(potency) : .decayingDoT(keyword: keyword, potency: potency)
    }
}
