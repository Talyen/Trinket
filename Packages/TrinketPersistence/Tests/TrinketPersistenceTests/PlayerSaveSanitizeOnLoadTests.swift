import Foundation
import SwiftData
import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

@MainActor
final class PlayerSaveSanitizeOnLoadTests {
    let context: PersistenceTestContext

    init() throws {
        context = try PersistenceTestContext()
    }

    @Test func ensureRequiredGraphPersistsSemanticSanitizeDiffs() throws {
        let storeURL = context.storeURL()
        var dirty = PlayerSave.testSeed
        dirty.homestead.resources[.wood] = -12
        dirty.roster.equipmentLoadouts["knight"] = EquipmentLoadout(
            itemIDsBySlot: [.weapon: "ghost-sword"]
        )

        try SaveTestSupport.writeRoot(dirty, to: storeURL)

        let store = try PlayerSaveStore(storeURL: storeURL, disableCloudSync: true)
        try #expect(store.homestead.resources[.wood] == 0)
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        try #expect(store.roster.equipmentLoadout(for: knight).itemID(for: .weapon) == nil)

        // Dirty homestead must not brick an unrelated journey write after load.
        var journey = store.journey
        let stageID = try #require(GameContent.chapters.first?.stages.first?.id)
        journey.completedStageIDs.insert(stageID)
        store.journey = journey
        try #expect(store.journey.completedStageIDs.contains(stageID))
        try #expect(store.lastPersistenceError == nil)

        let sideContext = try SaveTestSupport.makeSideContext(storeURL: storeURL)
        let balances = try sideContext.fetch(FetchDescriptor<HomesteadResourceBalanceModel>())
        let wood = balances.first { $0.resourceID == HomesteadResource.wood.rawValue }
        try #expect(wood == nil || wood?.quantity == 0)

        let slots = try sideContext.fetch(FetchDescriptor<EquipmentSlotModel>())
        try #expect(slots.allSatisfy { $0.itemID != "ghost-sword" })
    }
}
