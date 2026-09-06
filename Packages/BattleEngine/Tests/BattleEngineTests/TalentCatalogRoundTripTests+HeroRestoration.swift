import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

extension TalentCatalogRoundTripTests {
    @Test(arguments: [
        ("alchemist_health_t1_1", Effect.poison(2)),
        ("druid_health_t1_1", .thorns(2)),
    ])
    func `healing bonuses add one to only the first eligible direct heal`(talent: String, condition: Effect) throws {
        var battle = heroTalentBattle(talent)
        battle.roster.mutateRuntime(for: battle.hero) { $0.currentHealth = 1 }
        seedHeroTalentEffect(condition, on: .hero, in: &battle)
        for expectedBonus in [1, 0] {
            let before = battle.roster.hero.currentHealth
            let events = try playHeroTalentCard(heroTalentHealingCard, in: &battle)
            let heal = try #require(events.first { $0.effectKind == .instantHeal && $0.abilityName == heroTalentHealingCard.name })
            #expect(battle.roster.hero.currentHealth - before == (heal.isCritical ? 2 : 1) + expectedBonus)
        }
    }

    @Test func `measured dose waits until the next card and does not stack`() throws {
        var battle = heroTalentBattle("alchemist_health_t1_2")
        battle.roster.mutateRuntime(for: battle.hero) { $0.currentHealth = 1; $0.currentMana = 0 }
        let mixture = Ability(id: "test-mixture", name: "Mixture", tier: .basic, targetedEffects: [
            TargetedEffect(.resourceGain(.mana, 1), target: .actor),
            TargetedEffect(.instantHeal(.health, 1), target: .actor),
        ])
        let first = try playHeroTalentCard(mixture, in: &battle)
        let firstHeal = try #require(first.first { $0.effectKind == .instantHeal && $0.abilityName == mixture.name })
        #expect(firstHeal.amount == (firstHeal.isCritical ? 2 : 1))
        let next = try playHeroTalentCard(heroTalentHealingCard, in: &battle)
        let nextHeal = try #require(next.first { $0.effectKind == .instantHeal && $0.abilityName == heroTalentHealingCard.name })
        #expect(nextHeal.amount == (nextHeal.isCritical ? 2 : 1) + 1)
        let last = try playHeroTalentCard(heroTalentHealingCard, in: &battle)
        let lastHeal = try #require(last.first { $0.effectKind == .instantHeal && $0.abilityName == heroTalentHealingCard.name })
        #expect(lastHeal.amount == (lastHeal.isCritical ? 2 : 1))
    }

    @Test func `full mana does not prepare measured dose`() throws {
        var battle = heroTalentBattle("alchemist_health_t1_2")
        battle.roster.mutateRuntime(for: battle.hero) { $0.currentHealth = 1 }
        try playHeroTalentCard(.manaBerries, in: &battle)
        let events = try playHeroTalentCard(heroTalentHealingCard, in: &battle)
        let heal = try #require(events.first { $0.effectKind == .instantHeal && $0.abilityName == heroTalentHealingCard.name })
        #expect(heal.amount == (heal.isCritical ? 2 : 1))
    }

    @Test func `first overheal restores mana even when no health was missing`() throws {
        var battle = heroTalentBattle("alchemist_health_t2_2")
        battle.roster.mutateRuntime(for: battle.hero) { $0.currentMana = 0 }
        try playHeroTalentCard(heroTalentHealingCard, in: &battle)
        #expect(battle.roster.hero.currentMana == 1)
        battle.turnCount += 1
        try playHeroTalentCard(heroTalentHealingCard, in: &battle)
        #expect(battle.roster.hero.currentMana == 1)
    }

    @Test func `dew roots and shelter apply to the healed companion once`() throws {
        var battle = heroTalentBattle("druid_health_t3_1", "druid_health_t3_2", "druid_health_t4_1")
        battle.roster.mutateRuntime(for: battle.companion) { $0.currentHealth = 1 }
        seedHeroTalentEffect(.poison(2), on: .companion, in: &battle)
        seedHeroTalentEffect(.burn(2), on: .hero, in: &battle)
        let heal = Ability(
            id: "test-heal-companion",
            name: "Heal Companion",
            tier: .skill,
            targetedEffects: [TargetedEffect(.instantHeal(.health, 1), target: .companion)],
        )
        try playHeroTalentCard(heal, in: &battle)
        try playHeroTalentCard(heal, in: &battle)
        #expect(talentPoints(.poison, on: .companion, in: battle) == 1)
        #expect(talentPoints(.burn, on: .hero, in: battle) == 1)
        #expect(talentPoints(.thorns, on: .companion, in: battle) == 1)
    }

    @Test(arguments: [0, 10])
    func `clear mind adds capacity without refill only for mana users`(companionMana: Int) throws {
        var battle = heroTalentBattle("alchemist_cleanse_t3_1", companionMana: companionMana)
        let cleanse = Ability(id: "test-cleanse-party", name: "Cleanse Party", tier: .skill, targetedEffects: [
            TargetedEffect(.cleanse(nil), target: .hero), TargetedEffect(.cleanse(nil), target: .companion),
        ])
        try playHeroTalentCard(cleanse, in: &battle)
        battle.turnCount += 1
        try playHeroTalentCard(cleanse, in: &battle)
        #expect(battle.roster.hero.maxMana == 11)
        #expect(battle.roster.hero.currentMana == 10)
        #expect(battle.roster.companion.maxMana == (companionMana > 0 ? 11 : 0))
        #expect(battle.roster.companion.currentMana == companionMana)
    }

    @Test func `panacea cleanses and heals without duplicating rewards`() throws {
        var battle = heroTalentBattle("alchemist_cleanse_t2_1", "alchemist_cleanse_t2_2", "alchemist_cleanse_t3_1", "druid_health_t4_1")
        battle.roster.mutateRuntime(for: battle.hero) { $0.currentHealth = 1; $0.currentMana = 0 }
        seedHeroTalentEffect(.burn(2), on: .hero, in: &battle)
        seedHeroTalentEffect(.poison(2), on: .hero, in: &battle)
        let events = try playHeroTalentCard(.panaceaPotion, in: &battle)
        #expect(talentPoints(.burn, on: .hero, in: battle) == 0)
        #expect(talentPoints(.poison, on: .hero, in: battle) == 0)
        #expect(talentPoints(.thorns, on: .hero, in: battle) == 2)
        #expect(battle.roster.hero.currentMana == 1)
        #expect(battle.roster.hero.maxMana == 11)
        #expect(events.count { $0.abilityName == "Heat Recovery" } == 1)
        #expect(events.count { $0.abilityName == "Antitoxin Coating" } == 1)
        #expect(events.count { $0.abilityName == "Verdant Shelter" } == 1)
    }

    @Test func `clean break requires last debuff and is consumed by one attack`() throws {
        var battle = heroTalentBattle("alchemist_cleanse_t3_2")
        seedHeroTalentEffect(.poison(2), on: .hero, in: &battle)
        let cleanse = Ability(
            id: "test-cleanse",
            name: "Cleanse",
            tier: .basic,
            targetedEffects: [TargetedEffect(.cleanse(nil), target: .hero)],
        )
        try playHeroTalentCard(cleanse, in: &battle)
        seedHeroTalentEffect(.shield(.block, 1), on: .enemy, in: &battle)
        let events = try playHeroTalentCard(heroTalentPhysicalCard, in: &battle)
        let hit = try #require(events.first { $0.kind == .abilityDamage })
        #expect(hit.amount == (hit.isCritical ? 2 : 1))
        #expect(talentPoints(.shield, on: .enemy, in: battle) == 1)
        try playHeroTalentCard(heroTalentPhysicalCard, in: &battle)
        #expect(talentPoints(.shield, on: .enemy, in: battle) == 0)
    }

    @Test func `first bloom deep roots and living conduit require actual mana gain`() throws {
        var battle = heroTalentBattle("druid_mana_t1_1", "druid_mana_t2_2", "druid_mana_t3_2")
        battle.roster.mutateRuntime(for: battle.companion) { $0.currentMana = 0 }
        try playHeroTalentCard(.poisonDagger, in: &battle)
        try playHeroTalentCard(.manaBerries, in: &battle)
        #expect(battle.roster.companion.currentMana == 0)
        #expect(talentPoints(.thorns, on: .companion, in: battle) == 0)
        battle.roster.mutateRuntime(for: battle.hero) { $0.currentMana = 0 }
        seedHeroTalentEffect(.thorns(1), on: .hero, in: &battle)
        try playHeroTalentCard(.poisonDagger, in: &battle)
        try playHeroTalentCard(.manaBerries, in: &battle)
        #expect(battle.roster.hero.currentMana == 3)
        #expect(battle.roster.companion.currentMana == 1)
        #expect(talentPoints(.thorns, on: .companion, in: battle) == 1)
    }

    @Test func `thorns from A card remove only one poison and not A cleanse`() throws {
        var battle = heroTalentBattle("druid_poison_t4_1", "alchemist_cleanse_t2_2", "alchemist_poison_t2_2")
        battle.roster.mutateRuntime(for: battle.hero) { $0.currentMana = 0 }
        seedHeroTalentEffect(.poison(1), on: .hero, in: &battle)
        try playHeroTalentCard(.briarShield, in: &battle)
        #expect(talentPoints(.poison, on: .hero, in: battle) == 0)
        #expect(talentPoints(.thorns, on: .hero, in: battle) == 3)
        #expect(battle.roster.hero.currentMana == 0)
    }

    @Test func `thorn shedding follows the thorns recipient`() throws {
        var battle = heroTalentBattle("druid_poison_t4_1")
        seedHeroTalentEffect(.poison(2), on: .hero, in: &battle)
        battle.roster.mutateRuntime(for: battle.hero) { $0.currentHealth = 1 }
        let card = Ability(
            id: "test-ally-thorns", name: "Ally Thorns", tier: .skill,
            targetedEffects: [TargetedEffect(.thorns(1), target: .lowestHealthAlly)],
        )
        try playHeroTalentCard(card, owner: .companion, in: &battle)
        #expect(talentPoints(.poison, on: .hero, in: battle) == 1)
    }
}
