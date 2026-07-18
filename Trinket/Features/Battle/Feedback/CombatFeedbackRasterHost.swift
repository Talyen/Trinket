import QuartzCore
import SwiftUI
import TrinketDesignSystem
import UIKit

/// UIKit-backed chip host. Always mounted and refreshed through
/// `CombatFeedbackChipBridge` so chip publishes skip SwiftUI invalidation.
struct CombatFeedbackRasterSlot: View {
    @Environment(\.layoutDirection) private var layoutDirection

    let combatantID: String
    let dynamicTypeSize: DynamicTypeSize
    let displayScale: CGFloat

    var body: some View {
        CombatFeedbackRasterHost(
            combatantID: combatantID,
            dynamicTypeSize: dynamicTypeSize,
            layoutDirection: layoutDirection,
            displayScale: displayScale
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct CombatFeedbackRasterHost: UIViewRepresentable {
    let combatantID: String
    let dynamicTypeSize: DynamicTypeSize
    let layoutDirection: LayoutDirection
    let displayScale: CGFloat

    func makeUIView(context _: Context) -> CombatFeedbackRasterUIView {
        let view = CombatFeedbackRasterUIView()
        CombatFeedbackChipBridge.register(
            view,
            combatantID: combatantID,
            dynamicTypeSize: dynamicTypeSize,
            layoutDirection: layoutDirection,
            displayScale: displayScale
        )
        return view
    }

    func updateUIView(_ uiView: CombatFeedbackRasterUIView, context _: Context) {
        CombatFeedbackChipBridge.register(
            uiView,
            combatantID: combatantID,
            dynamicTypeSize: dynamicTypeSize,
            layoutDirection: layoutDirection,
            displayScale: displayScale
        )
    }

    static func dismantleUIView(_ uiView: CombatFeedbackRasterUIView, coordinator _: ()) {
        CombatFeedbackChipBridge.unregister(uiView)
    }
}

final class CombatFeedbackRasterUIView: UIView {
    private final class ChipLayer {
        let imageView: UIImageView
        var canvasItem: CombatFeedbackCanvasItem
        let rasterIdentity: ObjectIdentifier

        init(
            imageView: UIImageView,
            canvasItem: CombatFeedbackCanvasItem,
            rasterIdentity: ObjectIdentifier
        ) {
            self.imageView = imageView
            self.canvasItem = canvasItem
            self.rasterIdentity = rasterIdentity
        }
    }

    private var layersByID: [Int: ChipLayer] = [:]
    private var reusableImageViews: [UIImageView] = []
    private var cachedUIImages: [ObjectIdentifier: UIImage] = [:]

    /// True while any chip is mounted (used by the bridge flush filter).
    var isPresenting: Bool {
        !layersByID.isEmpty
    }

    /// First presented canvas item, if any (compat for single-chip diagnostics).
    var canvasItem: CombatFeedbackCanvasItem? {
        layersByID.values.first?.canvasItem
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        clipsToBounds = false
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Keeps the shared display-link motion clock resident before measured publishes.
    @MainActor
    static func prewarmMotionClock() {
        CombatFeedbackChipMotionClock.prewarm()
    }

    @MainActor
    func apply(chips: [(canvasItem: CombatFeedbackCanvasItem, raster: CombatFeedbackRaster?)]) {
        let intervalState = BattleFramePacingSignposts.signposter.beginInterval(
            BattleFramePacingSignposts.Name.chipHostApply
        )
        defer {
            BattleFramePacingSignposts.signposter.endInterval(
                BattleFramePacingSignposts.Name.chipHostApply,
                intervalState
            )
        }

        let validChips = chips.compactMap { chip -> (CombatFeedbackCanvasItem, CombatFeedbackRaster)? in
            guard let raster = chip.raster else { return nil }
            return (chip.canvasItem, raster)
        }
        let nextIDs = Set(validChips.map(\.0.id))
        for id in Array(layersByID.keys) where !nextIDs.contains(id) {
            recycleLayer(id: id)
        }

        for (canvasItem, raster) in validChips {
            if let existing = layersByID[canvasItem.id],
               existing.rasterIdentity == ObjectIdentifier(raster) {
                existing.canvasItem = canvasItem
                continue
            }
            recycleLayer(id: canvasItem.id)
            insert(canvasItem: canvasItem, raster: raster)
        }

        if layersByID.isEmpty {
            CombatFeedbackChipMotionClock.unregister(self)
        } else {
            CombatFeedbackChipMotionClock.register(self)
            tickMotion(at: .now)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        for layer in layersByID.values {
            layer.imageView.center = CGPoint(x: bounds.midX, y: bounds.midY)
        }
    }

    fileprivate func tickMotion(at date: Date) {
        for layer in layersByID.values {
            let pose = compositorPose(for: layer.canvasItem, at: date)
            layer.imageView.layer.transform = pose.transform
            layer.imageView.layer.opacity = Float(pose.opacity)
        }
    }

    private func insert(canvasItem: CombatFeedbackCanvasItem, raster: CombatFeedbackRaster) {
        let imageView = reusableImageViews.popLast() ?? makeImageView()
        let rasterID = ObjectIdentifier(raster)
        if let cached = cachedUIImages[rasterID] {
            imageView.image = cached
        } else {
            let image = UIImage(cgImage: raster.image, scale: raster.displayScale, orientation: .up)
            cachedUIImages[rasterID] = image
            imageView.image = image
        }
        imageView.bounds = CGRect(origin: .zero, size: raster.pointSize)
        imageView.center = CGPoint(x: bounds.midX, y: bounds.midY)
        imageView.layer.removeAllAnimations()
        // Same recipe sampling as the old CAKeyframe path; driven by the shared
        // display-link clock so publish does not install animation groups.
        let pose = compositorPose(for: canvasItem, at: .now)
        imageView.layer.transform = pose.transform
        imageView.layer.opacity = Float(pose.opacity)
        addSubview(imageView)

        layersByID[canvasItem.id] = ChipLayer(
            imageView: imageView,
            canvasItem: canvasItem,
            rasterIdentity: rasterID
        )
    }

    private func makeImageView() -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleToFill
        imageView.isUserInteractionEnabled = false
        return imageView
    }

    private func recycleLayer(id: Int) {
        guard let layer = layersByID.removeValue(forKey: id) else { return }
        layer.imageView.layer.removeAllAnimations()
        layer.imageView.removeFromSuperview()
        layer.imageView.image = nil
        layer.imageView.alpha = 1
        layer.imageView.transform = .identity
        layer.imageView.layer.transform = CATransform3DIdentity
        layer.imageView.layer.opacity = 1
        reusableImageViews.append(layer.imageView)
    }

    private func compositorPose(
        for canvasItem: CombatFeedbackCanvasItem,
        at date: Date
    ) -> (transform: CATransform3D, opacity: Double) {
        let item = canvasItem.item
        let recipe = TrinketMotion.Battle.chip(for: item.feedbackClass)
        let count = max(1, item.groupResultCount)
        let spacing = CombatFeedbackLayout.presentationSpacing(forCount: count)
        let jitter = CombatFeedbackLayout.horizontalOffset(
            seed: item.spawnSeed,
            jitter: recipe.horizontalJitter
        )
        let laneOffset = CombatFeedbackLayout.presentationOffset(
            index: item.presentationIndex,
            count: count,
            spacing: spacing
        )
        let fanOffset = CombatFeedbackLayout.presentationHorizontalFan(
            index: item.presentationIndex,
            count: count
        )
        let floatScale = CombatFeedbackLayout.floatTravelScale(forCount: count)
        var state = CombatFeedbackMotionSampler.state(
            for: item,
            recipe: recipe,
            at: date
        )
        state.verticalOffset *= Double(floatScale)
        state.horizontalOffset *= Double(floatScale)

        let rawX = state.horizontalOffset + jitter + fanOffset
        let rawY = state.verticalOffset + laneOffset
        let clamped = clampToSlot(
            x: rawX,
            y: rawY,
            scale: state.scale,
            chipSize: layersByID[canvasItem.id]?.imageView.bounds.size
                ?? CGSize(width: 80, height: 40)
        )
        let transform = CGAffineTransform.identity
            .translatedBy(x: clamped.x, y: clamped.y)
            .rotated(by: CGFloat(state.rotation * .pi / 180))
            .scaledBy(x: state.scale, y: state.scale)
        return (CATransform3DMakeAffineTransform(transform), state.opacity)
    }

    /// Keeps chip centers inside the feedback slot so dense packs do not drift
    /// under the portrait or past the card edges.
    private func clampToSlot(
        x: CGFloat,
        y: CGFloat,
        scale: Double,
        chipSize: CGSize
    ) -> CGPoint {
        let margin: CGFloat = 4
        let halfW = max(chipSize.width * CGFloat(scale) / 2, 12)
        let halfH = max(chipSize.height * CGFloat(scale) / 2, 12)
        let limitX = max(0, bounds.width / 2 - halfW - margin)
        let limitY = max(0, bounds.height / 2 - halfH - margin)
        return CGPoint(
            x: min(max(x, -limitX), limitX),
            y: min(max(y, -limitY), limitY)
        )
    }
}

/// One display-link clock for every chip host. Samples the same motion recipes
/// the previous CAKeyframe path used, without installing animation groups on publish.
@MainActor
private enum CombatFeedbackChipMotionClock {
    private static var hosts: [ObjectIdentifier: WeakHost] = [:]
    private static var displayLink: CADisplayLink?
    private static let tickTarget = TickTarget()

    private struct WeakHost {
        weak var view: CombatFeedbackRasterUIView?
    }

    static func register(_ view: CombatFeedbackRasterUIView) {
        hosts[ObjectIdentifier(view)] = WeakHost(view: view)
        ensureDisplayLink()
    }

    static func unregister(_ view: CombatFeedbackRasterUIView) {
        hosts.removeValue(forKey: ObjectIdentifier(view))
        // Keep the display link resident once started. Recreating CADisplayLink on
        // the next ChipHostApply was a measured publish-frame stall.
    }

    /// Starts the shared motion clock before the first measured chip publish.
    static func prewarm() {
        ensureDisplayLink()
    }

    private static func ensureDisplayLink() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: tickTarget, selector: #selector(TickTarget.tick(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    fileprivate static func handleTick() {
        let now = Date()
        var stale: [ObjectIdentifier] = []
        for (key, entry) in hosts {
            guard let view = entry.view else {
                stale.append(key)
                continue
            }
            view.tickMotion(at: now)
        }
        for key in stale {
            hosts.removeValue(forKey: key)
        }
    }
}

@MainActor
private final class TickTarget: NSObject {
    @objc func tick(_: CADisplayLink) {
        CombatFeedbackChipMotionClock.handleTick()
    }
}
