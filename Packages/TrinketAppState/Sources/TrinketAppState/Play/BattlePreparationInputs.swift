import TrinketContent
import TrinketCore
import TrinketPersistence

struct PlayBattlePartySnapshot: Equatable {
    let roster: PlayerRosterState
    let inventory: PlayerInventoryState
    let homestead: PlayerHomesteadState
    let worldSeed: UInt64
    let sessionGeneration: UInt64
}

extension PlayBattlePartySnapshot {
    @MainActor
    init(playerSave: PlayerSaveStore) {
        roster = playerSave.roster
        inventory = playerSave.inventory
        homestead = playerSave.homestead
        worldSeed = playerSave.worldSeed
        sessionGeneration = playerSave.sessionGeneration
    }
}

struct BattlePreparationInputs: Equatable {
    let launch: BattleLaunchInput
    let party: PlayBattlePartySnapshot
    let rngSeed: UInt64
}

struct BattleLaunchInput: Equatable {
    let completionBonus: VoyageCompletionBonus?
    let origin: PlayBattleOrigin?
    var hero: Combatant
    var companion: Combatant
    let encounter: ScaledEncounter?
    let stageReward: StageReward?
    let experienceBonusPercent: Int
    let victoryOnlyExperienceBonusPercent: Int
    let pendingRewardItem: InventoryItem?
    let additionalRewardItems: [InventoryItem]
    let stageRewardsAlreadyClaimed: Bool
    let universalModifiers: [AffixModifier]
    let nodeModifiers: [NodeModifierDefinition]

    init(
        origin: PlayBattleOrigin? = nil,
        hero: Combatant,
        companion: Combatant,
        encounter: ScaledEncounter? = nil,
        stageReward: StageReward? = nil,
        experienceBonusPercent: Int = 0,
        victoryOnlyExperienceBonusPercent: Int = 0,
        pendingRewardItem: InventoryItem? = nil,
        additionalRewardItems: [InventoryItem] = [],
        stageRewardsAlreadyClaimed: Bool = false,
        universalModifiers: [AffixModifier] = [],
        nodeModifiers: [NodeModifierDefinition] = [],
        completionBonus: VoyageCompletionBonus? = nil,
    ) {
        self.completionBonus = completionBonus
        self.origin = origin
        self.hero = hero
        self.companion = companion
        self.encounter = encounter
        self.stageReward = stageReward
        self.experienceBonusPercent = experienceBonusPercent
        self.victoryOnlyExperienceBonusPercent = victoryOnlyExperienceBonusPercent
        self.pendingRewardItem = pendingRewardItem
        self.additionalRewardItems = additionalRewardItems
        self.stageRewardsAlreadyClaimed = stageRewardsAlreadyClaimed
        self.universalModifiers = universalModifiers
        self.nodeModifiers = nodeModifiers
    }
}
