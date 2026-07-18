import CoreGraphics
import SwiftUI
import TrinketCore
import TrinketDesignSystem

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
    let dynamicTypeSize: DynamicTypeSize
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
    let buildCount: Int
    let evictionCount: Int
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
    private var recency: [CombatFeedbackRasterKey] = []
    private var hitCount = 0
    private var buildCount = 0
    private var evictionCount = 0
    private var pacedPrepareLoopTask: Task<Void, Never>?
    private var pendingPrepareQueue: [PendingPrepareRequest] = []
    private var preparedCatalogKey: String?

    private struct PendingPrepareRequest {
        let canvasItems: [CombatFeedbackCanvasItem]
        let dynamicTypeSize: DynamicTypeSize
        let layoutDirection: LayoutDirection
        let displayScale: CGFloat
        let onComplete: (@MainActor () -> Void)?
    }

    init(capacity: Int = defaultCapacity) {
        self.capacity = max(1, capacity)
    }

    /// Starts the paced-prepare loop before the first cache miss so publish frames
    /// only enqueue work instead of allocating a Task.
    func prewarmPacedPrepareLoop() {
        ensurePacedPrepareLoopRunning()
    }

    /// Lookup-only. The display-link path prefers this before composing.
    func cachedRaster(
        for canvasItem: CombatFeedbackCanvasItem,
        dynamicTypeSize: DynamicTypeSize,
        layoutDirection: LayoutDirection = .leftToRight,
        displayScale: CGFloat
    ) -> CombatFeedbackRaster? {
        let key = makeKey(
            for: canvasItem,
            dynamicTypeSize: dynamicTypeSize,
            layoutDirection: layoutDirection,
            displayScale: displayScale
        )
        guard let raster = rasters[key] else { return nil }
        hitCount += 1
        markMostRecent(key)
        return raster
    }

    /// Composes and stores a raster when missing. Warm atlas hits stay under 1 ms.
    /// When `useFrameBudget` is true and the key is a miss, skips compose so the
    /// caller can pace work across display-link ticks (see `prepareAll`).
    @discardableResult
    func prepare(
        for canvasItem: CombatFeedbackCanvasItem,
        dynamicTypeSize: DynamicTypeSize,
        layoutDirection: LayoutDirection = .leftToRight,
        displayScale: CGFloat,
        useFrameBudget: Bool = false
    ) -> CombatFeedbackRaster? {
        let scale = max(1, displayScale)
        let key = makeKey(
            for: canvasItem,
            dynamicTypeSize: dynamicTypeSize,
            layoutDirection: layoutDirection,
            displayScale: scale
        )
        if let raster = rasters[key] {
            hitCount += 1
            markMostRecent(key)
            return raster
        }
        if useFrameBudget {
            return nil
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

        let item = canvasItem.item
        guard let composed = CombatFeedbackChipComposer.compose(
            presentation: item.chipPresentation,
            feedbackClass: item.feedbackClass,
            presentationRole: item.presentationRole,
            dynamicTypeSize: dynamicTypeSize,
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
        insert(raster, for: key)
        return raster
    }

    /// Compatibility entry point used by tests and the performance harness.
    @discardableResult
    func raster(
        for canvasItem: CombatFeedbackCanvasItem,
        dynamicTypeSize: DynamicTypeSize,
        layoutDirection: LayoutDirection = .leftToRight,
        displayScale: CGFloat
    ) -> CombatFeedbackRaster? {
        prepare(
            for: canvasItem,
            dynamicTypeSize: dynamicTypeSize,
            layoutDirection: layoutDirection,
            displayScale: displayScale
        )
    }

    /// Eagerly composes every canvas item for the supplied feedback rows.
    /// When `useFrameBudget` is true, composes at most one miss per display-link
    /// tick so multi-target batches stay off a single publish frame.
    func prepareAll(
        for items: [CombatFeedbackItem],
        dynamicTypeSize: DynamicTypeSize,
        layoutDirection: LayoutDirection = .leftToRight,
        displayScale: CGFloat,
        useFrameBudget: Bool = false
    ) {
        prepareCanvasItems(
            Self.canvasItems(from: items),
            dynamicTypeSize: dynamicTypeSize,
            layoutDirection: layoutDirection,
            displayScale: displayScale,
            useFrameBudget: useFrameBudget
        )
    }

    /// Paced or immediate compose for already-resolved canvas items.
    func prepareCanvasItems(
        _ canvasItems: [CombatFeedbackCanvasItem],
        dynamicTypeSize: DynamicTypeSize,
        layoutDirection: LayoutDirection = .leftToRight,
        displayScale: CGFloat,
        useFrameBudget: Bool = false,
        onComplete: (@MainActor () -> Void)? = nil
    ) {
        guard !canvasItems.isEmpty else {
            onComplete?()
            return
        }
        guard useFrameBudget else {
            for canvasItem in canvasItems {
                _ = prepare(
                    for: canvasItem,
                    dynamicTypeSize: dynamicTypeSize,
                    layoutDirection: layoutDirection,
                    displayScale: displayScale
                )
            }
            onComplete?()
            return
        }
        // Publish frames only enqueue. A long-lived loop owns sleeps — cancelling
        // and reallocating `Task` here was a measured ChipPublish hitch.
        pendingPrepareQueue.append(
            PendingPrepareRequest(
                canvasItems: canvasItems,
                dynamicTypeSize: dynamicTypeSize,
                layoutDirection: layoutDirection,
                displayScale: displayScale,
                onComplete: onComplete
            )
        )
        ensurePacedPrepareLoopRunning()
    }

    private func ensurePacedPrepareLoopRunning() {
        guard pacedPrepareLoopTask == nil else { return }
        pacedPrepareLoopTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                guard !pendingPrepareQueue.isEmpty else {
                    // Interruptible park — a 1s sleep let cold chip misses expire
                    // before compose + re-flush, so feedback text never appeared.
                    try? await Task.sleep(for: .milliseconds(16))
                    continue
                }
                let request = pendingPrepareQueue.removeFirst()
                for canvasItem in request.canvasItems {
                    guard !Task.isCancelled else { return }
                    if cachedRaster(
                        for: canvasItem,
                        dynamicTypeSize: request.dynamicTypeSize,
                        layoutDirection: request.layoutDirection,
                        displayScale: request.displayScale
                    ) != nil {
                        continue
                    }
                    await Task.yield()
                    try? await Task.sleep(for: .milliseconds(16))
                    guard !Task.isCancelled else { return }
                    _ = prepare(
                        for: canvasItem,
                        dynamicTypeSize: request.dynamicTypeSize,
                        layoutDirection: request.layoutDirection,
                        displayScale: request.displayScale
                    )
                }
                request.onComplete?()
            }
        }
    }

    /// Starts paced glyph-atlas + closed-catalog prewarm for the current Dynamic Type / scale.
    func prewarmInfrastructure(
        dynamicTypeSize: DynamicTypeSize,
        displayScale: CGFloat
    ) {
        Task { @MainActor in
            await prewarmInfrastructureAndWait(
                dynamicTypeSize: dynamicTypeSize,
                displayScale: displayScale
            )
        }
    }

    func prewarmInfrastructureAndWait(
        dynamicTypeSize: DynamicTypeSize,
        displayScale: CGFloat
    ) async {
        let scale = max(1, displayScale)
        let catalogKey = "\(dynamicTypeSize)|\(Int((scale * 100).rounded()))"
        await CombatFeedbackGlyphAtlas.shared.prepareBattlePresentationAndWait(
            dynamicTypeSize: dynamicTypeSize,
            displayScale: scale
        )
        guard preparedCatalogKey != catalogKey else { return }
        let catalog = CombatFeedbackRasterCatalog.closedVocabularyCanvasItems()
        // Yield between small batches so Stage Select / Battle appear stay responsive
        // while still finishing before the typical first card play.
        let batchSize = 8
        var index = 0
        while index < catalog.count {
            let end = min(index + batchSize, catalog.count)
            for canvasItem in catalog[index ..< end] {
                _ = prepare(
                    for: canvasItem,
                    dynamicTypeSize: dynamicTypeSize,
                    displayScale: scale
                )
            }
            index = end
            await Task.yield()
        }
        preparedCatalogKey = catalogKey
    }

    func removeAll() {
        // Keep the paced-prepare loop alive across clears — restarting it on the
        // next miss allocated a Task on the measured ChipPublish frame.
        pendingPrepareQueue.removeAll(keepingCapacity: true)
        rasters.removeAll(keepingCapacity: true)
        recency.removeAll(keepingCapacity: true)
        preparedCatalogKey = nil
    }

    func removeAllIncludingAtlas() {
        removeAll()
        CombatFeedbackGlyphAtlas.shared.removeAll()
    }

    func resetDiagnostics() {
        hitCount = 0
        buildCount = 0
        evictionCount = 0
    }

    func snapshot() -> CombatFeedbackRasterPoolSnapshot {
        CombatFeedbackRasterPoolSnapshot(
            entryCount: rasters.count,
            estimatedByteCount: rasters.values.reduce(0) {
                $0 + $1.image.bytesPerRow * $1.image.height
            },
            hitCount: hitCount,
            buildCount: buildCount,
            evictionCount: evictionCount
        )
    }

    static func canvasItems(from items: [CombatFeedbackItem]) -> [CombatFeedbackCanvasItem] {
        // Prepare every action group in the batch — not only the single newest group
        // the overlay keeps on-screen — so staggered targets are warm before availableAt.
        var order: [Int] = []
        var grouped: [Int: [CombatFeedbackItem]] = [:]
        for item in items {
            if grouped[item.actionGroupID] == nil {
                order.append(item.actionGroupID)
            }
            grouped[item.actionGroupID, default: []].append(item)
        }
        let actionGroups = order.compactMap { id -> CombatFeedbackActionGroup? in
            guard let groupItems = grouped[id] else { return nil }
            return CombatFeedbackActionGroup(id: id, items: groupItems)
        }
        return CombatFeedbackOverlayPolicy.canvasItems(from: actionGroups)
    }

    private func makeKey(
        for canvasItem: CombatFeedbackCanvasItem,
        dynamicTypeSize: DynamicTypeSize,
        layoutDirection: LayoutDirection,
        displayScale: CGFloat
    ) -> CombatFeedbackRasterKey {
        let item = canvasItem.item
        let presentation = item.chipPresentation
        let scale = max(1, displayScale)
        return CombatFeedbackRasterKey(
            feedbackClass: item.feedbackClass.rawValue,
            presentationRole: item.presentationRole.rawValue,
            keyword: item.keyword.rawValue,
            visualRole: item.visualRole.cacheKey,
            leadingSymbolName: presentation.leadingSymbolName,
            trailingSymbolName: presentation.trailingSymbolName,
            label: canvasItem.label,
            dynamicTypeSize: dynamicTypeSize,
            layoutDirection: layoutDirection,
            displayScaleHundredths: Int((scale * 100).rounded())
        )
    }

    private func insert(_ raster: CombatFeedbackRaster, for key: CombatFeedbackRasterKey) {
        if rasters.count >= capacity, let leastRecent = recency.first {
            rasters.removeValue(forKey: leastRecent)
            recency.removeFirst()
            evictionCount += 1
        }
        rasters[key] = raster
        recency.append(key)
    }

    private func markMostRecent(_ key: CombatFeedbackRasterKey) {
        if let index = recency.firstIndex(of: key) {
            recency.remove(at: index)
        }
        recency.append(key)
    }
}
