import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct PoisonRewardApplicationTests {
    @Test(arguments: [0, 2, 4])
    func `Toxic Incense leaves only the Poison damage that passed Block`(block: Int) throws {
        let affix = try #require(GameContent.itemAffixDefinition(matching: "brass_censer"))
        var profile = CombatModifierProfile.zero
        affix.astral.triggers.apply(to: &profile, abilityName: affix.title)
        profile.triggers.holyDamagePoisonFlat = 4
        var battle = makeBattle(profile: profile)
        DefensePoolEngine.set(block, on: battle.enemy, in: &battle)
        let before = battle.health(of: battle.enemy)

        CombatExecutor.run { await CombatTriggerEngine.afterHolyDamageDealt(
            to: battle.enemy, source: battle.hero, in: &battle,
        ) }

        let lost = 4 - block
        #expect(before - battle.health(of: battle.enemy) == lost)
        #expect(battle.activeEffects(of: battle.enemy).first { $0.effect.kind == .poison }?.effect.potency == (lost > 0 ? lost : nil))
    }

    @Test func `Toxic Remedy refreshes from actual healing and combines with Volatile Remedy on a later attack`() throws {
        let affix = try #require(GameContent.itemAffixDefinition(matching: "mortar_and_pestle"))
        var profile = CombatModifierProfile.zero
        affix.basic.triggers.apply(to: &profile, abilityName: affix.title)
        profile.triggers.criticalChanceBonus = -1
        var battle = makeBattle(profile: profile)
        battle.roster.hero.currentHealth = 28
        let cardID = battle.resolution.beginCard(actorID: battle.hero.id)
        _ = battle.resolution.beginAction(BattleActionContext(actor: battle.hero, in: battle), origin: .card)

        _ = battle.resolveHeal(HealRequest(amount: 8, target: battle.hero, sourceActorID: battle.companion.id))
        #expect(battle.health(of: battle.enemy) == 100)
        #expect(battle.roster.hero.talents.pending.nextToxicRemedyDamageBonus?.value == 4)
        let refresh = battle.resolveHeal(HealRequest(amount: 20, target: battle.hero, sourceActorID: battle.hero.id))
        #expect(refresh.healthRestored == 4)
        #expect(battle.roster.hero.talents.pending.nextToxicRemedyDamageBonus?.value == 2)
        _ = battle.resolveHeal(HealRequest(amount: 20, target: battle.hero, sourceActorID: battle.hero.id))
        #expect(battle.roster.hero.talents.pending.nextToxicRemedyDamageBonus?.value == 2)
        let attack = DamageOperation.attack(scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1)
        let creatingHit = battle.resolveTestDamage(1, keyword: .poison, options: attack)
        #expect(creatingHit.healthLost == 1)
        battle.resolution.endAction()
        // A later action inside the same card still cannot spend its preparation.
        _ = battle.resolution.beginAction(BattleActionContext(actor: battle.hero, in: battle), origin: .card)
        let sameCardHit = battle.resolveTestDamage(1, keyword: .poison, options: attack)
        #expect(sameCardHit.healthLost == 1)
        battle.resolution.endAction()
        battle.resolution.endCard(cardID)
        let tick = battle.resolveTestDamage(1, keyword: .poison, options: .resolvedPeriodic)
        #expect(tick.healthLost == 1)
        #expect(battle.roster.hero.talents.pending.nextToxicRemedyDamageBonus?.value == 2)
        battle.roster.hero.talents.pending.nextPoisonDamageBonus = PreparedTalentBonus(value: 3)
        DefensePoolEngine.set(2, on: battle.enemy, in: &battle)
        let nextHit = battle.resolveTestDamage(1, keyword: .poison, options: attack)
        #expect(nextHit.healthLost == 4)
        #expect(battle.roster.hero.talents.pending.nextPoisonDamageBonus == nil)
        #expect(battle.roster.hero.talents.pending.nextToxicRemedyDamageBonus == nil)
        let unprepared = battle.resolveTestDamage(1, keyword: .poison, options: attack)
        #expect(unprepared.healthLost == 1)
        #expect(!battle.roster.hasAffliction(.poison, on: battle.enemy))
    }

    private func makeBattle(profile: CombatModifierProfile) -> BattleState {
        BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 40),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 40),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroModifiers: profile, appliesFightPacing: false,
        )
    }
}
