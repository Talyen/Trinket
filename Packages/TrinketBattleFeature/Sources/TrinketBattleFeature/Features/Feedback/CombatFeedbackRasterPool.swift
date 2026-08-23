import CoreGraphics
import QuartzCore
import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

struct CombatFeedbackRasterKey: Hashable {
    let feedbackClass: String
    let presentationRole: String
    /// Keyword + visual role keep identically symbolled styles (e.g. poison vs bleed)
    /// from sharing a pre-tinted raster.
    let keyword: String
    let visualRole: String
    let leadingSymbolName: String?
    let trailingSymbolName: String
    let label: CombatFeedbackChipLabel
    let layoutDirection: LayoutDirection
    let displayScaleHundredths: Int
}

/// Immutable raster owned exclusively by `CombatFeedbackRasterPool` (`@MainActor`).
/// Not Sendable: `CGImage` is not Sendable and the pool never crosses isolation.
final class CombatFeedbackRaster {
    let key: CombatFeedbackRasterKey
    let image: CGImage
    let pointSize: CGSize
    let displayScale: CGFloat

    init(
        key: CombatFeedbackRasterKey,
        image: CGImage,
        pointSize: CGSize,
        displayScale: CGFloat
    ) {
        self.key = key
        self.image = image
        self.pointSize = pointSize
        self.displayScale = displayScale
    }
}

struct CombatFeedbackRasterPoolSnapshot: Equatable {
    let entryCount: Int
    let estimatedByteCount: Int
    let hitCount: Int
    let missCount: Int
    let buildCount: Int
    let evictionCount: Int
    let unexpectedClosedVocabularyBuildCount: Int
    let numericMissCount: Int
    let rasterAllocationCount: Int
}

/// Battle-scoped, bounded storage for composed feedback chips. Composition is a
/// sub-millisecond glyph blit after atlas prewarm — cache hits stay transform-only.
@MainActor
final class CombatFeedbackRasterPool {
    static let shared = CombatFeedbackRasterPool()
    /// Fits the closed vocabulary catalog plus headroom for live numeric magnitudes
    /// during a fight. Numeric amounts stay on-demand (atlas digits are complete).
    static let defaultCapacity = 384

    private let capacity: Int
    private var rasters: [CombatFeedbackRasterKey: CombatFeedbackRaster] = [:]
    /// Epoch-stamped recency: O(1) touch on the display-link hit path; eviction
    /// scans stamps only on the miss path it already accompanies.
    private var lastUseEpoch: [CombatFeedbackRasterKey: Int] = [:]
    private var nextEpoch = 0
    private var hitCount = 0
    private var missCount = 0
    private var buildCount = 0
    private var evictionCount = 0
    private var unexpectedClosedVocabularyBuildCount = 0
    private var numericMissCount = 0
    private var rasterAllocationCount = 0
    private var preparedCatalogKey: CombatFeedbackGlyphAtlas.PresentationKey?
    private var pendingCatalogWarmup: PendingCatalogWarmup?
    private var catalogWarmupGeneration = 0

    private struct PendingCatalogWarmup {
        let generation: Int
        let task: Task<CombatFeedbackGlyphAtlas.PresentationKey?, Never>
    }

    init(capacity: Int = defaultCapacity) {
        self.capacity = max(1, capacity)
    }

    /// Lookup-only. The display-link path prefers this before composing.
    func cachedRaster(
        for item: CombatFeedbackItem,
        layoutDirection: LayoutDirection = .leftToRight,
        displayScale: CGFloat
    ) -> CombatFeedbackRaster? {
        let key = makeKey(
            for: item,
            layoutDirection: layoutDirection,
            displayScale: displayScale
        )
        guard let raster = rasters[key] else { return nil }
        hitCount += 1
        markMostRecent(key)
        return raster
    }

    /// Composes and stores a raster when missing. Warm atlas hits stay under 1 ms.
    @discardableResult
    func prepare(
        for item: CombatFeedbackItem,
        layoutDirection: LayoutDirection = .leftToRight,
        displayScale: CGFloat
    ) -> CombatFeedbackRaster? {
        let scale = max(1, displayScale)
        let key = makeKey(
            for: item,
            layoutDirection: layoutDirection,
            displayScale: scale
        )
        if let raster = rasters[key] {
            hitCount += 1
            markMostRecent(key)
            return raster
        }
        missCount += 1
        switch item.label {
        case .amount:
            numericMissCount += 1
        case .word where preparedCatalogKey != nil:
            unexpectedClosedVocabularyBuildCount += 1
        case .word:
            break
        }

        let intervalState = BattleFramePacingSignposts.signposter.beginInterval(
            BattleFramePacingSignposts.Name.feedbackRasterBuild
        )
        defer {
            BattleFramePacingSignposts.signposter.endInterval(
                BattleFramePacingSignposts.Name.feedbackRasterBuild,
                intervalState
            )
        }

        guard let composed = CombatFeedbackChipComposer.compose(
            presentation: item.chipPresentation,
            feedbackClass: item.feedbackClass,
            presentationRole: item.presentationRole,
            layoutDirection: layoutDirection,
            displayScale: scale
        ) else {
            return nil
        }

        let raster = CombatFeedbackRaster(
            key: key,
            image: composed.image,
            pointSize: composed.pointSize,
            displayScale: scale
        )
        buildCount += 1
        rasterAllocationCount += 1
        insert(raster, for: key)
        return raster
    }

    func prewarmInfrastructureAndWait(displayScale: CGFloat) async {
        let scale = max(1, displayScale)
        let key = CombatFeedbackGlyphAtlas.PresentationKey(displayScale: scale)
        while true {
            if let pendingCatalogWarmup {
                let completedKey = await pendingCatalogWarmup.task.value
                guard !Task.isCancelled, completedKey != nil else { return }
                continue
            }
            guard preparedCatalogKey != key else { return }
            let completedKey = await startCatalogWarmup(
                for: key,
                displayScale: scale
            ).value
            guard !Task.isCancelled, completedKey != nil else { return }
        }
    }

    private func startCatalogWarmup(
        for key: CombatFeedbackGlyphAtlas.PresentationKey,
        displayScale: CGFloat
    ) -> Task<CombatFeedbackGlyphAtlas.PresentationKey?, Never> {
        catalogWarmupGeneration &+= 1
        let generation = catalogWarmupGeneration
        let task: Task<CombatFeedbackGlyphAtlas.PresentationKey?, Never> = Task { @MainActor [weak self] in
            guard let self else { return nil }
            defer {
                if pendingCatalogWarmup?.generation == generation {
                    pendingCatalogWarmup = nil
                }
            }
            await CombatFeedbackGlyphAtlas.shared.prepareBattlePresentationAndWait(
                displayScale: displayScale
            )
            guard !Task.isCancelled, catalogWarmupGeneration == generation else { return nil }
            let catalog = CombatFeedbackRasterCatalog.closedVocabularyChips()
            // Yield between small batches so Stage Select / Battle appear stay responsive
            // while still finishing before the typical first card play.
            let batchSize = 8
            var index = 0
            while index < catalog.count {
                let end = min(index + batchSize, catalog.count)
                for item in catalog[index ..< end] {
                    _ = prepare(
                        for: item,
                        displayScale: displayScale
                    )
                }
                index = end
                await Task.yield()
                guard !Task.isCancelled, catalogWarmupGeneration == generation else { return nil }
            }
            preparedCatalogKey = key
            return key
        }
        pendingCatalogWarmup = PendingCatalogWarmup(
            generation: generation,
            task: task
        )
        return task
    }

    func removeAll() {
        catalogWarmupGeneration &+= 1
        pendingCatalogWarmup?.task.cancel()
        pendingCatalogWarmup = nil
        rasters.removeAll(keepingCapacity: true)
        lastUseEpoch.removeAll(keepingCapacity: true)
        preparedCatalogKey = nil
    }

    func resetDiagnostics() {
        hitCount = 0
        missCount = 0
        buildCount = 0
        evictionCount = 0
        unexpectedClosedVocabularyBuildCount = 0
        numericMissCount = 0
        rasterAllocationCount = 0
    }

    func snapshot() -> CombatFeedbackRasterPoolSnapshot {
        CombatFeedbackRasterPoolSnapshot(
            entryCount: rasters.count,
            estimatedByteCount: rasters.values.reduce(0) {
                $0 + $1.image.bytesPerRow * $1.image.height
            },
            hitCount: hitCount,
            missCount: missCount,
            buildCount: buildCount,
            evictionCount: evictionCount,
            unexpectedClosedVocabularyBuildCount: unexpectedClosedVocabularyBuildCount,
            numericMissCount: numericMissCount,
            rasterAllocationCount: rasterAllocationCount
        )
    }

    private func makeKey(
        for item: CombatFeedbackItem,
        layoutDirection: LayoutDirection,
        displayScale: CGFloat
    ) -> CombatFeedbackRasterKey {
        let presentation = item.chipPresentation
        let scale = max(1, displayScale)
        return CombatFeedbackRasterKey(
            feedbackClass: item.feedbackClass.rawValue,
            presentationRole: item.presentationRole.rawValue,
            keyword: item.keyword.rawValue,
            visualRole: item.visualRole.cacheKey,
            leadingSymbolName: presentation.leadingSymbolName,
            trailingSymbolName: presentation.trailingSymbolName,
            label: item.label,
            layoutDirection: layoutDirection,
            displayScaleHundredths: Int((scale * 100).rounded())
        )
    }

    private func insert(_ raster: CombatFeedbackRaster, for key: CombatFeedbackRasterKey) {
        if rasters.count >= capacity, let leastRecent = lastUseEpoch.min(by: { $0.value < $1.value })?.key {
            rasters.removeValue(forKey: leastRecent)
            lastUseEpoch.removeValue(forKey: leastRecent)
            evictionCount += 1
        }
        rasters[key] = raster
        markMostRecent(key)
    }

    private func markMostRecent(_ key: CombatFeedbackRasterKey) {
        nextEpoch += 1
        lastUseEpoch[key] = nextEpoch
    }
}
