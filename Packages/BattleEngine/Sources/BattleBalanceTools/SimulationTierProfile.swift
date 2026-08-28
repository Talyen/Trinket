import BattleEngine
import Foundation
import TrinketContent
import TrinketCore

public enum SimulationPowerTier: String, CaseIterable, Codable, Sendable {
    case early
    case middle
    case lateGame

    public var level: Int {
        switch self {
        case .early: 4
        case .middle: 20
        case .lateGame: 40
        }
    }

    public var identityTalentPointCap: Int? {
        switch self {
        case .early: 1
        case .middle, .lateGame: nil
        }
    }

    public var usesStarterGear: Bool {
        self == .early
    }

    public static func band(forLevel level: Int) -> Self {
        if level < 15 {
            return .early
        }
        if level < 35 {
            return .middle
        }
        return .lateGame
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
}

public struct SimulationBuildContext: Equatable, Hashable, Sendable {
    public let tier: SimulationPowerTier
    public let heroLoadout: AbilityLoadout
    public let companionLoadout: AbilityLoadout
    public let loadoutSampleIndex: Int
    public let seed: UInt64
    public let heroAffixIDs: [String]
    public let companionAffixIDs: [String]
    public let heroTalentIDs: [String]
    public let companionTalentIDs: [String]

    public init(
        tier: SimulationPowerTier,
        heroLoadout: AbilityLoadout,
        companionLoadout: AbilityLoadout,
        loadoutSampleIndex: Int,
        seed: UInt64,
        heroAffixIDs: [String] = [],
        companionAffixIDs: [String] = [],
        heroTalentIDs: [String] = [],
        companionTalentIDs: [String] = []
    ) {
        self.tier = tier
        self.heroLoadout = heroLoadout
        self.companionLoadout = companionLoadout
        self.loadoutSampleIndex = loadoutSampleIndex
        self.seed = seed
        self.heroAffixIDs = heroAffixIDs
        self.companionAffixIDs = companionAffixIDs
        self.heroTalentIDs = heroTalentIDs
        self.companionTalentIDs = companionTalentIDs
    }
}

public struct ConfiguredSimulationMatchup: Equatable, Sendable {
    public let hero: Combatant
    public let companion: Combatant
    public let enemy: Combatant
    public let heroModifiers: CombatModifierProfile
    public let companionModifiers: CombatModifierProfile
    public let enemyModifiers: CombatModifierProfile
    public let context: SimulationBuildContext
    public let enemyID: String
    public let isBoss: Bool

    public init(
        hero: Combatant,
        companion: Combatant,
        enemy: Combatant,
        heroModifiers: CombatModifierProfile,
        companionModifiers: CombatModifierProfile,
        enemyModifiers: CombatModifierProfile = .zero,
        context: SimulationBuildContext,
        enemyID: String,
        isBoss: Bool
    ) {
        self.hero = hero
        self.companion = companion
        self.enemy = enemy
        self.heroModifiers = heroModifiers
        self.companionModifiers = companionModifiers
        self.enemyModifiers = enemyModifiers
        self.context = context
        self.enemyID = enemyID
        self.isBoss = isBoss
    }
}
