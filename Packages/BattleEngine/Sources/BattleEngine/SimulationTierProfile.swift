import Foundation
import TrinketContent
import TrinketCore

public enum SimulationPowerTier: String, CaseIterable, Codable, Sendable {
    case early
    case middle
    case lateGame

    public var level: Int {
        switch self {
        case .early: 1
        case .middle: 20
        case .lateGame: 40
        }
    }

    public var displayName: String {
        switch self {
        case .early: "Early"
        case .middle: "Middle"
        case .lateGame: "Late Game"
        }
    }

    public var includesGear: Bool {
        self != .early
    }

    public var rarity: Rarity? {
        switch self {
        case .early: nil
        case .middle: .basic
        case .lateGame: .astral
        }
    }

    public var fixedAffixCount: Int? {
        switch self {
        case .early: nil
        case .middle: 1
        case .lateGame: 3
        }
    }

    public var usesRandomLoadouts: Bool {
        self != .early
    }
}

public struct SimulationBuildContext: Equatable, Hashable, Sendable {
    public let tier: SimulationPowerTier
    public let heroLoadout: AbilityLoadout
    public let petLoadout: AbilityLoadout
    public let loadoutSampleIndex: Int
    public let seed: UInt64
    public let heroAffixIDs: [String]
    public let petAffixIDs: [String]

    public init(
        tier: SimulationPowerTier,
        heroLoadout: AbilityLoadout,
        petLoadout: AbilityLoadout,
        loadoutSampleIndex: Int,
        seed: UInt64,
        heroAffixIDs: [String] = [],
        petAffixIDs: [String] = []
    ) {
        self.tier = tier
        self.heroLoadout = heroLoadout
        self.petLoadout = petLoadout
        self.loadoutSampleIndex = loadoutSampleIndex
        self.seed = seed
        self.heroAffixIDs = heroAffixIDs
        self.petAffixIDs = petAffixIDs
    }
}

public struct ConfiguredSimulationMatchup: Equatable, Sendable {
    public let hero: Combatant
    public let pet: Combatant
    public let enemy: Combatant
    public let heroModifiers: CombatModifierProfile
    public let petModifiers: CombatModifierProfile
    public let enemyModifiers: CombatModifierProfile
    public let context: SimulationBuildContext
    public let enemyID: String
    public let isBoss: Bool

    public init(
        hero: Combatant,
        pet: Combatant,
        enemy: Combatant,
        heroModifiers: CombatModifierProfile,
        petModifiers: CombatModifierProfile,
        enemyModifiers: CombatModifierProfile = .zero,
        context: SimulationBuildContext,
        enemyID: String,
        isBoss: Bool
    ) {
        self.hero = hero
        self.pet = pet
        self.enemy = enemy
        self.heroModifiers = heroModifiers
        self.petModifiers = petModifiers
        self.enemyModifiers = enemyModifiers
        self.context = context
        self.enemyID = enemyID
        self.isBoss = isBoss
    }

    public var matchup: BattleMatchup {
        BattleMatchup(hero: hero, pet: pet, enemy: enemy)
    }
}
