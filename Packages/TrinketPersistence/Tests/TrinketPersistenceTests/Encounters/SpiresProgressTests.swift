import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

@Suite("SpiresProgress")
struct SpiresProgressTests {
    @Test func `sequential spire clears reject skips repeats and floors above the tower`() {
        var state = PlayerSpiresState.freshStart
        let spireID = SpireID.ironVein.rawValue
        let floorCount = 3
        for floor in 1 ... floorCount {
            #expect(state.highestClearedFloor(for: spireID) == floor - 1)
            #expect(state.activeFloor(for: spireID, floorCount: floorCount) == floor)
            #expect(state.isFloorStartable(floor, spireID: spireID, floorCount: floorCount))
            #expect(!state.isFloorStartable(floor + 1, spireID: spireID, floorCount: floorCount))
            let skipped = state.markFloorCleared(floor + 1, spireID: spireID)
            #expect(!skipped)
            let cleared = state.markFloorCleared(floor, spireID: spireID)
            #expect(cleared)
            #expect(state.isFloorCleared(floor, spireID: spireID))
            #expect(!state.isFloorStartable(floor, spireID: spireID, floorCount: floorCount))
            let repeated = state.markFloorCleared(floor, spireID: spireID)
            #expect(!repeated)
            #expect(state.highestClearedFloor(for: spireID) == floor)
        }
        #expect(state.activeFloor(for: spireID, floorCount: floorCount) == floorCount)
        #expect(!state.isFloorStartable(floorCount + 1, spireID: spireID, floorCount: floorCount))
    }

    @Test func `completion honors overridden encounter level for experience`() throws {
        let spire = try #require(GameContent.spire(id: .ironVein))
        let topFloor = try #require(GameContent.spireFloor(spireID: .ironVein, floor: spire.floorCount))
        let authoredLevel = EncounterLevelResolver.spireEnemyLevel(for: topFloor)

        var save = SaveTestSupport.makeSave()
        for floor in 1 ..< spire.floorCount {
            _ = save.spires.markFloorCleared(floor, spireID: SpireID.ironVein.rawValue)
        }

        func grantedHeroXP(enemyEncounterLevel: Int?) -> Int {
            var attempt = save
            attempt.roster.progressions[attempt.roster.activeHeroID] = .at(level: authoredLevel)
            let hero = attempt.roster.activeHero
            let before = attempt.roster.progression(for: hero)
            SpireCompletion.complete(
                floor: topFloor,
                hero: hero,
                companion: attempt.roster.activeCompanion,
                enemyEncounterLevel: enemyEncounterLevel,
                save: &attempt,
            )
            return attempt.roster.progression(for: hero).currentXP - before.currentXP
        }

        let authored = grantedHeroXP(enemyEncounterLevel: authoredLevel)
        let scaled = grantedHeroXP(enemyEncounterLevel: authoredLevel - 7)

        #expect(authored > 0)
        #expect(scaled > 0)
        #expect(scaled < authored)
    }
}
