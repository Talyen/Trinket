import Testing
import TrinketBattleFeature
import TrinketBattleRuntime
import TrinketContent
import TrinketCore
import TrinketFeatureSupport
import TrinketPersistence
import TrinketTestSupport
@testable import TrinketAppState

@MainActor
enum PlayBattleLaunchTestSupport {
    static func setActiveParty(
        heroID: String,
        companionID: String,
        in state: PlaySession
    ) throws {
        var roster = state.playerSave.roster
        let hero = try #require(GameContent.heroes.first { $0.id == heroID })
        let companion = try #require(GameContent.companions.first { $0.id == companionID })
        roster.unlock(hero)
        roster.unlock(companion)
        roster.setActiveHero(hero)
        roster.setActiveCompanion(companion)
        state.playerSave.roster = roster
    }

    static func make(
        origin: PlayBattleOrigin? = nil,
        runKey: BattleRunKey? = nil,
        rngSeed: UInt64 = CombatantFixtures.deterministicBattleSeed,
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
            input: BattleLaunchInput(
                origin: origin,
                hero: hero,
                companion: companion,
                enemy: enemy,
                enemyEncounterLevel: enemyEncounterLevel,
                stageReward: stageReward,
                experienceBonusPercent: experienceBonusPercent,
                pendingRewardItem: pendingRewardItem,
                stageRewardsAlreadyClaimed: stageRewardsAlreadyClaimed,
                universalModifiers: universalModifiers
            ),
            runKey: runKey ?? origin?.runKey,
            rngSeed: rngSeed,
            rosterState: roster,
            inventoryState: inventory,
            homesteadState: homestead,
            defeatPrimaryAction: origin?.defeatPrimaryAction ?? .restart,
            hasProgressionRewards: runKey != nil || origin != nil,
            musicStageID: origin?.musicStageID
        ).configuration
    }
}
