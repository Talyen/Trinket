import Foundation
import TrinketCore

public enum MysteryEffect: Hashable, Sendable {
    case gainGold(Int)
    case gainMaterial(HomesteadResource)
    case gainExperience
    case gainGeneratedItem(baseTypeID: String, guaranteedAffixIDs: [String] = [])
    case gainRandomItem
    case unlockCombatant(String)
    case corruptItem
    case leave
}

public struct MysteryChoice: Hashable, Sendable {
    public let id: String
    public let label: String
    public let effects: [MysteryEffect]

    public init(id: String, label: String, effects: [MysteryEffect]) {
        self.id = id
        self.label = label
        self.effects = effects
    }
}

public struct MysteryEvent: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let narrative: String
    public let artID: String?
    public let unlockCombatantID: String?
    public let choices: [MysteryChoice]

    public var isRecruit: Bool {
        unlockCombatantID != nil
    }

    public init(
        id: String,
        title: String,
        narrative: String,
        artID: String?,
        unlockCombatantID: String? = nil,
        choices: [MysteryChoice]
    ) {
        self.id = id
        self.title = title
        self.narrative = narrative
        self.artID = artID
        self.unlockCombatantID = unlockCombatantID
        self.choices = choices
    }
}

public enum MysteryItemRarity {
    public static func roll(
        astralChanceBonusPercent: Int = 0,
        using randomNumberGenerator: inout some RandomNumberGenerator
    ) -> ItemDropTier {
        ItemRarityRoll.roll(
            bossContent: false,
            astralChanceBonusPercent: astralChanceBonusPercent,
            allowsUnique: false,
            using: &randomNumberGenerator
        )
    }
}
