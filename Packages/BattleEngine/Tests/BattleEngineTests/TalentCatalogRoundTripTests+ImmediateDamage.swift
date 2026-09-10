import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

extension TalentCatalogRoundTripTests {
    @Test(arguments: ["rogue_poison_t1_1", "ranger_burn_t1_1"])
    func `critical talents deal immediate damage and leave their status`(talentID: String) {
        var battle = BattleTestFixtures.makePipelineContext(
            heroModifiers: CombatantTalentCatalog.profile(for: [talentID]),
        )
        battle.appliesFightPacing = false
        let before = battle.roster.enemy.currentHealth
        _ = CombatTriggerEngine.afterCriticalHit(to: battle.enemy, source: battle.hero, in: &battle)
        let keyword: Keyword = talentID == "rogue_poison_t1_1" ? .poison : .burn
        #expect(battle.roster.enemy.currentHealth == before - 2)
        #expect(battle.roster.enemy.activeEffects.contains { $0.keyword == keyword && $0.effect.potency == 2 })
    }

    @Test(arguments: [false, true])
    func `fuel the flames damages only burning enemies`(burning: Bool) {
        var battle = BattleTestFixtures.makePipelineContext(
            heroModifiers: CombatantTalentCatalog.profile(for: ["wizard_burn_t2_2"]),
        )
        battle.appliesFightPacing = false
        if burning {
            battle.appendEffect(.burn(3), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 0)
        }
        let before = battle.roster.enemy.currentHealth
        _ = CombatTriggerEngine.afterSpendMana(
            ManaPayment(
                payer: battle.hero,
                balanceBefore: battle.mana(of: battle.hero) + 2,
                balanceAfter: battle.mana(of: battle.hero),
            ),
            in: &battle,
        )
        #expect(battle.roster.enemy.currentHealth == before - (burning ? 1 : 0))
        #expect(battle.roster.enemy.activeEffects.first?.effect.potency == (burning ? 4 : nil))
    }

    @Test(arguments: ["risen_skeleton_leech_t1_2", "risen_skeleton_leech_t3_2"])
    func `leech talents deal immediate damage and leave their status`(talentID: String) {
        var battle = BattleTestFixtures.makePipelineContext(
            companionModifiers: CombatantTalentCatalog.profile(for: [talentID]),
        )
        battle.appliesFightPacing = false
        battle.roster.mutateRuntime(for: battle.companion) { $0.currentHealth = 1 }
        let before = battle.roster.enemy.currentHealth
        _ = HealingEngine.leechFromDamage(
            4, sourceActorID: battle.companion.id, target: battle.enemy,
            abilityHasLeech: true, damageKeyword: .physical, in: &battle,
        )
        let keyword: Keyword = talentID == "risen_skeleton_leech_t1_2" ? .poison : .bleed
        #expect(battle.roster.enemy.currentHealth == before - 2)
        #expect(battle.roster.enemy.activeEffects.contains { $0.keyword == keyword && $0.effect.potency == 2 })
    }
}
