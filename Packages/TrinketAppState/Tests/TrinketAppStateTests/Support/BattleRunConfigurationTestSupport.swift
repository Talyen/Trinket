import TrinketBattleFeature
import TrinketBattleRuntime
import TrinketContent
import TrinketCore
import TrinketFeatureSupport
import TrinketPersistence
@testable import TrinketAppState

@MainActor
enum BattleRunConfigurationTestSupport {
    static func make(
        origin: PlayBattleOrigin? = nil,
        runKey: BattleRunKey? = nil,
        rngSeed: UInt64 = 0,
        hero: Combatant,
        companion: Combatant,
        enemy: Combatant? = nil,
        enemyEncounterLevel: Int? = nil,
        roster: PlayerRosterState = .initial,
        inventory: PlayerInventoryState = .initial,
        homestead: PlayerHomesteadState = .freshStart,
        stageReward: StageReward? = nil,
        experienceBonusPercent: Int = 0,
        pendingRewardItem: InventoryItem? = nil,
        stageRewardsAlreadyClaimed: Bool = false,
        universalModifiers: [AffixModifier] = []
    ) throws -> BattleRunConfiguration {
        PlayBattleLaunch.assembleLaunch(
            runKey: runKey ?? origin?.runKey,
            rngSeed: rngSeed,
            hero: hero,
            companion: companion,
            rosterState: roster,
            inventoryState: inventory,
            homesteadState: homestead,
            enemy: enemy,
            enemyEncounterLevel: enemyEncounterLevel,
            stageReward: stageReward,
            experienceBonusPercent: experienceBonusPercent,
            pendingRewardItem: pendingRewardItem,
            stageRewardsAlreadyClaimed: stageRewardsAlreadyClaimed,
            universalModifiers: universalModifiers,
            defeatPrimaryAction: origin?.defeatPrimaryAction ?? .restart,
            hasProgressionRewards: runKey != nil || origin != nil,
            musicStageID: origin?.musicStageID
        ).configuration
    }
}
