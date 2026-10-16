import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct ReflectedControlRegressionTests {
    @Test(arguments: [Keyword.stun, .freeze])
    func `triggered reflection controls a resistant tougher enemy while partial reflection stays partial`(keyword: Keyword) throws {
        for amount in [3, 4] {
            var battle = Self.makeBattle(keyword: keyword, amount: amount)

            let outcome = EffectHandlersTestSupport.dispatch(
                .cleanse(keyword), source: battle.companion, target: battle.hero, battle: &battle,
            )

            #expect(!battle.roster.hasAffliction(keyword, on: battle.hero))
            #expect(battle.roster.hasPendingActionSkip(for: battle.enemy, keyword: keyword) == (amount == 4))
            #expect(outcome.events.contains {
                $0.effectKind == .controlTriggered && $0.targetID == battle.enemy.id && $0.keyword == keyword
            } == (amount == 4))
            let meter = try #require(battle.activeEffects(of: battle.enemy).first { $0.keyword == keyword })
            #expect(meter.effect.controlMeterValues?.amount == (amount == 4 ? 20 : 2))
        }
    }

    @Test(arguments: [Keyword.stun, .freeze], [false, true])
    func `triggered reflection respects control prevention and negative status immunity`(keyword: Keyword, immune: Bool) {
        var battle = Self.makeBattle(keyword: keyword, amount: 4, preventsControl: !immune)
        let enemy = battle.enemy
        battle.roster.mutateRuntime(for: enemy) { $0.talents.turn.negativeStatusImmune = immune }

        _ = EffectHandlersTestSupport.dispatch(
            .cleanse(keyword), source: battle.companion, target: battle.hero, battle: &battle,
        )

        #expect(!battle.roster.hasAffliction(keyword, on: battle.hero))
        #expect(!battle.roster.hasControlStatus(for: enemy, keyword: keyword))
        #expect(!battle.activeEffects(of: enemy).contains { $0.keyword == keyword })
    }

    private static func makeBattle(keyword: Keyword, amount: Int, preventsControl: Bool = false) -> BattleState {
        BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            activeEnemyEffects: [ActiveEffect(id: 1, effect: .shield(.block, 10), remainingTurns: 0)],
            activeHeroEffects: [
                ActiveEffect(id: 2, effect: .controlMeter(keyword, amount, 4), remainingTurns: 0, sourceActorID: "enemy"),
            ],
            companionModifiers: CombatModifierProfile.withTriggers { $0.cleanseReflectDebuffToEnemy = true },
            enemyModifiers: CombatModifierProfile.withTriggers {
                $0.blockedControlBurnResistance = 0.5
                $0.blockedControlPrevention = preventsControl
            },
            dealOpeningHand: false, appliesFightPacing: false,
        )
    }
}
