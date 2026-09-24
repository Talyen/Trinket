import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

extension AbilityEffectIntegrationTests {
    @Test(arguments: [Ability.fangs])
    func `enemy basic freeze bonus does not repeat on later ticks`(ability: Ability) throws {
        var enemyProfile = CombatModifierProfile.zero
        enemyProfile.triggers.basicAttackFreezeBuildup = 1
        var battle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 100),
            enemyModifiers: enemyProfile, dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        _ = BattleTurnEngine.performAction(ability: ability, actor: battle.enemy, abilityTarget: battle.hero, context: &battle)
        #expect(battle.health(of: battle.hero) == 98)
        let kind: EffectKind = ability.id == "ray-of-frost" ? .recurringDamage : .bleed
        let active = try #require(battle.activeEffects(of: battle.hero).first { $0.effect.kind == kind })
        let handler = try #require(EffectHandlers.all[kind])
        _ = handler.advanceTurn(active, on: battle.hero, in: &battle)
        #expect(battle.health(of: battle.hero) == 97)
    }

    @Test(arguments: [Keyword.poison, .freeze])
    func `typed leech chance can succeed and fail on ongoing damage`(keyword: Keyword) {
        var healed: Set<Bool> = []
        for seed in UInt64(1) ... 32 {
            var profile = CombatModifierProfile.zero
            profile.triggers.criticalChanceBonus = -1
            if keyword == .poison {
                profile.triggers.poisonDamageLeechChancePercent = 0.5
            } else {
                profile.triggers.freezeDamageLeechChancePercent = 0.5
            }
            var battle = BattleStateTestFactory.makeBattleWithAbilities(
                heroModifiers: profile, rngSeed: seed, dealOpeningHand: false,
            )
            battle.appliesFightPacing = false
            battle.roster.hero.currentHealth = 1
            _ = battle.resolveDamage(.doTTick(amount: 8, target: battle.enemy, keyword: keyword, sourceActorID: battle.hero.id))
            #expect([1, 5].contains(battle.roster.hero.currentHealth))
            healed.insert(battle.roster.hero.currentHealth > 1)
        }
        #expect(healed == [false, true])
    }

    @Test func `blessed aegis grants actor block heals lowest ally and deals holy damage`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false)
        battle.appliesFightPacing = false
        battle.roster.companion.currentHealth = 10
        let enemyBefore = battle.health(of: battle.enemy)

        _ = BattleTurnEngine.performAction(
            ability: .blessedAegis,
            actor: battle.hero,
            abilityTarget: battle.enemy,
            context: &battle,
        )

        #expect(BattleTestFixtures.shieldPoints(for: battle.hero, in: battle) == 5)
        #expect(battle.health(of: battle.companion) == 15)
        #expect(battle.health(of: battle.hero) == battle.hero.maxHealth)
        #expect(enemyBefore - battle.health(of: battle.enemy) == 5)
        #expect(!battle.activeEffects(of: battle.hero).contains { $0.effect.kind == .onHitDamage })
        #expect(!battle.activeEffects(of: battle.companion).contains { $0.effect.kind == .onHitDamage })
    }

    @Test func `blessed aegis holy damage does not grow with stored block`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(enemyMaxHealth: 500, dealOpeningHand: false)
        battle.appliesFightPacing = false
        DefensePoolEngine.set(8, on: battle.hero, in: &battle)
        let before = battle.health(of: battle.enemy)
        _ = BattleTurnEngine.performAction(
            ability: .blessedAegis,
            actor: battle.hero,
            abilityTarget: battle.enemy,
            context: &battle,
        )
        #expect(BattleTestFixtures.shieldPoints(for: battle.hero, in: battle) == 13)
        #expect(before - battle.health(of: battle.enemy) == 5)
    }

    @Test(arguments: [Keyword.poison, .freeze], [false, true])
    func `typed leech shares the normal single healing path`(keyword: Keyword, alreadyLeeches: Bool) {
        var profile = CombatModifierProfile(leechHealingBonus: 1)
        profile.triggers.criticalChanceBonus = -1
        profile.triggers.leechRestoreManaFlat = 2
        if keyword == .poison {
            profile.triggers.poisonDamageLeechChancePercent = 0.75
        } else {
            profile.triggers.freezeDamageLeechChancePercent = 0.75
        }
        profile.triggers.leechChancePercent = 0.25
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroMaxHealth: 50, heroMaxMana: 10, heroMana: 0,
            heroModifiers: profile, dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        battle.roster.hero.currentHealth = 10
        _ = battle.resolveDamage(DamageRequest(
            amount: 8, target: battle.enemy, keyword: keyword, sourceActorID: battle.hero.id,
            options: .effect(abilityHasLeech: alreadyLeeches),
        ))
        #expect(battle.roster.hero.currentHealth == 15)
        #expect(battle.roster.hero.currentMana == 2)
    }

    @Test func `typed leech does not apply to other damage types`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.poisonDamageLeechChancePercent = 1
        profile.triggers.freezeDamageLeechChancePercent = 1
        var battle = BattleStateTestFactory.makeBattleWithAbilities(heroModifiers: profile, dealOpeningHand: false)
        battle.appliesFightPacing = false
        battle.roster.hero.currentHealth = 1
        _ = battle.resolveDamage(DamageRequest(
            amount: 8, target: battle.enemy, keyword: .holy, sourceActorID: battle.hero.id, options: .reaction(),
        ))
        #expect(battle.roster.hero.currentHealth == 1)
    }
}
