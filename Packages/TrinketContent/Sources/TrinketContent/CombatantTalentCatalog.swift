import Foundation
import TrinketCore

/// Canonical catalog of combatant talent trees and placeholder nodes for Heroes and Companions.
public enum CombatantTalentCatalog {
    /// The 3 canonical keyword affinities for each Hero and Companion.
    public static let combatantKeywordAffinities: [String: [Keyword]] = [
        // Heroes
        "knight": [.block, .holy, .stun],
        "rogue": [.poison, .bleed, .dodge],
        "wizard": [.freeze, .burn, .mana],
        "ranger": [.poison, .burn, .bleed],
        "warlock": [.burn, .leech, .mana],

        // Companions
        "bear": [.block, .physical, .stun],
        "frost_whelp": [.freeze, .mana, .stun],
        "lizard_scout": [.poison, .bleed, .gold],
        "panther": [.bleed, .leech, .dodge],
        "phoenix": [.burn, .health, .deathsDoor],
        "wolf": [.bleed, .dodge, .physical],
        "golden_retriever": [.gold, .block, .health],
        "library_owl": [.holy, .cleanse, .health],
        "risen_skeleton": [.physical, .leech, .deathsDoor],
        "mana_moth": [.mana, .freeze, .burn],
        "pixie": [.cleanse, .health, .holy],
        "shield_scarab": [.block, .stun, .holy],
        "fox": [.gold, .dodge, .stun],
    ]

    private static let keywordSymbolNames: [Keyword: String] = [
        .physical: "burst.fill",
        .burn: "flame.fill",
        .stun: "bolt.fill",
        .block: "shield.fill",
        .health: "heart.fill",
        .gold: "circle.circle.fill",
        .holy: "sun.max.fill",
        .poison: "drop.fill",
        .bleed: "drop.fill",
        .leech: "drop",
        .freeze: "snowflake",
        .dodge: "figure.run",
        .purge: "shield.slash.fill",
        .cleanse: "sparkles",
        .mana: "moon.stars.fill",
        .deathsDoor: "hourglass.bottomhalf.filled",
    ]

    /// Default SF Symbol name for a keyword.
    public static func defaultSymbolName(for keyword: Keyword) -> String {
        keywordSymbolNames[keyword] ?? "sparkles"
    }

    /// Resolves the 3-tree talent configuration for a combatant.
    public static func config(for combatantID: String) -> CombatantTalentConfig {
        let keywords = combatantKeywordAffinities[combatantID] ?? [.physical, .block, .health]
        let trees = keywords.map { makeTree(combatantID: combatantID, keyword: $0) }
        return CombatantTalentConfig(combatantID: combatantID, trees: trees)
    }

    /// Generates a standardized 2x3 placeholder tree for a keyword affinity (6 nodes total).
    private static func makeTree(combatantID: String, keyword: Keyword) -> TalentTree {
        let symbol = defaultSymbolName(for: keyword)
        let kwName = keyword.rawValue
        var nodes = [TalentNode]()
        nodes.reserveCapacity(6)

        for tier in 1 ... 3 {
            for col in 1 ... 2 {
                let nodeID = "\(combatantID)_\(keyword.rawValue.lowercased())_t\(tier)_\(col)"
                let tierName = tier == 1 ? "Adept" : (tier == 2 ? "Focus" : "Mastery")
                let name = "\(kwName) \(tierName) \(col)"
                let description = "Tier \(tier) \(kwName) synergy node \(col). Augments \(kwName.lowercased()) effects in combat."
                nodes.append(
                    TalentNode(
                        id: nodeID,
                        name: name,
                        keyword: keyword,
                        symbolName: symbol,
                        tier: tier,
                        description: description
                    )
                )
            }
        }

        return TalentTree(keyword: keyword, nodes: nodes)
    }
}
