import XCTest
@testable import BattleEngine
import TrinketCore
import TrinketContent


/// Test factory for `BattleState` that produces a battle with a fixed RNG
/// seed. The default `BattleState` initializer picks a random seed, which
/// makes `Double.random` dodge and critical rolls inside `applyDamage`
/// non-deterministic across runs. Tests that assert on damage amount,
/// status application, or other outcomes gated by these checks must use
/// this factory to avoid flakes.
enum BattleStateTestFactory {
    /// Seed chosen so early damage rolls are reproducible without triggering
    /// the default 5% critical chance.
    private static let deterministicNonCriticalSeed: UInt64 = 1772

    /// Builds a `BattleState` with a fixed seed so all randomness inside
    /// the battle is reproducible. Signature mirrors `BattleState.init`
    /// (minus the `rngSeed` argument, which is fixed here).
    static func makeBattle(
        hero: Combatant,
        pet: Combatant,
        enemy: Combatant? = nil,
        activeEnemyEffects: [ActiveEffect] = [],
        activeHeroEffects: [ActiveEffect] = [],
        activePetEffects: [ActiveEffect] = [],
        initialGold: Int = 0,
        heroModifiers: CombatModifierProfile = .zero,
        petModifiers: CombatModifierProfile = .zero
    ) -> BattleState {
        BattleState(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeEnemyEffects: activeEnemyEffects,
            activeHeroEffects: activeHeroEffects,
            activePetEffects: activePetEffects,
            initialGold: initialGold,
            heroModifiers: heroModifiers,
            petModifiers: petModifiers,
            rngSeed: deterministicNonCriticalSeed
        )
    }

    /// Seeds active effects on a combatant for unit tests.
    static func seedActiveEffects(
        _ effects: [ActiveEffect],
        for combatant: Combatant,
        on battle: inout BattleState
    ) {
        battle.seedActiveEffects(effects, for: combatant)
    }
}
