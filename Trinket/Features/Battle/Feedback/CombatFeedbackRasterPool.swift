import CoreGraphics
import CoreText
import QuartzCore
import SwiftUI
import TrinketCore
import TrinketDesignSystem
import UIKit

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
    /// Sized for a fight's concurrent chip templates without retaining every historic amount.
    static let defaultCapacity = 32

    private let capacity: Int
    private var rasters: [CombatFeedbackRasterKey: CombatFeedbackRaster] = [:]
    private var recency: [CombatFeedbackRasterKey] = []
    private var hitCount = 0
    private var buildCount = 0
    private var evictionCount = 0
    private var pendingPrepareTask: Task<Void, Never>?

    init(capacity: Int = defaultCapacity) {
        self.capacity = max(1, capacity)
    }

    /// Lookup-only. The display-link path must never pay for a cache miss here.
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

    /// Builds and stores a raster when missing. Prefer calling this before the chip
    /// becomes visible (record / stagger windows), not inside a `TimelineView` body.
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

        if useFrameBudget, !CombatFeedbackRasterPrepareBudget.consume() {
            return nil
        }

        // Restore real baker after noop diagnostic.
        let intervalState = BattleFramePacingSignposts.signposter.beginInterval(
            BattleFramePacingSignposts.Name.feedbackRasterBuild
        )
        defer {
            BattleFramePacingSignposts.signposter.endInterval(
                BattleFramePacingSignposts.Name.feedbackRasterBuild,
                intervalState
            )
        }

        guard let baked = CombatFeedbackRasterBaker.bake(
            canvasItem: canvasItem,
            dynamicTypeSize: dynamicTypeSize,
            displayScale: scale
        ) else { return nil }

        let raster = CombatFeedbackRaster(
            key: key,
            image: baked.image,
            pointSize: baked.pointSize,
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

    /// Prepares every canvas item for the supplied feedback rows, waiting for a
    /// display refresh between builds so a multi-target batch cannot hitch one frame.
    func prepareAll(
        for items: [CombatFeedbackItem],
        dynamicTypeSize: DynamicTypeSize,
        displayScale: CGFloat
    ) {
        let canvasItems = Self.canvasItems(from: items)
        guard !canvasItems.isEmpty else { return }

        pendingPrepareTask?.cancel()
        pendingPrepareTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for (index, canvasItem) in canvasItems.enumerated() {
                guard !Task.isCancelled else { return }
                _ = prepare(
                    for: canvasItem,
                    dynamicTypeSize: dynamicTypeSize,
                    displayScale: displayScale
                )
                if index < canvasItems.count - 1 {
                    await CombatFeedbackRasterPrepareBudget.waitForNextDisplayLink()
                }
            }
        }
    }

    /// Warms Core Text / SF Symbol machinery with a throwaway chip so the first
    /// real combat label does not pay process-wide first-touch costs mid-frame.
    func prewarmInfrastructure(
        dynamicTypeSize: DynamicTypeSize,
        displayScale: CGFloat
    ) {
        let probe = CombatFeedbackItem(
            id: -1,
            sourceEventIDs: [-1],
            actionGroupID: -1,
            presentationIndex: 0,
            groupResultCount: 1,
            targetID: "prewarm",
            feedbackClass: .directDamage,
            keyword: .physical,
            text: "0",
            secondaryText: nil,
            spawnSeed: 0,
            lifetime: 0.1,
            availableAt: .distantPast,
            expiresAt: .distantPast,
            reactionKind: .none
        )
        let canvasItem = CombatFeedbackCanvasItem(item: probe, text: "0")
        _ = prepare(
            for: canvasItem,
            dynamicTypeSize: dynamicTypeSize,
            displayScale: displayScale
        )
        // Drop the probe so it does not occupy capacity during the fight.
        let key = makeKey(
            for: canvasItem,
            dynamicTypeSize: dynamicTypeSize,
            displayScale: displayScale
        )
        rasters.removeValue(forKey: key)
        if let index = recency.firstIndex(of: key) {
            recency.remove(at: index)
        }
        buildCount = max(0, buildCount - 1)
    }

    func removeAll() {
        pendingPrepareTask?.cancel()
        pendingPrepareTask = nil
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
            text: canvasItem.text,
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

/// Caps MainActor raster builds to one per display refresh so three combatant panes
/// cannot serialize three cold bakes into a single severe stall.
@MainActor
enum CombatFeedbackRasterPrepareBudget {
    private static var windowStartedAt: CFTimeInterval = 0
    private static var preparesInWindow = 0
    private static let windowSeconds: CFTimeInterval = 1.0 / 60.0

    static func consume() -> Bool {
        let now = CACurrentMediaTime()
        if now - windowStartedAt >= windowSeconds {
            windowStartedAt = now
            preparesInWindow = 0
        }
        guard preparesInWindow < 1 else { return false }
        preparesInWindow += 1
        return true
    }

    static func waitForNextDisplayLink() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let link = CADisplayLink(
                target: DisplayLinkResumeBox(continuation: continuation),
                selector: #selector(DisplayLinkResumeBox.fire)
            )
            link.add(to: .main, forMode: .common)
            DisplayLinkResumeBox.retain(link)
        }
    }
}

@MainActor
private final class DisplayLinkResumeBox: NSObject {
    private static var retainedLinks: [ObjectIdentifier: CADisplayLink] = [:]

    private let continuation: CheckedContinuation<Void, Never>
    private var didResume = false

    init(continuation: CheckedContinuation<Void, Never>) {
        self.continuation = continuation
    }

    static func retain(_ link: CADisplayLink) {
        retainedLinks[ObjectIdentifier(link)] = link
    }

    @objc func fire(_ link: CADisplayLink) {
        guard !didResume else { return }
        didResume = true
        link.invalidate()
        Self.retainedLinks.removeValue(forKey: ObjectIdentifier(link))
        continuation.resume()
    }
}

/// UIKit/Core Text bake that matches the previous SwiftUI `ImageRenderer` recipe without
/// paying SwiftUI layout on the display-link miss path.
enum CombatFeedbackRasterBaker {
    private static let horizontalPadding: CGFloat = 4
    private static let verticalPadding: CGFloat = 5
    private static let symbolTextSpacing: CGFloat = 8
    private static let shadowOffsetY: CGFloat = 1.5

    struct BakedRaster {
        let image: CGImage
        let pointSize: CGSize
    }

    @MainActor
    static func bake(
        canvasItem: CombatFeedbackCanvasItem,
        dynamicTypeSize: DynamicTypeSize,
        displayScale: CGFloat
    ) -> BakedRaster? {
        let item = canvasItem.item
        let style = item.feedbackVisualStyle
        let recipe = TrinketMotion.Battle.chip(for: item.feedbackClass)
        let scale = max(1, displayScale)
        let font = uiFont(
            recipe: recipe,
            dynamicTypeSize: dynamicTypeSize
        )
        let tint = UIColor(style.color)
        let shadow = UIColor(TrinketDesign.Colors.Overlay.ink.opacity(0.95))

        let symbolConfig = UIImage.SymbolConfiguration(font: font)
        guard let symbol = UIImage(
            systemName: style.symbolName,
            withConfiguration: symbolConfig
        )?.withTintColor(tint, renderingMode: .alwaysOriginal) else {
            return nil
        }

        let text = canvasItem.text as NSString
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: tint
        ]
        let textSize = text.size(withAttributes: textAttributes)
        let symbolSize = symbol.size
        let contentWidth = symbolSize.width + symbolTextSpacing + textSize.width
        let contentHeight = max(symbolSize.height, textSize.height)
        let pointSize = CGSize(
            width: ceil(contentWidth + horizontalPadding * 2),
            height: ceil(contentHeight + verticalPadding * 2 + shadowOffsetY)
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: pointSize, format: format)
        let image = renderer.image { _ in
            let contentOrigin = CGPoint(x: horizontalPadding, y: verticalPadding)
            let symbolOrigin = CGPoint(
                x: contentOrigin.x,
                y: contentOrigin.y + (contentHeight - symbolSize.height) / 2
            )
            let textOrigin = CGPoint(
                x: contentOrigin.x + symbolSize.width + symbolTextSpacing,
                y: contentOrigin.y + (contentHeight - textSize.height) / 2
            )

            let shadowContext = UIGraphicsGetCurrentContext()
            shadowContext?.setShadow(
                offset: CGSize(width: 0, height: shadowOffsetY),
                blur: 0,
                color: shadow.cgColor
            )
            symbol.draw(at: symbolOrigin)
            text.draw(at: textOrigin, withAttributes: textAttributes)
            shadowContext?.setShadow(offset: .zero, blur: 0, color: nil)
        }

        guard let cgImage = image.cgImage else { return nil }
        return BakedRaster(image: cgImage, pointSize: pointSize)
    }

    private static func uiFont(
        recipe: CombatFeedbackMotionRecipe,
        dynamicTypeSize: DynamicTypeSize
    ) -> UIFont {
        let textStyle = uiTextStyle(recipe.textStyle)
        let category = uiContentSizeCategory(dynamicTypeSize)
        let traits = UITraitCollection(preferredContentSizeCategory: category)
        let preferred = UIFont.preferredFont(forTextStyle: textStyle, compatibleWith: traits)
        let weight = uiWeight(recipe.fontWeight)
        let weighted = UIFont.systemFont(ofSize: preferred.pointSize, weight: weight)
        let roundedDescriptor = weighted.fontDescriptor.withDesign(.rounded) ?? weighted.fontDescriptor
        let monospacedDescriptor = roundedDescriptor.addingAttributes([
            .featureSettings: [[
                UIFontDescriptor.FeatureKey.type: kNumberSpacingType,
                UIFontDescriptor.FeatureKey.selector: kMonospacedNumbersSelector
            ]]
        ])
        return UIFont(descriptor: monospacedDescriptor, size: preferred.pointSize)
    }

    private static func uiTextStyle(_ style: Font.TextStyle) -> UIFont.TextStyle {
        switch style {
        case .largeTitle: .largeTitle
        case .title: .title1
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .body: .body
        case .callout: .callout
        case .subheadline: .subheadline
        case .footnote: .footnote
        case .caption: .caption1
        case .caption2: .caption2
        @unknown default: .title3
        }
    }

    private static func uiWeight(_ weight: Font.Weight) -> UIFont.Weight {
        switch weight {
        case .ultraLight: .ultraLight
        case .thin: .thin
        case .light: .light
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        case .black: .black
        default: .bold
        }
    }

    private static func uiContentSizeCategory(_ size: DynamicTypeSize) -> UIContentSizeCategory {
        switch size {
        case .xSmall: .extraSmall
        case .small: .small
        case .medium: .medium
        case .large: .large
        case .xLarge: .extraLarge
        case .xxLarge: .extraExtraLarge
        case .xxxLarge: .extraExtraExtraLarge
        case .accessibility1: .accessibilityMedium
        case .accessibility2: .accessibilityLarge
        case .accessibility3: .accessibilityExtraLarge
        case .accessibility4: .accessibilityExtraExtraLarge
        case .accessibility5: .accessibilityExtraExtraExtraLarge
        @unknown default: .large
        }
    }
}
