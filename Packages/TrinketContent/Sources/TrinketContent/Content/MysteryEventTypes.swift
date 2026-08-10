import Foundation
import TrinketCore

public enum MysteryEffect: Hashable, Sendable {
    case gainGold(Int)
    case gainMaterial(HomesteadResource)
    /// Grants ~1 equal-level battle of XP to the active hero and companion.
    case gainExperience
    /// Procedural item: rarity is rolled 80% basic / 20% astral at grant time.
    case gainGeneratedItem(baseTypeID: String, guaranteedAffixIDs: [String] = [])
    case gainRandomItem
    /// Unlocks a hero or companion on the player roster (idempotent at apply time).
    case unlockCombatant(String)
    /// Opens inventory selection to corrupt one owned item.
    case corruptItem
    /// Leaves without mutating inventory; still records altar encounter when on Corruption Altar.
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
    /// When set, this is a one-choice recruit encounter for that combatant.
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
    public static let baseAstralChancePercent = 20

    /// 80% basic / 20% astral by default; homestead Moonlit Sanctum adds to astral chance.
    public static func roll(
        astralChanceBonusPercent: Int = 0,
        using randomNumberGenerator: inout some RandomNumberGenerator
    ) -> Rarity {
        ItemRarityRoll.roll(
            baseAstralChancePercent: baseAstralChancePercent,
            astralChanceBonusPercent: astralChanceBonusPercent,
            using: &randomNumberGenerator
        )
    }
}
