import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct CompanionTalentReviewTests {
    @Test func `paralysis can stun when block absorbs a poison attack`() throws {
        var profile = CombatantTalentCatalog.profile(for: ["lizard_scout_poison_t3_1"])
        profile.triggers.poisonAttackStunChancePercent = 1
        let attack = Ability(id: "poison-attack", name: "Poison Attack", tier: .basic, directDamage: 4, damageKeyword: .poison)
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionAbilities: [attack], enemyMaxHealth: 100,
            companionModifiers: profile, dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        DefensePoolEngine.set(100, on: battle.enemy, in: &battle)
        let before = battle.roster.enemy.currentHealth
        battle.nextCardID += 1
        battle.hand = BattleHand(cards: [BattleCard(id: battle.nextCardID, ability: attack, owner: .companion)])
        _ = try BattleTestFixtures.playCardNamed("Poison Attack", owner: .companion, on: &battle)

        #expect(battle.roster.enemy.currentHealth == before)
        #expect(battle.roster.hasControlStatus(for: battle.enemy, keyword: .stun))
    }

    @Test func `seismic reversal retaliates when bear block breaks`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionModifiers: CombatantTalentCatalog.profile(for: ["bear_stun_t4_1"]),
            dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        DefensePoolEngine.set(3, on: battle.companion, in: &battle)
        let enemyHealth = battle.roster.enemy.currentHealth
        let hit = DamageRequest(
            amount: 2, target: battle.companion, keyword: .physical, sourceActorID: battle.enemy.id,
            options: .effect(scaling: .flat, accuracy: .unavoidable),
        )

        _ = battle.resolveDamage(hit)
        #expect(battle.roster.enemy.currentHealth == enemyHealth)
        _ = battle.resolveDamage(hit)
        #expect(battle.roster.enemy.currentHealth == enemyHealth - 1)
    }

    @Test func `living archive grants thorns once per restoring action`() {
        var profile = CombatantTalentCatalog.profile(for: ["library_owl_health_t4_1"])
        profile.triggers.healthRestoreThornsChancePercent = 1
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionModifiers: profile, dealOpeningHand: false,
        )
        battle.roster.hero.currentHealth = 10

        _ = battle.healEmitting(amount: 2, target: battle.hero, source: battle.companion, abilityName: "Heal")
        _ = battle.healEmitting(amount: 2, target: battle.hero, source: battle.companion, abilityName: "Heal")

        #expect(battle.activeEffects(of: battle.hero).contains { $0.effect == .thorns(3) })
    }

    @Test func `mans best friend redirects only the first fatal hit`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionModifiers: CombatantTalentCatalog.profile(for: ["golden_retriever_health_t2_2"]),
            dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        battle.roster.hero.currentHealth = 5
        let companionHealth = battle.roster.companion.currentHealth
        let hit = DamageRequest(
            amount: 6, target: battle.hero, keyword: .physical, sourceActorID: battle.enemy.id,
            options: .effect(scaling: .flat, accuracy: .unavoidable),
        )

        _ = battle.resolveDamage(hit)
        #expect(battle.roster.hero.currentHealth == 5)
        #expect(battle.roster.companion.currentHealth == companionHealth - 6)
        #expect(battle.roster.companion.talents.battle.interceptedFirstAllyFatalHit)
        _ = battle.resolveDamage(hit)
        #expect(battle.roster.companion.currentHealth == companionHealth - 6)
    }

    @Test func `shared spoils restores the ally after a gold steal`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionModifiers: CombatantTalentCatalog.profile(for: ["lizard_scout_gold_t4_1"]),
            dealOpeningHand: false,
        )
        battle.roster.hero.currentHealth = 5

        _ = battle.grantGoldEvent(2, to: battle.companion, abilityName: "Steal", isTheft: true)

        #expect(battle.roster.hero.currentHealth == 7)
    }

    @Test func `undying ember leeches only from phoenix burn during deaths door`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionModifiers: CombatantTalentCatalog.profile(for: ["phoenix_deathsdoor_t4_1"]),
            dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        battle.roster.companion.currentHealth = 1
        battle.appendEffect(.deathsDoor, to: battle.companion, sourceID: battle.companion.id, remainingTurns: 2)
        let burn = DamageRequest(
            amount: 8, target: battle.enemy, keyword: .burn, sourceActorID: battle.companion.id,
            options: .reaction(),
        )

        _ = battle.resolveDamage(burn)
        #expect(battle.roster.companion.currentHealth > 1)
        ActiveEffectMutation.removeMatching(from: battle.companion, in: &battle) { $0.kind == .deathsDoor }
        battle.roster.companion.currentHealth = 1
        _ = battle.resolveDamage(burn)
        #expect(battle.roster.companion.currentHealth == 1)
    }
}
