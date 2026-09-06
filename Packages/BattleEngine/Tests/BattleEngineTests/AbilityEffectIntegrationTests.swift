import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct AbilityEffectIntegrationTests {
    @Test(arguments: [Ability.heal, .block])
    func `hemorrhage waits for an attack after support card`(support: Ability) {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false)
        battle.roster.setActiveEffects(
            [ActiveEffect(id: 100, effect: .hemorrhage(4), remainingTurns: 0, sourceActorID: "enemy")],
            for: battle.hero,
        )
        _ = BattleTurnEngine.performAction(
            ability: support, actor: battle.hero, abilityTarget: battle.enemy, context: &battle,
        )
        #expect(battle.activeEffects(of: battle.hero).contains { $0.effect == .hemorrhage(4) })
        let health = battle.health(of: battle.hero)
        _ = BattleTurnEngine.performAction(
            ability: .slash, actor: battle.hero, abilityTarget: battle.enemy, context: &battle,
        )
        #expect(!battle.activeEffects(of: battle.hero).contains { $0.effect == .hemorrhage(4) })
        #expect(battle.health(of: battle.hero) < health)
    }

    @Test func `cleansing removes hemorrhage before it can trigger`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false)
        battle.roster.setActiveEffects(
            [ActiveEffect(id: 100, effect: .hemorrhage(4), remainingTurns: 0, sourceActorID: "enemy")],
            for: battle.hero,
        )
        let health = battle.health(of: battle.hero)
        let cleanse = Ability(id: "cleanse", name: "Cleanse", tier: .skill, effects: [.cleanse(nil)])
        _ = BattleTurnEngine.performAction(
            ability: cleanse, actor: battle.hero, abilityTarget: battle.enemy, context: &battle,
        )
        #expect(battle.health(of: battle.hero) == health)
        #expect(!battle.activeEffects(of: battle.hero).contains { $0.effect == .hemorrhage(4) })
    }
}
