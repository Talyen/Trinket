import Foundation
import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

struct StageRewardClaimFallbackTests {
    enum ClaimFallbackMode: String, Sendable {
        case journey
        case spire
    }

    @Test(arguments: [ClaimFallbackMode.journey, .spire])
    func claimFallbackUsesPartyAdjustedEncounterLevel(mode: ClaimFallbackMode) throws {
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let companion = try #require(GameContent.companions.first { $0.id == "wolf" })

        var pinned = SaveTestSupport.makeSave()
        pinned.roster.progressions[hero.id] = .at(level: 3)
        pinned.roster.progressions[companion.id] = .at(level: 2)
        let level = try expectedLevel(mode: mode, in: pinned)
        try complete(
            mode: mode,
            hero: hero,
            companion: companion,
            save: &pinned,
            enemyEncounterLevel: level
        )
        let pinnedXP = pinned.roster.progression(for: hero).currentXP

        var fallback = SaveTestSupport.makeSave()
        fallback.roster.progressions[hero.id] = .at(level: 3)
        fallback.roster.progressions[companion.id] = .at(level: 2)
        try complete(
            mode: mode,
            hero: hero,
            companion: companion,
            save: &fallback,
            enemyEncounterLevel: nil
        )

        try assertModeExpectations(mode: mode, level: level)
        #expect(fallback.roster.progression(for: hero).currentXP == pinnedXP)
    }

    private func complete(
        mode: ClaimFallbackMode,
        hero: Combatant,
        companion: Combatant,
        save: inout PlayerSave,
        enemyEncounterLevel: Int?
    ) throws {
        switch mode {
        case .journey:
            let deepStage = try deepJourneyStage()
            StageCompletion.complete(
                deepStage,
                hero: hero,
                companion: companion,
                enemyEncounterLevel: enemyEncounterLevel,
                in: GameContent.chapters,
                save: &save
            )
        case .spire:
            let spire = try #require(GameContent.spire(id: .ironVein))
            let topFloor = try #require(
                GameContent.spireFloor(spireID: .ironVein, floor: spire.floorCount)
            )
            for floor in 1 ..< spire.floorCount {
                _ = save.spires.markFloorCleared(floor, spireID: SpireID.ironVein.rawValue)
            }
            SpireCompletion.complete(
                floor: topFloor,
                hero: hero,
                companion: companion,
                enemyEncounterLevel: enemyEncounterLevel,
                save: &save
            )
        }
    }

    private func expectedLevel(mode: ClaimFallbackMode, in save: PlayerSave) throws -> Int {
        switch mode {
        case .journey:
            let deepStage = try deepJourneyStage()
            return StageCompletion.partyAdjustedEncounterLevel(for: deepStage, save: save)
        case .spire:
            let topFloor = try ironVeinTopFloor()
            return EncounterLevelResolver.partyAdjusted(
                EncounterLevelResolver.spireEnemyLevel(for: topFloor),
                partyAverageLevel: save.roster.activePartyAverageLevel
            )
        }
    }

    private func assertModeExpectations(mode: ClaimFallbackMode, level: Int) throws {
        switch mode {
        case .journey:
            #expect(level == 5)
        case .spire:
            let topFloor = try ironVeinTopFloor()
            #expect(level < EncounterLevelResolver.spireEnemyLevel(for: topFloor))
        }
    }

    private func deepJourneyStage() throws -> Stage {
        try #require(
            GameContent.chapters.flatMap(\.stages).last(where: {
                $0.encounter.isCombat
                    && StageCompletion.resolvedEncounterLevel(for: $0, in: GameContent.chapters) > 5
            })
        )
    }

    private func ironVeinTopFloor() throws -> SpireFloor {
        let spire = try #require(GameContent.spire(id: .ironVein))
        return try #require(GameContent.spireFloor(spireID: .ironVein, floor: spire.floorCount))
    }
}
