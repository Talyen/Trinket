import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct ColdSnapControlProtectionTests {
    @Test func `Steadfast blocks Cold Snap from doubling existing Freeze buildup`() throws {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        let companion = CombatantFixtures.passiveCompanion()
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, abilities: [.coldSnap])
        var heroModifiers = CombatModifierProfile.zero
        heroModifiers.triggers.blockedControlPrevention = true
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero, companion: companion, enemy: enemy,
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .controlMeter(.freeze, 1, 4), remainingTurns: 0),
                ActiveEffect(id: 2, effect: .shield(.block, 3), remainingTurns: 0),
            ],
            heroModifiers: heroModifiers, dealOpeningHand: false,
        )
        battle.appliesFightPacing = false

        _ = BattleTurnEngine.performAction(
            ability: .coldSnap, actor: enemy, abilityTarget: hero, context: &battle,
        )

        let meter = try #require(battle.activeEffects(of: hero).first { $0.keyword == .freeze })
        #expect(meter.effect.controlMeterValues?.amount == 1)
        #expect(!battle.roster.hasPendingActionSkip(for: hero, keyword: .freeze))
    }

    @Test func `Perfect Purity blocks Cold Snap from doubling existing Freeze buildup`() throws {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, abilities: [.coldSnap])
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero, enemy: enemy,
            activeHeroEffects: [ActiveEffect(id: 1, effect: .controlMeter(.freeze, 1, 4), remainingTurns: 0)],
            dealOpeningHand: false,
        )
        battle.roster.mutateRuntime(for: hero) { $0.talents.turn.negativeStatusImmune = true }
        battle.appliesFightPacing = false

        _ = BattleTurnEngine.performAction(
            ability: .coldSnap, actor: enemy, abilityTarget: hero, context: &battle,
        )

        let meter = try #require(battle.activeEffects(of: hero).first { $0.keyword == .freeze })
        #expect(meter.effect.controlMeterValues?.amount == 1)
    }
}
