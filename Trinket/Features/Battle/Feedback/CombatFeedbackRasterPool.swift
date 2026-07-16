import CoreGraphics
import SwiftUI
import TrinketDesignSystem

struct CombatFeedbackRasterKey: Hashable {
    let feedbackClass: String
    let symbolName: String
    let text: String
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

/// Battle-scoped, bounded storage for fully composed feedback labels. Rasterizing the
/// symbol, glyphs, color, and shadow once keeps the display-link path to image transforms.
@MainActor
final class CombatFeedbackRasterPool {
    static let shared = CombatFeedbackRasterPool()
    static let defaultCapacity = 16

    private let capacity: Int
    private var rasters: [CombatFeedbackRasterKey: CombatFeedbackRaster] = [:]
    private var recency: [CombatFeedbackRasterKey] = []
    private var hitCount = 0
    private var buildCount = 0
    private var evictionCount = 0

    init(capacity: Int = defaultCapacity) {
        self.capacity = max(1, capacity)
    }

    func raster(
        for canvasItem: CombatFeedbackCanvasItem,
        dynamicTypeSize: DynamicTypeSize,
        displayScale: CGFloat
    ) -> CombatFeedbackRaster? {
        let item = canvasItem.item
        let style = item.feedbackVisualStyle
        let scale = max(1, displayScale)
        let key = CombatFeedbackRasterKey(
            feedbackClass: item.feedbackClass.rawValue,
            symbolName: style.symbolName,
            text: canvasItem.text,
            dynamicTypeSize: dynamicTypeSize,
            displayScaleHundredths: Int((scale * 100).rounded())
        )

        if let raster = rasters[key] {
            hitCount += 1
            markMostRecent(key)
            return raster
        }

        let recipe = TrinketMotion.Battle.chip(for: item.feedbackClass)
        let label = Text(Image(systemName: style.symbolName))
            + Text("  \(canvasItem.text)")
        let content = label
            .font(recipe.font(for: .headline))
            .foregroundStyle(style.color)
            .shadow(
                color: TrinketDesign.Colors.Overlay.ink.opacity(0.95),
                radius: 0,
                y: 1.5
            )
            .padding(.horizontal, TrinketDesign.Metrics.extraSmallSpacing)
            .padding(.vertical, 5)
            .fixedSize()
            .environment(\.dynamicTypeSize, dynamicTypeSize)

        let intervalState = BattleFramePacingSignposts.signposter.beginInterval(
            BattleFramePacingSignposts.Name.feedbackRasterBuild
        )
        defer {
            BattleFramePacingSignposts.signposter.endInterval(
                BattleFramePacingSignposts.Name.feedbackRasterBuild,
                intervalState
            )
        }
        let renderer = ImageRenderer(content: content)
        renderer.scale = scale
        guard let image = renderer.cgImage else { return nil }

        let raster = CombatFeedbackRaster(
            key: key,
            image: image,
            pointSize: CGSize(
                width: CGFloat(image.width) / scale,
                height: CGFloat(image.height) / scale
            ),
            displayScale: scale
        )
        buildCount += 1
        insert(raster, for: key)
        return raster
    }

    func removeAll() {
        rasters.removeAll(keepingCapacity: true)
        recency.removeAll(keepingCapacity: true)
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
