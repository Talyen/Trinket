import Foundation
import Testing
import TrinketDesignSystem
@testable import Trinket

struct CombatFeedbackRasterCatalogTests {
    @Test @MainActor func closedCatalogFitsDefaultCapacityWithoutEviction() async {
        await CombatFeedbackGlyphAtlas.shared.prepareBattlePresentationAndWait(
            dynamicTypeSize: .large,
            displayScale: 2
        )
        let catalog = CombatFeedbackRasterCatalog.closedVocabularyCanvasItems(
            at: Date(timeIntervalSince1970: 10)
        )
        #expect(!catalog.isEmpty)
        #expect(catalog.count <= CombatFeedbackRasterPool.defaultCapacity)

        let pool = CombatFeedbackRasterPool(capacity: CombatFeedbackRasterPool.defaultCapacity)
        for canvasItem in catalog {
            let raster = pool.prepare(
                for: canvasItem,
                dynamicTypeSize: .large,
                displayScale: 2
            )
            #expect(raster != nil, "Catalog chip failed to compose: \(canvasItem.label)")
        }
        let snapshot = pool.snapshot()
        #expect(snapshot.entryCount == catalog.count)
        #expect(snapshot.evictionCount == 0)
        #expect(snapshot.buildCount == catalog.count)

        for canvasItem in catalog {
            #expect(
                pool.cachedRaster(
                    for: canvasItem,
                    dynamicTypeSize: .large,
                    displayScale: 2
                ) != nil
            )
        }
        #expect(pool.snapshot().hitCount == catalog.count)
    }

    @Test @MainActor func warmHostApplyUsesPreallocatedLayersAndParksItsIdleClock() async throws {
        await CombatFeedbackGlyphAtlas.shared.prepareBattlePresentationAndWait(
            dynamicTypeSize: .large,
            displayScale: 2
        )
        let pool = CombatFeedbackRasterPool(capacity: CombatFeedbackRasterPool.defaultCapacity)
        let canvasItems = Array(
            CombatFeedbackRasterCatalog.closedVocabularyCanvasItems().prefix(
                CombatFeedbackRasterUIView.preallocatedSlotCount
            )
        )
        let chips = try canvasItems.map { canvasItem in
            let raster = try #require(pool.prepare(
                for: canvasItem,
                dynamicTypeSize: .large,
                displayScale: 2
            ))
            return (canvasItem: canvasItem, raster: Optional(raster))
        }
        let host = CombatFeedbackRasterUIView(
            frame: CGRect(x: 0, y: 0, width: 240, height: 180)
        )
        CombatFeedbackRasterHostDiagnostics.reset()

        host.apply(chips: chips)

        #expect(CombatFeedbackRasterHostDiagnostics.snapshot().warmPathAllocationCount == 0)
        #expect(!CombatFeedbackRasterUIView.isMotionClockPaused)
        host.apply(chips: [])
        #expect(CombatFeedbackRasterUIView.isMotionClockPaused)
        #expect(pool.snapshot().isPrepareClockPaused)
    }
}
