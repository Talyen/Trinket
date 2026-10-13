import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct CombatMagnitudeRegressionTests {
    @Test func `repeated dodge preparations saturate and are spent by the next attack`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.damageAfterDodgeBonus = Int.max / 2 + 1
        var battle = makeBattle(profile: profile)
        for _ in 0 ..< 2 {
            _ = CombatExecutor.run { await CombatTriggerEngine.afterDodge(
                by: battle.hero, attackerID: battle.enemy.id, in: &battle,
            ) }
        }
        #expect(battle.roster.hero.talents.pending.damageAfterDodge == Int.max)

        let outcome = battle.resolveDamage(DamageRequest(
            amount: 1, target: battle.enemy, keyword: .physical,
            sourceActorID: battle.hero.id, options: .attack(accuracy: .unavoidable),
        ))

        #expect(outcome.healthLost == 3)
        #expect(battle.roster.hero.talents.pending.damageAfterDodge == 0)
    }

    @Test func `Marked preserves capped attack damage when its bonus saturates`() {
        var battle = makeBattle()
        battle.appendEffect(.marked(Int.max, 2), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 2)

        let outcome = battle.resolveDamage(DamageRequest(
            amount: 1, target: battle.enemy, keyword: .physical,
            sourceActorID: battle.hero.id, options: .attack(accuracy: .unavoidable),
        ))

        #expect(outcome.healthLost == 3)
        #expect(!battle.activeEffects(of: battle.enemy).contains { $0.effect.kind == .marked })
        #expect(outcome.events.contains { $0.effectKind == .markedConsumed && $0.amount == Int.max })
    }

    @Test func `stacked Dazzled reductions prevent damage without overflowing`() {
        var battle = makeBattle()
        for amount in [Int.max, 1] {
            battle.appendEffect(.damageReductionFlat(amount, 2), to: battle.hero, sourceID: battle.enemy.id, remainingTurns: 2)
        }

        let outcome = battle.resolveDamage(DamageRequest(
            amount: 6, target: battle.enemy, keyword: .physical,
            sourceActorID: battle.hero.id, options: .attack(accuracy: .unavoidable),
        ))

        #expect(outcome.healthLost == 0)
        #expect(battle.health(of: battle.enemy) == 20)
    }

    @Test func `Venomtrail preserves capped Poison tick damage at maximum potency`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.poisonDamageVsBleedingFlat = 1
        var battle = makeBattle(profile: profile)
        battle.appendEffect(.bleed(1), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 2)

        let outcome = battle.resolveDoTTick(
            basePotency: Int.max, keyword: .poison, target: battle.enemy, sourceActorID: battle.hero.id,
        )

        #expect(outcome.healthLost == 3)
        #expect(battle.health(of: battle.enemy) == 17)
    }

    @Test func `Kingbreaker adds maximum enemy Block without crashing or consuming the pool`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.stunDamageAddsEnemyBlock = true
        var battle = makeBattle(profile: profile)
        DefensePoolEngine.set(Int.max, on: battle.enemy, in: &battle)

        let outcome = battle.resolveDamage(DamageRequest(
            amount: 1, target: battle.enemy, keyword: .stun,
            sourceActorID: battle.hero.id, options: .attack(accuracy: .unavoidable),
        ))

        #expect(outcome.healthLost == 3)
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.enemy)) == Int.max)
    }

    private func makeBattle(profile: CombatModifierProfile = .zero) -> BattleState {
        var heroProfile = profile
        heroProfile.triggers.criticalChanceBonus = -1
        var enemyProfile = CombatModifierProfile.zero
        enemyProfile.triggers.maxDamagePerHitCap = 3
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 20),
            heroModifiers: heroProfile, enemyModifiers: enemyProfile,
        )
        battle.appliesFightPacing = false
        return battle
    }
}
