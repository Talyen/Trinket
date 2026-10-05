import TrinketContent

/// Display projection of a launch. The supplied plan supports provisional reveals;
/// application settlement and Retry use the authoritative run record instead.
public struct BattlePresentationContext: Sendable {
    public let inventoryItems: [InventoryItem]
    public let rewardPlan: BattleRewardPlan
    public let rewardInputs: RewardSettlementInputs?
    public let stageRewardsAlreadyClaimed: Bool
    public let hasProgressionRewards: Bool
    public let musicStageID: String?
    public let nodeModifiers: [NodeModifierDefinition]

    public init(
        inventoryItems: [InventoryItem],
        rewardPlan: BattleRewardPlan,
        stageRewardsAlreadyClaimed: Bool,
        hasProgressionRewards: Bool,
        musicStageID: String?,
        nodeModifiers: [NodeModifierDefinition] = [],
        rewardInputs: RewardSettlementInputs? = nil,
    ) {
        self.inventoryItems = inventoryItems
        self.rewardPlan = rewardPlan
        self.rewardInputs = rewardInputs
        self.stageRewardsAlreadyClaimed = stageRewardsAlreadyClaimed
        self.hasProgressionRewards = hasProgressionRewards
        self.musicStageID = musicStageID
        self.nodeModifiers = nodeModifiers
    }

    public static let empty = Self(
        inventoryItems: [],
        rewardPlan: BattleRewardPlan(
            stageGold: 0, goldFindPercent: 0, heroExperience: 0,
            companionExperience: 0, materials: [], items: [],
        ),
        stageRewardsAlreadyClaimed: false,
        hasProgressionRewards: false,
        musicStageID: nil,
    )
}
