import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

struct MysteryEventPinTests {
    @Test func `pin journey event is idempotent`() {
        var save = SaveTestSupport.makeSave(modifiedAt: .now)
        #expect(MysteryEventPinApplier.pinJourneyEvent(
            stageID: "chapter-1-stage-5",
            eventID: "mana-berries",
            save: &save,
        ))
        #expect(save.journey.pinnedMysteryEventIDs["chapter-1-stage-5"] == "mana-berries")
        #expect(MysteryEventPinApplier.pinJourneyEvent(
            stageID: "chapter-1-stage-5",
            eventID: "other-event",
            save: &save,
        ))
        #expect(save.journey.pinnedMysteryEventIDs["chapter-1-stage-5"] == "mana-berries")
    }

    @Test func `pin labyrinth event writes missing pin and skips missing node`() {
        var save = SaveTestSupport.makeSave(modifiedAt: .now)
        #expect(!MysteryEventPinApplier.pinLabyrinthEvent(
            nodeID: "missing-node",
            eventID: "mana-berries",
            save: &save,
        ))

        var node = LabyrinthNode(
            id: "node-a",
            type: .mystery,
            depth: 2,
            clusterID: "cluster-1",
        )
        save.labyrinth.nodes[node.id] = node
        #expect(MysteryEventPinApplier.pinLabyrinthEvent(
            nodeID: node.id,
            eventID: "mana-berries",
            save: &save,
        ))
        #expect(save.labyrinth.nodes[node.id]?.mysteryEventID == "mana-berries")

        node.mysteryEventID = "mana-berries"
        save.labyrinth.nodes[node.id] = node
        #expect(MysteryEventPinApplier.pinLabyrinthEvent(
            nodeID: node.id,
            eventID: "other-event",
            save: &save,
        ))
        #expect(save.labyrinth.nodes[node.id]?.mysteryEventID == "mana-berries")
    }

    @Test func `journey gates corruption altar by chapter number`() {
        let inventory = PlayerInventoryState.testSeed
        let chapterOne = MysteryEventPickContext.journey(
            chapterNumber: 1,
            inventory: inventory,
            corruptionAltarCooldownRemaining: 0,
        )
        #expect(chapterOne.allowsCorruptionAltar == false)

        let chapterTwo = MysteryEventPickContext.journey(
            chapterNumber: 2,
            inventory: inventory,
            corruptionAltarCooldownRemaining: 0,
        )
        #expect(chapterTwo.allowsCorruptionAltar == true)
    }

    @Test func `labyrinth always allows corruption altar`() {
        let inventory = PlayerInventoryState.testSeed
        let context = MysteryEventPickContext.labyrinth(
            inventory: inventory,
            corruptionAltarCooldownRemaining: 3,
        )
        #expect(context.allowsCorruptionAltar == true)
        #expect(context.corruptionAltarCooldownRemaining == 3)
        #expect(
            context.hasEligibleCorruptTarget
                == !ItemCorruption.eligibleTargets(in: inventory).isEmpty,
        )
    }
}
