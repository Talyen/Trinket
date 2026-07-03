import Foundation
import TrinketCore
import TrinketContent

/// Single owner of all battle mutable state: roster, RNG, counters, events,
/// gold, and loop metadata. `BattleState` holds one store; rule engines mutate
/// it in place through `BattleEngineContext` (a typealias).
public struct BattleMutableStore {
    public var roster: BattleRoster
    public var rng: SeededRandomNumberGenerator
    public var tickCount: Int
    public var nextEffectID: Int
    public var nextEventID: Int
    public var events: [ActionEvent]
    public var gold: Int
    public let initialGold: Int
    public let build: BattleCombatBuild
    public var actionCount: Int
    public var hasLoggedDefeat: Bool
    public var hasLoggedPartyDefeat: Bool

    public init(
        roster: BattleRoster,
        rng: SeededRandomNumberGenerator,
        tickCount: Int = 0,
        nextEffectID: Int,
        nextEventID: Int,
        events: [ActionEvent],
        gold: Int,
        initialGold: Int,
        build: BattleCombatBuild,
        actionCount: Int = 0,
        hasLoggedDefeat: Bool = false,
        hasLoggedPartyDefeat: Bool = false
    ) {
        self.roster = roster
        self.rng = rng
        self.tickCount = tickCount
        self.nextEffectID = nextEffectID
        self.nextEventID = nextEventID
        self.events = events
        self.gold = gold
        self.initialGold = initialGold
        self.build = build
        self.actionCount = actionCount
        self.hasLoggedDefeat = hasLoggedDefeat
        self.hasLoggedPartyDefeat = hasLoggedPartyDefeat
    }

    public static func make(
        hero: Combatant,
        pet: Combatant,
        enemy: Combatant,
        activeEnemyEffects: [ActiveEffect] = [],
        activeHeroEffects: [ActiveEffect] = [],
        activePetEffects: [ActiveEffect] = [],
        initialGold: Int = 0,
        heroModifiers: CombatModifierProfile = .zero,
        petModifiers: CombatModifierProfile = .zero,
        rngSeed: UInt64
    ) -> BattleMutableStore {
        let build = BattleCombatBuild(
            hero: hero,
            pet: pet,
            heroModifiers: heroModifiers,
            petModifiers: petModifiers
        )
        let roster = BattleRoster(
            hero: CombatantRuntime(
                combatant: hero,
                initialActiveEffects: activeHeroEffects,
                maximumHealthBonus: heroModifiers.maximumHealthBonus,
                maximumManaBonus: heroModifiers.maximumManaBonus
            ),
            pet: CombatantRuntime(
                combatant: pet,
                initialActiveEffects: activePetEffects,
                maximumHealthBonus: petModifiers.maximumHealthBonus,
                maximumManaBonus: petModifiers.maximumManaBonus
            ),
            enemy: CombatantRuntime(combatant: enemy, initialActiveEffects: activeEnemyEffects)
        )
        let maxExistingEffectID = max(
            activeEnemyEffects.map(\.id).max() ?? 0,
            activeHeroEffects.map(\.id).max() ?? 0,
            activePetEffects.map(\.id).max() ?? 0
        )
        let nextEffectID = maxExistingEffectID + 1

        return BattleMutableStore(
            roster: roster,
            rng: SeededRandomNumberGenerator(seed: rngSeed),
            nextEffectID: nextEffectID,
            nextEventID: 0,
            events: [],
            gold: initialGold,
            initialGold: initialGold,
            build: build
        )
    }
}
