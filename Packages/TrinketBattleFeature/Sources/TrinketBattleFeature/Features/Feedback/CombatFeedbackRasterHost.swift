import QuartzCore
import SwiftUI
import TrinketDesignSystem
import TrinketFeatureSupport
import UIKit

/// UIKit-backed chip host. Always mounted and refreshed through
/// `CombatFeedbackChipBridge` so chip publishes skip SwiftUI invalidation.
struct CombatFeedbackRasterSlot: View {
    @Environment(\.layoutDirection) private var layoutDirection

    let combatantID: String
    let cardHeight: CGFloat
    let displayScale: CGFloat

    var body: some View {
        CombatFeedbackRasterHost(
            combatantID: combatantID,
            cardHeight: cardHeight,
            layoutDirection: layoutDirection,
            displayScale: displayScale
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct CombatFeedbackRasterHost: UIViewRepresentable {
    let combatantID: String
    let cardHeight: CGFloat
    let layoutDirection: LayoutDirection
    let displayScale: CGFloat

    func makeUIView(context _: Context) -> CombatFeedbackRasterUIView {
        let view = CombatFeedbackRasterUIView()
        view.cardHeight = cardHeight
        CombatFeedbackChipBridge.register(
            view,
            combatantID: combatantID,
            layoutDirection: layoutDirection,
            displayScale: displayScale
        )
        return view
    }

    func updateUIView(_ uiView: CombatFeedbackRasterUIView, context _: Context) {
        uiView.cardHeight = cardHeight
        CombatFeedbackChipBridge.register(
            uiView,
            combatantID: combatantID,
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
        let layer: CALayer
        var item: CombatFeedbackItem
        let rasterIdentity: ObjectIdentifier

        init(
            layer: CALayer,
            item: CombatFeedbackItem,
            rasterIdentity: ObjectIdentifier
        ) {
            self.layer = layer
            self.item = item
            self.rasterIdentity = rasterIdentity
        }
    }

    static let preallocatedSlotCount = Int(ceil(
        TrinketMotion.Battle.chipDisplayDuration / TrinketMotion.Battle.feedbackStreamStagger
    )) + 1

    private var layersByID: [Int: ChipLayer] = [:]
    private var orderedLayers: [ChipLayer] = []
    private var reusableLayers: [CALayer] = []
    var cardHeight: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        clipsToBounds = false
        for _ in 0 ..< Self.preallocatedSlotCount {
            let chipLayer = makeLayer()
            layer.addSublayer(chipLayer)
            reusableLayers.append(chipLayer)
        }
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
    static var isMotionClockPaused: Bool {
        CombatFeedbackChipMotionClock.isPaused
    }

    @MainActor
    func apply(chips: [(item: CombatFeedbackItem, raster: CombatFeedbackRaster?)]) {
        let intervalState = BattleFramePacingSignposts.signposter.beginInterval(
            BattleFramePacingSignposts.Name.chipHostApply
        )
        defer {
            BattleFramePacingSignposts.signposter.endInterval(
                BattleFramePacingSignposts.Name.chipHostApply,
                intervalState
            )
        }

        let validChips = chips.compactMap { chip -> (CombatFeedbackItem, CombatFeedbackRaster)? in
            guard let raster = chip.raster else { return nil }
            return (chip.item, raster)
        }
        let nextIDs = Set(validChips.map(\.0.id))
        for id in Array(layersByID.keys) where !nextIDs.contains(id) {
            recycleLayer(id: id)
        }

        for (item, raster) in validChips {
            if let existing = layersByID[item.id],
               existing.rasterIdentity == ObjectIdentifier(raster) {
                existing.item = item
                continue
            }
            recycleLayer(id: item.id)
            insert(item: item, raster: raster)
        }

        orderedLayers = layersByID.values.sorted(by: Self.chipLayerOrder)

        if layersByID.isEmpty {
            CombatFeedbackChipMotionClock.unregister(self)
        } else {
            CombatFeedbackChipMotionClock.register(self)
            tickMotion(at: .now)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !bounds.isEmpty else { return }
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        withLayerActionsDisabled {
            for layer in layersByID.values {
                layer.layer.position = center
                // Reveal chips inserted before the host had a measured frame.
                if layer.layer.isHidden {
                    layer.layer.isHidden = false
                }
            }
        }
    }

    fileprivate func tickMotion(at date: Date) {
        let states = orderedLayers.map { chipLayer in
            sampledState(
                for: chipLayer.item,
                chipHeight: chipLayer.layer.bounds.height,
                at: date
            )
        }
        let verticalOffsets = Self.packedVerticalOffsets(
            desired: states.map { CGFloat($0.verticalOffset) },
            scaledHeights: zip(orderedLayers, states).map { chipLayer, state in
                chipLayer.layer.bounds.height * CGFloat(state.scale)
            }
        )

        withLayerActionsDisabled {
            for (index, chipLayer) in orderedLayers.enumerated() {
                let state = states[index]
                let transform = CGAffineTransform.identity
                    .translatedBy(x: 0, y: verticalOffsets[index])
                    .scaledBy(x: state.scale, y: state.scale)
                chipLayer.layer.transform = CATransform3DMakeAffineTransform(transform)
                chipLayer.layer.opacity = Float(state.opacity)
            }
        }
    }

    static func packedVerticalOffsets(
        desired: [CGFloat],
        scaledHeights: [CGFloat],
        gap: CGFloat = CombatFeedbackLayout.streamGap
    ) -> [CGFloat] {
        guard desired.count == scaledHeights.count, desired.count > 1 else {
            return desired
        }
        var resolved = desired
        for index in stride(from: desired.count - 2, through: 0, by: -1) {
            let maximumOlderOffset = resolved[index + 1]
                - (scaledHeights[index] + scaledHeights[index + 1]) / 2
                - gap
            resolved[index] = min(resolved[index], maximumOlderOffset)
        }
        return resolved
    }

    private static func chipLayerOrder(_ lhs: ChipLayer, _ rhs: ChipLayer) -> Bool {
        let lhsItem = lhs.item
        let rhsItem = rhs.item
        if lhsItem.availableAt == rhsItem.availableAt {
            return lhsItem.id < rhsItem.id
        }
        return lhsItem.availableAt < rhsItem.availableAt
    }

    /// Shared chip-motion sampling: travel distance from the host's card height
    /// plus the sampler state at `date`.
    private func sampledState(
        for item: CombatFeedbackItem,
        chipHeight: CGFloat,
        at date: Date
    ) -> CombatFeedbackAnimationState {
        let travelDistance = TrinketMotion.Battle.chipTravelDistance(
            cardHeight: cardHeight,
            chipHeight: chipHeight
        )
        return CombatFeedbackMotionSampler.state(
            for: item,
            travelDistance: travelDistance,
            at: date
        )
    }

    private func compositorPose(
        for item: CombatFeedbackItem,
        chipSize: CGSize,
        at date: Date
    ) -> (transform: CATransform3D, opacity: Double) {
        let state = sampledState(
            for: item,
            chipHeight: chipSize.height,
            at: date
        )
        let transform = CGAffineTransform.identity
            .translatedBy(x: 0, y: state.verticalOffset)
            .scaledBy(x: state.scale, y: state.scale)
        return (CATransform3DMakeAffineTransform(transform), state.opacity)
    }

    private func insert(item: CombatFeedbackItem, raster: CombatFeedbackRaster) {
        let chipLayer: CALayer
        if let reusable = reusableLayers.popLast() {
            chipLayer = reusable
        } else {
            chipLayer = makeLayer()
            layer.addSublayer(chipLayer)
        }
        let rasterID = ObjectIdentifier(raster)
        let hasMeasuredBounds = !bounds.isEmpty
        // Same recipe sampling as the old CAKeyframe path; driven by the shared
        // display-link clock so publish does not install animation groups.
        let pose = compositorPose(
            for: item,
            chipSize: raster.pointSize,
            at: .now
        )
        withLayerActionsDisabled {
            chipLayer.contents = raster.image
            chipLayer.contentsScale = raster.displayScale
            chipLayer.bounds = CGRect(origin: .zero, size: raster.pointSize)
            chipLayer.removeAllAnimations()
            chipLayer.transform = pose.transform
            chipLayer.opacity = Float(pose.opacity)
            if hasMeasuredBounds {
                chipLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
                chipLayer.isHidden = false
            } else {
                // Stay hidden until layoutSubviews can place us at the real center.
                chipLayer.isHidden = true
            }
        }

        layersByID[item.id] = ChipLayer(
            layer: chipLayer,
            item: item,
            rasterIdentity: rasterID
        )
    }

    private func makeLayer() -> CALayer {
        let chipLayer = CALayer()
        chipLayer.contentsGravity = .resize
        chipLayer.isHidden = true
        return chipLayer
    }

    private func recycleLayer(id: Int) {
        guard let layer = layersByID.removeValue(forKey: id) else { return }
        withLayerActionsDisabled {
            layer.layer.removeAllAnimations()
            layer.layer.contents = nil
            layer.layer.transform = CATransform3DIdentity
            layer.layer.opacity = 1
            layer.layer.isHidden = true
        }
        reusableLayers.append(layer.layer)
    }

    /// Display-link sampling must write model values without Core Animation's
    /// default ~0.25s implicit actions, or layout position corrections animate
    /// downward while the rise transform continues upward.
    private func withLayerActionsDisabled(_ updates: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        updates()
        CATransaction.commit()
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

    static var isPaused: Bool {
        displayLink?.isPaused ?? true
    }

    static func register(_ view: CombatFeedbackRasterUIView) {
        hosts[ObjectIdentifier(view)] = WeakHost(view: view)
        ensureDisplayLink()
        displayLink?.isPaused = false
    }

    static func unregister(_ view: CombatFeedbackRasterUIView) {
        hosts.removeValue(forKey: ObjectIdentifier(view))
        if hosts.isEmpty {
            displayLink?.isPaused = true
        }
    }

    /// Starts the shared motion clock before the first measured chip publish.
    static func prewarm() {
        ensureDisplayLink()
    }

    private static func ensureDisplayLink() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: tickTarget, selector: #selector(TickTarget.tick(_:)))
        link.add(to: .main, forMode: .common)
        link.isPaused = hosts.isEmpty
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
        if hosts.isEmpty {
            displayLink?.isPaused = true
        }
    }
}

@MainActor
private final class TickTarget: NSObject {
    @objc func tick(_: CADisplayLink) {
        CombatFeedbackChipMotionClock.handleTick()
    }
}
