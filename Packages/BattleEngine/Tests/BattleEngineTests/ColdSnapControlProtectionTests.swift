import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct ColdSnapControlProtectionTests {
    private static let multiplyFreeze = Ability(
        id: "multiply-freeze", name: "Multiply Freeze", tier: .skill, effects: [.multiplyControlMeter(.freeze, 2)],
    )

    @Test func `Steadfast blocks control multiplication from doubling existing Freeze buildup`() throws {
        var battle = BattleStateTestFactory.makeBattle(
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy, abilities: [.coldSnap]),
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .controlMeter(.freeze, 1, 4), remainingTurns: 0),
                ActiveEffect(id: 2, effect: .shield(.block, 3), remainingTurns: 0),
            ],
            heroModifiers: .withTriggers { $0.blockedControlPrevention = true },
            dealOpeningHand: false, appliesFightPacing: false,
        )

        _ = battle.performTestAction(Self.multiplyFreeze, from: .enemy, to: .hero)

        let meter = try #require(battle.activeEffects(of: battle.hero).first { $0.keyword == .freeze })
        #expect(meter.effect.controlMeterValues?.amount == 1)
        #expect(!battle.roster.hasPendingActionSkip(for: battle.hero, keyword: .freeze))
    }

    @Test func `Perfect Purity blocks control multiplication from doubling existing Freeze buildup`() throws {
        var battle = BattleStateTestFactory.makeBattle(
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy, abilities: [.coldSnap]),
            activeHeroEffects: [ActiveEffect(id: 1, effect: .controlMeter(.freeze, 1, 4), remainingTurns: 0)],
            dealOpeningHand: false,
        )
        battle.roster.mutateRuntime(for: battle.hero) { $0.talents.turn.negativeStatusImmune = true }
        battle.appliesFightPacing = false

        _ = battle.performTestAction(Self.multiplyFreeze, from: .enemy, to: .hero)

        let meter = try #require(battle.activeEffects(of: battle.hero).first { $0.keyword == .freeze })
        #expect(meter.effect.controlMeterValues?.amount == 1)
    }
}
