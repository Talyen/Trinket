import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

extension TalentCatalogRoundTripTests {
    @Test func `playful energy draws once per restoring action`() {
        var profile = CombatantTalentCatalog.profile(for: ["golden_retriever_health_t1_2"])
        profile.triggers.healthRestoreDrawChancePercent = 1
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionAbilities: [.bash, .fangs], companionModifiers: profile, dealOpeningHand: false,
        )
        battle.companionDeck = CombatDeck(abilities: [.bash, .fangs])
        battle.roster.hero.currentHealth = 10
        let first = battle.healEmitting(amount: 2, target: battle.hero, source: battle.companion, abilityName: "Heal")
        let second = battle.healEmitting(amount: 2, target: battle.hero, source: battle.companion, abilityName: "Heal")
        #expect(first.contains { $0.abilityName == "Playful Energy" })
        #expect(!second.contains { $0.abilityName == "Playful Energy" })
        battle.actionCount += 1
        let later = battle.healEmitting(amount: 2, target: battle.hero, source: battle.companion, abilityName: "Heal")
        #expect(later.contains { $0.abilityName == "Playful Energy" })
    }

    @Test func `safe perch grants dodge only at full health`() {
        var battle = capstoneBattle(companion: ["library_owl_health_t1_1"])
        let full = DamagePipeline.dodgeChance(for: battle.companion, attackerID: battle.enemy.id, in: battle)
        battle.roster.companion.currentHealth -= 1
        let injured = DamagePipeline.dodgeChance(for: battle.companion, attackerID: battle.enemy.id, in: battle)
        #expect(abs(full - injured - 0.10) < 0.0001)
    }

    @Test func `wing buffet deals freeze damage on dodge`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            enemyAbilities: [.slash],
            companionModifiers: CombatantTalentCatalog.profile(for: ["frost_whelp_dodge_t2_2"]),
            dealOpeningHand: false,
        )
        let before = battle.roster.enemy.currentHealth
        let events = CombatTriggerEngine.afterDodge(by: battle.companion, attackerID: battle.enemy.id, in: &battle)
        #expect(battle.roster.enemy.currentHealth == before - 2)
        #expect(events.contains { $0.keyword == .freeze && $0.amount == 2 })
        #expect(battle.additionalControlSkipsByCombatantID[battle.enemy.id, default: 0] == 0)
    }

    @Test func `natural poison expiry pays the last source and explicit removal does not`() {
        var battle = heroTalentBattle("alchemist_poison_t2_2", "druid_poison_t2_2")
        battle.roster.mutateRuntime(for: battle.hero) { $0.currentMana = 0 }
        battle.roster.mutateRuntime(for: battle.companion) { $0.currentHealth = 1 }
        seedHeroTalentEffect(.poison(1), on: .enemy, in: &battle)
        _ = EffectTurnEngine.advanceAll(context: &battle)
        #expect(battle.roster.hero.currentMana == 2)
        #expect(battle.roster.companion.currentHealth == 4)
        seedHeroTalentEffect(.poison(1), on: .enemy, in: &battle)
        _ = EffectTurnEngine.advanceAll(context: &battle)
        #expect(battle.roster.hero.currentMana == 4)
        battle.turnCount += 1
        seedHeroTalentEffect(.poison(1), on: .hero, in: &battle)
        battle.removeTalentPoint(.poison, from: battle.hero)
        _ = EffectTurnEngine.advanceAll(context: &battle)
        #expect(battle.roster.hero.currentMana == 4)
        #expect(battle.roster.companion.currentHealth == 7)
        seedHeroTalentEffect(.poison(1), on: .enemy, in: &battle, source: .companion)
        _ = EffectTurnEngine.advanceAll(context: &battle)
        #expect(battle.roster.hero.currentMana == 4)
    }

    @Test func `shared prescription transfers resolved excess without bouncing or revival`() throws {
        var battle = heroTalentBattle("alchemist_health_t3_1")
        let healCard = Ability(id: "self-heal", name: "Self Heal", tier: .basic, targetedEffects: [
            TargetedEffect(.instantHeal(.health, 3), target: .actor),
        ])
        battle.roster.companion.currentHealth = 1
        for _ in 0 ..< 2 {
            let before = battle.roster.companion.currentHealth
            let events = try playHeroTalentCard(healCard, in: &battle)
            let heal = try #require(events.first { $0.effectKind == .instantHeal && $0.abilityName == healCard.name })
            let transfer = try #require(events.first { $0.abilityName == "Shared Prescription" })
            #expect(transfer.amount == (heal.isCritical ? 6 : 3))
            #expect(!transfer.isCritical)
            #expect(battle.roster.companion.currentHealth == before + transfer.amount)
            #expect(events.count { $0.abilityName == "Shared Prescription" } == 1)
        }
        battle.roster.companion.currentHealth = battle.roster.companion.maxHealth - 1
        let limited = try playHeroTalentCard(healCard, in: &battle)
        #expect(limited.first { $0.abilityName == "Shared Prescription" }?.amount == 1)
        battle.roster.companion.currentHealth = 0
        let defeated = try playHeroTalentCard(healCard, in: &battle)
        #expect(battle.roster.companion.currentHealth == 0)
        #expect(!defeated.contains { $0.abilityName == "Shared Prescription" })
    }

    @Test func `quiet grove grants dodge only at full health`() {
        var battle = heroTalentBattle("druid_health_t2_1")
        let fullChance = DamagePipeline.dodgeChance(for: battle.companion, attackerID: battle.enemy.id, in: battle)
        battle.roster.companion.currentHealth -= 1
        let woundedChance = DamagePipeline.dodgeChance(for: battle.companion, attackerID: battle.enemy.id, in: battle)
        #expect(abs(fullChance - woundedChance - 0.10) < 0.0001)
    }

    @Test func `shared current empowers the companion's next attack`() {
        var battle = capstoneBattle(hero: ["druid_mana_t3_1"])
        var ability = Ability.kindling
        _ = BattleTurnEngine.spendManaToEmpowerBurnOrFreezeIfNeeded(
            for: &ability, actor: battle.hero, context: &battle,
        )
        #expect(battle.roster.companion.talents.pending.cardDamageBonus == 2)
        let hit = battle.resolveDamage(DamageRequest(
            amount: 3, target: battle.enemy, keyword: .physical, sourceActorID: battle.companion.id,
            options: DamageOperation.attack(
                tier: .basic, scaling: .items, accuracy: .unavoidable, abilityCriticalChanceBonus: -1,
            ),
        ))
        #expect(hit.healthLost == 5)
        #expect(battle.roster.companion.talents.pending.cardDamageBonus == 0)
    }

    @Test(arguments: [0, 1, 6])
    func `grove reserve grants companion dodge with unspent mana`(mana: Int) {
        var battle = heroTalentBattle("druid_mana_t2_1")
        battle.roster.hero.currentMana = mana
        let chance = DamagePipeline.dodgeChance(for: battle.companion, attackerID: battle.enemy.id, in: battle)
        #expect(abs(chance - (mana > 0 ? 0.20 : 0.10)) < 0.0001)
    }

    @Test func `last wager draws when gold arrives below half health`() {
        var battle = heroTalentBattle("wildcard_gold_t3_1")
        battle.heroDeck = CombatDeck(abilities: [.slash, .slash])
        let full = battle.grantGoldEvent(1, to: battle.hero, abilityName: "Gold")
        #expect(!full.contains { $0.effectKind == .cardsDrawn })
        battle.roster.hero.currentHealth = battle.roster.hero.maxHealth / 2 - 1
        let wounded = battle.grantGoldEvent(1, to: battle.hero, abilityName: "Gold")
        #expect(wounded.contains { $0.effectKind == .cardsDrawn })
    }
}
