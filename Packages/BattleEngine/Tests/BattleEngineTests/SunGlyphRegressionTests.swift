import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct SunGlyphRegressionTests {
    @Test(arguments: [4, 10], [false, true])
    func `Sun Glyph grants ally Block on Holy hits including winning reflections`(
        enemyHealth: Int,
        reflected: Bool,
    ) {
        var profile = CombatantTalentCatalog.profile(for: ["shield_scarab_holy_t2_1"])
        if reflected {
            // Guarantee Radiant Shell's authored chance so the reflection path is deterministic.
            profile.triggers.blockHolyReflectChancePercent = 1
        }
        var battle = BattleStateTestFactory.makeMinimalBattle(
            enemy: CombatantFixtures.passiveEnemy(maxHealth: enemyHealth),
            companionModifiers: profile, appliesFightPacing: false,
        )
        let outcome: CombatOutcome
        if reflected {
            DefensePoolEngine.set(4, on: battle.companion, in: &battle)
            outcome = battle.resolveTestDamage(
                4,
                from: .enemy,
                to: .companion,
                options: .attack(scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
            )
            #expect(outcome.healthLost == 0)
        } else {
            outcome = holyHit(in: &battle)
            #expect(outcome.healthLost == 4)
        }

        #expect(battle.roster.enemy.currentHealth == enemyHealth - 4)
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.hero.activeEffects) == 2)
        #expect(outcome.events.contains {
            $0.effectKind == .shieldApplied && $0.targetID == battle.hero.id
                && $0.amount == 2 && $0.abilityName == "Sun Glyph"
        })

        if battle.roster.enemy.isAlive {
            let second = holyHit(in: &battle)
            #expect(DefensePoolEngine.blockPoints(in: battle.roster.hero.activeEffects) == 2)
            #expect(!second.events.contains { $0.abilityName == "Sun Glyph" })
        }
    }

    private func holyHit(in battle: inout BattleState) -> CombatOutcome {
        battle.resolveTestDamage(
            4,
            from: .companion,
            keyword: .holy,
            options: .attack(scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        )
    }

    @Test(arguments: [false, true], [false, true])
    func `Sun Glyph and Vitality Infusion require surviving their hit's retaliation`(holy: Bool, survives: Bool) {
        let talent = holy ? "shield_scarab_holy_t2_1" : "panther_leech_t2_1"
        var battle = BattleStateTestFactory.makeMinimalBattle(
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            companionHealth: survives ? 5 : 1,
            companionModifiers: CombatantTalentCatalog.profile(for: [talent]), appliesFightPacing: false,
        )
        battle.roster.companion.hasConsumedDeathsDoor = true
        battle.appendEffect(.thorns(4), to: battle.enemy, sourceID: battle.enemy.id, remainingTurns: 0)
        // Vitality Infusion qualifies through guaranteed Leech even when Sapped prevents restoration.
        battle.appendEffect(.healingReductionPercent(1, 2), to: battle.companion, sourceID: battle.enemy.id, remainingTurns: 2)

        let result = battle.resolveTestDamage(
            2,
            from: .companion,
            keyword: holy ? .holy : .physical,
            options: .attack(scaling: .flat, accuracy: .unavoidable, guaranteedCritical: true, abilityHasLeech: !holy),
        )

        #expect(result.healthLost == 4)
        #expect(battle.health(of: battle.companion) == (survives ? 1 : 0))
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.hero)) == (survives ? (holy ? 2 : 3) : 0))
        let reward = holy ? "Sun Glyph" : "Vitality Infusion"
        #expect(result.events.contains { $0.abilityName == reward } == survives)
    }
}
