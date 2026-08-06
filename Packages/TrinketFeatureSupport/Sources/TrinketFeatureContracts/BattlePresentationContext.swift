import TrinketContent
import TrinketCore

/// Immutable Play-owned data required to render and resolve one battle.
///
/// The runtime only needs `BattleRunConfiguration` to simulate combat. This
/// contract carries the presentation and reward data across the app/feature
/// boundary without making either side depend on the other's state container.
public struct BattlePresentationContext: Sendable {
    public let inventoryItems: [InventoryItem]
    public let stageReward: StageReward?
    public let rewardItems: [InventoryItem]
    public let pendingRewardItem: InventoryItem?
    public let experienceBonusPercent: Int
    public let goldFindPercent: Int
    public let stageRewardsAlreadyClaimed: Bool
    public let defeatPrimaryAction: BattleDefeatPrimaryAction
    public let hasProgressionRewards: Bool
    public let musicStageID: String?
    public let heroExperienceAward: Int
    public let companionExperienceAward: Int
    public let materialRewards: [ResourceAmount]

    public init(
        inventoryItems: [InventoryItem],
        stageReward: StageReward?,
        rewardItems: [InventoryItem],
        pendingRewardItem: InventoryItem?,
        experienceBonusPercent: Int,
        goldFindPercent: Int,
        stageRewardsAlreadyClaimed: Bool,
        defeatPrimaryAction: BattleDefeatPrimaryAction,
        hasProgressionRewards: Bool,
        musicStageID: String?,
        heroExperienceAward: Int,
        companionExperienceAward: Int,
        materialRewards: [ResourceAmount]
    ) {
        self.inventoryItems = inventoryItems
        self.stageReward = stageReward
        self.rewardItems = rewardItems
        self.pendingRewardItem = pendingRewardItem
        self.experienceBonusPercent = experienceBonusPercent
        self.goldFindPercent = goldFindPercent
        self.stageRewardsAlreadyClaimed = stageRewardsAlreadyClaimed
        self.defeatPrimaryAction = defeatPrimaryAction
        self.hasProgressionRewards = hasProgressionRewards
        self.musicStageID = musicStageID
        self.heroExperienceAward = heroExperienceAward
        self.companionExperienceAward = companionExperienceAward
        self.materialRewards = materialRewards
    }

    public static let empty = Self(
        inventoryItems: [],
        stageReward: nil,
        rewardItems: [],
        pendingRewardItem: nil,
        experienceBonusPercent: 0,
        goldFindPercent: 0,
        stageRewardsAlreadyClaimed: false,
        defeatPrimaryAction: .restart,
        hasProgressionRewards: false,
        musicStageID: nil,
        heroExperienceAward: 0,
        companionExperienceAward: 0,
        materialRewards: []
    )
}
