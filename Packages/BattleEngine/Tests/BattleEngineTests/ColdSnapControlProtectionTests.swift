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
        var heroModifiers = CombatModifierProfile.zero
        heroModifiers.triggers.blockedControlPrevention = true
        var battle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 20),
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy, abilities: [.coldSnap]),
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .controlMeter(.freeze, 1, 4), remainingTurns: 0),
                ActiveEffect(id: 2, effect: .shield(.block, 3), remainingTurns: 0),
            ],
            heroModifiers: heroModifiers,
            dealOpeningHand: false,
        )
        battle.appliesFightPacing = false

        _ = BattleTurnEngine.performAction(
            ability: Self.multiplyFreeze, actor: battle.enemy, abilityTarget: battle.hero, context: &battle,
        )

        let meter = try #require(battle.activeEffects(of: battle.hero).first { $0.keyword == .freeze })
        #expect(meter.effect.controlMeterValues?.amount == 1)
        #expect(!battle.roster.hasPendingActionSkip(for: battle.hero, keyword: .freeze))
    }

    @Test func `Perfect Purity blocks control multiplication from doubling existing Freeze buildup`() throws {
        var battle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 20),
            enemy: CombatantFixtures.combatant(id: "enemy", role: .enemy, abilities: [.coldSnap]),
            activeHeroEffects: [ActiveEffect(id: 1, effect: .controlMeter(.freeze, 1, 4), remainingTurns: 0)],
            dealOpeningHand: false,
        )
        battle.roster.mutateRuntime(for: battle.hero) { $0.talents.turn.negativeStatusImmune = true }
        battle.appliesFightPacing = false

        _ = BattleTurnEngine.performAction(
            ability: Self.multiplyFreeze, actor: battle.enemy, abilityTarget: battle.hero, context: &battle,
        )

        let meter = try #require(battle.activeEffects(of: battle.hero).first { $0.keyword == .freeze })
        #expect(meter.effect.controlMeterValues?.amount == 1)
    }
}
