import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

struct HexmarkTests {
    private func makeContext(
        enemyEffects: [ActiveEffect] = [],
        nextEffectID: Int = 1
    ) -> BattleEngineContext {
        let hero = CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 20)
        let companion = CombatantFixtures.combatant(id: "companion", role: .companion, maxHealth: 20)
        let enemy = CombatantFixtures.combatant(id: "enemy", role: .enemy, maxHealth: 40)
        return BattleEngineContext(
            roster: BattleRoster(
                hero: CombatantRuntime(combatant: hero),
                companion: CombatantRuntime(combatant: companion),
                enemy: CombatantRuntime(combatant: enemy, initialActiveEffects: enemyEffects)
            ),
            rng: SeededRandomNumberGenerator(seed: 1772),
            nextEffectID: nextEffectID,
            nextEventID: 1,
            events: [],
            gold: 0,
            initialGold: 0,
            heroModifiers: CombatModifierProfile(firstHitApplyMarked: true),
            companionModifiers: .zero,
            enemyModifiers: .zero
        )
    }

    private func directHit(
        amount: Int,
        target: Combatant,
        sourceActorID: String
    ) -> DamageRequest {
        DamageRequest(
            amount: amount,
            target: target,
            keyword: .physical,
            sourceActorID: sourceActorID,
            options: DamageOptions(
                applyStatBonus: false,
                applyItemBonus: false,
                applyDodge: false,
                qualifiesForAmbush: true
            )
        )
    }

    private func hasMarked(_ effects: [ActiveEffect]) -> Bool {
        effects.contains {
            if case .marked = $0.effect {
                return true
            }
            return false
        }
    }

    @Test func hexmarkAppliesMarkedForLaterHitWithoutSameHitBonus() throws {
        var context = makeContext()
        let hero = context.roster.hero.combatant
        let enemy = context.roster.enemy.combatant

        let firstHit = context.resolveDamage(directHit(amount: 3, target: enemy, sourceActorID: hero.id))

        try #expect(firstHit.healthLost == 3)
        try #expect(firstHit.events.contains {
            $0.effectKind == .markedApplied && $0.abilityName == "Hexmark"
        })
        try #expect(!firstHit.events.contains { $0.effectKind == .markedConsumed })
        try #expect(hasMarked(context.roster.activeEffects(for: enemy)))
        try #expect(context.roster.runtime(for: hero)?.hasTriggeredHexmark == true)

        let secondHit = context.resolveDamage(directHit(amount: 3, target: enemy, sourceActorID: hero.id))

        try #expect(secondHit.healthLost == 3 + Effect.standardMarkedBonus)
        try #expect(secondHit.events.contains { $0.effectKind == .markedConsumed })
        try #expect(!hasMarked(context.roster.activeEffects(for: enemy)))
    }

    @Test func hexmarkSurvivesArmorRefreshOnFirstHit() throws {
        let armor = ActiveEffect(
            id: 1,
            effect: .mitigation(.armor, 4),
            remainingTicks: 6,
            sourceActorID: "enemy"
        )
        var context = makeContext(enemyEffects: [armor], nextEffectID: 2)
        let hero = context.roster.hero.combatant
        let enemy = context.roster.enemy.combatant

        let outcome = context.resolveDamage(directHit(amount: 6, target: enemy, sourceActorID: hero.id))

        try #expect(outcome.events.contains {
            $0.effectKind == .markedApplied && $0.abilityName == "Hexmark"
        })
        try #expect(!outcome.events.contains { $0.effectKind == .markedConsumed })
        try #expect(hasMarked(context.roster.activeEffects(for: enemy)))
    }
}
