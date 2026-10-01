import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

extension AbilityEffectIntegrationTests {
    @Test func `winning Burn critical restores Furnace Rhythm Mana`() throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            enemyMaxHealth: 1, companionMaxMana: 10, companionMana: 0,
            companionModifiers: CombatantTalentCatalog.profile(for: ["phoenix_burn_t4_1"]),
            dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        let attack = Ability(
            id: "winning-burn", name: "Winning Burn", tier: .basic,
            damageComponents: [DamageComponent(1, keyword: .burn)],
            guaranteedCriticalCondition: .enemyFullHealth,
        )
        let card = BattleCardCombatEngine.deal(attack, owner: .companion, context: &battle)

        let events = try battle.playCard(cardID: card.id)

        #expect(battle.isEnemyDefeated)
        #expect(events.contains { $0.kind == .abilityDamage && $0.isCritical })
        #expect(battle.mana(of: battle.companion) == 3)
        #expect(events.contains { $0.abilityName == "Furnace Rhythm" && $0.amount == 3 })
    }

    @Test(arguments: [Keyword.holy, .bleed])
    func `winning Companion attacks retain their talent draw`(keyword: Keyword) throws {
        let talentID = keyword == .holy ? "library_owl_holy_t2_2" : "lizard_scout_bleed_t3_1"
        let name = keyword == .holy ? "Radiant Wisdom" : "Frenzied Tail"
        var profile = CombatantTalentCatalog.profile(for: [talentID])
        profile.triggers.holyAttackDrawChancePercent = keyword == .holy ? 1 : 0
        profile.triggers.bleedCriticalDrawChancePercent = keyword == .bleed ? 1 : 0
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            enemyMaxHealth: 1, companionModifiers: profile, dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        battle.companionDeck = CombatDeck(abilities: [.stargaze])
        let attack = Ability(
            id: "winning-draw", name: "Winning Draw", tier: .basic,
            damageComponents: [DamageComponent(1, keyword: keyword)],
            guaranteedCriticalCondition: .enemyFullHealth,
        )
        let card = BattleCardCombatEngine.deal(attack, owner: .companion, context: &battle)

        let events = try battle.playCard(cardID: card.id)

        #expect(battle.isEnemyDefeated)
        #expect(events.contains { $0.kind == .abilityDamage && $0.isCritical })
        #expect(events.count { $0.effectKind == .cardsDrawn && $0.abilityName == name } == 1)
        #expect(battle.hand.cards.count == 1)
        #expect(battle.hand.cards.first?.ability.id == Ability.stargaze.id)
    }

    @Test(arguments: [Keyword.physical, .holy])
    func `winning first Companion attacks grant their talent Block`(keyword: Keyword) throws {
        let talentID = keyword == .physical ? "risen_skeleton_physical_t1_1" : "pixie_holy_t2_1"
        let name = keyword == .physical ? "Bone Shield" : "Radiant Barrier"
        var profile = CombatantTalentCatalog.profile(for: [talentID])
        // Enemy riders remain ineligible once the attack has won.
        profile.triggers.physicalCriticalBleedDamage = 3
        profile.triggers.holyCriticalStunDamage = 3
        profile.triggers.holyCritEnemyNextAttackMissChance = 1
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            enemyMaxHealth: 1, companionModifiers: profile, dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        let attack = Ability(
            id: "winning-block", name: "Winning Block", tier: .basic,
            damageComponents: [DamageComponent(1, keyword: keyword)],
            guaranteedCriticalCondition: .enemyFullHealth,
        )
        let card = BattleCardCombatEngine.deal(attack, owner: .companion, context: &battle)

        let events = try battle.playCard(cardID: card.id)

        #expect(battle.isEnemyDefeated)
        #expect(events.contains { $0.abilityName == name && $0.amount == 3 })
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.companion)) == 3)
        #expect(!events.contains { $0.abilityName == "Cleaving Bones" || $0.abilityName == "Stun Flare" })
        #expect(battle.roster.enemy.talents.pending.nextAttackMissChance == 0)
    }
}
