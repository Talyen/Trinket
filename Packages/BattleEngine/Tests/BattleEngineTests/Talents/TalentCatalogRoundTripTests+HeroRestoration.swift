import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

extension TalentCatalogRoundTripTests {
    @Test func `quick fingers claims its critical theft draw even with an empty deck`() {
        var battle = heroTalentBattle("rogue_gold_t3_2")
        _ = battle.resolution.beginCard(actorID: battle.hero.id)
        battle.mutateHeroCard { $0.didCriticalHit = true }
        battle.heroDeck = CombatDeck()
        _ = battle.grantGoldEvent(2, to: battle.hero, abilityName: "Theft", isTheft: true)
        battle.heroDeck = CombatDeck(abilities: [.stab])
        let events = battle.grantGoldEvent(2, to: battle.hero, abilityName: "Theft", isTheft: true)
        #expect(!events.contains { $0.effectKind == .cardsDrawn })
        #expect(battle.heroDeck.count == 1)
    }

    @Test(arguments: [38, 40])
    func `scavengers cache heals on first theft each turn without spending gold`(startingHealth: Int) throws {
        var battle = capstoneBattle(companion: [
            "lizard_scout_gold_t2_1", "lizard_scout_gold_t2_2",
            "lizard_scout_gold_t3_1", "lizard_scout_gold_t4_1",
        ])
        battle.roster.companion.currentHealth = startingHealth
        _ = battle.grantGoldEvent(5, to: battle.companion, abilityName: "Reward")
        _ = battle.grantGoldEvent(1, to: battle.hero, abilityName: "Hero theft", isTheft: true)
        #expect(battle.roster.companion.currentHealth == startingHealth)

        let goldBefore = battle.gold
        let first = try playHeroTalentCard(heroTalentPhysicalCard, owner: .companion, in: &battle)
        #expect(battle.roster.companion.currentHealth == 40)
        #expect(battle.gold - goldBefore == (startingHealth == 40 ? 2 : 1))
        #expect(first.contains { $0.effectKind == .instantHeal && $0.targetID == battle.companion.id })

        let goldAfterTheft = battle.gold
        let hit = battle.resolveDamage(DamageRequest(
            amount: 3, target: battle.companion, keyword: .physical,
            sourceActorID: battle.enemy.id, options: DamageOperation.effect(scaling: .statsAndItems, accuracy: .unavoidable),
        ))
        #expect(hit.healthLost == 3)
        #expect(battle.gold == goldAfterTheft)
        try playHeroTalentCard(heroTalentPhysicalCard, owner: .companion, in: &battle)
        _ = battle.resolveDamage(.doTTick(
            amount: 1, target: battle.enemy, keyword: .poison, sourceActorID: battle.companion.id,
        ))
        #expect(battle.roster.companion.currentHealth == 37)

        _ = battle.endTurn()
        _ = battle.resolveDamage(.doTTick(
            amount: 1, target: battle.enemy, keyword: .poison, sourceActorID: battle.companion.id,
        ))
        #expect(battle.roster.companion.currentHealth == 39)
        _ = battle.resolveDamage(.doTTick(
            amount: 1, target: battle.enemy, keyword: .bleed, sourceActorID: battle.companion.id,
        ))
        #expect(battle.roster.companion.currentHealth == 39)
    }

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

    @Test func `shelter seed grants three block after healing an injured ally`() throws {
        var battle = heroTalentBattle("druid_health_t2_2")
        battle.roster.hero.currentHealth = 1
        for _ in 0 ..< 2 {
            let before = battle.roster.hero.currentHealth
            let block = talentPoints(.shield, on: .hero, in: battle)
            try playHeroTalentCard(.apple, in: &battle)
            #expect(battle.roster.hero.currentHealth > before)
            #expect(talentPoints(.shield, on: .hero, in: battle) == block + 3)
        }
        battle.roster.hero.currentHealth = 20
        let before = talentPoints(.shield, on: .hero, in: battle)
        try playHeroTalentCard(.apple, in: &battle)
        #expect(talentPoints(.shield, on: .hero, in: battle) == before)
        battle.roster.companion.currentHealth = 1
        let allyHeal = Ability(id: "ally-heal", name: "Ally Heal", tier: .skill, targetedEffects: [
            TargetedEffect(.instantHeal(.health, 12), target: .companion),
        ])
        try playHeroTalentCard(allyHeal, in: &battle)
        #expect(talentPoints(.shield, on: .companion, in: battle) == 3)
    }

    @Test(arguments: [4, 20])
    func `vampiric touch leeches blocked damage and activates soul drain`(block: Int) {
        var battle = capstoneBattle(hero: ["warlock_leech_t1_1", "warlock_leech_t2_2"])
        battle.roster.hero.currentHealth = 10
        battle.roster.hero.currentMana = 0
        var unblocked = battle
        seedHeroTalentEffect(.shield(.block, block), on: .enemy, in: &battle)
        var options = DamageOperation.periodic
        options.abilityHasLeech = true
        let request = DamageRequest(
            amount: 8, target: battle.enemy, keyword: .physical, sourceActorID: battle.hero.id, options: options,
        )
        _ = unblocked.resolveDamage(request)
        let hit = battle.resolveDamage(request)
        #expect(hit.healthLost == max(0, 8 - block))
        #expect(battle.roster.hero.currentHealth == unblocked.roster.hero.currentHealth)
        #expect(battle.roster.hero.currentHealth > 10)
        #expect(battle.roster.hero.currentMana == 1)
    }
}
