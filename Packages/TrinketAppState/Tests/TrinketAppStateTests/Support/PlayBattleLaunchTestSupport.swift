import BattleEngine
import Testing
import TrinketBattleFeature
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
import TrinketFeatureSupport
@testable import TrinketAppState
@testable import TrinketPersistence

@MainActor
enum PlayBattleLaunchTestSupport {
    static func assemble(
        input: BattleLaunchInput,
        rngSeed: UInt64,
        rosterState: PlayerRosterState,
        inventoryState: PlayerInventoryState,
        homesteadState: PlayerHomesteadState = .freshStart,
        worldSeed: UInt64 = 0,
    ) -> BattleLaunchAssembly {
        PlayBattleCoordinator.assembleLaunch(BattlePreparationInputs(
            launch: input,
            party: PlayBattlePartySnapshot(roster: rosterState, inventory: inventoryState, homestead: homesteadState, worldSeed: worldSeed),
            rngSeed: rngSeed,
        ))
    }

    /// Polls `condition` (up to ~3s) until the save-retry machinery settles.
    /// Single home for the retry-settling loop previously copied across
    /// shop/mystery/victory/defeat tests.
    static func awaitSaveQuiescence(when condition: () -> Bool) async throws {
        for _ in 0 ..< 300 where condition() {
            try await Task.sleep(for: .milliseconds(10))
        }
    }

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
        assemble(
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
            rngSeed: rngSeed,
            rosterState: roster,
            inventoryState: inventory,
            homesteadState: homestead,
        ).configuration
    }
}
