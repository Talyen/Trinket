import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct TurnBoundaryRegressionTests {
    @Test func `Mana Shield protects against the enemy attack following End Turn`() {
        let attack = Ability(
            id: "strike", name: "Strike", tier: .basic,
            damageComponents: [DamageComponent(4, keyword: .physical, target: .hero)],
        )
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            enemyAbilities: [attack], heroMaxMana: 4, heroMana: 4,
            heroModifiers: CombatantTalentCatalog.profile(for: ["wizard_mana_t1_2"]),
        )
        battle.appliesFightPacing = false
        let health = battle.health(of: battle.hero)
        let events = battle.endTurn()
        #expect(battle.health(of: battle.hero) == health)
        let shieldIndex = events.firstIndex { $0.abilityName == "Mana Shield" }
        let attackIndex = events.firstIndex { $0.kind == .ability && $0.actorID == battle.enemy.id }
        #expect(shieldIndex != nil && attackIndex != nil)
        if let shieldIndex, let attackIndex {
            #expect(shieldIndex < attackIndex)
        }
    }

    @Test(arguments: [false, true])
    func `Gold rewards and Gold steals retain their meaning in the battle log`(theft: Bool) {
        var battle = BattleStateTestFactory.makeBattleWithAbilities()
        let ability = theft ? Ability.steal : Ability.goldenPlate
        let events = BattleTurnEngine.performAction(
            ability: ability, actor: battle.hero, abilityTarget: battle.enemy, context: &battle,
        )
        let summary = events.first { $0.kind == .ability && $0.abilityID == ability.id }?.appliedEffectSummaries
        #expect(summary?.contains(theft ? "steal 2 Gold" : "gain 5 Gold") == true)
    }
}
