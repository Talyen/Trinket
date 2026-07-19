import QuartzCore
import SwiftUI
import TrinketDesignSystem
import UIKit

/// UIKit-backed chip host. Always mounted and refreshed through
/// `CombatFeedbackChipBridge` so chip publishes skip SwiftUI invalidation.
struct CombatFeedbackRasterSlot: View {
    @Environment(\.layoutDirection) private var layoutDirection

    let combatantID: String
    let cardHeight: CGFloat
    let dynamicTypeSize: DynamicTypeSize
    let displayScale: CGFloat

    var body: some View {
        CombatFeedbackRasterHost(
            combatantID: combatantID,
            cardHeight: cardHeight,
            dynamicTypeSize: dynamicTypeSize,
            layoutDirection: layoutDirection,
            displayScale: displayScale
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct CombatFeedbackRasterHost: UIViewRepresentable {
    let combatantID: String
    let cardHeight: CGFloat
    let dynamicTypeSize: DynamicTypeSize
    let layoutDirection: LayoutDirection
    let displayScale: CGFloat

    func makeUIView(context _: Context) -> CombatFeedbackRasterUIView {
        let view = CombatFeedbackRasterUIView()
        view.cardHeight = cardHeight
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
        uiView.cardHeight = cardHeight
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
        let layer: CALayer
        var canvasItem: CombatFeedbackCanvasItem
        let rasterIdentity: ObjectIdentifier

        init(
            layer: CALayer,
            canvasItem: CombatFeedbackCanvasItem,
            rasterIdentity: ObjectIdentifier
        ) {
            self.layer = layer
            self.canvasItem = canvasItem
            self.rasterIdentity = rasterIdentity
        }
    }

    static let preallocatedSlotCount = CombatFeedbackLayout.maxVisibleIndividualChips + 1

    private var layersByID: [Int: ChipLayer] = [:]
    private var reusableLayers: [CALayer] = []
    var cardHeight: CGFloat = 0

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
            layer.layer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        }
    }

    fileprivate func tickMotion(at date: Date) {
        for layer in layersByID.values {
            let pose = compositorPose(
                for: layer.canvasItem,
                chipSize: layer.layer.bounds.size,
                at: date
            )
            layer.layer.transform = pose.transform
            layer.layer.opacity = Float(pose.opacity)
        }
    }

    private func insert(canvasItem: CombatFeedbackCanvasItem, raster: CombatFeedbackRaster) {
        let chipLayer: CALayer
        if let reusable = reusableLayers.popLast() {
            chipLayer = reusable
        } else {
            chipLayer = makeLayer()
            layer.addSublayer(chipLayer)
            CombatFeedbackRasterHostDiagnostics.noteWarmPathAllocation()
        }
        let rasterID = ObjectIdentifier(raster)
        chipLayer.contents = raster.image
        chipLayer.contentsScale = raster.displayScale
        chipLayer.bounds = CGRect(origin: .zero, size: raster.pointSize)
        chipLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        chipLayer.removeAllAnimations()
        // Same recipe sampling as the old CAKeyframe path; driven by the shared
        // display-link clock so publish does not install animation groups.
        let pose = compositorPose(
            for: canvasItem,
            chipSize: raster.pointSize,
            at: .now
        )
        chipLayer.transform = pose.transform
        chipLayer.opacity = Float(pose.opacity)
        chipLayer.isHidden = false

        layersByID[canvasItem.id] = ChipLayer(
            layer: chipLayer,
            canvasItem: canvasItem,
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
        layer.layer.removeAllAnimations()
        layer.layer.contents = nil
        layer.layer.transform = CATransform3DIdentity
        layer.layer.opacity = 1
        layer.layer.isHidden = true
        reusableLayers.append(layer.layer)
    }

    private func compositorPose(
        for canvasItem: CombatFeedbackCanvasItem,
        chipSize: CGSize,
        at date: Date
    ) -> (transform: CATransform3D, opacity: Double) {
        let item = canvasItem.item
        let travelDistance = TrinketMotion.Battle.chipTravelDistance(
            cardHeight: cardHeight,
            chipHeight: chipSize.height
        )
        let state = CombatFeedbackMotionSampler.state(
            for: item,
            travelDistance: travelDistance,
            at: date
        )
        let transform = CGAffineTransform.identity
            .translatedBy(x: 0, y: state.verticalOffset)
        return (CATransform3DMakeAffineTransform(transform), state.opacity)
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

struct CombatFeedbackHostSnapshot: Equatable, Sendable {
    let warmPathAllocationCount: Int
}

@MainActor
enum CombatFeedbackRasterHostDiagnostics {
    private static var warmPathAllocationCount = 0

    static func noteWarmPathAllocation() {
        warmPathAllocationCount += 1
    }

    static func reset() {
        warmPathAllocationCount = 0
    }

    static func snapshot() -> CombatFeedbackHostSnapshot {
        CombatFeedbackHostSnapshot(
            warmPathAllocationCount: warmPathAllocationCount
        )
    }
}

@MainActor
private final class TickTarget: NSObject {
    @objc func tick(_: CADisplayLink) {
        CombatFeedbackChipMotionClock.handleTick()
    }
}
