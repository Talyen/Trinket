import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

extension AbilityEffectIntegrationTests {
    @Test(arguments: [Ability.rayOfFrost, .fangs])
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

    @Test(arguments: [BattleParticipant.hero, .companion, .enemy], [false, true])
    func `blessed aegis protects only living allies`(caster: BattleParticipant, companionDefeated: Bool) {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false)
        battle.appliesFightPacing = false
        if companionDefeated {
            battle.roster.companion.currentHealth = 0
        }
        let casterAlive = battle.roster[caster].isAlive
        let actor = battle.roster[caster].combatant
        _ = BattleTurnEngine.performAction(ability: .blessedAegis, actor: actor, abilityTarget: battle.enemy, context: &battle)
        for owner in [BattleParticipant.hero, .companion, .enemy] {
            let member = battle.roster[owner]
            let protected = casterAlive && member.isAlive && (caster == .enemy ? owner == .enemy : owner != .enemy)
            #expect(BattleTestFixtures.shieldPoints(for: member.combatant, in: battle) == (protected ? 4 : 0))
            #expect(member.activeEffects.contains { $0.effect == .onHitDamage(.holy, 4) } == protected)
        }
    }

    @Test func `blessed aegis wards refresh and trigger independently`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(enemyMaxHealth: 500, dealOpeningHand: false)
        battle.appliesFightPacing = false
        for _ in 0 ..< 2 {
            _ = BattleTurnEngine.performAction(ability: .blessedAegis, actor: battle.hero, abilityTarget: battle.enemy, context: &battle)
        }
        #expect(battle.roster.hero.activeEffects.count { $0.effect == .onHitDamage(.holy, 4) } == 1)
        for owner in [BattleParticipant.hero, .companion] {
            let member = battle.roster[owner].combatant
            let events = battle.resolveDamage(DamageRequest(
                amount: 1, target: member, keyword: .physical, sourceActorID: battle.enemy.id,
                options: .attack(accuracy: .unavoidable),
            )).events
            #expect(events.contains { $0.keyword == .holy && $0.targetID == battle.enemy.id && $0.amount >= 4 })
            #expect(!battle.roster[owner].activeEffects.contains { $0.effect == .onHitDamage(.holy, 4) })
            if owner == .hero {
                #expect(battle.roster.companion.activeEffects.contains { $0.effect == .onHitDamage(.holy, 4) })
            }
        }
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
