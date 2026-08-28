import Foundation

public enum LegacyIDRemap {
    public static let talentNodeIDAliases: [String: String] = {
        var aliases: [String: String] = [:]
        for tier in 1 ... 3 {
            for col in 1 ... 2 {
                aliases["rogue_dodge_t\(tier)_\(col)"] = "rogue_gold_t\(tier)_\(col)"
                aliases["frost_whelp_stun_t\(tier)_\(col)"] = "frost_whelp_dodge_t\(tier)_\(col)"
            }
        }
        return aliases
    }()

    public static let abilityIDAliases: [String: String] = [
        "concussive-shot": "astral-arrow",
        "crystal-bulwark": "glacial-ward",
        "glacial-ward": "blizzard",
        "mana-crystals": "pixie-dust",
        "wise-frost": "apple",
    ]

    public static func remappedTalentNodeID(_ nodeID: String) -> String {
        talentNodeIDAliases[nodeID] ?? nodeID
    }

    public static func remappedAbilityID(_ id: String) -> String? {
        abilityIDAliases[id]
    }
}
