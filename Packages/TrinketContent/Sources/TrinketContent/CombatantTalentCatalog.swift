import Foundation
import TrinketCore

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
        triggers: CombatTraitTriggers = CombatTraitTriggers(),
    ) {
        self.name = name
        self.symbolName = symbolName
        self.description = description
        self.modifiers = modifiers
        self.triggers = triggers
    }
}

public enum CombatantTalentCatalog {
    public struct TreeAffinity: Sendable, Hashable {
        public let name: String
        public let keyword: Keyword

        public init(name: String, keyword: Keyword) {
            self.name = name
            self.keyword = keyword
        }
    }

    public static let combatantTreeAffinities: [String: [TreeAffinity]] = [
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

    public static func validNodeIDs(for combatantID: String) -> Set<String> {
        validNodeIDsByCombatantID[combatantID] ?? []
    }

    public static func config(for combatantID: String) -> CombatantTalentConfig {
        guard let cached = allConfigs[combatantID] else {
            preconditionFailure("Missing talent config for \(combatantID)")
        }
        return cached
    }

    public static func configIfAvailable(for combatantID: String) -> CombatantTalentConfig? {
        guard let config = allConfigs[combatantID] else {
            #if DEBUG
            if let combatant = GameContent.combatant(matching: combatantID),
               combatant.role != .enemy {
                assertionFailure("Missing talent config for \(combatantID) (\(combatant.role.rawValue))")
            } else if GameContent.heroes.contains(where: { $0.id == combatantID })
                || GameContent.companions.contains(where: { $0.id == combatantID }) {
                assertionFailure("Missing talent config for \(combatantID)")
            }
            #endif
            return nil
        }
        return config
    }

    public static func effect(for nodeID: String) -> CombatantTalentEffect? {
        signatureTalents[nodeID]
    }

    private static func makeTree(combatantID: String, name: String, keyword: Keyword) -> TalentTree {
        var nodes = [TalentNode]()
        nodes.reserveCapacity(10)

        let kwSlug = keyword.rawValue.lowercased().filter { $0.isLetter || $0.isNumber }
        var row = 1
        while row <= 20 {
            var rowNodes: [TalentNode] = []
            for col in 1 ... 2 {
                let nodeID = "\(combatantID)_\(kwSlug)_t\(row)_\(col)"
                guard let signature = signatureTalents[nodeID] else {
                    #if DEBUG
                    if row <= 3 {
                        assertionFailure(
                            "Missing authored talent \(nodeID) for \(combatantID) \(keyword.rawValue), check ContentManifest/talents.tsv",
                        )
                    }
                    #endif
                    continue
                }
                rowNodes.append(
                    TalentNode(
                        id: nodeID,
                        name: signature.name,
                        keyword: keyword,
                        row: row,
                        symbolName: signature.symbolName.isEmpty ? nil : signature.symbolName,
                        description: signature.description,
                    ),
                )
            }
            if row <= 3 {
                precondition(rowNodes.count == 2, "Missing authored talent row \(row) for \(combatantID) \(keyword.rawValue)")
                nodes.append(contentsOf: rowNodes)
            } else {
                guard !rowNodes.isEmpty else { break }
                nodes.append(contentsOf: rowNodes)
            }
            row += 1
        }
        precondition(row <= 20, "Talent row generation exceeded safety limit for \(combatantID) \(keyword.rawValue)")

        return TalentTree(name: name, keyword: keyword, nodes: nodes)
    }
}
