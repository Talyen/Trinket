import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct GoldDefenseRegressionTests {
    @Test(arguments: [BattleParticipant.hero, .companion], [0, 1, 100])
    func `Golden Plate rewards only its wearers current turn Gold without creating or spending it`(
        owner: BattleParticipant, amount: Int,
    ) throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            appliesFightPacing: false,
        )
        let actor = battle.roster[owner].combatant
        let partner = battle.roster[owner == .hero ? .companion : .hero].combatant
        battle.grantGoldEvent(10, to: partner, abilityName: "Partner Gold")
        try play(.goldenPlate, owner: owner, in: &battle)
        #expect(BattleTestFixtures.shieldPoints(for: actor, in: battle) == 8)
        battle.grantGoldEvent(amount, to: actor, abilityName: "Gold")
        let gold = battle.gold
        for _ in 0 ..< 2 {
            DefensePoolEngine.set(0, on: actor, in: &battle)
            try play(.goldenPlate, owner: owner, in: &battle)
            #expect(BattleTestFixtures.shieldPoints(for: actor, in: battle) == (amount > 0 ? 12 : 8))
            #expect(battle.gold == gold)
        }
        _ = battle.endTurn()
        DefensePoolEngine.set(0, on: actor, in: &battle)
        try play(.goldenPlate, owner: owner, in: &battle)
        #expect(BattleTestFixtures.shieldPoints(for: actor, in: battle) == 8)
        #expect(battle.gold == gold)
    }

    @Test(arguments: [false, true])
    func `Feint cannot return itself with Returning Gale`(priorAttack: Bool) throws {
        let signature = try #require(GameContent.unique(matching: "the_returning_gale")?.affixPowers?.first)
        var profile = CombatModifierProfile.zero
        signature.triggers.apply(to: &profile)
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroModifiers: profile, appliesFightPacing: false,
        )
        if priorAttack {
            try play(.slash, owner: .hero, in: &battle)
        }
        try play(.feint, owner: .hero, in: &battle)
        let events = battle.performTestAction(.slash, from: .enemy, to: .hero)
        #expect(events.contains { $0.effectKind == .dodgeApplied })
        let held = battle.hand.cards + battle.hand.buffer
        #expect(!held.contains { $0.ability.id == Ability.feint.id })
        #expect(held.contains { $0.ability.id == Ability.slash.id } == priorAttack)
        #expect(events.contains { $0.abilityName == "The Returning Gale" } == priorAttack)
    }

    private func play(_ ability: Ability, owner: BattleParticipant, in battle: inout BattleState) throws {
        let card = BattleCardCombatEngine.deal(ability, owner: owner, context: &battle)
        _ = try CombatExecutor.run { try await BattleCardCombatEngine.resolveDrawnCard(card, context: &battle) }
    }
}
