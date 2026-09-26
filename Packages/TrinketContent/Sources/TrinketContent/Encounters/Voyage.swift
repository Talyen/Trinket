import Foundation
import TrinketCore

public enum VoyageDifficulty: String, CaseIterable, Codable, Sendable {
    case easy, medium, hard

    public var title: String {
        rawValue.capitalized
    }

    public var nodeCount: Int {
        switch self {
        case .easy: 8
        case .medium: 10
        case .hard: 12
        }
    }

    public var levelOffset: Int {
        switch self {
        case .easy: -3
        case .medium: 0
        case .hard: 3
        }
    }

    public func encounterLevel(partyLevel: Int) -> Int {
        max(1, partyLevel + levelOffset)
    }
}

public struct VoyageOffer: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let chapterID: String
    public let difficulty: VoyageDifficulty
    public let seed: UInt64
    public let rewardModifier: RewardModifier

    public init(id: String, chapterID: String, difficulty: VoyageDifficulty, seed: UInt64, rewardModifier: RewardModifier = .gold) {
        self.id = id
        self.chapterID = chapterID
        self.difficulty = difficulty
        self.seed = seed
        self.rewardModifier = rewardModifier
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        chapterID = try values.decode(String.self, forKey: .chapterID)
        difficulty = try values.decode(VoyageDifficulty.self, forKey: .difficulty)
        seed = try values.decode(UInt64.self, forKey: .seed)
        rewardModifier = try values.decodeIfPresent(RewardModifier.self, forKey: .rewardModifier) ?? .gold
    }
}

public struct VoyageNode: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public var type: LabyrinthNodeType
    public let enemyID: String?
    public var modifierIDs: [NodeModifierID]
    public var recruitEventID: String?
    public var mysteryEventID: String?
    public var mysteryOffersPayload: Data?
    public var shopPayload: Data?
    public var isCleared = false

    public init(id: String, type: LabyrinthNodeType, enemyID: String?, modifierIDs: [NodeModifierID], recruitEventID: String?) {
        self.id = id
        self.type = type
        self.enemyID = enemyID
        self.modifierIDs = modifierIDs
        self.recruitEventID = recruitEventID
    }

    public var effects: NodeModifierEffects {
        .combining(NodeModifierCatalog.modifiers(ids: modifierIDs))
    }
}

public enum VoyageCatalog {
    public static func enemyIDs(chapterID: String) -> [String] {
        switch chapterID {
        case "chapter-1": ["slime", "mud_elemental", "goblin", "will_o_wisp"]
        case "chapter-2": ["skeleton", "mimic", "necromancer", "living_armor"]
        case "chapter-3": ["fire_elemental", "fire_imp", "hellhound", "pyromancer"]
        case "chapter-4": ["frost_elemental", "winter_wolf", "ice_wraith", "yeti"]
        default: []
        }
    }

    public static func bossID(chapterID: String) -> String? {
        switch chapterID {
        case "chapter-1": "the_blight_treant"
        case "chapter-2": "the_iron_bear"
        case "chapter-3": "the_forge_golem"
        case "chapter-4": "the_frostwarden"
        default: nil
        }
    }

    public static func modifiers(type: LabyrinthNodeType, enemyID: String?) -> [NodeModifierDefinition] {
        if type.isCombat, let enemyID {
            return NodeModifierCatalog.combatModifiers(for: enemyID, nodeType: type)
        }
        return NodeModifierCatalog.modifiers.filter { $0.applies(to: type) }
    }
}

public enum VoyageGenerator {
    public static func nodes(
        for offer: VoyageOffer, eligibleRecruitEventIDs: [String], eligibleRewards: [RewardModifier] = RewardModifier.allCases,
    ) -> [VoyageNode] {
        var rng = SeededRandomNumberGenerator(seed: offer.seed)
        let battles = switch offer.difficulty {
        case .easy: 3
        case .medium: 4
        case .hard: 5
        }
        let shops = offer.difficulty == .hard ? 2 : 1
        let mysteries = offer.difficulty == .easy ? 2 : 3
        var remaining: [LabyrinthNodeType: Int] = [.battle: battles - 1, .shop: shops, .mystery: mysteries, .recruit: 1]
        if eligibleRecruitEventIDs.isEmpty {
            remaining[.recruit] = 0
            remaining[.mystery, default: 0] += 1
        }
        // Finite backtracking over at most ten middle slots; no unbounded reroll loop.
        guard let middle = arrange(remaining, prefix: [.battle], using: &rng) else {
            preconditionFailure("Voyage encounter counts must admit a valid route")
        }
        let types: [LabyrinthNodeType] = [.battle] + middle + [.boss]
        var bag: [String] = []
        var previousEnemy: String?
        var previousModifier: NodeModifierID?
        return types.enumerated().map { index, type in
            let enemyID: String?
            if type == .battle {
                if bag.isEmpty {
                    bag = VoyageCatalog.enemyIDs(chapterID: offer.chapterID).shuffled(using: &rng)
                    if bag.last == previousEnemy, bag.count > 1 {
                        bag.swapAt(0, bag.count - 1)
                    }
                }
                enemyID = bag.popLast()
                previousEnemy = enemyID
            } else {
                enemyID = type == .boss ? VoyageCatalog.bossID(chapterID: offer.chapterID) : nil
            }
            let modifier = NodeModifierCatalog.pickModifier(
                for: type, enemyID: enemyID, eligibleRewards: eligibleRewards, excluding: previousModifier, using: &rng,
            )
            previousModifier = modifier
            return VoyageNode(
                id: "\(offer.id)-node-\(index + 1)", type: type, enemyID: enemyID,
                modifierIDs: modifier.map { [$0] } ?? [],
                recruitEventID: type == .recruit ? eligibleRecruitEventIDs.sorted().randomElement(using: &rng) : nil,
            )
        }
    }

    private static func arrange(
        _ remaining: [LabyrinthNodeType: Int], prefix: [LabyrinthNodeType], using rng: inout some RandomNumberGenerator,
    ) -> [LabyrinthNodeType]? {
        if remaining.values.allSatisfy({ $0 == 0 }) {
            return []
        }
        let choices = LabyrinthNodeType.allCases.filter { remaining[$0, default: 0] > 0 }.shuffled(using: &rng)
        for type in choices {
            if type == .battle {
                if prefix.suffix(2).count == 2, prefix.suffix(2).allSatisfy({ $0 == .battle }) {
                    continue
                }
            } else if prefix.last == type {
                continue
            }
            var next = remaining
            next[type, default: 0] -= 1
            if let tail = arrange(next, prefix: prefix + [type], using: &rng) {
                return [type] + tail
            }
        }
        return nil
    }
}
