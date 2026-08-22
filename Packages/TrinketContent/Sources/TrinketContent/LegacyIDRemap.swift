import Foundation

/// Renames of authored catalog IDs that can still appear in shipped saves.
///
/// Owned next to the catalogs so a future ID rename updates its entry in the
/// same commit; `LegacyIDRemapInvariantTests` fails loudly when a remap target
/// no longer exists. Unmatched IDs degrade silently at hydration time, which is
/// exactly what these tables exist to prevent.
public enum LegacyIDRemap {
    /// Former Dodge/Stun tree node IDs for Rogue and Frost Whelp.
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

    /// Ability renames / choice swaps.
    public static let abilityIDAliases: [String: String] = [
        "concussive-shot": "astral-arrow",
        "crystal-bulwark": "glacial-ward",
        "glacial-ward": "blizzard",
        "mana-crystals": "pixie-dust",
        "wise-frost": "apple",
    ]

    /// Returns the current node ID for a legacy ID, or `nodeID` unchanged.
    public static func remappedTalentNodeID(_ nodeID: String) -> String {
        talentNodeIDAliases[nodeID] ?? nodeID
    }

    /// Returns the current ability ID for a legacy ID, or `nil`.
    public static func remappedAbilityID(_ id: String) -> String? {
        abilityIDAliases[id]
    }
}
