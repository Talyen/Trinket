import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct ThornsArithmeticBoundaryTests {
    @Test(arguments: [false, true])
    func `capped Thorns preserves its stack without gain feedback and still retaliates`(talentGain: Bool) {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroEffects: [ActiveEffect(id: 1, effect: .thorns(Int.max), remainingTurns: 0)],
            heroModifiers: .withTriggers {
                $0.blockGainThornsPercent = 1
                $0.thornsDamageFlat = 1
                $0.thornsDamageDoubleWhileBlocked = true
            }, appliesFightPacing: false,
        )
        battle.roster.enemy.hasConsumedDeathsDoor = true
        let original = battle.roster.hero.activeEffects
        let gains = battle.recordingEvents { battle in
            if talentGain {
                CombatTriggerEngine.heroTalentThorns(
                    to: battle.hero, source: battle.hero, amount: 1, name: "Thorns", in: &battle,
                )
                DefensePoolEngine.set(2, on: battle.hero, in: &battle)
            } else {
                _ = battle.applyBlockGain(2, to: battle.hero, source: battle.hero, abilityName: "Block")
            }
        }
        #expect(battle.activeEffects(of: battle.hero).filter { $0.effect.kind == .thorns } == original)
        #expect(!gains.contains { $0.effectKind == .thornsApplied })

        _ = battle.resolveTestDamage(1, from: .enemy, to: .hero, options: .attack(accuracy: .unavoidable))

        #expect(battle.isEnemyDefeated)
        #expect(!battle.activeEffects(of: battle.hero).contains { $0.effect.kind == .thorns })
    }

    @Test func `Interdict rejects triggered Thorns without false gain feedback`() {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            enemyModifiers: .withTriggers { $0.interdict = true }, appliesFightPacing: false,
        )
        _ = EffectHandlersTestSupport.dispatch(.thorns(3), battle: &battle)
        _ = EffectHandlersTestSupport.dispatch(.purge(nil), source: battle.enemy, battle: &battle)
        let nextID = battle.nextEffectID

        let gains = battle.recordingEvents { battle in
            CombatTriggerEngine.heroTalentThorns(to: battle.hero, source: battle.hero, name: "Thorns", in: &battle)
        }

        #expect(battle.roster.hero.activeEffects.isEmpty)
        #expect(battle.nextEffectID == nextID)
        #expect(gains.isEmpty)
    }
}
