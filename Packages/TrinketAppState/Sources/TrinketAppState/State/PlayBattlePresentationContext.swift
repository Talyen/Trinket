import TrinketContent
import TrinketCore
import TrinketFeatureContracts

/// Play-owned data that explains how a prepared battle is presented and resolved.
///
/// The runtime only needs `BattleRunConfiguration` to simulate combat. Reward policy,
/// defeat behavior, inventory inspection, and music remain owned by Play instead of
/// leaking into the runtime lifecycle contract.
public struct PlayBattlePresentationContext: Sendable {
    public let inventoryItems: [InventoryItem]
    public let stageReward: StageReward?
    public let rewardItems: [InventoryItem]
    public let pendingRewardItem: InventoryItem?
    public let experienceBonusPercent: Int
    public let goldFindPercent: Int
    public let stageRewardsAlreadyClaimed: Bool
    public let universalModifiers: [AffixModifier]
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
        universalModifiers: [AffixModifier],
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
        self.universalModifiers = universalModifiers
        self.defeatPrimaryAction = defeatPrimaryAction
        self.hasProgressionRewards = hasProgressionRewards
        self.musicStageID = musicStageID
        self.heroExperienceAward = heroExperienceAward
        self.companionExperienceAward = companionExperienceAward
        self.materialRewards = materialRewards
    }
}
