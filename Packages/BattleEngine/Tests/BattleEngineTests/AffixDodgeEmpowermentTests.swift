import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

struct AffixDodgeEmpowermentTests {
    @Test func damageAfterDodgeSurvivesDoTTickAndAppliesOnDirectHit() throws {
        let heroCombatant = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 50,
            abilities: [
                Ability(
                    id: "strike",
                    name: "Strike",
                    tier: .basic,
                    directDamage: 1,
                    damageKeyword: .physical
                ),
            ]
        )
        let enemyCombatant = BattleTestFixtures.passiveEnemy(maxHealth: 100)
        var context = BattleState(
            roster: BattleRoster(
                hero: CombatantRuntime(combatant: heroCombatant),
                companion: CombatantRuntime(combatant: BattleTestFixtures.passiveCompanion()),
                enemy: CombatantRuntime(combatant: enemyCombatant)
            ),
            rng: SeededRandomNumberGenerator(seed: 2),
            nextEffectID: 1,
            nextEventID: 1,
            events: [],
            gold: 0,
            initialGold: 0,
            heroModifiers: .zero,
            companionModifiers: .zero,
            enemyModifiers: .zero
        )
        context.roster.mutateRuntime(for: heroCombatant) { $0.pendingDamageAfterDodge = 3 }

        let dotLost = DoTDamage.resolveTurnDamage(
            basePotency: 1,
            keyword: .burn,
            target: enemyCombatant,
            sourceActorID: heroCombatant.id,
            in: &context
        ).healthLost
        try #expect(dotLost == 1)
        try #expect(context.roster.runtime(for: heroCombatant)?.pendingDamageAfterDodge == 3)

        let directLost = context.resolveDamage(
            DamageRequest(
                amount: 1,
                target: enemyCombatant,
                keyword: .physical,
                sourceActorID: heroCombatant.id,
                options: DamageOptions(
                    applyStatBonus: false,
                    applyItemBonus: true,
                    applyDodge: false,
                    qualifiesForAmbush: true,
                    isAttackHit: true
                )
            )
        ).healthLost
        try #expect(directLost == 4)
        try #expect(context.roster.runtime(for: heroCombatant)?.pendingDamageAfterDodge == 0)
    }
}
