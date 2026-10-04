import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct SunwallCadenceRegressionTests {
    @Test func `Sunwall rolls once across Smite and its Denouncing follow-up`() throws {
        var profile = CombatantTalentCatalog.profile(for: ["knight_holy_t4_1"])
        let power = try #require(GameContent.itemAffixDefinition(matching: "denouncing")).astral
        profile.merge(power.modifiers)
        power.triggers.apply(to: &profile)
        profile.triggers.sunwallChancePercent = 1
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [.smite], heroModifiers: profile, dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        battle.appendEffect(.nextStrikeDouble, to: battle.enemy, sourceID: battle.enemy.id, remainingTurns: 0)
        let card = BattleCardCombatEngine.deal(.smite, owner: .hero, context: &battle)

        let events = try battle.playCard(cardID: card.id)

        #expect(battle.health(of: battle.enemy) == 92)
        #expect(events.filter { $0.effectKind == .shieldApplied && $0.abilityName == "Sunwall" }.map(\.amount) == [4])
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.companion)) == 4)

        let next = BattleCardCombatEngine.deal(.smite, owner: .hero, context: &battle)
        let nextEvents = try battle.playCard(cardID: next.id)
        #expect(nextEvents.filter { $0.effectKind == .shieldApplied && $0.abilityName == "Sunwall" }.map(\.amount) == [4])
    }
}
