import Foundation
import TrinketContent
import TrinketCore

public enum SimulationPowerTier: String, CaseIterable, Codable, Sendable {
    case early
    case middle
    case lateGame

    public var level: Int {
        switch self {
        case .early: return 1
        case .middle: return 20
        case .lateGame: return 40
        }
    }

    public var displayName: String {
        switch self {
        case .early: return "Early"
        case .middle: return "Middle"
        case .lateGame: return "Late Game"
        }
    }

    public var includesGear: Bool {
        self != .early
    }

    public var rarity: Rarity? {
        switch self {
        case .early: return nil
        case .middle: return .basic
        case .lateGame: return .astral
        }
    }

    public var fixedAffixCount: Int? {
        switch self {
        case .early: return nil
        case .middle: return 1
        case .lateGame: return 3
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

    public init(
        tier: SimulationPowerTier,
        heroLoadout: AbilityLoadout,
        petLoadout: AbilityLoadout,
        loadoutSampleIndex: Int,
        seed: UInt64
    ) {
        self.tier = tier
        self.heroLoadout = heroLoadout
        self.petLoadout = petLoadout
        self.loadoutSampleIndex = loadoutSampleIndex
        self.seed = seed
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
