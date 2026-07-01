import Foundation
@testable import Trinket

/// Test factory for `BattleState` that produces a battle with a fixed RNG
/// seed. The default `BattleState` initializer picks a random seed, which
/// makes `Double.random` dodge rolls inside `applyDamage` non-deterministic
/// across runs. Tests that assert on damage amount, status application,
/// or other outcomes gated by a dodge check must use this factory to
/// avoid flakes.
enum BattleStateTestFactory {
    /// Builds a `BattleState` with `rngSeed: 0` so all randomness inside
    /// the battle is reproducible. Signature mirrors `BattleState.init`
    /// (minus the `rngSeed` argument, which is fixed here).
    static func makeBattle(
        hero: Combatant,
        pet: Combatant,
        enemy: Combatant? = nil,
        activeEnemyEffects: [ActiveEffect] = [],
        activeHeroEffects: [ActiveEffect] = [],
        activePetEffects: [ActiveEffect] = [],
        initialGold: Int = 0
    ) -> BattleState {
        BattleState(
            hero: hero,
            pet: pet,
            enemy: enemy,
            activeEnemyEffects: activeEnemyEffects,
            activeHeroEffects: activeHeroEffects,
            activePetEffects: activePetEffects,
            initialGold: initialGold,
            rngSeed: 0
        )
    }
}
