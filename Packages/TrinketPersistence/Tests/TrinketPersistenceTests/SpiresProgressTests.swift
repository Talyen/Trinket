import Testing
import TrinketContent
import TrinketCore
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
}
