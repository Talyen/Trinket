import TrinketContent
import TrinketCore

public struct BattlePresentationContext: Sendable {
    public let completionBonus: VoyageCompletionBonus?
    public let inventoryItems: [InventoryItem]
    public let stageReward: StageReward?
    public let rewardItems: [InventoryItem]
    public let pendingRewardItem: InventoryItem?
    public let experienceBonusPercent: Int
    public let goldFindPercent: Int
    public let goldFindFlat: Int
    public let gemsFindBonus: Int
    public let goldOverflowExperience: Int
    public let rewardInputs: RewardSettlementInputs?
    public let stageRewardsAlreadyClaimed: Bool
    public let hasProgressionRewards: Bool
    public let musicStageID: String?
    public let heroExperienceAward: Int
    public let companionExperienceAward: Int
    public let materialRewards: [ResourceAmount]
    public let labyrinthModifiers: [LabyrinthModifierDefinition]

    public var rewardPlan: BattleRewardPlan {
        BattleRewardPlan(
            stageGold: stageRewardsAlreadyClaimed ? 0 : stageReward?.gold ?? 0,
            goldFindPercent: goldFindPercent,
            goldFindFlat: goldFindFlat,
            gemsFindBonus: gemsFindBonus,
            goldOverflowExperience: goldOverflowExperience,
            heroExperience: stageRewardsAlreadyClaimed ? 0 : heroExperienceAward,
            companionExperience: stageRewardsAlreadyClaimed ? 0 : companionExperienceAward,
            materials: stageRewardsAlreadyClaimed ? [] : materialRewards,
            items: stageRewardsAlreadyClaimed ? [] : rewardItems,
            completionBonus: stageRewardsAlreadyClaimed ? nil : completionBonus,
        )
    }

    public init(
        inventoryItems: [InventoryItem],
        stageReward: StageReward?,
        rewardItems: [InventoryItem],
        pendingRewardItem: InventoryItem?,
        experienceBonusPercent: Int,
        goldFindPercent: Int,
        goldFindFlat: Int = 0,
        gemsFindBonus: Int = 0,
        stageRewardsAlreadyClaimed: Bool,
        hasProgressionRewards: Bool,
        musicStageID: String?,
        heroExperienceAward: Int,
        companionExperienceAward: Int,
        materialRewards: [ResourceAmount],
        labyrinthModifiers: [LabyrinthModifierDefinition] = [],
        goldOverflowExperience: Int = 0,
        rewardInputs: RewardSettlementInputs? = nil,
        completionBonus: VoyageCompletionBonus? = nil,
    ) {
        self.completionBonus = completionBonus
        self.inventoryItems = inventoryItems
        self.stageReward = stageReward
        self.rewardItems = rewardItems
        self.pendingRewardItem = pendingRewardItem
        self.experienceBonusPercent = experienceBonusPercent
        self.goldFindPercent = goldFindPercent
        self.goldFindFlat = goldFindFlat
        self.gemsFindBonus = gemsFindBonus
        self.goldOverflowExperience = goldOverflowExperience
        self.rewardInputs = rewardInputs
        self.stageRewardsAlreadyClaimed = stageRewardsAlreadyClaimed
        self.hasProgressionRewards = hasProgressionRewards
        self.musicStageID = musicStageID
        self.heroExperienceAward = heroExperienceAward
        self.companionExperienceAward = companionExperienceAward
        self.materialRewards = materialRewards
        self.labyrinthModifiers = labyrinthModifiers
    }

    public static let empty = Self(
        inventoryItems: [],
        stageReward: nil,
        rewardItems: [],
        pendingRewardItem: nil,
        experienceBonusPercent: 0,
        goldFindPercent: 0,
        stageRewardsAlreadyClaimed: false,
        hasProgressionRewards: false,
        musicStageID: nil,
        heroExperienceAward: 0,
        companionExperienceAward: 0,
        materialRewards: [],
        labyrinthModifiers: [],
    )
}
