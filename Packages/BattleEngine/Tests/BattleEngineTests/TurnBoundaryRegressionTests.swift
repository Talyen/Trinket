import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct TurnBoundaryRegressionTests {
    @Test func `Mana reserves cannot indefinitely absorb attacks above the Shield talent budget`() {
        let attack = Ability(
            id: "reserve-breaker", name: "Reserve Breaker", tier: .basic,
            damageComponents: [DamageComponent(10, keyword: .physical, target: .hero)],
        )
        var profile = CombatantTalentCatalog.profile(for: ["wizard_mana_t1_2"])
        profile.triggers.dodgeChanceBonus = -1
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            enemyAbilities: [attack], heroMaxMana: 29, heroMana: 29,
            heroModifiers: profile,
        )
        battle.appliesFightPacing = false
        let health = battle.health(of: battle.hero)

        let events = battle.endTurn()

        #expect(events.first { $0.abilityName == "Mana Shield" }?.amount == 6)
        #expect(battle.health(of: battle.hero) == health - 4)
        #expect(battle.mana(of: battle.hero) == 29)
    }

    @Test func `Mana Shield protects against the enemy attack following End Turn`() {
        let attack = Ability(
            id: "strike", name: "Strike", tier: .basic,
            damageComponents: [DamageComponent(4, keyword: .physical, target: .hero)],
        )
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            enemyAbilities: [attack], heroMaxMana: 4, heroMana: 4,
            heroModifiers: CombatantTalentCatalog.profile(for: ["wizard_mana_t1_2"]),
        )
        battle.appliesFightPacing = false
        let health = battle.health(of: battle.hero)
        let events = battle.endTurn()
        #expect(battle.health(of: battle.hero) == health)
        let shieldIndex = events.firstIndex { $0.abilityName == "Mana Shield" }
        let attackIndex = events.firstIndex { $0.kind == .ability && $0.actorID == battle.enemy.id }
        #expect(shieldIndex != nil && attackIndex != nil)
        if let shieldIndex, let attackIndex {
            #expect(shieldIndex < attackIndex)
        }
    }

    @Test(arguments: [false, true])
    func `Gold rewards and Gold steals retain their meaning in the battle log`(theft: Bool) {
        var battle = BattleStateTestFactory.makeBattleWithAbilities()
        let ability = theft ? Ability.steal : Ability.goldenPlate
        let events = BattleTurnEngine.performAction(
            ability: ability, actor: battle.hero, abilityTarget: battle.enemy, context: &battle,
        )
        let summary = events.first { $0.kind == .ability && $0.abilityID == ability.id }?.appliedEffectSummaries
        #expect(summary?.contains(theft ? "steal 2 Gold" : "gain 5 Gold") == true)
    }

    @Test func `End Turn stops Hibernation after Arcane Cleansing wins the battle`() throws {
        var hero = CombatantTalentCatalog.profile(for: ["wizard_mana_t2_2"])
        let absolution = try #require(GameContent.itemAffixDefinition(matching: "sin_eaters_lantern"))
        absolution.basic.triggers.apply(to: &hero, abilityName: absolution.title)
        var companion = CombatantTalentCatalog.profile(for: ["bear_block_t1_2"])
        let remedy = try #require(GameContent.itemAffixDefinition(matching: "mortar_and_pestle"))
        remedy.basic.triggers.apply(to: &companion, abilityName: remedy.title)
        var battle = cadenceBattle(heroModifiers: hero, companionModifiers: companion)
        battle.roster.hero.currentHealth = 20
        battle.roster.companion.currentHealth = 10
        battle.appendEffect(.poison(1), to: battle.hero, sourceID: battle.enemy.id, remainingTurns: 0)
        DefensePoolEngine.set(1, on: battle.companion, in: &battle)

        let events = CombatExecutor.run { await CombatTriggerEngine.atPlayerEndTurn(in: &battle) }

        #expect(battle.isBattleOver)
        #expect(battle.health(of: battle.companion) == 13)
        #expect(!battle.roster.hasAffliction(.poison, on: battle.hero))
        #expect(!events.contains { $0.abilityName == "Hibernation" })
    }

    @Test func `Purifying Aura stops before cleansing its second ally after victory`() {
        var hero = CombatModifierProfile.zero
        hero.triggers.healthRestoredPoisonPercent = 0.5
        var pixie = CombatantTalentCatalog.profile(for: ["pixie_cleanse_t1_1", "pixie_cleanse_t3_2"])
        pixie.triggers.criticalChanceBonus = -1
        var battle = cadenceBattle(heroModifiers: hero, companionModifiers: pixie)
        battle.appendEffect(.poison(1), to: battle.hero, sourceID: battle.enemy.id, remainingTurns: 0)
        battle.appendEffect(.burn(1), to: battle.companion, sourceID: battle.enemy.id, remainingTurns: 0)

        let events = CombatExecutor.run { await CombatTriggerEngine.atPlayerTurnStart(in: &battle) }

        #expect(battle.isBattleOver)
        #expect(!battle.roster.hasAffliction(.poison, on: battle.hero))
        #expect(battle.roster.hasAffliction(.burn, on: battle.companion))
        #expect(events.count(where: { $0.abilityName == "Purifying Aura" && $0.effectKind == .cleanseApplied }) == 1)
    }

    @Test func `Passive Income victory stops Verdant Renewal in the same regeneration step`() throws {
        var hero = CombatModifierProfile.zero
        let remedy = try #require(GameContent.itemAffixDefinition(matching: "mortar_and_pestle"))
        remedy.basic.triggers.apply(to: &hero, abilityName: remedy.title)
        var companion = CombatModifierProfile.zero
        for id in ["merchants_favor", "windfall", "groves_favor"] {
            let affix = try #require(GameContent.itemAffixDefinition(matching: id))
            affix.astral.triggers.apply(to: &companion, abilityName: affix.title)
        }
        companion.triggers.criticalChanceBonus = -1
        var battle = cadenceBattle(heroModifiers: hero, companionModifiers: companion)

        let events = CombatExecutor.run { await CombatTriggerEngine.atPlayerTurnStart(in: &battle) }

        #expect(battle.isBattleOver)
        #expect(battle.gold == 1)
        #expect(battle.health(of: battle.hero) == 12)
        #expect(!events.contains { $0.abilityName == "Verdant Renewal" })
    }

    private func cadenceBattle(
        heroModifiers: CombatModifierProfile,
        companionModifiers: CombatModifierProfile = .zero,
    ) -> BattleState {
        var hero = heroModifiers
        hero.triggers.criticalChanceBonus = -1
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 100, maxMana: 4),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 100),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroHealth: 10, companionHealth: 20, enemyHealth: 1, heroMana: 0,
            heroModifiers: hero, companionModifiers: companionModifiers,
        )
        battle.appliesFightPacing = false
        return battle
    }
}
