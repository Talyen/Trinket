import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

extension TalentCatalogRoundTripTests {
    @Test func `icebound exchange transfers absorbed block without gain bonuses`() {
        var profile = CombatantTalentCatalog.profile(for: ["golden_retriever_block_t4_1"])
        profile.blockGainedBonus = 4
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionModifiers: profile, dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        DefensePoolEngine.set(5, on: battle.enemy, in: &battle)

        let outcome = battle.resolveDamage(DamageRequest(
            amount: 3, target: battle.enemy, keyword: .freeze,
            sourceActorID: battle.companion.id, options: .reaction(),
        ))

        #expect(talentPoints(.shield, on: .enemy, in: battle) == 2)
        #expect(talentPoints(.shield, on: .hero, in: battle) == 3)
        #expect(talentPoints(.shield, on: .companion, in: battle) == 3)
        #expect(outcome.events.count { $0.abilityName == "Icebound Exchange" && $0.amount == 3 } == 2)
    }

    func capstoneBattle(hero: [String] = [], companion: [String] = []) -> BattleState {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroMaxHealth: 40, companionMaxHealth: 40, enemyMaxHealth: 200,
            heroMaxMana: 10, companionMaxMana: 10,
            heroModifiers: CombatantTalentCatalog.profile(for: Set(hero)),
            companionModifiers: CombatantTalentCatalog.profile(for: Set(companion)),
            dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        return battle
    }

    @Test func `living archive echoes card healing once on its original recipient`() throws {
        var battle = capstoneBattle(companion: ["library_owl_health_t4_1"])
        battle.roster.hero.currentHealth = 1
        let card = Ability(
            id: "archive-heal", name: "Archive Heal", tier: .skill,
            targetedEffects: [TargetedEffect(.instantHeal(.health, 6), target: .hero)],
        )
        try playHeroTalentCard(card, owner: .companion, in: &battle)
        let restored = battle.roster.hero.currentHealth - 1
        #expect(restored >= 6)
        battle.roster.hero.currentHealth = 1
        battle.roster.companion.currentHealth = 1
        let events = battle.endTurn()
        let expected = CombatRounding.scaled(restored, multiplier: 0.5)
        #expect(battle.roster.hero.currentHealth == 1 + expected)
        #expect(battle.roster.companion.currentHealth == 1)
        #expect(events.contains { $0.abilityName == "Living Archive" && $0.amount == expected })
        _ = battle.endTurn()
        #expect(battle.roster.hero.currentHealth == 1 + expected)
    }

    @Test func `living archive echoes restored health rather than attempted overheal`() throws {
        var battle = capstoneBattle(companion: ["library_owl_health_t4_1"])
        battle.roster.hero.currentHealth = 38
        let card = Ability(
            id: "archive-overheal", name: "Archive Overheal", tier: .skill,
            targetedEffects: [TargetedEffect(.instantHeal(.health, 10), target: .hero)],
        )
        try playHeroTalentCard(card, owner: .companion, in: &battle)
        #expect(battle.roster.hero.currentHealth == 40)
        let echo = battle.roster.runtime(for: battle.hero)?.talents.pending.healingEchoes.first
        #expect(echo?.amount == CombatRounding.scaled(2, multiplier: 0.5))
    }

    @Test func `copied battles keep queued healing and cleanse protection independent`() throws {
        var original = capstoneBattle(companion: ["library_owl_health_t4_1", "library_owl_cleanse_t4_1"])
        original.roster.companion.currentHealth = 1
        seedHeroTalentEffect(.poison(2), on: .companion, in: &original, source: .enemy)
        var changed = original
        try playHeroTalentCard(heroTalentHealingCard, owner: .companion, in: &changed)
        _ = CombatTriggerEngine.performRandomCleanses(
            source: changed.companion, target: changed.companion, count: 1, abilityName: "Cleanse", in: &changed,
        )
        seedHeroTalentEffect(.poison(2), on: .companion, in: &changed, source: .enemy)
        seedHeroTalentEffect(.poison(2), on: .companion, in: &original, source: .enemy)
        #expect(talentPoints(.poison, on: .companion, in: changed) == 0)
        #expect(talentPoints(.poison, on: .companion, in: original) > 0)
        let changedHealth = changed.roster.companion.currentHealth
        _ = HealingEngine.resolveHealingEchoes(in: &changed)
        _ = HealingEngine.resolveHealingEchoes(in: &original)
        #expect(changed.roster.companion.currentHealth > changedHealth)
        #expect(original.roster.companion.currentHealth == 1)
    }

    @Test func `living archive does not echo passive healing or revive its recipient`() throws {
        var battle = capstoneBattle(companion: ["library_owl_health_t4_1"])
        battle.roster.hero.currentHealth = 1
        _ = battle.healEmitting(amount: 4, target: battle.hero, source: battle.companion, abilityName: "Passive")
        let afterPassive = battle.roster.hero.currentHealth
        _ = battle.endTurn()
        #expect(battle.roster.hero.currentHealth == afterPassive)
        let card = Ability(
            id: "archive-heal", name: "Archive Heal", tier: .skill,
            targetedEffects: [TargetedEffect(.instantHeal(.health, 6), target: .hero)],
        )
        try playHeroTalentCard(card, owner: .companion, in: &battle)
        battle.roster.hero.currentHealth = 0
        _ = HealingEngine.resolveHealingEchoes(in: &battle)
        #expect(battle.roster.hero.currentHealth == 0)
    }

    @Test func `wishspring shares overhealing with existing blessings and respects mana capacity`() {
        var battle = capstoneBattle(companion: ["pixie_health_t4_1", "pixie_health_t3_1", "pixie_health_t3_2"])
        battle.roster.hero.currentMana = 0
        _ = HealingEngine.resolveHeal(
            HealRequest(amount: 8, target: battle.hero, sourceActorID: battle.companion.id), in: &battle,
        )
        #expect(battle.roster.hero.currentMana == 4)
        #expect(battle.roster.hero.maxHealth == 41)
        #expect(talentPoints(.shield, on: .hero, in: battle) == 7)
        battle.roster.hero.currentMana = 9
        _ = HealingEngine.resolveHeal(
            HealRequest(amount: 8, target: battle.hero, sourceActorID: battle.companion.id), in: &battle,
        )
        #expect(battle.roster.hero.currentMana == 10)
        battle.roster.hero.currentHealth = 1
        battle.roster.hero.currentMana = 0
        _ = HealingEngine.resolveHeal(
            HealRequest(amount: 8, target: battle.hero, sourceActorID: battle.companion.id), in: &battle,
        )
        #expect(battle.roster.hero.currentMana == 0)
    }

    @Test func `marrowmend emits block for leech overhealing without exceeding six`() {
        var battle = capstoneBattle(companion: ["risen_skeleton_leech_t4_1"])
        var options = DamageOperation.reaction()
        options.abilityHasLeech = true
        let request = DamageRequest(
            amount: 12, target: battle.enemy, keyword: .physical,
            sourceActorID: battle.companion.id, options: options,
        )
        let result = battle.resolveDamage(request)
        #expect(talentPoints(.shield, on: .companion, in: battle) == 6)
        #expect(result.events.contains { $0.abilityName == "Marrowmend" && $0.amount == 6 })
        _ = battle.resolveDamage(request)
        #expect(talentPoints(.shield, on: .companion, in: battle) == 6)
        _ = battle.applyBlock(4, to: battle.companion, source: battle.companion, abilityName: "Other Block")
        _ = battle.resolveDamage(request)
        #expect(talentPoints(.shield, on: .companion, in: battle) == 10)
    }

    @Test func `contagious joy uses one roll at the higher living party critical chance`() {
        var battle = capstoneBattle(companion: ["golden_retriever_health_t4_1", "golden_retriever_health_t2_2"])
        seedHeroTalentEffect(.criticalChanceBonus(0.4, 2), on: .hero, in: &battle)
        let heroChance = CriticalChanceEngine.chance(actorID: battle.hero.id, defender: battle.hero, in: battle)
        let companionChance = CriticalChanceEngine.chance(actorID: battle.companion.id, defender: battle.hero, in: battle)
        #expect(heroChance > companionChance)
        var expectedRNG = battle.rng
        let expectedCritical = BattleChance.succeeds(probability: heroChance, using: &expectedRNG)
        battle.roster.hero.currentHealth = 1
        let healed = HealingEngine.resolveHeal(HealRequest(
            amount: 4, target: battle.hero, sourceActorID: battle.companion.id,
            origin: .restoration(.health), logAs: .instantHeal(actorName: battle.companion.name, abilityName: "Care", keyword: .health),
        ), in: &battle)
        #expect(healed.healthRestored == (expectedCritical ? 8 : 4))
        #expect(healed.flags.contains(.critical) == expectedCritical)
        battle.roster.hero.currentHealth = 0
        expectedRNG = battle.rng
        let expectedWithoutHero = BattleChance.succeeds(probability: companionChance, using: &expectedRNG)
        #expect(CriticalChanceEngine.rollSucceeds(
            keyword: .health, actorID: battle.companion.id, defender: battle.companion,
            usePartyMaximum: true, in: &battle,
        ) == expectedWithoutHero)
    }

    @Test func `lesson learned prevents reapplication but not damage until next turn`() throws {
        var battle = capstoneBattle(companion: ["library_owl_cleanse_t4_1", "library_owl_cleanse_t2_2"])
        seedHeroTalentEffect(.poison(2), on: .hero, in: &battle, source: .enemy)
        seedHeroTalentEffect(.burn(2), on: .companion, in: &battle, source: .enemy)
        try playHeroTalentCard(.cleanse, owner: .companion, in: &battle)
        #expect(talentPoints(.poison, on: .hero, in: battle) == 0)
        #expect(talentPoints(.burn, on: .companion, in: battle) == 0)
        let health = battle.roster.hero.currentHealth
        _ = DoTApplicator.applyDecayingDoT(
            keyword: .poison, potency: 3, to: battle.hero, sourceActorID: battle.enemy.id,
            application: .ability, in: &battle,
        )
        #expect(battle.roster.hero.currentHealth == health - 3)
        #expect(talentPoints(.poison, on: .hero, in: battle) == 0)
        seedHeroTalentEffect(.burn(3), on: .companion, in: &battle, source: .enemy)
        #expect(talentPoints(.burn, on: .companion, in: battle) == 0)
        _ = battle.endTurn()
        seedHeroTalentEffect(.poison(2), on: .hero, in: &battle, source: .enemy)
        #expect(talentPoints(.poison, on: .hero, in: battle) == 2)
    }
}
