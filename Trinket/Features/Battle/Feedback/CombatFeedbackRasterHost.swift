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
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        for layer in layersByID.values {
            layer.imageView.center = CGPoint(x: bounds.midX, y: bounds.midY)
        }
    }

    private func insert(canvasItem: CombatFeedbackCanvasItem, raster: CombatFeedbackRaster) {
        let imageView = reusableImageViews.popLast() ?? makeImageView()
        imageView.image = UIImage(cgImage: raster.image, scale: raster.displayScale, orientation: .up)
        imageView.bounds = CGRect(origin: .zero, size: raster.pointSize)
        imageView.center = CGPoint(x: bounds.midX, y: bounds.midY)
        addSubview(imageView)

        layersByID[canvasItem.id] = ChipLayer(
            imageView: imageView,
            canvasItem: canvasItem,
            rasterIdentity: ObjectIdentifier(raster)
        )
        installCompositorAnimation(on: imageView, for: canvasItem)
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
        reusableImageViews.append(layer.imageView)
    }

    private func installCompositorAnimation(
        on imageView: UIImageView,
        for canvasItem: CombatFeedbackCanvasItem
    ) {
        let item = canvasItem.item
        let recipe = TrinketMotion.Battle.chip(for: item.feedbackClass)
        let now = Date()
        let elapsed = max(0, now.timeIntervalSince(item.availableAt))
        let duration = max(0.001, item.expiresAt.timeIntervalSince(now))
        let initialProgress = min(1, elapsed / max(item.lifetime, 0.001))
        let jitter = CombatFeedbackLayout.horizontalOffset(
            seed: item.spawnSeed,
            jitter: recipe.horizontalJitter
        )
        let laneOffset = CombatFeedbackLayout.presentationOffset(
            index: item.presentationIndex,
            spacing: recipe.stackSpacing
        )
        let fanOffset = CombatFeedbackLayout.presentationHorizontalFan(
            index: item.presentationIndex
        )
        let sampleCount = 20
        var transforms: [NSValue] = []
        var opacities: [NSNumber] = []
        var keyTimes: [NSNumber] = []

        for index in 0 ... sampleCount {
            let localProgress = Double(index) / Double(sampleCount)
            let sampleDate = item.availableAt.addingTimeInterval(
                item.lifetime * (initialProgress + (1 - initialProgress) * localProgress)
            )
            let state = CombatFeedbackMotionSampler.state(
                for: item,
                recipe: recipe,
                at: sampleDate
            )
            let transform = CGAffineTransform.identity
                .translatedBy(
                    x: state.horizontalOffset + jitter + fanOffset,
                    y: state.verticalOffset + laneOffset
                )
                .rotated(by: CGFloat(state.rotation * .pi / 180))
                .scaledBy(x: state.scale, y: state.scale)
            transforms.append(NSValue(caTransform3D: CATransform3DMakeAffineTransform(transform)))
            opacities.append(NSNumber(value: state.opacity))
            keyTimes.append(NSNumber(value: localProgress))
        }

        let transformAnimation = CAKeyframeAnimation(keyPath: "transform")
        transformAnimation.values = transforms
        transformAnimation.keyTimes = keyTimes
        let opacityAnimation = CAKeyframeAnimation(keyPath: "opacity")
        opacityAnimation.values = opacities
        opacityAnimation.keyTimes = keyTimes
        let group = CAAnimationGroup()
        group.animations = [transformAnimation, opacityAnimation]
        group.duration = duration
        group.timingFunction = CAMediaTimingFunction(name: .linear)
        group.isRemovedOnCompletion = true

        imageView.layer.transform = transforms.last?.caTransform3DValue ?? CATransform3DIdentity
        imageView.layer.opacity = opacities.last?.floatValue ?? 0
        imageView.layer.add(group, forKey: "combat-feedback")
    }
}
