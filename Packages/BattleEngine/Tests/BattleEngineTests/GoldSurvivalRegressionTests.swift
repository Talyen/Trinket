import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct GoldSurvivalRegressionTests {
    @Test(arguments: ["Windfall", "Health is Wealth", "Golden Recovery"])
    func `Gold keeps its committed gain but stops later rewards when restoration kills its owner`(checkpoint: String) {
        var profile = CombatModifierProfile.zero
        profile.triggers.criticalChanceBonus = -1
        profile.triggers.onHealDealHoly = 1
        profile.triggers.gainGoldBonusHealSelf = checkpoint == "Windfall" ? 2 : 0
        profile.triggers.goldGainHealChancePercent = checkpoint == "Golden Recovery" ? 0 : 1
        profile.triggers.goldGainHealAmount = 2
        profile.triggers.onGainGoldHealParty = 2
        var partnerProfile = CombatModifierProfile.zero
        partnerProfile.triggers.blockPerGoldEarnedEvery = 1
        var enemyProfile = CombatModifierProfile.zero
        enemyProfile.triggers.onBlockHitDealHoly = 4
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 30),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 30),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroHealth: 1, companionHealth: 5,
            heroModifiers: profile, companionModifiers: partnerProfile,
            enemyModifiers: enemyProfile, appliesFightPacing: false,
        )
        battle.roster.hero.hasConsumedDeathsDoor = true
        DefensePoolEngine.set(6, on: battle.enemy, in: &battle)

        let gain = battle.recordingResult { battle in await battle.grantGold(
            1, to: battle.hero, abilityName: "Gold",
        ) }

        #expect(gain.value == 1)
        #expect(battle.gold == 1)
        #expect(gain.events.contains { $0.keyword == .gold && $0.amount == 1 })
        #expect(!battle.roster.hero.isAlive)
        #expect(battle.health(of: battle.companion) == 5)
        #expect(!gain.events.contains { $0.effectKind == .instantHeal && $0.targetID == battle.companion.id })
        // The partner's own threshold still observes the Gold already earned.
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.companion)) == 1)
    }

    @Test func `Shared Spoils cannot trigger Gold restoration after its owner falls`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.criticalChanceBonus = -1
        profile.triggers.onHealDealHoly = 1
        profile.triggers.goldTheftHealAllyFlat = 2
        profile.triggers.gainGoldBonusHealSelf = 2
        profile.triggers.onGainGoldHealParty = 2
        var enemyProfile = CombatModifierProfile.zero
        enemyProfile.triggers.onBlockHitDealHoly = 4
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 30),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 30),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroHealth: 5, companionHealth: 1,
            companionModifiers: profile, enemyModifiers: enemyProfile, appliesFightPacing: false,
        )
        battle.roster.companion.hasConsumedDeathsDoor = true
        DefensePoolEngine.set(6, on: battle.enemy, in: &battle)

        let gain = battle.recordingResult { battle in await battle.grantGold(
            1, to: battle.companion, abilityName: "Theft", isTheft: true,
        ) }

        #expect(gain.value == 1)
        #expect(!battle.roster.companion.isAlive)
        #expect(battle.health(of: battle.hero) == 7)
        #expect(gain.events.count(where: { $0.effectKind == .instantHeal }) == 1)
    }

    @Test func `Gold restoration that wins still finishes support rewards for a living owner`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.criticalChanceBonus = -1
        profile.triggers.gainGoldBonusHealSelf = 2
        profile.triggers.onHealDealHoly = 1
        profile.triggers.onGainGoldHealParty = 2
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 30),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 30),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroHealth: 1, companionHealth: 5, enemyHealth: 1,
            heroModifiers: profile, appliesFightPacing: false,
        )

        battle.grantGoldEvent(1, to: battle.hero, abilityName: "Gold")

        #expect(battle.isEnemyDefeated)
        #expect(battle.roster.hero.isAlive)
        #expect(battle.health(of: battle.hero) == 5)
        #expect(battle.health(of: battle.companion) == 7)
    }
}
