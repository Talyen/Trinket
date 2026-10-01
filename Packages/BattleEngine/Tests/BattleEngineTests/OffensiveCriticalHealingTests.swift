import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct OffensiveCriticalHealingTests {
    @Test(arguments: [BattleParticipant.hero, .companion])
    func `Burning enemy critical bonuses do not apply to restoration`(owner: BattleParticipant) {
        var battle = makeBattle(owner: owner)
        let source = battle.roster[owner].combatant
        battle.appendEffect(.burn(1), to: battle.hero, sourceID: battle.enemy.id, remainingTurns: 0)
        battle.appendEffect(.burn(1), to: battle.enemy, sourceID: source.id, remainingTurns: 0)

        let allyChance = CriticalChanceEngine.chance(actorID: source.id, defender: battle.hero, in: battle)
        let attackChance = CriticalChanceEngine.chance(
            actorID: source.id, defender: battle.enemy, countsBleedingDefender: true, in: battle,
        )
        #expect(abs(allyChance - 0.10) < 0.0001)
        #expect(abs(attackChance - 0.25) < 0.0001)

        // Seed 9 draws 0.2208: the offensive bonus used to double this Heal.
        let restored = battle.resolveHeal(HealRequest(
            amount: 5, target: battle.hero, sourceActorID: source.id, origin: .restoration(.health),
        ))
        #expect(!restored.isCritical)
        #expect(restored.healthRestored == 5)
        #expect(battle.roster.hero.currentHealth == 15)
    }

    @Test func `Burning ally retains ordinary restoration critical chance and party maximum`() {
        var battle = makeBattle(owner: .companion)
        battle.appendEffect(.burn(1), to: battle.hero, sourceID: battle.enemy.id, remainingTurns: 0)
        battle.appendEffect(.criticalChanceBonus(0.30, 2), to: battle.hero, sourceID: battle.hero.id, remainingTurns: 2)
        #expect(CriticalChanceEngine.rollSucceeds(
            actorID: battle.companion.id, defender: battle.hero, usePartyMaximum: true, in: &battle,
        ))

        // Seed 7 draws 0.0987, below the unchanged ordinary 10% chance.
        battle.rng = SeededRandomNumberGenerator(seed: 7)
        let restored = battle.resolveHeal(HealRequest(
            amount: 5, target: battle.hero, sourceActorID: battle.companion.id, origin: .restoration(.health),
        ))
        #expect(restored.isCritical)
        #expect(restored.healthRestored == 10)
    }

    private func makeBattle(owner: BattleParticipant) -> BattleState {
        let talents: Set<String> = owner == .hero ? ["warlock_burn_t3_2"] : ["ranger_burn_t4_1"]
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 40),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 40),
            enemy: CombatantFixtures.passiveEnemy(),
            heroHealth: 10,
            heroModifiers: CombatantTalentCatalog.profile(for: talents),
            rngSeed: 9,
        )
        battle.appliesFightPacing = false
        return battle
    }

    @Test(arguments: [UInt64(9), 4])
    func `Lastlight grants restoration critical chance while Deaths Door is active without doubling attack bonus`(rngSeed: UInt64) {
        var profile = CombatModifierProfile.zero
        profile.triggers.deathsDoorCriticalChanceBonus = 0.20
        var ordinary = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 40),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 40),
            enemy: CombatantFixtures.passiveEnemy(),
            heroHealth: 1, companionHealth: 10, heroModifiers: profile, rngSeed: rngSeed,
        )
        ordinary.appliesFightPacing = false
        var lastlight = ordinary
        lastlight.appendEffect(.deathsDoor, to: lastlight.hero, sourceID: lastlight.hero.id, remainingTurns: 2)
        var attacking = lastlight

        let ordinaryHeal = ordinary.resolveHeal(HealRequest(
            amount: 5, target: ordinary.companion, sourceActorID: ordinary.hero.id, origin: .restoration(.health),
        ))
        let lastlightHeal = lastlight.resolveHeal(HealRequest(
            amount: 5, target: lastlight.companion, sourceActorID: lastlight.hero.id, origin: .restoration(.health),
        ))
        #expect(!ordinaryHeal.isCritical)
        #expect(ordinaryHeal.healthRestored == 5)
        // Seed 9 draws 0.2208; seed 4 draws 0.4156 and catches a duplicated 20% attack bonus.
        #expect(lastlightHeal.isCritical == (rngSeed == 9))
        #expect(lastlightHeal.healthRestored == (rngSeed == 9 ? 10 : 5))
        let attack = attacking.resolveDamage(DamageRequest(
            amount: 5, target: attacking.enemy, keyword: .physical, sourceActorID: attacking.hero.id,
            options: .attack(tier: .basic, scaling: .flat, accuracy: .unavoidable),
        ))
        #expect(attack.isCritical == (rngSeed == 9))
        #expect(attack.healthLost == (rngSeed == 9 ? 10 : 5))
    }
}
