import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

extension TalentCatalogRoundTripTests {
    @Test(arguments: [Effect.cleanse(nil), .cleanseRandom, .cleanseHealPerDebuff(2)])
    func `mass cleanse reaches the other ally when the first has no debuffs`(effect: Effect) throws {
        var battle = heroTalentBattle("library_owl_cleanse_t2_2")
        seedHeroTalentEffect(.burn(2), on: .companion, in: &battle)
        seedHeroTalentEffect(.poison(2), on: .companion, in: &battle)
        let ability = Ability(id: "empty-cleanse", name: "Cleanse", tier: .basic, targetedEffects: [
            TargetedEffect(effect, target: .hero),
        ])
        let events = try playHeroTalentCard(ability, in: &battle)
        #expect(!battle.hasTalentDebuff(on: battle.companion))
        #expect(events.count { $0.effectKind == .cleanseApplied && $0.targetID == battle.companion.id } == 2)
    }

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

    @Test func `clean break draws poison only when the last debuff is removed and can repeat`() throws {
        var battle = heroTalentBattle("alchemist_cleanse_t3_2")
        battle.heroDeck = CombatDeck(abilities: [.block, .causticJab, .causticJab])
        seedHeroTalentEffect(.poison(2), on: .hero, in: &battle)
        seedHeroTalentEffect(.burn(2), on: .hero, in: &battle)
        let partial = Ability(id: "cleanse-poison", name: "Antitoxin", tier: .skill, effects: [.cleanse(.poison)])
        let first = try playHeroTalentCard(partial, in: &battle)
        #expect(!first.contains { $0.abilityName == "Clean Break" })
        let complete = try playHeroTalentCard(.cleanse, in: &battle)
        #expect(complete.contains { $0.abilityName == "Clean Break" && $0.effectKind == .cardsDrawn })
        #expect(battle.hand.cards.contains { $0.owner == .hero && $0.ability.id == Ability.causticJab.id })
        let empty = try playHeroTalentCard(.cleanse, in: &battle)
        #expect(!empty.contains { $0.abilityName == "Clean Break" })
        seedHeroTalentEffect(.poison(2), on: .hero, in: &battle)
        let repeated = try playHeroTalentCard(.cleanse, in: &battle)
        #expect(repeated.contains { $0.abilityName == "Clean Break" && $0.effectKind == .cardsDrawn })
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

    @Test func `shelter seed grants actual healing as thorns to injured allies repeatedly`() throws {
        var battle = heroTalentBattle("druid_health_t2_2")
        battle.roster.hero.currentHealth = 1
        for _ in 0 ..< 2 {
            let before = battle.roster.hero.currentHealth
            let thorns = talentPoints(.thorns, on: .hero, in: battle)
            try playHeroTalentCard(.apple, in: &battle)
            #expect(talentPoints(.thorns, on: .hero, in: battle) == thorns + battle.roster.hero.currentHealth - before)
        }
        battle.roster.hero.currentHealth = 20
        let before = talentPoints(.thorns, on: .hero, in: battle)
        try playHeroTalentCard(.apple, in: &battle)
        #expect(talentPoints(.thorns, on: .hero, in: battle) == before)
        battle.roster.companion.currentHealth = 1
        let allyHeal = Ability(id: "ally-heal", name: "Ally Heal", tier: .skill, targetedEffects: [
            TargetedEffect(.instantHeal(.health, 12), target: .companion),
        ])
        try playHeroTalentCard(allyHeal, in: &battle)
        #expect(talentPoints(.thorns, on: .companion, in: battle) == battle.roster.companion.currentHealth - 1)
    }

    @Test func `thorn shedding converts only companion thorns and consumes the full pool`() {
        var battle = heroTalentBattle("druid_poison_t4_1")
        for owner in [BattleParticipant.hero, .companion] {
            seedHeroTalentEffect(.thorns(7), on: owner, in: &battle)
            let target = battle.roster[owner].combatant
            let events = battle.resolveDamage(DamageRequest(
                amount: 1, target: target, keyword: .physical, sourceActorID: battle.enemy.id,
                options: DamageOptions(applyDodge: false, isAttackHit: true),
            )).events
            let keyword: Keyword = owner == .companion ? .poison : .physical
            #expect(events.contains { $0.effectKind == .thornsTriggered && $0.keyword == keyword && $0.amount == 7 })
            #expect(talentPoints(.thorns, on: owner, in: battle) == 0)
        }
        #expect(talentPoints(.poison, on: .enemy, in: battle) == 7)
    }
}
