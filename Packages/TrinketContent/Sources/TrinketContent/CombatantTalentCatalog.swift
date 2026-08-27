import Foundation
import TrinketCore

/// Defines an authored talent node's distinct mechanics, modifiers, and triggers.
public struct CombatantTalentEffect: Sendable {
    public let name: String
    public let symbolName: String
    public let description: String
    public let modifiers: [AffixModifier]
    public let triggers: CombatTraitTriggers

    public init(
        name: String,
        symbolName: String = "",
        description: String,
        modifiers: [AffixModifier] = [],
        triggers: CombatTraitTriggers = CombatTraitTriggers()
    ) {
        self.name = name
        self.symbolName = symbolName
        self.description = description
        self.modifiers = modifiers
        self.triggers = triggers
    }
}

/// Canonical catalog of combatant talent trees for Heroes and Companions.
public enum CombatantTalentCatalog {
    /// Authored name and keyword affinity pairing for a combatant's talent tree.
    public struct TreeAffinity: Sendable, Hashable {
        public let name: String
        public let keyword: Keyword

        public init(name: String, keyword: Keyword) {
            self.name = name
            self.keyword = keyword
        }
    }

    /// The 3 named keyword affinity trees for each Hero and Companion.
    public static let combatantTreeAffinities: [String: [TreeAffinity]] = [
        // Heroes
        "knight": [
            TreeAffinity(name: "Crusade", keyword: .stun),
            TreeAffinity(name: "Chivalry", keyword: .block),
            TreeAffinity(name: "Devotion", keyword: .holy),
        ],
        "ranger": [
            TreeAffinity(name: "Nightshade", keyword: .poison),
            TreeAffinity(name: "Marksmanship", keyword: .bleed),
            TreeAffinity(name: "Wildfire", keyword: .burn),
        ],
        "rogue": [
            TreeAffinity(name: "Cutpurse", keyword: .gold),
            TreeAffinity(name: "Venom", keyword: .poison),
            TreeAffinity(name: "Laceration", keyword: .bleed),
        ],
        "wizard": [
            TreeAffinity(name: "Cryomancy", keyword: .freeze),
            TreeAffinity(name: "Pyromancy", keyword: .burn),
            TreeAffinity(name: "Arcana", keyword: .mana),
        ],
        "warlock": [
            TreeAffinity(name: "Siphon", keyword: .leech),
            TreeAffinity(name: "Occult", keyword: .mana),
            TreeAffinity(name: "Hellfire", keyword: .burn),
        ],

        // Companions
        "wolf": [
            TreeAffinity(name: "Fangs", keyword: .bleed),
            TreeAffinity(name: "Agility", keyword: .dodge),
            TreeAffinity(name: "Savagery", keyword: .physical),
        ],
        "bear": [
            TreeAffinity(name: "Endurance", keyword: .block),
            TreeAffinity(name: "Ferocity", keyword: .physical),
            TreeAffinity(name: "Tremor", keyword: .stun),
        ],
        "frost_whelp": [
            TreeAffinity(name: "Rime", keyword: .freeze),
            TreeAffinity(name: "Anima", keyword: .mana),
            TreeAffinity(name: "Flight", keyword: .dodge),
        ],
        "lizard_scout": [
            TreeAffinity(name: "Toxin", keyword: .poison),
            TreeAffinity(name: "Barbs", keyword: .bleed),
            TreeAffinity(name: "Scavenge", keyword: .gold),
        ],
        "panther": [
            TreeAffinity(name: "Gouge", keyword: .bleed),
            TreeAffinity(name: "Predation", keyword: .leech),
            TreeAffinity(name: "Prowl", keyword: .dodge),
        ],
        "phoenix": [
            TreeAffinity(name: "Kindle", keyword: .burn),
            TreeAffinity(name: "Renewal", keyword: .health),
            TreeAffinity(name: "Rebirth", keyword: .deathsDoor),
        ],
        "golden_retriever": [
            TreeAffinity(name: "Retrieval", keyword: .gold),
            TreeAffinity(name: "Loyalty", keyword: .block),
            TreeAffinity(name: "Morale", keyword: .health),
        ],
        "library_owl": [
            TreeAffinity(name: "Sanctuary", keyword: .health),
            TreeAffinity(name: "Illumination", keyword: .holy),
            TreeAffinity(name: "Erudition", keyword: .cleanse),
        ],
        "risen_skeleton": [
            TreeAffinity(name: "Ossuary", keyword: .physical),
            TreeAffinity(name: "Entropy", keyword: .leech),
            TreeAffinity(name: "Deathrattle", keyword: .deathsDoor),
        ],
        "mana_moth": [
            TreeAffinity(name: "Aether", keyword: .mana),
            TreeAffinity(name: "Frostveil", keyword: .freeze),
            TreeAffinity(name: "Cinder", keyword: .burn),
        ],
        "pixie": [
            TreeAffinity(name: "Purification", keyword: .cleanse),
            TreeAffinity(name: "Blessing", keyword: .health),
            TreeAffinity(name: "Luminescence", keyword: .holy),
        ],
        "shield_scarab": [
            TreeAffinity(name: "Carapace", keyword: .block),
            TreeAffinity(name: "Quake", keyword: .stun),
            TreeAffinity(name: "Sunstone", keyword: .holy),
        ],
        "fox": [
            TreeAffinity(name: "Thievery", keyword: .gold),
            TreeAffinity(name: "Trickery", keyword: .dodge),
            TreeAffinity(name: "Befuddle", keyword: .stun),
        ],
    ]

    // Signature talent definitions are generated from ContentManifest/talents.tsv
    // (`CombatantTalentCatalog.generated.swift`). Per-combatant dictionaries keep
    // each literal off the GCD worker-thread stack.

    public static let allConfigs: [String: CombatantTalentConfig] = {
        var configs: [String: CombatantTalentConfig] = [:]
        configs.reserveCapacity(combatantTreeAffinities.count)
        for (combatantID, affinities) in combatantTreeAffinities {
            let trees = affinities.map { makeTree(combatantID: combatantID, name: $0.name, keyword: $0.keyword) }
            configs[combatantID] = CombatantTalentConfig(combatantID: combatantID, trees: trees)
        }
        return configs
    }()

    public static let validNodeIDsByCombatantID: [String: Set<String>] = {
        var nodeIDs: [String: Set<String>] = [:]
        nodeIDs.reserveCapacity(allConfigs.count)
        for (combatantID, config) in allConfigs {
            nodeIDs[combatantID] = Set(config.trees.flatMap(\.nodes).map(\.id))
        }
        return nodeIDs
    }()

    /// Resolves the valid talent node IDs for a combatant in O(1).
    public static func validNodeIDs(for combatantID: String) -> Set<String> {
        validNodeIDsByCombatantID[combatantID] ?? []
    }

    /// Resolves the 3-tree talent configuration for a combatant.
    public static func config(for combatantID: String) -> CombatantTalentConfig {
        guard let cached = allConfigs[combatantID] else {
            preconditionFailure("Missing talent config for \(combatantID)")
        }
        return cached
    }

    /// Resolves the signature talent effect for a specific node ID, if authored.
    public static func effect(for nodeID: String) -> CombatantTalentEffect? {
        signatureTalents[nodeID]
    }

    /// Generates a standardized 2x3 tree for a keyword affinity (6 nodes total).
    private static func makeTree(combatantID: String, name: String, keyword: Keyword) -> TalentTree {
        var nodes = [TalentNode]()
        nodes.reserveCapacity(6)

        let kwSlug = keyword.rawValue.lowercased().filter { $0.isLetter || $0.isNumber }
        for row in 1 ... 3 {
            for col in 1 ... 2 {
                let nodeID = "\(combatantID)_\(kwSlug)_t\(row)_\(col)"
                guard let signature = signatureTalents[nodeID] else {
                    preconditionFailure("Missing authored talent \(nodeID)")
                }
                nodes.append(
                    TalentNode(
                        id: nodeID,
                        name: signature.name,
                        keyword: keyword,
                        row: row,
                        symbolName: signature.symbolName.isEmpty ? nil : signature.symbolName,
                        description: signature.description
                    )
                )
            }
        }

        return TalentTree(name: name, keyword: keyword, nodes: nodes)
    }
}
