import Testing
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine
@testable import TrinketContent

extension AbilityEffectIntegrationTests {
    @Test(arguments: [0, 1, 4], [false, true])
    func `Blackjack steals once for existing or newly applied Stun`(initialStun: Int, finishingHit: Bool) {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            enemyMaxHealth: 20, heroModifiers: .withTriggers { $0.criticalChanceBonus = -1 }, dealOpeningHand: false,
            appliesFightPacing: false,
        )
        if initialStun > 0 {
            battle.insertEffect(
                .controlMeter(.stun, initialStun, 4), to: battle.enemy,
                sourceID: battle.hero.id, remainingTurns: 0,
            )
        }
        if finishingHit {
            battle.roster.enemy.currentHealth = 2
        }

        let events = battle.performTestAction(.blackjack)

        let qualifies = initialStun == 4 || (initialStun == 1 && !finishingHit)
        let theft = events.filter { $0.effectKind == .resourceGain && $0.abilityID == "blackjack" && $0.keyword == .gold }
        #expect(battle.gold == (qualifies ? 3 : 0))
        #expect(theft.count == (qualifies ? 1 : 0))
    }

    @Test func `enemy basic freeze bonus does not repeat on the Bleed tick`() throws {
        var battle = BattleStateTestFactory.makeBattle(
            hero: CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 100),
            enemyModifiers: .withTriggers { $0.basicAttackFreezeBuildup = 1 }, dealOpeningHand: false, appliesFightPacing: false,
        )
        battle.performTestAction(.fangs, from: .enemy, to: .hero)
        #expect(battle.health(of: battle.hero) == 98)
        let active = try #require(battle.activeEffects(of: battle.hero).first { $0.effect.isBleed })
        CombatExecutor.run { await EffectHandlers.advanceTurn(active, on: battle.hero, in: &battle) }
        #expect(battle.health(of: battle.hero) == 97)
    }

    @Test(arguments: [Keyword.poison, .freeze], [false, true])
    func `typed leech chance succeeds or fails on ongoing damage`(keyword: Keyword, succeeds: Bool) throws {
        let seed = try #require((UInt64(1) ... 32).first { seed in
            var rng = SeededRandomNumberGenerator(seed: seed)
            return BattleChance.succeeds(probability: 0.5, using: &rng) == succeeds
        })
        let profile = CombatModifierProfile.withTriggers {
            $0.criticalChanceBonus = -1
            if keyword == .poison {
                $0.poisonDamageLeechChancePercent = 0.5
            } else {
                $0.freezeDamageLeechChancePercent = 0.5
            }
        }
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroModifiers: profile, dealOpeningHand: false, appliesFightPacing: false,
        )
        battle.rng = SeededRandomNumberGenerator(seed: seed)
        battle.roster.hero.currentHealth = 1
        _ = battle.resolveDamage(.doTTick(amount: 8, target: battle.enemy, keyword: keyword, sourceActorID: battle.hero.id))
        #expect(battle.roster.hero.currentHealth == (succeeds ? 5 : 1))
    }

    @Test func `blessed aegis grants actor block heals lowest ally and deals holy damage`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(dealOpeningHand: false, appliesFightPacing: false)
        battle.roster.companion.currentHealth = 10
        let enemyBefore = battle.health(of: battle.enemy)

        battle.performTestAction(.blessedAegis)

        #expect(BattleTestFixtures.shieldPoints(for: battle.hero, in: battle) == 4)
        #expect(battle.health(of: battle.companion) == 15)
        #expect(battle.health(of: battle.hero) == battle.hero.maxHealth)
        #expect(enemyBefore - battle.health(of: battle.enemy) == 5)
        #expect(!battle.activeEffects(of: battle.hero).contains { $0.effect.kind == .onHitDamage })
        #expect(!battle.activeEffects(of: battle.companion).contains { $0.effect.kind == .onHitDamage })
    }

    @Test func `blessed aegis holy damage does not grow with stored block`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(enemyMaxHealth: 500, dealOpeningHand: false, appliesFightPacing: false)
        DefensePoolEngine.set(8, on: battle.hero, in: &battle)
        let before = battle.health(of: battle.enemy)
        battle.performTestAction(.blessedAegis)
        #expect(BattleTestFixtures.shieldPoints(for: battle.hero, in: battle) == 12)
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
            heroModifiers: profile, dealOpeningHand: false, appliesFightPacing: false,
        )
        battle.roster.hero.currentHealth = 10
        _ = battle.resolveTestDamage(8, keyword: keyword, options: .effect(abilityHasLeech: alreadyLeeches))
        #expect(battle.roster.hero.currentHealth == 15)
        #expect(battle.roster.hero.currentMana == 2)
    }

    @Test func `typed leech does not apply to other damage types`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroModifiers: .withTriggers {
                $0.poisonDamageLeechChancePercent = 1
                $0.freezeDamageLeechChancePercent = 1
            },
            dealOpeningHand: false,
            appliesFightPacing: false,
        )
        battle.roster.hero.currentHealth = 1
        _ = battle.resolveTestDamage(8, keyword: .holy, options: .reaction())
        #expect(battle.roster.hero.currentHealth == 1)
    }
}
