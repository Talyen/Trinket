import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

extension ManaEmpowermentTests {
    @Test func `large saved Mana capacities remain usable for shared and discounted empowerment`() throws {
        var patron = CombatModifierProfile.zero
        patron.triggers.dragonPatronage = true
        let battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroMaxMana: Int.max, heroMana: 1,
            companionMaxMana: Int.max, companionMana: 2,
            companionModifiers: patron, dealOpeningHand: false,
        )
        var shared = ManaEmpowermentBudget(ability: .frostbolt, actor: battle.hero, in: battle)
        let sharedPayment = shared.nextPayment()
        let payment = try #require(sharedPayment)
        #expect(payment.ownMana == 1 && payment.partnerMana == 2)
        #expect(shared.nextPayment() == nil)

        var discounted = CombatModifierProfile.zero
        discounted.triggers.empowermentCostReduction = 2
        var discountedBattle = BattleStateTestFactory.makeBattleWithAbilities(
            heroMaxMana: Int.max, heroMana: 1,
            heroModifiers: discounted, dealOpeningHand: false,
        )
        discountedBattle.roster.hero.talents.pending.nextManaEmpowerDiscount = 1
        var repeated = ManaEmpowermentBudget(ability: .meteor, actor: discountedBattle.hero, in: discountedBattle)
        #expect(repeated.purchaseLimit == Int.max)
        let freePayment = repeated.nextPayment()
        #expect(try #require(freePayment).ownMana == 0)
        let paidPayment = repeated.nextPayment()
        #expect(try #require(paidPayment).ownMana == 1)
        #expect(repeated.nextPayment() == nil)
    }
}
