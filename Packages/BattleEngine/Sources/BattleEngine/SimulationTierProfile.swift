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
}

public struct SimulationBuildContext: Equatable, Hashable, Sendable {
    public let tier: SimulationPowerTier
    public let heroLoadout: AbilityLoadout
    public let companionLoadout: AbilityLoadout
    public let loadoutSampleIndex: Int
    public let seed: UInt64
    public let heroAffixIDs: [String]
    public let companionAffixIDs: [String]

    public init(
        tier: SimulationPowerTier,
        heroLoadout: AbilityLoadout,
        companionLoadout: AbilityLoadout,
        loadoutSampleIndex: Int,
        seed: UInt64,
        heroAffixIDs: [String] = [],
        companionAffixIDs: [String] = []
    ) {
        self.tier = tier
        self.heroLoadout = heroLoadout
        self.companionLoadout = companionLoadout
        self.loadoutSampleIndex = loadoutSampleIndex
        self.seed = seed
        self.heroAffixIDs = heroAffixIDs
        self.companionAffixIDs = companionAffixIDs
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

    public var matchup: BattleMatchup {
        BattleMatchup(hero: hero, companion: companion, enemy: enemy)
    }
}
