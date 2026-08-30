import Testing
import TrinketContent
@testable import TrinketPersistence

struct MysteryEventPickContextSaveTests {
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
