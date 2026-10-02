import TrinketContent
import TrinketCore

/// Mode-specific loot identity and bonuses. The resolver receives the captured
/// encounter level separately; requests do not derive a competing quality level.
public struct LootRequest: Equatable, Sendable {
    public var seedSalt: String
    public var itemID: String
    public var keywordBias: Set<Keyword>
    public var goldFoundPercent: Int
    public var materialsFoundPercent: Int
    public var rewardModifier: RewardModifier?
    public var additionalRewardModifier: RewardModifier?

    public init(
        seedSalt: String,
        itemID: String,
        keywordBias: Set<Keyword> = [],
        goldFoundPercent: Int = 0,
        materialsFoundPercent: Int = 0,
        rewardModifier: RewardModifier? = nil,
        additionalRewardModifier: RewardModifier? = nil,
    ) {
        self.seedSalt = seedSalt
        self.itemID = itemID
        self.keywordBias = keywordBias
        self.goldFoundPercent = goldFoundPercent
        self.materialsFoundPercent = materialsFoundPercent
        self.rewardModifier = rewardModifier
        self.additionalRewardModifier = additionalRewardModifier
    }
}

public struct RewardOwnership: Equatable, Sendable {
    public var eligibleModifiers: [RewardModifier] {
        RewardModifier.eligible(ownedTrinketIDs: ownedTrinketIDs, ownedUniqueIDs: ownedUniqueIDs)
    }

    public func modifiers(ids: [NodeModifierID]) -> [NodeModifierDefinition] {
        NodeModifierCatalog.modifiers(ids: ids, eligibleRewards: eligibleModifiers)
    }

    public var ownedTrinketIDs: Set<String>
    public var ownedUniqueIDs: Set<String>

    public init(ownedTrinketIDs: Set<String> = [], ownedUniqueIDs: Set<String> = []) {
        self.ownedTrinketIDs = ownedTrinketIDs
        self.ownedUniqueIDs = ownedUniqueIDs
    }

    public init(_ inventory: PlayerInventoryState) {
        self.init(ownedTrinketIDs: inventory.ownedTrinketIDs, ownedUniqueIDs: inventory.ownedUniqueIDs)
    }

    public init(_ save: PlayerSave) {
        self.init(save.inventory)
    }
}

public extension LootRequest {
    static func journey(stage: Stage) -> LootRequest {
        LootRequest(
            seedSalt: "battle-loot-journey-\(stage.id)",
            itemID: "\(stage.id)-loot",
        )
    }

    static func spire(floor: SpireFloor, rewardModifier: RewardModifier? = nil) -> LootRequest {
        var keywordBias: Set<Keyword> = []
        if let spire = GameContent.spire(id: floor.spireID) {
            keywordBias.insert(spire.keyword)
        }
        return LootRequest(
            seedSalt: "battle-loot-spire-\(floor.spireID.rawValue)-\(floor.floor)",
            itemID: "spire-\(floor.spireID.rawValue)-floor-\(floor.floor)-loot",
            keywordBias: keywordBias,
            rewardModifier: rewardModifier,
        )
    }

    static func labyrinth(node: LabyrinthNode, effects: NodeModifierEffects) -> LootRequest {
        LootRequest(
            seedSalt: "battle-loot-labyrinth-\(node.id)",
            itemID: LabyrinthCompletion.rewardItemID(forNodeID: node.id),
            goldFoundPercent: effects.goldFoundPercent - (effects.rewardModifier?.goldBonusPercent ?? 0),
            materialsFoundPercent: effects.materialsFoundPercent - (effects.rewardModifier?.materialsBonusPercent ?? 0),
            rewardModifier: effects.rewardModifier,
        )
    }

    static func voyage(
        node: VoyageNode, effects: NodeModifierEffects,
        additionalRewardModifier: RewardModifier? = nil,
    ) -> LootRequest {
        LootRequest(
            seedSalt: node.id, itemID: "voyage-\(node.id)",
            goldFoundPercent: effects.goldFoundPercent - (effects.rewardModifier?.goldBonusPercent ?? 0),
            materialsFoundPercent: effects.materialsFoundPercent - (effects.rewardModifier?.materialsBonusPercent ?? 0),
            rewardModifier: effects.rewardModifier,
            additionalRewardModifier: additionalRewardModifier,
        )
    }

    static func contract(
        offerID: String, modifier: RewardModifier = .gold,
    ) -> LootRequest {
        LootRequest(
            seedSalt: "battle-loot-contract-\(offerID)",
            itemID: "contract-\(offerID)-loot",
            rewardModifier: modifier,
        )
    }
}
