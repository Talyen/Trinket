import Foundation
import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct CombatSafetyRegressionTests {
    @Test func `companion equipment bonuses saturate`() {
        var profile = CombatModifierProfile.zero
        profile.companionDamageDealtBonus = Int.max
        profile.companionPhysicalDamageDealtBonus = 1
        let battle = BattleStateTestFactory.makeMinimalBattle(heroModifiers: profile)
        #expect(DamagePipeline.outgoingDamageBonus(for: battle.companion.id, keyword: .physical, in: battle) == Int.max)
    }

    @Test func `prepared talent damage saturates`() {
        var battle = BattleStateTestFactory.makeMinimalBattle()
        battle.roster.hero.talents.pending.nextAttackDamageBonus = PreparedTalentBonus(value: Int.max)
        var damage = packet(in: battle)
        damage.remaining = 1
        damage.itemBonus = 1
        DamagePipeline.applyTalentStatusMultipliers(to: &damage, in: &battle)
        #expect(damage.remaining == Int.max)
        #expect(damage.itemBonus == Int.max)
        #expect(battle.roster.hero.talents.pending.nextAttackDamageBonus == nil)
    }

    @Test func `backdraft saturates both damage snapshots`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.backdraft = true
        var battle = BattleStateTestFactory.makeMinimalBattle(heroModifiers: profile)
        battle.insertEffect(.burn(1), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 0)
        var damage = packet(in: battle)
        damage.isCritical = true
        damage.remaining = Int.max
        damage.unique.outgoingDamage = Int.max
        DamagePipeline.applyBackdraftBonus(to: &damage, in: &battle)
        #expect(damage.remaining == Int.max)
        #expect(damage.unique.outgoingDamage == Int.max)
        #expect(!battle.activeEffects(of: battle.enemy).contains { $0.effect.kind == .burn })
    }

    @Test func `combined block breaking stops at the remaining pool`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.sunderingBlockMultiplier = Double(Int.max)
        profile.triggers.physicalBlockBreakMultiplier = Double(Int.max)
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleStateTestFactory.makeMinimalBattle(heroModifiers: profile, appliesFightPacing: false)
        DefensePoolEngine.set(10, on: battle.enemy, in: &battle)
        let result = battle.resolveTestDamage(1, options: .attack(accuracy: .unavoidable))
        #expect(result.healthLost == 0)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.enemy)) == 0)
    }

    @Test func `golden crucible saturates accumulated gold`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.goldGainedNextHolyDamage = true
        var battle = BattleStateTestFactory.makeMinimalBattle(heroModifiers: profile)
        battle.roster.hero.uniques.goldDamage = Int.max
        UniqueCombatEngine.gainedGold(1, by: battle.hero, in: &battle)
        #expect(battle.roster.hero.uniques.goldDamage == Int.max)
    }

    @Test(arguments: [false, true])
    func `inspecting prepared damage cannot trap`(percentage: Bool) {
        var battle = BattleStateTestFactory.makeMinimalBattle()
        if percentage {
            battle.roster.hero.talents.pending.cardDamagePercent = Double(Int.max)
        } else {
            battle.roster.hero.talents.pending.cardDamageBonus = Int.max
            battle.roster.hero.talents.pending.feintStrikeDamageBonus = 1
        }
        let summaries = battle.talentEffectSummaries(of: battle.hero)
        let displayedMaximum = Int.max.formatted(.number.locale(Locale(identifier: "en")))
        #expect(summaries.contains { $0.text.contains(displayedMaximum) })
    }

    @Test(arguments: PlayPolicy.allCases)
    func `auto battle scores large support cards without trapping`(policy: PlayPolicy) {
        var battle = BattleStateTestFactory.makeMinimalBattle()
        battle.hand = BattleHand()
        let card = BattleCardCombatEngine.deal(
            Ability(id: "mana", name: "Mana", tier: .basic, effects: [.resourceGain(.mana, Int.max)]),
            owner: .hero, context: &battle,
        )
        #expect(policy.preferredPlayableCard(in: battle)?.id == card.id)
    }

    @Test func `oversized automatic draw stops when decks are empty`() {
        var battle = BattleStateTestFactory.makeMinimalBattle(appliesFightPacing: false)
        battle.heroDeck = CombatDeck(abilities: [.slash])
        battle.companionDeck = CombatDeck()
        let outcome = EffectHandlersTestSupport.dispatch(.drawAndPlayCards(Int.max), battle: &battle)
        #expect(outcome.didApply)
        #expect(outcome.events.first { $0.effectKind == .cardsDrawn }?.amount == 1)
        #expect(battle.heroDeck.abilities.isEmpty)
    }

    @Test func `pruning removes only available thorns in bounded work`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.pruningHealthRemoveEnemyThorns = Int.max
        var battle = BattleStateTestFactory.makeMinimalBattle(heroHealth: 1, heroModifiers: profile, appliesFightPacing: false)
        battle.insertEffect(.thorns(Int.max), to: battle.enemy, sourceID: battle.enemy.id, remainingTurns: 0)
        battle.insertEffect(.thorns(2), to: battle.enemy, sourceID: battle.enemy.id, remainingTurns: 0)
        _ = battle.resolveHeal(HealRequest(amount: 1, target: battle.hero, sourceActorID: battle.hero.id))
        #expect(battle.activeEffects(of: battle.enemy).filter { $0.effect.kind == .thorns }.map(\.effect) == [.thorns(2)])
    }

    @Test(arguments: [3, 6])
    func `empowerment preview pays card block cost first`(block: Int) throws {
        var profile = CombatModifierProfile.zero
        profile.triggers.freezeEmpowermentBlockPerMana = 1
        var battle = BattleStateTestFactory.makeMinimalBattle(heroModifiers: profile, appliesFightPacing: false)
        battle.roster.hero.currentMana = 0
        DefensePoolEngine.set(block, on: battle.hero, in: &battle)
        battle.hand = BattleHand()
        let ability = Ability(
            id: "block-freeze", name: "Block Freeze", tier: .basic,
            damageComponents: [DamageComponent(1, keyword: .freeze)], blockCost: 3,
        )
        let card = BattleCardCombatEngine.deal(ability, owner: .hero, context: &battle)
        let uses = battle.assessCard(card).resources.filter { $0.keyword == .block }
        #expect(uses.count == 1)
        #expect(uses.first?.amount == block)
        #expect(uses.first?.balance == block)
        _ = try battle.playCard(cardID: card.id)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.hero)) == 0)
    }

    private func packet(in battle: BattleState) -> DamageResolutionState {
        DamageResolutionState(
            amount: 1, combatant: battle.enemy, sourceActorID: battle.hero.id,
            damageKeyword: .physical, options: .attack(accuracy: .unavoidable),
        )
    }
}
