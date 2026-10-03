import TrinketContent
import TrinketCore
import TrinketPersistence

struct PlayBattlePartySnapshot: Equatable {
    let roster: PlayerRosterState
    let inventory: PlayerInventoryState
    let homestead: PlayerHomesteadState
    let worldSeed: UInt64

    init(roster: PlayerRosterState, inventory: PlayerInventoryState, homestead: PlayerHomesteadState, worldSeed: UInt64) {
        self.roster = roster
        self.inventory = inventory
        self.homestead = homestead
        self.worldSeed = worldSeed
    }

    @MainActor
    init(playerSave: PlayerSaveStore) {
        roster = playerSave.roster
        inventory = playerSave.inventory
        homestead = playerSave.homestead
        worldSeed = playerSave.worldSeed
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
    let hero: Combatant
    let companion: Combatant
    let enemy: Combatant?
    let enemyEncounterLevel: Int?
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
        enemy: Combatant? = nil,
        enemyEncounterLevel: Int? = nil,
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
        self.enemy = enemy
        self.enemyEncounterLevel = enemyEncounterLevel
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
