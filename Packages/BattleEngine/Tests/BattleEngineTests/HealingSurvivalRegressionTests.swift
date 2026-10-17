import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct HealingSurvivalRegressionTests {
    @Test(arguments: [false, true])
    func `healing rewards stop when a triggered cleanse defeats the healer`(cleanSlate: Bool) {
        var profile = CombatModifierProfile.zero
        profile.triggers.cleanSlate = cleanSlate
        profile.triggers.onHealCleanseTargetChance = cleanSlate ? 0 : 1
        profile.triggers.cleanseHolyDamage = 3
        profile.triggers.onHealGrantBlock = 3
        profile.triggers.healOverTimeOnHealAmount = 2
        profile.triggers.healOverTimeOnHealTurns = 2
        profile.triggers.overhealConvertsToBlock = true
        profile.triggers.wishspring = true
        var battle = makeBattle(profile: profile, heroHealth: 19)
        battle.insertEffect(.poison(2), to: battle.hero, sourceID: battle.enemy.id, remainingTurns: 0)

        let outcome = battle.resolveHeal(HealRequest(amount: 3, target: battle.hero, sourceActorID: battle.companion.id))

        #expect(!battle.roster.companion.isAlive)
        #expect(outcome.healthRestored == 1)
        #expect(battle.health(of: battle.hero) == 20)
        #expect(!battle.hasTalentDebuff(on: battle.hero))
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.hero)) == (cleanSlate ? 0 : 5))
        #expect(battle.roster.hero.currentMana == (cleanSlate ? 0 : 1))
        #expect(battle.roster.hero.talents.timed.lingeringBlessing == nil)
    }

    @Test func `stored healing from a defeated source preserves restoration and recipient overflow rewards`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.onHealGrantBlock = 3
        profile.triggers.wishspring = true
        var battle = makeBattle(profile: profile, heroHealth: 19, heroModifiers: .withTriggers { $0.overhealConvertsToBlock = true })
        battle.roster.companion.currentHealth = 0

        let outcome = battle.resolveHeal(HealRequest(
            amount: 3, target: battle.hero, sourceActorID: battle.companion.id, origin: .periodic,
        ))

        #expect(outcome.healthRestored == 1)
        #expect(battle.health(of: battle.hero) == 20)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.hero)) == 2)
        #expect(battle.roster.hero.currentMana == 0)
    }

    @Test func `Shared Roots requires its Druid to survive Cleansing Dew`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.cleansingDew = true
        profile.triggers.cleanseHolyDamage = 3
        profile.triggers.sharedRootsHealPercent = 1
        var battle = makeBattle(profile: profile, heroHealth: 5)
        battle.insertEffect(.poison(2), to: battle.companion, sourceID: battle.enemy.id, remainingTurns: 0)

        _ = battle.resolveHeal(HealRequest(amount: 1, target: battle.companion, sourceActorID: battle.companion.id))

        #expect(!battle.roster.companion.isAlive)
        #expect(battle.health(of: battle.hero) == 5)
    }

    @Test(arguments: [false, true])
    func `party card healing stops when its source falls during the first heal`(survives: Bool) {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 20),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 20),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroHealth: survives ? 10 : 1, companionHealth: 5,
            heroModifiers: .withTriggers {
                $0.cardsPlayedHealPartyThreshold = 1
                $0.cardsPlayedHealPartyAmount = 2
                $0.onHealDealHoly = 3
                $0.criticalChanceBonus = -1
            },
            enemyModifiers: .withTriggers { $0.onBlockHitDealHoly = 4 },
            appliesFightPacing: false,
        )
        battle.roster.hero.hasConsumedDeathsDoor = true
        battle.turnCadence.cardsPlayed[.hero] = 1
        DefensePoolEngine.set(6, on: battle.enemy, in: &battle)

        CombatExecutor.run { await CombatTriggerEngine.afterPartyCardPlayed(in: &battle) }

        #expect(battle.roster.hero.isAlive == survives)
        #expect(battle.health(of: battle.companion) == (survives ? 7 : 5))
    }

    private func makeBattle(
        profile: CombatModifierProfile,
        heroHealth: Int,
        heroModifiers: CombatModifierProfile = .zero,
    ) -> BattleState {
        var companionProfile = profile
        companionProfile.triggers.criticalChanceBonus = -1
        var enemy = CombatModifierProfile.zero
        enemy.triggers.onBlockHitDealHoly = 2
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 20, maxMana: 5),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 20),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroHealth: heroHealth, companionHealth: 1, heroMana: 0,
            heroModifiers: heroModifiers, companionModifiers: companionProfile, enemyModifiers: enemy, appliesFightPacing: false,
        )
        battle.roster.companion.hasConsumedDeathsDoor = true
        DefensePoolEngine.set(6, on: battle.enemy, in: &battle)
        return battle
    }
}
