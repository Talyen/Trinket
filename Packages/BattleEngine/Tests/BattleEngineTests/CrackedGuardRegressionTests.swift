import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct CrackedGuardRegressionTests {
    @Test func `Laughing Guard breaking enemy Block prepares the next Critical Hit`() throws {
        var profile = CombatantTalentCatalog.profile(for: ["wildcard_physical_t2_2"])
        let laughingGuard = try #require(GameContent.unique(matching: "laughing_guard")?.affixPowers?.first)
        profile.triggers.merge(laughingGuard.triggers)
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [.slash], heroModifiers: profile, dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        DefensePoolEngine.set(8, on: battle.hero, in: &battle)
        DefensePoolEngine.set(2, on: battle.enemy, in: &battle)

        _ = UniqueCombatEngine.afterUniqueDodge(by: battle.hero, attackerID: battle.enemy.id, in: &battle)

        #expect(DefensePoolEngine.blockPoints(in: battle.roster.enemy.activeEffects) == 0)
        #expect(battle.roster.hero.talents.pending.nextAttackGuaranteedCritical != nil)
        let card = BattleCardCombatEngine.deal(.slash, owner: .hero, context: &battle)
        let events = try battle.playCard(cardID: card.id)
        #expect(events.contains { $0.kind == .abilityDamage && $0.abilityID == Ability.slash.id && $0.isCritical })
        #expect(battle.roster.hero.talents.pending.nextAttackGuaranteedCritical == nil)
    }

    @Test func `Block break preparation waits for the next card rather than a later hit`() throws {
        var profile = CombatantTalentCatalog.profile(for: ["wildcard_physical_t2_2"])
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroModifiers: profile, dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        DefensePoolEngine.set(1, on: battle.enemy, in: &battle)
        let twoHits = Ability(
            id: "two-physical-hits", name: "Two Physical Hits", tier: .basic,
            damageComponents: [DamageComponent(2, keyword: .physical), DamageComponent(2, keyword: .physical)],
        )
        let card = BattleCardCombatEngine.deal(twoHits, owner: .hero, context: &battle)
        let creating = try battle.playCard(cardID: card.id)
        #expect(creating.filter { $0.kind == .abilityDamage }.allSatisfy { !$0.isCritical })
        #expect(battle.roster.hero.talents.pending.nextAttackGuaranteedCritical != nil)
        let next = BattleCardCombatEngine.deal(.slash, owner: .hero, context: &battle)
        let consuming = try battle.playCard(cardID: next.id)
        #expect(consuming.contains { $0.kind == .abilityDamage && $0.isCritical })
        #expect(battle.roster.hero.talents.pending.nextAttackGuaranteedCritical == nil)
    }
}
