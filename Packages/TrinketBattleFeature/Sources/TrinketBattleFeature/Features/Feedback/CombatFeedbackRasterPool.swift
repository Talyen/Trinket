import CoreGraphics
import QuartzCore
import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

struct CombatFeedbackRasterKey: Hashable {
    let typography: CombatFeedbackTypographyTier
    let presentation: CombatFeedbackChipPresentation
    let layoutDirection: LayoutDirection
    let displayScaleHundredths: Int

    init(
        item: CombatFeedbackItem,
        layoutDirection: LayoutDirection,
        displayScale: CGFloat,
    ) {
        typography = item.feedbackClass.typographyTier
        presentation = item.chipPresentation
        self.layoutDirection = layoutDirection
        displayScaleHundredths = Int((max(1, displayScale) * 100).rounded())
    }
}

final class CombatFeedbackRaster {
    let key: CombatFeedbackRasterKey
    let image: CGImage
    let pointSize: CGSize
    let displayScale: CGFloat

    init(
        key: CombatFeedbackRasterKey,
        image: CGImage,
        pointSize: CGSize,
        displayScale: CGFloat,
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

@MainActor
final class CombatFeedbackRasterPool {
    static let shared = CombatFeedbackRasterPool()
    static let defaultCapacity = 384

    private let capacity: Int
    private var rasters: [CombatFeedbackRasterKey: CombatFeedbackRaster] = [:]
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

    private let rasterize: @Sendable ([CombatFeedbackChipComposer.RasterInputs]) async -> [CombatFeedbackChipComposer.ComposedRaster?]

    init(
        capacity: Int = defaultCapacity,
        rasterize: @escaping @Sendable ([CombatFeedbackChipComposer.RasterInputs]) async
            -> [CombatFeedbackChipComposer.ComposedRaster?] = CombatFeedbackRasterPool.rasterize,
    ) {
        self.capacity = max(1, capacity)
        self.rasterize = rasterize
    }

    @concurrent
    private nonisolated static func rasterize(
        _ requests: [CombatFeedbackChipComposer.RasterInputs],
    ) async -> [CombatFeedbackChipComposer.ComposedRaster?] {
        var prepared: [CombatFeedbackChipComposer.ComposedRaster?] = []
        for request in requests {
            guard !Task.isCancelled else { return prepared }
            prepared.append(CombatFeedbackChipComposer.render(request))
        }
        return prepared
    }

    func cachedRaster(
        for item: CombatFeedbackItem,
        layoutDirection: LayoutDirection = .leftToRight,
        displayScale: CGFloat,
    ) -> CombatFeedbackRaster? {
        let key = CombatFeedbackRasterKey(
            item: item,
            layoutDirection: layoutDirection,
            displayScale: displayScale,
        )
        return lookup(key)
    }

    @discardableResult
    func prepare(
        for item: CombatFeedbackItem,
        layoutDirection: LayoutDirection = .leftToRight,
        displayScale: CGFloat,
    ) -> CombatFeedbackRaster? {
        let scale = max(1, displayScale)
        let key = CombatFeedbackRasterKey(
            item: item,
            layoutDirection: layoutDirection,
            displayScale: scale,
        )
        if let raster = lookup(key) {
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
            BattleFramePacingSignposts.Name.feedbackRasterBuild,
        )
        defer {
            BattleFramePacingSignposts.signposter.endInterval(
                BattleFramePacingSignposts.Name.feedbackRasterBuild,
                intervalState,
            )
        }

        guard let composed = CombatFeedbackChipComposer.compose(
            presentation: item.chipPresentation,
            feedbackClass: item.feedbackClass,
            layoutDirection: layoutDirection,
            displayScale: scale,
        ) else {
            return nil
        }

        let raster = CombatFeedbackRaster(
            key: key,
            image: composed.image,
            pointSize: composed.pointSize,
            displayScale: scale,
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
                displayScale: scale,
            ).value
            guard !Task.isCancelled, completedKey != nil else { return }
        }
    }

    private func startCatalogWarmup(
        for key: CombatFeedbackGlyphAtlas.PresentationKey,
        displayScale: CGFloat,
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
                displayScale: displayScale,
            )
            guard !Task.isCancelled, catalogWarmupGeneration == generation else { return nil }
            let requests = rasterRequests(displayScale: displayScale)
            let prepared = await rasterize(requests.map(\.1))
            guard !Task.isCancelled, catalogWarmupGeneration == generation else { return nil }
            guard prepared.count == requests.count, prepared.allSatisfy({ $0 != nil }) else { return nil }
            for (request, image) in zip(requests, prepared) {
                guard rasters[request.0] == nil, let image else { continue }
                let raster = CombatFeedbackRaster(
                    key: request.0, image: image.image,
                    pointSize: image.pointSize, displayScale: displayScale,
                )
                buildCount += 1
                rasterAllocationCount += 1
                insert(raster, for: request.0)
            }
            preparedCatalogKey = key
            return key
        }
        pendingCatalogWarmup = PendingCatalogWarmup(
            generation: generation,
            task: task,
        )
        return task
    }

    private func rasterRequests(
        displayScale: CGFloat,
    ) -> [(CombatFeedbackRasterKey, CombatFeedbackChipComposer.RasterInputs)] {
        CombatFeedbackClosedVocabulary.orderedChips().compactMap { item -> (
            CombatFeedbackRasterKey,
            CombatFeedbackChipComposer.RasterInputs,
        )? in
            let rasterKey = CombatFeedbackRasterKey(item: item, layoutDirection: .leftToRight, displayScale: displayScale)
            guard rasters[rasterKey] == nil,
                  let inputs = CombatFeedbackChipComposer.prepareInputs(
                      presentation: item.chipPresentation,
                      feedbackClass: item.feedbackClass,
                      displayScale: displayScale,
                  ) else { return nil }
            return (rasterKey, inputs)
        }
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
            rasterAllocationCount: rasterAllocationCount,
        )
    }

    private func lookup(_ key: CombatFeedbackRasterKey) -> CombatFeedbackRaster? {
        guard let raster = rasters[key] else { return nil }
        hitCount += 1
        markMostRecent(key)
        return raster
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
