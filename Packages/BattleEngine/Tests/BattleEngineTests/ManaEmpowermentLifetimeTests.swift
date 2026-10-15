import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct ManaEmpowermentLifetimeTests {
    @Test func `completed empowerment cannot strengthen a later reaction`() {
        var battle = makeBattle()
        let ability = Ability(
            id: "empowered-burn", name: "Empowered Burn", tier: .basic,
            directDamage: 2, damageKeyword: .burn, criticalChanceBonus: -1,
        )
        let events = battle.performTestAction(ability, from: .companion)
        #expect(events.filter { $0.kind == .abilityDamage }.map(\.amount) == [12])

        let reaction = battle.resolveTestDamage(4, from: .companion, keyword: .burn, options: .reaction())
        #expect(reaction.healthLost == 4)
    }

    @Test(arguments: [false, true])
    func `nested casts preserve parent empowerment through prepared repeats and Spell Echo`(repeats: Bool) throws {
        var battle = makeBattle(echoes: true)
        if repeats {
            battle.appendEffect(.playNextCardTwice, to: battle.companion, sourceID: battle.companion.id, remainingTurns: 0)
        }
        let nested = Ability(
            id: "nested-hit", name: "Nested Hit", tier: .basic,
            directDamage: 2, criticalChanceBonus: -1,
        )
        battle.companionDeck = CombatDeck(abilities: [nested])
        let ability = Ability(
            id: "nested-empowered-burn", name: "Nested Empowered Burn", tier: .skill,
            criticalChanceBonus: -1,
            operations: [
                .damage(DamageComponent(2, keyword: .burn)),
                .effect(TargetedEffect(.drawAndPlayCards(1), target: .actor)),
                .damage(DamageComponent(2, keyword: .burn)),
            ],
        )
        let card = BattleCardCombatEngine.deal(ability, owner: .companion, context: &battle)
        let events = try battle.playCard(cardID: card.id).events

        let hits = events.filter { $0.kind == .abilityDamage && $0.abilityID == ability.id }
        #expect(hits.map(\.amount) == (repeats ? [12, 12, 12, 12, 2, 2] : [12, 12, 2, 2]))
        #expect(events.filter { $0.kind == .abilityDamage && $0.abilityID == nested.id }.map(\.amount) == [2])
        #expect(battle.mana(of: battle.companion) == 0)
    }

    private func makeBattle(echoes: Bool = false) -> BattleState {
        var profile = CombatModifierProfile.zero
        profile.triggers.criticalChanceBonus = -1
        profile.triggers.manaEmpowerDamageChancePercent = 1
        profile.triggers.manaEmpowerDamageMultiplier = 2
        profile.triggers.manaEmpowerBurnFreezeDamageMultiplier = 2
        profile.triggers.empoweredSkillEchoes = echoes
        return BattleStateTestFactory.makeBattleWithAbilities(
            enemyMaxHealth: 200, companionMaxMana: 3, companionMana: 3,
            companionModifiers: profile, dealOpeningHand: false, appliesFightPacing: false,
        )
    }
}
