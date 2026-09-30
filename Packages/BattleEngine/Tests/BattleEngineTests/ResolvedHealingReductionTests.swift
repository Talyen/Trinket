import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct ResolvedHealingReductionTests {
    @Test(arguments: [false, true])
    func `Symbiosis respects each recipient's Sapped without repeating healer bonuses`(heroSapped: Bool) throws {
        let affix = try #require(GameContent.itemAffixDefinition(matching: "symbiosis"))
        var profile = CombatModifierProfile.zero
        affix.basic.triggers.apply(to: &profile, abilityName: affix.title)
        profile.healthRestoredBonus = 4
        profile.healthRestoredPercent = 0.5
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 100),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 100),
            enemy: CombatantFixtures.passiveEnemy(abilities: [.serratedEdge]),
            heroModifiers: profile,
        )
        battle.appliesFightPacing = false
        for target in heroSapped ? [battle.hero, battle.companion] : [battle.companion] {
            _ = BattleTurnEngine.performAction(
                ability: .serratedEdge, actor: battle.enemy, abilityTarget: target, context: &battle,
            )
        }
        battle.roster.hero.currentHealth = 10
        battle.roster.companion.currentHealth = 10

        let result = HealingEngine.leechFromDamage(
            16, sourceActorID: battle.hero.id, target: battle.enemy, abilityHasLeech: true, in: &battle,
        )

        let expectedHeroRestoration = heroSapped ? 14 : 18
        let expectedCompanionShare = heroSapped ? 5 : 7
        #expect(result.healthRestored == expectedHeroRestoration)
        #expect(battle.health(of: battle.hero) == 10 + expectedHeroRestoration)
        #expect(battle.health(of: battle.companion) == 10 + expectedCompanionShare)
        let share = try #require(result.events.first { $0.abilityName == "Symbiosis" && $0.effectKind == .instantHeal })
        #expect(share.amount == expectedCompanionShare)
        #expect(!share.isCritical)
    }
}
