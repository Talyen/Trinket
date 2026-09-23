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

    @Test(arguments: [Effect.cleanse(nil), .cleanseRandom, .cleanseHealPerDebuff(2)])
    func `mass cleanse waits for a successful first cleanse`(effect: Effect) throws {
        var battle = heroTalentBattle("library_owl_cleanse_t2_2")
        seedHeroTalentEffect(.burn(2), on: .companion, in: &battle)
        seedHeroTalentEffect(.poison(2), on: .companion, in: &battle)
        let ability = Ability(id: "empty-cleanse", name: "Cleanse", tier: .basic, targetedEffects: [
            TargetedEffect(effect, target: .hero),
        ])
        let empty = try playHeroTalentCard(ability, in: &battle)
        #expect(battle.hasTalentDebuff(on: battle.companion))
        #expect(empty.count { $0.effectKind == .cleanseApplied && $0.targetID == battle.companion.id } == 0)
        seedHeroTalentEffect(.poison(2), on: .hero, in: &battle)
        let successful = try playHeroTalentCard(ability, in: &battle)
        #expect(!battle.hasTalentDebuff(on: battle.hero))
        #expect(!battle.hasTalentDebuff(on: battle.companion))
        #expect(successful.contains { $0.effectKind == .cleanseApplied && $0.targetID == battle.companion.id })
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
