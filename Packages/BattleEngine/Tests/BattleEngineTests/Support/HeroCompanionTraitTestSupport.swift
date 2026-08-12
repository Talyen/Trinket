import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

enum HeroCompanionTraitTestSupport {
    static func makeContext(
        hero: Combatant,
        companion: Combatant,
        enemy: Combatant,
        heroModifiers: CombatModifierProfile = .zero,
        companionModifiers: CombatModifierProfile = .zero,
        seed: UInt64 = BattleTestFixtures.deterministicNonCriticalSeed
    ) -> BattleState {
        BattleState(
            roster: BattleRoster(
                hero: CombatantRuntime(combatant: hero),
                companion: CombatantRuntime(combatant: companion),
                enemy: CombatantRuntime(combatant: enemy)
            ),
            rng: SeededRandomNumberGenerator(seed: seed),
            nextEffectID: 1,
            nextEventID: 1,
            events: [],
            gold: 0,
            initialGold: 0,
            heroModifiers: heroModifiers,
            companionModifiers: companionModifiers,
            enemyModifiers: .zero
        )
    }

    static func apply(
        _ effect: Effect,
        abilityName: String,
        source: Combatant,
        target: Combatant,
        in context: inout BattleState
    ) -> EffectApplyOutcome {
        let ability = Ability(
            id: "test-\(abilityName)",
            name: abilityName,
            tier: .basic,
            targetedEffects: [TargetedEffect(effect)]
        )
        guard let handler = EffectHandlers.handler(for: effect.kind) else {
            preconditionFailure("Missing handler for \(effect.kind)")
        }
        return handler.apply(
            effect,
            ability: ability,
            source: source,
            target: target,
            action: ActionApplyContext(),
            in: &context
        )
    }

    static func shieldPoints(for combatant: Combatant, in context: BattleState) -> Int {
        context.roster.activeEffects(for: combatant).reduce(0) { sum, active in
            if case let .shield(.block, points) = active.effect {
                return sum + points
            }
            return sum
        }
    }

    static func poisonPotency(on combatant: Combatant, in context: BattleState) -> Int {
        context.roster.activeEffects(for: combatant).reduce(0) { sum, active in
            if case let .poison(potency) = active.effect {
                return sum + potency
            }
            return sum
        }
    }
}
