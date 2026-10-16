import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct CompanionAttackSurvivalTests {
    @Test(arguments: [false, true])
    func `Companion Holy hit stops remaining benefits after lethal Gold or Purge reactions`(purgeReaction: Bool) {
        var profile = CombatModifierProfile.zero
        profile.triggers.criticalChanceBonus = -1
        profile.triggers.criticalGoldStealFlat = purgeReaction ? 0 : 1
        profile.triggers.gainGoldBonusHealSelf = purgeReaction ? 0 : 1
        profile.triggers.onHealDealHoly = 1
        profile.triggers.holyCriticalAllyIgnoreBlock = true
        profile.triggers.holyCriticalPurgeCount = purgeReaction ? 1 : 0
        profile.triggers.crownfall = purgeReaction
        profile.triggers.holyAttackEnemyMissChance = 1
        profile.triggers.holyAttackDrawChancePercent = 1
        profile.triggers.holyAttackCleanseAllyChancePercent = 1
        profile.triggers.holyCritEnemyNextAttackMissChance = 1
        var enemyProfile = CombatModifierProfile.zero
        enemyProfile.triggers.onBlockHitDealHoly = 3
        enemyProfile.triggers.sealedSarcophagus = true
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 30),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 30),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            companionHealth: 1,
            companionModifiers: profile, enemyModifiers: enemyProfile, appliesFightPacing: false,
        )
        battle.roster.companion.hasConsumedDeathsDoor = true
        battle.companionDeck = CombatDeck(abilities: [.block])
        DefensePoolEngine.set(20, on: battle.enemy, in: &battle)
        battle.insertEffect(.poison(2), to: battle.hero, sourceID: battle.enemy.id, remainingTurns: 1)
        battle.insertEffect(.thorns(2), to: battle.enemy, sourceID: battle.enemy.id, remainingTurns: 0)

        let events = battle.recordingEvents { battle in await CombatTriggerEngine.afterCompanionAttackHit(
            keyword: .holy, actor: battle.companion, critical: true, healthLost: 1,
            triggers: profile.triggers, in: &battle,
        ) }

        #expect(!battle.roster.companion.isAlive)
        #expect(battle.roster.hero.isAlive)
        #expect(battle.gold == (purgeReaction ? 0 : 1))
        // Revealed Flaw precedes Bane of Evil and remains committed if the later Purge is lethal.
        #expect((battle.roster.hero.talents.pending.nextAttackIgnoresBlock != nil) == purgeReaction)
        #expect(battle.activeEffects(of: battle.hero).contains { $0.effect == .poison(2) })
        #expect(battle.companionDeck.abilities.map(\.id) == [Ability.block.id])
        #expect(battle.roster.enemy.talents.pending.nextAttackMissChance == 0)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.enemy)) == (purgeReaction ? 17 : 19))
        #expect(!events.contains { $0.abilityName == "Purifying Light" || $0.abilityName == "Radiant Wisdom" })
        #expect(events.contains { $0.abilityName == (purgeReaction ? "Bane of Evil" : "Pickpocket") })
    }

    @Test(arguments: [false, true])
    func `final Companion hit does not prepare enemy misses after lethal reward retaliation`(goldReaction: Bool) {
        var profile = CombatModifierProfile.zero
        profile.triggers.criticalChanceBonus = -1
        profile.triggers.attackGoldStealAmount = goldReaction ? 1 : 0
        profile.triggers.attackGoldStealChancePercent = 1
        profile.triggers.gainGoldBonusHealSelf = 1
        profile.triggers.onHealDealHoly = 1
        profile.triggers.holyCriticalStunDamage = goldReaction ? 0 : 1
        profile.triggers.holyCritEnemyNextAttackMissChance = 1
        var enemyProfile = CombatModifierProfile.zero
        enemyProfile.triggers.onBlockHitDealHoly = 3
        var battle = BattleStateTestFactory.makeMinimalBattle(
            companion: CombatantFixtures.passiveCompanion(maxHealth: 30),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            companionHealth: 1,
            companionModifiers: profile, enemyModifiers: enemyProfile, appliesFightPacing: false,
        )
        battle.roster.companion.hasConsumedDeathsDoor = true
        DefensePoolEngine.set(20, on: battle.enemy, in: &battle)

        let events = battle.recordingEvents { battle in await CombatTriggerEngine.afterFinalCompanionCardHit(
            keyword: .holy, actor: battle.companion, critical: true, triggers: profile.triggers, in: &battle,
        ) }

        #expect(!battle.roster.companion.isAlive)
        #expect(battle.roster.enemy.talents.pending.nextAttackMissChance == 0)
        #expect(battle.gold == (goldReaction ? 1 : 0))
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.enemy)) == 19)
        #expect(events.contains { $0.abilityName == "Snatch" } == goldReaction)
    }
}
