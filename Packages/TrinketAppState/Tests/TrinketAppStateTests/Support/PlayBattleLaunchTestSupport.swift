import BattleEngine
import Testing
import TrinketBattleFeature
import TrinketContent
import TrinketCore
import TrinketFeatureSupport
import TrinketPersistence
import TrinketTestSupport
@testable import TrinketAppState

@MainActor
enum PlayBattleLaunchTestSupport {
    /// First stage of the first campaign chapter. Prefer this over indexing
    /// `GameContent.chapters[0].stages.first` so content-order assumptions live
    /// in one place.
    static func firstJourneyStage() throws -> Stage {
        try #require(GameContent.chapters.first?.stages.first)
    }

    /// Unlocks and activates a hero + companion pair.
    /// Levels default to nil (leave progression untouched); pass explicit
    /// levels for difficulty/award math tests (e.g. contracts).
    static func setActiveParty(
        heroID: String,
        companionID: String,
        heroLevel: Int? = nil,
        companionLevel: Int? = nil,
        in state: PlaySession,
    ) throws {
        var roster = state.playerSave.roster
        let hero = try #require(GameContent.heroes.first { $0.id == heroID })
        let companion = try #require(GameContent.companions.first { $0.id == companionID })
        roster.unlock(hero)
        roster.unlock(companion)
        roster.setActiveHero(hero)
        roster.setActiveCompanion(companion)
        if let heroLevel {
            roster.progressions[roster.activeHeroID] = .at(level: heroLevel)
        }
        if let companionLevel {
            roster.progressions[roster.activeCompanionID] = .at(level: companionLevel)
        }
        #expect(state.playerSave.persistBatch(logging: "Test setup") { $0.roster = roster })
    }

    static func setActiveCompanion(_ companion: Combatant, in state: PlaySession) {
        var roster = state.playerSave.roster
        _ = roster.unlock(companion)
        roster.setActiveCompanion(companion)
        #expect(state.playerSave.persistBatch(logging: "Test setup") { $0.roster = roster })
    }

    static func make(
        origin: PlayBattleOrigin? = nil,
        runKey: BattleRunKey? = nil,
        rngSeed: UInt64 = CombatantFixtures.deterministicBattleSeed,
        hero: Combatant,
        companion: Combatant,
        enemy: Combatant? = nil,
        enemyEncounterLevel: Int? = nil,
        roster: PlayerRosterState = .testSeed,
        inventory: PlayerInventoryState = .testSeed,
        homestead: PlayerHomesteadState = .freshStart,
        stageReward: StageReward? = nil,
        experienceBonusPercent: Int = 0,
        pendingRewardItem: InventoryItem? = nil,
        stageRewardsAlreadyClaimed: Bool = false,
        universalModifiers: [AffixModifier] = [],
    ) -> BattleRunConfiguration {
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
                universalModifiers: universalModifiers,
            ),
            runKey: runKey ?? origin?.runKey,
            rngSeed: rngSeed,
            rosterState: roster,
            inventoryState: inventory,
            homesteadState: homestead,
            // Launches with a mode origin (or explicit run key) carry
            // progression rewards; bare launches without either do not.
            hasProgressionRewards: runKey != nil || origin != nil,
        ).configuration
    }
}
