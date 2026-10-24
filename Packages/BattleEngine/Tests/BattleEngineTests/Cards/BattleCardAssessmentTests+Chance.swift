import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

extension BattleCardAssessmentTests {
    @Test(arguments: [0.0, 0.3, 1.0])
    func `chance effects do not promise a recipient or a fixed payment`(chance: Double) throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroMaxMana: 6, heroMana: 6, dealOpeningHand: false, appliesFightPacing: false,
        )
        let ability = Ability(
            id: "chance-conversion", name: "Chance Conversion", tier: .skill,
            targetedEffects: [TargetedEffect(.convertManaToBlock, target: .actor, chance: chance)],
        )
        let card = BattleCardCombatEngine.deal(ability, owner: .hero, context: &battle)
        let rng = battle.rng

        let assessment = battle.assessCard(card)

        #expect(assessment.denial == nil)
        #expect(assessment.targets.isEmpty == (chance < 1))
        if chance == 0 {
            #expect(assessment.resources.isEmpty)
            _ = try battle.playCard(cardID: card.id)
            #expect(battle.mana(of: battle.hero) == 6)
        } else {
            let use = try #require(assessment.resources.first)
            #expect(use.keyword == .mana)
            #expect(use.amount == (chance == 1 ? 6 : nil))
            #expect(battle.rng == rng)
        }
    }

    @Test func `Bounty Shot previews its hit without promising its chance Gold`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false)
        let card = BattleCardCombatEngine.deal(.bountyShot, owner: .hero, context: &battle)

        #expect(battle.assessCard(card).targets == [
            .init(combatantID: battle.enemy.id, intent: .damage(.stun)),
        ])
    }
}
