import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

@Suite("SpiresProgress")
struct SpiresProgressTests {
    @Test func freshStartIsUncleared() {
        let state = PlayerSpiresState.freshStart
        #expect(state.highestClearedFloor(for: SpireID.ironVein.rawValue) == 0)
        #expect(state.activeFloor(for: SpireID.ironVein.rawValue, floorCount: 10) == 1)
        #expect(state.isFloorUnlocked(1, spireID: SpireID.ironVein.rawValue, floorCount: 10))
        #expect(!state.isFloorUnlocked(2, spireID: SpireID.ironVein.rawValue, floorCount: 10))
        #expect(state.isFloorStartable(1, spireID: SpireID.ironVein.rawValue))
        #expect(!state.isFloorStartable(2, spireID: SpireID.ironVein.rawValue))
    }

    @Test func sequentialClearsAdvanceActiveFloor() {
        var state = PlayerSpiresState.freshStart
        let clearedFirst = state.markFloorCleared(1, spireID: SpireID.ironVein.rawValue)
        #expect(clearedFirst)
        #expect(state.highestClearedFloor(for: SpireID.ironVein.rawValue) == 1)
        #expect(state.activeFloor(for: SpireID.ironVein.rawValue, floorCount: 10) == 2)
        #expect(state.isFloorCleared(1, spireID: SpireID.ironVein.rawValue))
        #expect(!state.isFloorStartable(1, spireID: SpireID.ironVein.rawValue))
        #expect(state.isFloorStartable(2, spireID: SpireID.ironVein.rawValue))

        let reclearFirst = state.markFloorCleared(1, spireID: SpireID.ironVein.rawValue)
        #expect(!reclearFirst)
        let skipToThird = state.markFloorCleared(3, spireID: SpireID.ironVein.rawValue)
        #expect(!skipToThird)
        #expect(state.highestClearedFloor(for: SpireID.ironVein.rawValue) == 1)
    }

    @Test func unlockAllSetsAllFloorCounts() {
        var state = PlayerSpiresState.freshStart
        state.unlockAll()
        for spire in GameContent.spires {
            #expect(state.highestClearedFloor(for: spire.id.rawValue) == spire.floorCount)
            #expect(state.isFloorCleared(spire.floorCount, spireID: spire.id.rawValue))
        }
    }

    @Test func completionHonorsOverriddenEncounterLevelForExperience() throws {
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
                save: &attempt
            )
            return attempt.roster.progression(for: hero).currentXP - before.currentXP
        }

        let authored = grantedHeroXP(enemyEncounterLevel: nil)
        let scaled = grantedHeroXP(enemyEncounterLevel: authoredLevel - 7)

        #expect(authored > 0)
        #expect(scaled > 0)
        #expect(scaled < authored)
    }
}
