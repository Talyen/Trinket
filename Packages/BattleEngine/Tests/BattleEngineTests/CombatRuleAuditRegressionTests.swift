import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct CombatRuleAuditRegressionTests {
    @Test func `Concussive Blow reduces the recovered enemy action and then expires`() {
        var hero = CombatantTalentCatalog.profile(for: ["knight_stun_t1_2"])
        hero.triggers.dodgeChanceBonus = -1
        var companion = CombatModifierProfile.zero
        companion.triggers.dodgeChanceBonus = -1
        let attack = Ability(id: "recovery-hit", name: "Recovery Hit", tier: .basic, directDamage: 10)
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            enemyAbilities: [attack], heroMaxHealth: 100, companionMaxHealth: 100,
            heroModifiers: hero, companionModifiers: companion, dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        _ = ControlMeterEngine.applyMeterCharge(
            ControlMeterEngine.threshold(for: battle.enemy, in: battle), keyword: .stun,
            to: battle.enemy, sourceActorID: battle.hero.id, applyFightPacing: false, in: &battle,
        )
        _ = BattleCardCombatEngine.endTurn(context: &battle)
        let recovered = BattleCardCombatEngine.endTurn(context: &battle)
        #expect(recovered.filter { $0.kind == .abilityDamage && $0.actorID == battle.enemy.id }.map(\.amount) == [5])
        let later = BattleCardCombatEngine.endTurn(context: &battle)
        #expect(later.filter { $0.kind == .abilityDamage && $0.actorID == battle.enemy.id }.map(\.amount) == [10])
    }

    @Test func `Pulverize strips Block on a counterattacking Basic`() {
        let profile = CombatantTalentCatalog.profile(for: ["bear_physical_t3_2"])
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionAbilities: [.slash], companionModifiers: profile, dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        DefensePoolEngine.set(20, on: battle.enemy, in: &battle)
        battle.appendEffect(.nextStrikeCritical, to: battle.companion, sourceID: battle.companion.id, remainingTurns: 0)
        let events = BattleTurnEngine.performAction(
            ability: .slash, actor: battle.companion, abilityTarget: battle.enemy,
            origin: .counterattack, context: &battle,
        )
        #expect(events.contains { $0.kind == .abilityDamage && $0.isCritical })
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.enemy)) == 0)
    }

    @Test func `Volatile Remedy waits for the next attack after Poison Dagger Leech`() throws {
        var profile = CombatantTalentCatalog.profile(for: ["alchemist_health_t3_2"])
        profile.triggers.poisonDamageLeech = true
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroModifiers: profile, dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        battle.roster.hero.currentHealth = 10
        let dagger = try play(.poisonDagger, in: &battle)
        #expect(dagger.filter { $0.kind == .abilityDamage && $0.abilityID == Ability.poisonDagger.id }.map(\.amount) == [1, 1])
        let next = try play(.causticJab, in: &battle)
        #expect(next.filter { $0.kind == .abilityDamage && $0.abilityID == Ability.causticJab.id }.map(\.amount) == [3])
    }

    @Test func `Meteor stops buying empowerment after a Purge reaction wins`() throws {
        var profile = CombatModifierProfile.zero
        profile.triggers.manaEmpowerPurgeCount = 1
        profile.triggers.onPurgeDealHolyDamage = 2
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            enemyMaxHealth: 1, heroMaxMana: 9, heroMana: 9,
            heroModifiers: profile, dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        battle.appendEffect(.thorns(1), to: battle.enemy, sourceID: battle.enemy.id, remainingTurns: 0)
        _ = try play(.meteor, in: &battle)
        #expect(battle.isBattleOver)
        #expect(battle.mana(of: battle.hero) == 6)
    }

    @Test func `Gold action summaries include the Gold actually granted by equipment`() throws {
        var profile = CombatModifierProfile.zero
        profile.goldGainedBonus = 2
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroModifiers: profile, dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        let events = try play(.goldenPlate, in: &battle)
        #expect(battle.gold == 7)
        let summary = try #require(events.first { $0.kind == .ability && $0.abilityID == Ability.goldenPlate.id })
        #expect(summary.appliedEffectSummaries.contains("gain 7 Gold"))
        #expect(BattleLogReducer.entries(from: events).contains { $0.text.contains("gain 7 Gold") })
    }

    private func play(_ ability: Ability, in battle: inout BattleState) throws -> [ActionEvent] {
        let card = BattleCardCombatEngine.deal(ability, owner: .hero, context: &battle)
        return try BattleCardCombatEngine.playDrawnCard(card, context: &battle)
    }
}
