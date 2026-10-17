import Testing
import TrinketContent
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
            heroModifiers: hero, companionModifiers: companion, dealOpeningHand: false, appliesFightPacing: false,
        )
        _ = battle.chargeTestControl(
            ControlMeterEngine.threshold(for: battle.enemy, in: battle),
            keyword: .stun,
            to: battle.enemy,
            sourceActorID: battle.hero.id,
            applyFightPacing: false,
        )
        _ = battle.endTurn()
        let recovered = battle.endTurn().events
        #expect(recovered.filter { $0.kind == .abilityDamage && $0.actorID == battle.enemy.id }.map(\.amount) == [5])
        let later = battle.endTurn().events
        #expect(later.filter { $0.kind == .abilityDamage && $0.actorID == battle.enemy.id }.map(\.amount) == [10])
    }

    @Test(arguments: ["bear_physical_t3_2", "wolf_physical_t2_1"])
    func `Physical Critical removal talents report remaining Block stripped on a counterattacking Basic`(talentID: String) throws {
        let profile = CombatantTalentCatalog.profile(for: [talentID])
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionAbilities: [.slash], companionModifiers: profile, dealOpeningHand: false, appliesFightPacing: false,
        )
        DefensePoolEngine.set(20, on: battle.enemy, in: &battle)
        battle.insertEffect(.nextStrikeCritical, to: battle.companion, sourceID: battle.companion.id, remainingTurns: 0)
        let events = battle.recordingEvents { battle in await BattleTurnEngine.performAction(
            ability: .slash, actor: battle.companion, abilityTarget: battle.enemy,
            origin: .counterattack, context: &battle,
        ) }
        #expect(events.contains { $0.kind == .abilityDamage && $0.isCritical })
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.enemy)) == 0)
        let losses = events.filter { $0.effectKind == .blockStripped }
        #expect(losses.count == 1)
        let loss = try #require(losses.first)
        let absorbed = events.filter { $0.effectKind == .shieldAbsorbed }.reduce(0) { $0 + $1.amount }
        #expect(loss.amount == 20 - absorbed)
        #expect(loss.actorID == battle.companion.id && loss.targetID == battle.enemy.id)
        let name = talentID == "bear_physical_t3_2" ? "Pulverize" : "Bone-Crushing Bite"
        #expect(BattleLogProjection.entries(from: events).count(where: {
            $0.text == "\(battle.companion.name) removes \(loss.amount) Block from \(battle.enemy.name) (\(name))."
        }) == 1)
    }

    @Test func `Volatile Remedy waits for the next attack after Poison Dagger Leech`() throws {
        var profile = CombatantTalentCatalog.profile(for: ["alchemist_health_t3_2"])
        profile.triggers.poisonAttackLeech = true
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroModifiers: profile, dealOpeningHand: false, appliesFightPacing: false,
        )
        battle.roster.hero.currentHealth = 10
        let dagger = try play(.poisonDagger, in: &battle)
        #expect(dagger.filter { $0.kind == .abilityDamage && $0.abilityID == Ability.poisonDagger.id }.map(\.amount) == [1, 1])
        let next = try play(.causticJab, in: &battle)
        #expect(next.filter { $0.kind == .abilityDamage && $0.abilityID == Ability.causticJab.id }.map(\.amount) == [3])
    }

    @Test func `Denouncing prepares a later Holy attack while Meteor finishes its Mana empowerment`() throws {
        var profile = CombatModifierProfile.zero
        profile.triggers.manaEmpowerPurgeCount = 1
        profile.triggers.purgeNextHolyAttackBonus = 2
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            enemyMaxHealth: 1, heroMaxMana: 9, heroMana: 9,
            heroModifiers: profile, dealOpeningHand: false, appliesFightPacing: false,
        )
        battle.insertEffect(.thorns(1), to: battle.enemy, sourceID: battle.enemy.id, remainingTurns: 0)
        _ = try play(.meteor, in: &battle)
        #expect(battle.isBattleOver)
        #expect(battle.mana(of: battle.hero) == 0)
        #expect(battle.roster.hero.talents.pending.nextPurgeHolyAttackBonus?.value == 2)
    }

    @Test func `Gold action summaries include the Gold actually granted by equipment`() throws {
        var profile = CombatModifierProfile.zero
        profile.goldGainedBonus = 2
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroModifiers: profile, dealOpeningHand: false, appliesFightPacing: false,
        )
        let events = try play(.goldenPlate, in: &battle)
        #expect(battle.gold == 7)
        let summary = try #require(events.first { $0.kind == .ability && $0.abilityID == Ability.goldenPlate.id })
        #expect(summary.appliedEffects.contains(.resourceGain(.gold, 7)))
        #expect(BattleLogProjection.entries(from: events).contains { $0.text.contains("gain 7 Gold") })
    }

    private func play(_ ability: Ability, in battle: inout BattleState) throws -> [ActionEvent] {
        let card = BattleCardCombatEngine.deal(ability, owner: .hero, context: &battle)
        return try battle.recordingEvents { context in _ = try await BattleCardCombatEngine.resolveDrawnCard(card, context: &context) }
    }
}
