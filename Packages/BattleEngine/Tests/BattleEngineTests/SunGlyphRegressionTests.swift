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
            hero: CombatantFixtures.passiveHero(),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: enemyHealth),
            companionModifiers: profile,
        )
        battle.appliesFightPacing = false
        let outcome: CombatOutcome
        if reflected {
            DefensePoolEngine.set(4, on: battle.companion, in: &battle)
            outcome = battle.resolveDamage(DamageRequest(
                amount: 4, target: battle.companion, keyword: .physical,
                sourceActorID: battle.enemy.id,
                options: .attack(scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
            ))
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
        battle.resolveDamage(DamageRequest(
            amount: 4, target: battle.enemy, keyword: .holy,
            sourceActorID: battle.companion.id,
            options: .attack(scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1),
        ))
    }
}
