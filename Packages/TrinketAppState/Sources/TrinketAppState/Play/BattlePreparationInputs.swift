import TrinketContent
import TrinketCore
import TrinketPersistence

struct PlayBattlePartySnapshot: Equatable {
    let roster: PlayerRosterState
    let inventory: PlayerInventoryState
    let homestead: PlayerHomesteadState
    let worldSeed: UInt64
    let sessionGeneration: UInt64

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
    let origin: PlayBattleOrigin? = nil
    var hero: Combatant
    var companion: Combatant
    let encounter: ScaledEncounter? = nil
    let stageReward: StageReward? = nil
    let experienceBonusPercent: Int = 0
    let victoryOnlyExperienceBonusPercent: Int = 0
    let pendingRewardItem: InventoryItem? = nil
    let additionalRewardItems: [InventoryItem] = []
    let stageRewardsAlreadyClaimed: Bool = false
    let universalModifiers: [AffixModifier] = []
    let nodeModifiers: [NodeModifierDefinition] = []
    let completionBonus: VoyageCompletionBonus? = nil
}
