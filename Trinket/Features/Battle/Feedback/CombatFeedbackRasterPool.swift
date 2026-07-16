import CoreGraphics
import SwiftUI
import TrinketCore
import TrinketDesignSystem

struct CombatFeedbackRasterKey: Hashable {
    let feedbackClass: String
    let symbolName: String
    let label: CombatFeedbackChipLabel
    let dynamicTypeSize: DynamicTypeSize
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
    /// Sized for a fight's concurrent chip templates without retaining every historic amount.
    static let defaultCapacity = 32

    private let capacity: Int
    private var rasters: [CombatFeedbackRasterKey: CombatFeedbackRaster] = [:]
    private var recency: [CombatFeedbackRasterKey] = []
    private var hitCount = 0
    private var buildCount = 0
    private var evictionCount = 0
    private var pendingPacedPrepareTask: Task<Void, Never>?

    init(capacity: Int = defaultCapacity) {
        self.capacity = max(1, capacity)
    }

    /// Lookup-only. The display-link path prefers this before composing.
    func cachedRaster(
        for canvasItem: CombatFeedbackCanvasItem,
        dynamicTypeSize: DynamicTypeSize,
        displayScale: CGFloat
    ) -> CombatFeedbackRaster? {
        let key = makeKey(
            for: canvasItem,
            dynamicTypeSize: dynamicTypeSize,
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
        displayScale: CGFloat,
        useFrameBudget: Bool = false
    ) -> CombatFeedbackRaster? {
        let scale = max(1, displayScale)
        let key = makeKey(
            for: canvasItem,
            dynamicTypeSize: dynamicTypeSize,
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
            label: canvasItem.label,
            style: item.feedbackVisualStyle,
            feedbackClass: item.feedbackClass,
            dynamicTypeSize: dynamicTypeSize,
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
        displayScale: CGFloat
    ) -> CombatFeedbackRaster? {
        prepare(
            for: canvasItem,
            dynamicTypeSize: dynamicTypeSize,
            displayScale: displayScale
        )
    }

    /// Eagerly composes every canvas item for the supplied feedback rows.
    /// When `useFrameBudget` is true, composes at most one miss per display-link
    /// tick so multi-target batches stay off a single publish frame.
    func prepareAll(
        for items: [CombatFeedbackItem],
        dynamicTypeSize: DynamicTypeSize,
        displayScale: CGFloat,
        useFrameBudget: Bool = false
    ) {
        let canvasItems = Self.canvasItems(from: items)
        guard useFrameBudget else {
            for canvasItem in canvasItems {
                _ = prepare(
                    for: canvasItem,
                    dynamicTypeSize: dynamicTypeSize,
                    displayScale: displayScale
                )
            }
            return
        }
        pendingPacedPrepareTask?.cancel()
        pendingPacedPrepareTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for canvasItem in canvasItems {
                guard !Task.isCancelled else { return }
                if cachedRaster(
                    for: canvasItem,
                    dynamicTypeSize: dynamicTypeSize,
                    displayScale: displayScale
                ) != nil {
                    continue
                }
                await CombatFeedbackDisplayLinkGate.waitForNextDisplayLink()
                guard !Task.isCancelled else { return }
                _ = prepare(
                    for: canvasItem,
                    dynamicTypeSize: dynamicTypeSize,
                    displayScale: displayScale
                )
            }
            pendingPacedPrepareTask = nil
        }
    }

    /// Starts paced glyph-atlas prewarm for the current Dynamic Type / scale.
    func prewarmInfrastructure(
        dynamicTypeSize: DynamicTypeSize,
        displayScale: CGFloat
    ) {
        CombatFeedbackGlyphAtlas.shared.prepareBattlePresentation(
            dynamicTypeSize: dynamicTypeSize,
            displayScale: displayScale
        )
    }

    func prewarmInfrastructureAndWait(
        dynamicTypeSize: DynamicTypeSize,
        displayScale: CGFloat
    ) async {
        await CombatFeedbackGlyphAtlas.shared.prepareBattlePresentationAndWait(
            dynamicTypeSize: dynamicTypeSize,
            displayScale: displayScale
        )
    }

    func removeAll() {
        pendingPacedPrepareTask?.cancel()
        pendingPacedPrepareTask = nil
        rasters.removeAll(keepingCapacity: true)
        recency.removeAll(keepingCapacity: true)
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
        displayScale: CGFloat
    ) -> CombatFeedbackRasterKey {
        let item = canvasItem.item
        let style = item.feedbackVisualStyle
        let scale = max(1, displayScale)
        return CombatFeedbackRasterKey(
            feedbackClass: item.feedbackClass.rawValue,
            symbolName: style.symbolName,
            label: canvasItem.label,
            dynamicTypeSize: dynamicTypeSize,
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
