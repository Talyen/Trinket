import Foundation
import Testing
import TrinketDesignSystem
import TrinketFeatureSupport
@testable import TrinketBattleFeature

struct CombatFeedbackRasterCatalogTests {
    @Test @MainActor func sevenChipStreamPacksMixedSizesWithoutOverlap() {
        let desired: [CGFloat] = [-72, -66, -58, -47, -34, -18, 0]
        let heights: [CGFloat] = [36, 44, 36, 36, 44, 36, 44]
        let gap = CombatFeedbackLayout.streamGap

        let packed = CombatFeedbackRasterUIView.packedVerticalOffsets(
            desired: desired,
            scaledHeights: heights
        )

        #expect(packed.count == 7)
        #expect(packed.last == desired.last)
        for index in 0 ..< packed.count - 1 {
            let clearance = packed[index + 1] - packed[index]
            #expect(clearance >= (heights[index] + heights[index + 1]) / 2 + gap)
        }
    }

    @Test @MainActor func feedbackRasterPoolReusesAndBoundsPreparedLabels() throws {
        let pool = CombatFeedbackRasterPool(capacity: 2)
        let canvasItems = Array(
            CombatFeedbackRasterCatalog.closedVocabularyCanvasItems(
                at: Date(timeIntervalSince1970: 10)
            ).prefix(3)
        )
        #expect(canvasItems.count == 3)

        let first = try #require(pool.prepare(
            for: canvasItems[0],
            dynamicTypeSize: .large,
            displayScale: 2
        ))
        let reused = try #require(pool.cachedRaster(
            for: canvasItems[0],
            dynamicTypeSize: .large,
            displayScale: 2
        ))
        #expect(first === reused)

        _ = pool.prepare(for: canvasItems[1], dynamicTypeSize: .large, displayScale: 2)
        _ = pool.prepare(for: canvasItems[2], dynamicTypeSize: .large, displayScale: 2)
        let snapshot = pool.snapshot()
        #expect(snapshot.entryCount == 2)
        #expect(snapshot.estimatedByteCount > 0)
        #expect(snapshot.hitCount == 1)
        #expect(snapshot.buildCount == 3)
        #expect(snapshot.evictionCount == 1)
    }

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
            CombatFeedbackRasterCatalog.closedVocabularyCanvasItems().prefix(7)
        )
        #expect(canvasItems.count == 7)
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
