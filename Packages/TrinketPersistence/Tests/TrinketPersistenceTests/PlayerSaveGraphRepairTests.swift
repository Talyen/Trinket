import Testing
@testable import TrinketPersistence

struct PlayerSaveGraphRepairTests {
    @Test func `canonical graph needs no bootstrap repair`() {
        let save = PlayerSave.testSeed
        let root = PlayerSaveRoot(save: save)

        #expect(root.repairSlices(for: save).isEmpty)
    }

    @Test func `missing top level model repairs only its slice`() {
        let save = PlayerSave.fresh
        let root = PlayerSaveRoot(save: save)
        root.inventory = nil

        #expect(root.repairSlices(for: save) == .inventory)
    }

    @Test func `duplicate child rows request owning slice repair`() throws {
        var save = PlayerSave.fresh
        save.journey.completedStageIDs.insert("chapter-1-stage-1")
        let root = PlayerSaveRoot(save: save)
        let stage = try #require(root.journey?.stages?.first)
        root.journey?.stages?.append(
            JourneyStageProgressModel(
                stageID: stage.stageID,
                isCompleted: stage.isCompleted,
                rewardsClaimed: stage.rewardsClaimed,
                mysteryEventID: stage.mysteryEventID,
            ),
        )

        #expect(root.repairSlices(for: save).contains(.journey))
    }
}
