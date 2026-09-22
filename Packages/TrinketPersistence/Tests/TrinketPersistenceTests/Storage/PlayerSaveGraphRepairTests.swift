import Testing
import TrinketCore
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

    @Test func `dangling roster rows request repair though values read clean`() {
        // These rows are dropped by the value read, so value-level `changed()`
        // sees a clean save: repair must detect them at the graph level.
        let save = PlayerSave.testSeed
        let root = PlayerSaveRoot(save: save)
        #expect(root.repairSlices(for: save).isEmpty)

        root.roster?.abilityLoadouts?.append(AbilityLoadoutModel(combatantID: "ghost-combatant"))
        root.roster?.unlockedCombatants?.append(UnlockedCombatantModel(combatantID: "knight", role: "ghost-role"))
        root.roster?.equipmentLoadouts?.first { $0.combatantID == "knight" }?.slots?.append(
            EquipmentSlotModel(slotID: "ghost-slot", itemID: "ghost-item"),
        )

        #expect(root.repairSlices(for: save).contains(.roster))
    }

    @Test func `dangling inventory and homestead rows request repair`() {
        let save = PlayerSave.testSeed
        let root = PlayerSaveRoot(save: save)
        #expect(root.repairSlices(for: save).isEmpty)

        let ghost = InventoryItemModel()
        ghost.id = "ghost-item"
        ghost.baseTypeID = "removed-family"
        root.inventory?.items?.append(ghost)
        #expect(root.repairSlices(for: save).contains(.inventory))

        root.inventory?.items?.removeAll { $0.id == "ghost-item" }
        let goldBalance = HomesteadResourceBalanceModel(resourceID: HomesteadResource.gold.rawValue, quantity: 5)
        root.homestead?.resources?.append(goldBalance)
        #expect(root.repairSlices(for: save).contains(.homestead))
    }

    @Test func `empty spire id and bad starter phase request repair`() {
        let save = PlayerSave.testSeed
        let root = PlayerSaveRoot(save: save)
        root.spires?.floors?.append(SpireFloorProgressModel(spireID: "", highestClearedFloor: 1))
        #expect(root.repairSlices(for: save).contains(.spires))

        root.spires?.floors?.removeAll { $0.spireID.isEmpty }
        root.starterSelectionPhaseRawValue = "removed-phase"
        #expect(root.repairSlices(for: save).contains(.root))
    }
}
