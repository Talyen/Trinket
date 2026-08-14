import TrinketContent
import TrinketCore
@testable import BattleEngine

/// Test factory for `BattleState` that produces a battle with a fixed RNG
/// seed. The default `BattleState` initializer picks a random seed, which
/// makes `Double.random` dodge and critical rolls inside `applyDamage`
/// non-deterministic across runs. Tests that assert on damage amount,
/// status application, or other outcomes gated by these checks must use
/// this factory to avoid flakes.
enum BattleStateTestFactory {
    /// Builds a `BattleState` with a fixed seed so all randomness inside
    /// the battle is reproducible. Signature mirrors `BattleState.init`
    /// (minus the `rngSeed` argument, which is fixed here).
    static func makeBattle(
        hero: Combatant,
        companion: Combatant,
        enemy: Combatant? = nil,
        activeEnemyEffects: [ActiveEffect] = [],
        activeHeroEffects: [ActiveEffect] = [],
        activeCompanionEffects: [ActiveEffect] = [],
        initialGold: Int = 0,
        heroModifiers: CombatModifierProfile = .zero,
        companionModifiers: CombatModifierProfile = .zero,
        enemyModifiers: CombatModifierProfile = .zero,
        rngSeed: UInt64 = BattleTestFixtures.deterministicNonCriticalSeed,
        tracksLog: Bool = false,
        tracksEvents: Bool = true,
        dealOpeningHand: Bool = true
    ) -> BattleState {
        BattleState(
            hero: hero,
            companion: companion,
            enemy: enemy,
            activeEnemyEffects: activeEnemyEffects,
            activeHeroEffects: activeHeroEffects,
            activeCompanionEffects: activeCompanionEffects,
            initialGold: initialGold,
            heroModifiers: heroModifiers,
            companionModifiers: companionModifiers,
            enemyModifiers: enemyModifiers,
            rngSeed: rngSeed,
            tracksLog: tracksLog,
            tracksEvents: tracksEvents,
            dealOpeningHand: dealOpeningHand
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

    /// Convenient helper for card & turn tests requiring custom ability loadouts and initial mana.
    static func makeBattleWithAbilities(
        heroAbilities: [Ability] = [],
        companionAbilities: [Ability] = [],
        enemyAbilities: [Ability] = [],
        heroMaxHealth: Int = 50,
        companionMaxHealth: Int = 50,
        enemyMaxHealth: Int = 100,
        heroMaxMana: Int = 0,
        heroMana: Int? = nil,
        companionMaxMana: Int = 0,
        companionMana: Int? = nil,
        initialGold: Int = 0,
        heroModifiers: CombatModifierProfile = .zero,
        companionModifiers: CombatModifierProfile = .zero,
        rngSeed: UInt64 = BattleTestFixtures.deterministicNonCriticalSeed,
        tracksLog: Bool = false,
        dealOpeningHand: Bool = true
    ) -> BattleState {
        let hero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: heroMaxHealth,
            maxMana: heroMaxMana,
            abilities: heroAbilities
        )
        let companion = Combatant(
            id: "companion",
            name: "Companion",
            role: .companion,
            maxHealth: companionMaxHealth,
            maxMana: companionMaxMana,
            abilities: companionAbilities
        )
        let enemy = Combatant(
            id: "enemy",
            name: "Enemy",
            role: .enemy,
            maxHealth: enemyMaxHealth,
            abilities: enemyAbilities
        )
        var battle = makeBattle(
            hero: hero,
            companion: companion,
            enemy: enemy,
            initialGold: initialGold,
            heroModifiers: heroModifiers,
            companionModifiers: companionModifiers,
            rngSeed: rngSeed,
            tracksLog: tracksLog,
            dealOpeningHand: dealOpeningHand
        )
        if let heroMana {
            battle.withEngineContext { context in
                context.roster.mutateRuntime(for: hero) { $0.currentMana = heroMana }
            }
        }
        if let companionMana {
            battle.withEngineContext { context in
                context.roster.mutateRuntime(for: companion) { $0.currentMana = companionMana }
            }
        }
        return battle
    }
}
