import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct CounterattackRewardRegressionTests {
    @Test func `Temper Cycle readies Bleed damage after a Burn Basic counterattack`() {
        var battle = makeBattle(talents: ["warlock_burn_t4_2"])

        _ = counter(.fireArrow, in: &battle)
        #expect(battle.health(of: battle.enemy) == 98)
        #expect(battle.roster.hero.talents.pending.nextBleedDamageBonus == 1)

        _ = counter(.rendingSlash, in: &battle)
        #expect(battle.health(of: battle.enemy) == 95)
        #expect(battle.roster.hero.talents.pending.nextBleedDamageBonus == 0)
        _ = counter(.rendingSlash, in: &battle)
        #expect(battle.health(of: battle.enemy) == 93)
    }

    @Test func `Consolation Prize grants one card for a fully blocked Basic counterattack`() {
        var battle = makeBattle(talents: ["wildcard_gold_t1_1"])
        DefensePoolEngine.set(3, on: battle.enemy, in: &battle)

        let events = counter(.slash, in: &battle)
        #expect(battle.health(of: battle.enemy) == 100)
        #expect(battle.hand.totalCount == 1)
        #expect(events.contains { $0.abilityName == "Consolation Prize" && $0.effectKind == .cardsDrawn })

        DefensePoolEngine.set(3, on: battle.enemy, in: &battle)
        _ = counter(.slash, in: &battle)
        #expect(battle.hand.totalCount == 1)
        #expect(battle.gold == 0)
    }

    @Test func `Feigned Miss doubles only the next Physical attack after a blocked Basic counterattack`() {
        var battle = makeBattle(talents: ["wildcard_physical_t3_2"])
        DefensePoolEngine.set(3, on: battle.enemy, in: &battle)

        _ = counter(.slash, in: &battle)
        #expect(battle.health(of: battle.enemy) == 100)
        #expect(battle.roster.hero.talents.pending.doubleNextPhysicalAttack?.value == true)

        _ = counter(.slash, in: &battle)
        #expect(battle.health(of: battle.enemy) == 94)
        #expect(battle.roster.hero.talents.pending.doubleNextPhysicalAttack == nil)
        _ = counter(.slash, in: &battle)
        #expect(battle.health(of: battle.enemy) == 91)
    }

    private func makeBattle(talents: Set<String>) -> BattleState {
        var profile = CombatantTalentCatalog.profile(for: talents)
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroModifiers: profile, dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        return battle
    }

    private func counter(_ ability: Ability, in battle: inout BattleState) -> [ActionEvent] {
        BattleTurnEngine.performAction(
            ability: ability, actor: battle.hero, abilityTarget: battle.enemy,
            origin: .counterattack, context: &battle,
        )
    }
}
