import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

extension BattleCardCombatTests {
    @Test func `direct effects and their reactions share a group without sharing origin`() throws {
        let ability = Ability(
            id: "feedback", name: "Same Display Name", tier: .basic,
            targetedEffects: [TargetedEffect(.shield(.block, 4), target: .actor)],
        )
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [ability], heroModifiers: CombatantTalentCatalog.profile(for: ["knight_block_t1_2"]),
        )
        battle.appliesFightPacing = false
        let card = try #require(battle.hand.cards.first)
        let events = try battle.playCard(cardID: card.id)
        let block = try #require(events.first { $0.effectKind == .shieldApplied })
        let thorns = try #require(events.first { $0.effectKind == .thornsApplied })
        #expect(block.origin == .direct)
        #expect(thorns.origin == .automatic)
        #expect(Set(events.map(\.feedbackGroupID)).count == 1)
        let next = BattleTurnEngine.performAction(ability: ability, actor: battle.hero, abilityTarget: battle.enemy, context: &battle)
        #expect(next.first?.feedbackGroupID != block.feedbackGroupID)
        let automatic = battle.withAutomaticPlay { context in
            BattleTurnEngine.performAction(ability: ability, actor: context.hero, abilityTarget: context.enemy, context: &context)
        }
        #expect(automatic.filter { $0.effectKind == .shieldApplied }.allSatisfy { $0.origin == .automatic })
    }

    @Test(arguments: [2, 8])
    func `absorption events distinguish full and partial block`(block: Int) throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false)
        battle.appliesFightPacing = false
        DefensePoolEngine.set(block, on: battle.hero, in: &battle)
        let outcome = battle.resolveDamage(DamageRequest(
            amount: 5, target: battle.hero, keyword: .physical, sourceActorID: battle.enemy.id,
            options: .attack(scaling: .flat, accuracy: .unavoidable),
        ))
        let event = try #require(outcome.events.first { $0.effectKind == .shieldAbsorbed })
        #expect(event.isFullyBlocked == (block >= 5))
    }

    @Test func `periodic feedback shares its checkpoint and detail includes active preparations`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false)
        battle.appliesFightPacing = false
        battle.appendEffect(.bleed(2), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 3)
        battle.appendEffect(.poison(3), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 0)
        let events = EffectTurnEngine.advanceAll(context: &battle)
        let ticks = events.filter { $0.kind == .status }
        #expect(ticks.count == 2)
        #expect(ticks.allSatisfy { $0.origin == .periodic })
        #expect(Set(ticks.map(\.feedbackGroupID)).count == 1)
        battle.roster.hero.talents.pending.nextAttackHolyBonus = 3
        battle.roster.hero.talents.timed.dodge.amount = 0.2
        battle.roster.hero.talents.timed.dodge.expiresAtTurn = battle.turnCount + 1
        let summaries = battle.effectSummaries(of: battle.hero)
        #expect(summaries.contains { $0.keyword == .holy })
        #expect(summaries.contains { $0.keyword == .dodge })
        battle.roster.hero.talents.pending.nextAttackHolyBonus = 0
        battle.roster.hero.talents.beginTurn(battle.turnCount + 1)
        #expect(battle.effectSummaries(of: battle.hero).isEmpty)
    }
}
