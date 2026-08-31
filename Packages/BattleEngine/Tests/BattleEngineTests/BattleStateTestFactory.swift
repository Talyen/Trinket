import TrinketContent
import TrinketCore
@testable import BattleEngine

enum BattleStateTestFactory {
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
        enemyFaction: EnemyFaction = .mortal,
        rngSeed: UInt64 = BattleTestFixtures.deterministicNonCriticalSeed,
        tracksLog: Bool = false,
        tracksEvents: Bool = true,
        dealOpeningHand: Bool = true,
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
            enemyFaction: enemyFaction,
            rngSeed: rngSeed,
            tracksLog: tracksLog,
            tracksEvents: tracksEvents,
            dealOpeningHand: dealOpeningHand,
        )
    }

    static func drawOpeningHand(on battle: inout BattleState) {
        battle.drawOpeningHand()
    }

    static func seedActiveEffects(
        _ effects: [ActiveEffect],
        for combatant: Combatant,
        on battle: inout BattleState,
    ) {
        battle.seedActiveEffects(effects, for: combatant)
    }

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
        dealOpeningHand: Bool = true,
    ) -> BattleState {
        let hero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: heroMaxHealth,
            maxMana: heroMaxMana,
            abilities: heroAbilities,
        )
        let companion = Combatant(
            id: "companion",
            name: "Companion",
            role: .companion,
            maxHealth: companionMaxHealth,
            maxMana: companionMaxMana,
            abilities: companionAbilities,
        )
        let enemy = Combatant(
            id: "enemy",
            name: "Enemy",
            role: .enemy,
            maxHealth: enemyMaxHealth,
            abilities: enemyAbilities,
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
            dealOpeningHand: dealOpeningHand,
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

    static func makeMinimalBattle(
        hero: Combatant,
        companion: Combatant,
        enemy: Combatant,
        heroEffects: [ActiveEffect] = [],
        companionEffects: [ActiveEffect] = [],
        enemyEffects: [ActiveEffect] = [],
        heroHealth: Int? = nil,
        companionHealth: Int? = nil,
        enemyHealth: Int? = nil,
        heroMana: Int? = nil,
        companionMana: Int? = nil,
        enemyMana: Int? = nil,
        heroModifiers: CombatModifierProfile = .zero,
        companionModifiers: CombatModifierProfile = .zero,
        enemyModifiers: CombatModifierProfile = .zero,
        rngSeed: UInt64 = BattleTestFixtures.deterministicNonCriticalSeed,
        nextEffectID: Int? = nil,
        nextEventID: Int = 0,
    ) -> BattleState {
        let maxExistingEffectID = max(
            heroEffects.map(\.id).max() ?? 0,
            companionEffects.map(\.id).max() ?? 0,
            enemyEffects.map(\.id).max() ?? 0,
        )
        return BattleState(
            roster: BattleRoster(
                hero: CombatantRuntime(
                    combatant: hero,
                    initialHealth: heroHealth,
                    initialMana: heroMana,
                    initialActiveEffects: heroEffects,
                    maximumHealthBonus: heroModifiers.maximumHealthBonus,
                    maximumManaBonus: heroModifiers.maximumManaBonus,
                ),
                companion: CombatantRuntime(
                    combatant: companion,
                    initialHealth: companionHealth,
                    initialMana: companionMana,
                    initialActiveEffects: companionEffects,
                    maximumHealthBonus: companionModifiers.maximumHealthBonus,
                    maximumManaBonus: companionModifiers.maximumManaBonus,
                ),
                enemy: CombatantRuntime(
                    combatant: enemy,
                    initialHealth: enemyHealth,
                    initialMana: enemyMana,
                    initialActiveEffects: enemyEffects,
                ),
            ),
            rng: SeededRandomNumberGenerator(seed: rngSeed),
            nextEffectID: nextEffectID ?? maxExistingEffectID + 1,
            nextEventID: nextEventID,
            events: [],
            gold: 0,
            initialGold: 0,
            heroModifiers: heroModifiers,
            companionModifiers: companionModifiers,
            enemyModifiers: enemyModifiers,
        )
    }
}
