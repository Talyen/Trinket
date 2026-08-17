import Foundation
import TrinketCore

/// Defines an authored talent node's distinct mechanics, modifiers, and triggers.
public struct CombatantTalentEffect: Sendable {
    public let name: String
    public let description: String
    public let modifiers: [AffixModifier]
    public let triggers: CombatTraitTriggers

    public init(
        name: String,
        description: String,
        modifiers: [AffixModifier] = [],
        triggers: CombatTraitTriggers = CombatTraitTriggers(
        )
    ) {
        self.name = name
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
            TreeAffinity(name: "Chivalry", keyword: .block),
            TreeAffinity(name: "Devotion", keyword: .holy),
            TreeAffinity(name: "Crusade", keyword: .stun),
        ],
        "rogue": [
            TreeAffinity(name: "Venom", keyword: .poison),
            TreeAffinity(name: "Laceration", keyword: .bleed),
            TreeAffinity(name: "Cutpurse", keyword: .gold),
        ],
        "wizard": [
            TreeAffinity(name: "Cryomancy", keyword: .freeze),
            TreeAffinity(name: "Pyromancy", keyword: .burn),
            TreeAffinity(name: "Arcana", keyword: .mana),
        ],
        "ranger": [
            TreeAffinity(name: "Nightshade", keyword: .poison),
            TreeAffinity(name: "Wildfire", keyword: .burn),
            TreeAffinity(name: "Marksmanship", keyword: .bleed),
        ],
        "warlock": [
            TreeAffinity(name: "Hellfire", keyword: .burn),
            TreeAffinity(name: "Siphon", keyword: .leech),
            TreeAffinity(name: "Occult", keyword: .mana),
        ],

        // Companions
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
        "wolf": [
            TreeAffinity(name: "Fangs", keyword: .bleed),
            TreeAffinity(name: "Agility", keyword: .dodge),
            TreeAffinity(name: "Savagery", keyword: .physical),
        ],
        "golden_retriever": [
            TreeAffinity(name: "Retrieval", keyword: .gold),
            TreeAffinity(name: "Loyalty", keyword: .block),
            TreeAffinity(name: "Morale", keyword: .health),
        ],
        "library_owl": [
            TreeAffinity(name: "Illumination", keyword: .holy),
            TreeAffinity(name: "Erudition", keyword: .cleanse),
            TreeAffinity(name: "Sanctuary", keyword: .health),
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

    /// The 3 canonical keyword affinities for each Hero and Companion.
    public static var combatantKeywordAffinities: [String: [Keyword]] {
        combatantTreeAffinities.mapValues { $0.map(\.keyword) }
    }

    // Signature talent definitions migrated from the legacy trait system.
    // Split into per-combatant groups: a single literal of all 324 nodes
    // generates a one-time initializer too large for the GCD worker thread stack.

    public static let signatureTalents: [String: CombatantTalentEffect] = {
        var combined: [String: CombatantTalentEffect] = [:]
        combined.reserveCapacity(324)
        for group in [
            knightTalents, rogueTalents, wizardTalents, rangerTalents, warlockTalents,
            bearTalents, frostWhelpTalents, lizardScoutTalents, pantherTalents, phoenixTalents,
            wolfTalents, goldenRetrieverTalents, libraryOwlTalents, risenSkeletonTalents,
            manaMothTalents, pixieTalents, shieldScarabTalents, foxTalents,
        ] {
            for (key, value) in group {
                combined[key] = value
            }
        }
        return combined
    }()

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

    private static let fallbackAffinities: [TreeAffinity] = [
        TreeAffinity(name: "Physical", keyword: .physical),
        TreeAffinity(name: "Block", keyword: .block),
        TreeAffinity(name: "Health", keyword: .health),
    ]

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
        if let nodeIDs = validNodeIDsByCombatantID[combatantID] {
            return nodeIDs
        }
        let dynamicConfig = config(for: combatantID)
        return Set(dynamicConfig.trees.flatMap(\.nodes).map(\.id))
    }

    /// Resolves the 3-tree talent configuration for a combatant.
    public static func config(for combatantID: String) -> CombatantTalentConfig {
        if let cached = allConfigs[combatantID] {
            return cached
        }
        let affinities = combatantTreeAffinities[combatantID] ?? fallbackAffinities
        let trees = affinities.map { makeTree(combatantID: combatantID, name: $0.name, keyword: $0.keyword) }
        return CombatantTalentConfig(combatantID: combatantID, trees: trees)
    }

    /// Resolves the signature talent effect for a specific node ID, if authored.
    public static func effect(for nodeID: String) -> CombatantTalentEffect? {
        signatureTalents[nodeID]
    }

    /// Resolves modifiers for a set of unlocked talent nodes.
    public static func modifiers(for unlockedNodeIDs: Set<String>) -> [AffixModifier] {
        guard !unlockedNodeIDs.isEmpty else { return [] }
        return unlockedNodeIDs.flatMap { signatureTalents[$0]?.modifiers ?? [] }
    }

    /// Resolves triggers for a set of unlocked talent nodes.
    public static func triggers(for unlockedNodeIDs: Set<String>) -> CombatTraitTriggers {
        guard !unlockedNodeIDs.isEmpty else { return CombatTraitTriggers() }
        if unlockedNodeIDs.count == 1,
           let firstID = unlockedNodeIDs.first,
           let effect = signatureTalents[firstID] {
            return effect.triggers
        }
        var combined = CombatTraitTriggers()
        for nodeID in unlockedNodeIDs.sorted() {
            if let effect = signatureTalents[nodeID] {
                combined.merge(effect.triggers)
            }
        }
        return combined
    }

    /// Generates a standardized 2x3 tree for a keyword affinity (6 nodes total), inserting signature talents when defined.
    private static func makeTree(combatantID: String, name: String, keyword: Keyword) -> TalentTree {
        let symbol = defaultSymbolName(for: keyword)
        let kwName = keyword.rawValue
        var nodes = [TalentNode]()
        nodes.reserveCapacity(6)

        let kwSlug = keyword.rawValue.lowercased().filter { $0.isLetter || $0.isNumber }
        for row in 1 ... 3 {
            for col in 1 ... 2 {
                let nodeID = "\(combatantID)_\(kwSlug)_r\(row)_\(col)"
                let legacyID = "\(combatantID)_\(kwSlug)_t\(row)_\(col)"
                let signature = signatureTalents[nodeID] ?? signatureTalents[legacyID]
                let effectiveID = signatureTalents[nodeID] != nil ? nodeID : (signatureTalents[legacyID] != nil ? legacyID : nodeID)

                if let signature {
                    nodes.append(
                        TalentNode(
                            id: effectiveID,
                            name: signature.name,
                            keyword: keyword,
                            symbolName: symbol,
                            row: row,
                            description: signature.description
                        )
                    )
                } else {
                    let rowName = row == 1 ? "Foundation" : (row == 2 ? "Focus" : "Specialization")
                    let nodeName = "\(name) \(rowName) \(col)"
                    let description = "Row \(row) \(name) (\(kwName)) synergy node \(col). Augments \(kwName.lowercased()) effects in combat."
                    nodes.append(
                        TalentNode(
                            id: effectiveID,
                            name: nodeName,
                            keyword: keyword,
                            symbolName: symbol,
                            row: row,
                            description: description
                        )
                    )
                }
            }
        }

        return TalentTree(name: name, keyword: keyword, nodes: nodes)
    }
}
