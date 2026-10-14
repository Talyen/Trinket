import QuartzCore
import SwiftUI
import TrinketDesignSystem
import TrinketFeatureSupport
import UIKit

struct CombatFeedbackRasterSlot: View {
    @Environment(BattleSession.self) private var battleSession
    @Environment(\.layoutDirection) private var layoutDirection

    let combatantID: String
    let displayScale: CGFloat
    let bottomInset: CGFloat

    var body: some View {
        CombatFeedbackRasterHost(
            bridge: battleSession.feedback.chipBridge,
            combatantID: combatantID,
            layoutDirection: layoutDirection,
            displayScale: displayScale,
            bottomInset: bottomInset,
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct CombatFeedbackRasterHost: UIViewRepresentable {
    let bridge: CombatFeedbackChipBridge
    let combatantID: String
    let layoutDirection: LayoutDirection
    let displayScale: CGFloat
    let bottomInset: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(bridge: bridge)
    }

    @MainActor
    final class Coordinator {
        var bridge: CombatFeedbackChipBridge

        init(bridge: CombatFeedbackChipBridge) {
            self.bridge = bridge
        }
    }

    func makeUIView(context _: Context) -> CombatFeedbackRasterUIView {
        let view = CombatFeedbackRasterUIView()
        view.bottomInset = bottomInset
        bridge.register(
            view,
            combatantID: combatantID,
            layoutDirection: layoutDirection,
            displayScale: displayScale,
        )
        return view
    }

    func updateUIView(_ uiView: CombatFeedbackRasterUIView, context: Context) {
        if context.coordinator.bridge !== bridge {
            context.coordinator.bridge.unregister(uiView)
            context.coordinator.bridge = bridge
        }
        uiView.bottomInset = bottomInset
        bridge.register(
            uiView,
            combatantID: combatantID,
            layoutDirection: layoutDirection,
            displayScale: displayScale,
        )
    }

    static func dismantleUIView(_ uiView: CombatFeedbackRasterUIView, coordinator: Coordinator) {
        coordinator.bridge.unregister(uiView)
    }
}

final class CombatFeedbackRasterUIView: UIView {
    private final class ChipLayer {
        let layer: CALayer
        var item: CombatFeedbackItem
        var motionTrack: CombatFeedbackMotionTrack
        var rasterIdentity: ObjectIdentifier
        var reservationSize: CGSize = .zero
        var lanePush = StationaryFeedbackPush()
        var slot: StationaryFeedbackLayout.Slot?
        var basePosition: CGPoint = .zero

        init(
            layer: CALayer,
            item: CombatFeedbackItem,
            rasterIdentity: ObjectIdentifier,
            motionTrack: CombatFeedbackMotionTrack,
        ) {
            self.layer = layer
            self.item = item
            self.rasterIdentity = rasterIdentity
            self.motionTrack = motionTrack
        }
    }

    static let preallocatedSlotCount = 12

    var bottomInset: CGFloat = 0 {
        didSet {
            guard bottomInset != oldValue else { return }
            layoutStationary()
        }
    }

    var onEvict: ((Set<Int>) -> Void)?
    private struct LayoutInput: Equatable {
        let id: Int
        let region: CombatFeedbackRegion
        let reservationSize: CGSize
    }

    private var stationaryLayout = StationaryFeedbackLayout()
    private var lastLayoutInputs: [LayoutInput] = []
    private var lastLayoutBounds: CGRect?
    private var lastLayoutBottomInset: CGFloat?
    private var riseDistance: CGFloat = 0
    private var shineLayers: [ObjectIdentifier: CALayer] = [:]
    private var layersByID: [Int: ChipLayer] = [:]
    private var orderedLayers: [ChipLayer] = []
    private var reusableLayers: [CALayer] = []
    #if DEBUG
    private(set) var debugApplyCount = 0
    private(set) var debugLayoutCount = 0
    var debugLastAppliedChips: [CombatFeedbackItem] = []
    var debugVisibleChipIDs: Set<Int> {
        Set(layersByID.keys)
    }

    var debugIsMotionRegistered: Bool {
        CombatFeedbackChipMotionClock.isRegistered(self)
    }

    func debugTickMotion(at date: Date) {
        tickMotion(at: date)
    }
    #endif

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        clipsToBounds = true
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

    @MainActor
    static func prewarmMotionClock() {
        CombatFeedbackChipMotionClock.prewarm()
    }

    @MainActor
    func apply(
        chips: [(item: CombatFeedbackItem, raster: CombatFeedbackRaster?)],
        motionTracks: [Int: CombatFeedbackMotionTrack] = [:],
    ) {
        let intervalState = BattleFramePacingSignposts.signposter.beginInterval(
            BattleFramePacingSignposts.Name.chipHostApply,
        )
        defer {
            BattleFramePacingSignposts.signposter.endInterval(
                BattleFramePacingSignposts.Name.chipHostApply,
                intervalState,
            )
        }

        let validChips = chips.compactMap { chip -> (CombatFeedbackItem, CombatFeedbackRaster)? in
            guard let raster = chip.raster else { return nil }
            return (chip.item, raster)
        }
        #if DEBUG
        debugApplyCount += 1
        debugLastAppliedChips = validChips.map(\.0)
        #endif
        let nextIDs = Set(validChips.map(\.0.id))
        var orderChanged = false
        for id in Array(layersByID.keys) where !nextIDs.contains(id) {
            recycleLayer(id: id)
            orderChanged = true
        }

        for (item, raster) in validChips {
            if let existing = layersByID[item.id] {
                if existing.item.availableAt != item.availableAt || existing.item.presentationIndex != item.presentationIndex {
                    orderChanged = true
                }
                if existing.rasterIdentity != ObjectIdentifier(raster) {
                    withLayerActionsDisabled {
                        configureRaster(raster, on: existing.layer)
                    }
                    existing.rasterIdentity = ObjectIdentifier(raster)
                }
                existing.item = item
                if let sharedTrack = motionTracks[item.id] {
                    existing.motionTrack = sharedTrack
                }
                continue
            }
            insert(item: item, raster: raster, motionTrack: motionTracks[item.id] ?? CombatFeedbackMotionTrack())
            orderChanged = true
        }

        if orderChanged {
            orderedLayers = layersByID.values.sorted(by: Self.chipLayerOrder)
        }
        layoutStationary()

        tickMotion(at: .now)
        updateMotionClock()
    }

    func stopMotion() {
        CombatFeedbackChipMotionClock.unregister(self)
    }

    private func updateMotionClock() {
        if orderedLayers.allSatisfy({ $0.item.pausedAt != nil }) {
            stopMotion()
        } else {
            CombatFeedbackChipMotionClock.register(self)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !bounds.isEmpty else { return }
        layoutStationary()
        withLayerActionsDisabled {
            for layer in layersByID.values where layer.layer.isHidden {
                layer.layer.isHidden = false
            }
        }
        tickMotion(at: .now)
    }

    fileprivate func tickMotion(at date: Date) {
        guard !bounds.isEmpty else { return }
        withLayerActionsDisabled { tickStationary(at: date) }
    }

    private static func chipLayerOrder(_ lhs: ChipLayer, _ rhs: ChipLayer) -> Bool {
        let lhsItem = lhs.item
        let rhsItem = rhs.item
        if lhsItem.availableAt == rhsItem.availableAt {
            if lhsItem.presentationIndex != rhsItem.presentationIndex {
                return lhsItem.presentationIndex < rhsItem.presentationIndex
            }
            return lhsItem.id < rhsItem.id
        }
        return lhsItem.availableAt < rhsItem.availableAt
    }

    private func insert(item: CombatFeedbackItem, raster: CombatFeedbackRaster, motionTrack: CombatFeedbackMotionTrack) {
        let chipLayer: CALayer
        if let reusable = reusableLayers.popLast() {
            chipLayer = reusable
        } else {
            chipLayer = makeLayer()
            layer.addSublayer(chipLayer)
        }
        let rasterID = ObjectIdentifier(raster)
        let hasMeasuredBounds = !bounds.isEmpty
        let shadowColor = resolvedShadowColor
        withLayerActionsDisabled {
            configureRaster(raster, on: chipLayer)
            chipLayer.shadowColor = shadowColor
            chipLayer.shadowRadius = 8
            chipLayer.shadowOffset = .zero
            chipLayer.contentsScale = raster.displayScale
            chipLayer.bounds = CGRect(origin: .zero, size: raster.pointSize)
            chipLayer.removeAllAnimations()
            chipLayer.transform = CATransform3DIdentity
            chipLayer.opacity = 0
            if hasMeasuredBounds {
                chipLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
                chipLayer.isHidden = false
            } else {
                chipLayer.isHidden = true
            }
        }

        let chip = ChipLayer(layer: chipLayer, item: item, rasterIdentity: rasterID, motionTrack: motionTrack)
        chip.reservationSize = CGSize(
            width: raster.pointSize.width + max(0, CGFloat(item.reservedDigitCount) * raster.maximumDigitWidth - raster.textWidth),
            height: raster.pointSize.height,
        )
        layersByID[item.id] = chip
    }

    private func makeLayer() -> CALayer {
        let chipLayer = CALayer()
        chipLayer.contentsGravity = .resize
        chipLayer.isHidden = true
        return chipLayer
    }

    /// Resolves the chip shadow in this view's traits instead of a fresh
    /// `EnvironmentValues()`, so Dark Mode/tint overrides apply to shadows
    /// the same way they apply to composer tints.
    private var resolvedShadowColor: CGColor {
        var environment = EnvironmentValues()
        environment.colorScheme = traitCollection.userInterfaceStyle == .dark ? .dark : .light
        return TrinketDesign.Colors.accentEmphasized.resolve(in: environment).cgColor
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) else { return }
        let shadowColor = resolvedShadowColor
        withLayerActionsDisabled {
            for chip in layersByID.values {
                chip.layer.shadowColor = shadowColor
            }
        }
    }

    private func recycleLayer(id: Int) {
        guard let layer = layersByID.removeValue(forKey: id) else { return }
        withLayerActionsDisabled {
            layer.layer.removeAllAnimations()
            layer.layer.contents = nil
            if let shine = shineLayers[ObjectIdentifier(layer.layer)] {
                shine.isHidden = true
                shine.mask?.contents = nil
            }
            layer.layer.transform = CATransform3DIdentity
            layer.layer.opacity = 1
            layer.layer.isHidden = true
        }
        reusableLayers.append(layer.layer)
    }

    private func withLayerActionsDisabled(_ updates: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        updates()
        CATransaction.commit()
    }
}

private extension CombatFeedbackRasterUIView {
    private func configureRaster(_ raster: CombatFeedbackRaster, on chipLayer: CALayer) {
        chipLayer.contents = raster.image
        chipLayer.contentsScale = raster.displayScale
        chipLayer.bounds = CGRect(origin: .zero, size: raster.pointSize)
        let key = ObjectIdentifier(chipLayer)
        guard let mask = raster.shineMask else {
            shineLayers[key]?.isHidden = true
            shineLayers[key]?.mask?.contents = nil
            return
        }
        let shine: CALayer
        if let existing = shineLayers[key] {
            shine = existing
        } else {
            shine = CALayer()
            let gradient = CAGradientLayer()
            let environment = EnvironmentValues()
            gradient.colors = [0.0, 0.25, 1, 0.25, 0].map {
                TrinketDesign.Colors.Overlay.paper.opacity($0).resolve(in: environment).cgColor
            }
            gradient.locations = [0.2, 0.38, 0.5, 0.62, 0.8]
            gradient.startPoint = CGPoint(x: 0, y: 0.2)
            gradient.endPoint = CGPoint(x: 1, y: 0.8)
            shine.addSublayer(gradient)
            let flash = CALayer()
            flash.backgroundColor = TrinketDesign.Colors.Overlay.paper.resolve(in: environment).cgColor
            flash.opacity = 0
            shine.addSublayer(flash)
            shine.mask = CALayer()
            chipLayer.addSublayer(shine)
            shineLayers[key] = shine
        }
        shine.frame = chipLayer.bounds
        shine.sublayers?.forEach { $0.frame = shine.bounds }
        shine.mask?.frame = shine.bounds
        shine.mask?.contents = mask
        shine.mask?.contentsScale = raster.displayScale
        shine.isHidden = true
    }

    private func layoutStationary() {
        let inputs = orderedLayers.map {
            LayoutInput(id: $0.item.id, region: $0.item.region, reservationSize: $0.reservationSize)
        }
        guard inputs != lastLayoutInputs || bounds != lastLayoutBounds || bottomInset != lastLayoutBottomInset else { return }
        lastLayoutInputs = inputs
        lastLayoutBounds = bounds
        lastLayoutBottomInset = bottomInset
        #if DEBUG
        debugLayoutCount += 1
        #endif
        riseDistance = min(CombatFeedbackMotionSampler.riseDistance, max(0, bounds.height / 2 - 12))
        stationaryLayout.retain(ids: Set(orderedLayers.map(\.item.id)), in: bounds)
        for chip in orderedLayers {
            let sizeScale = StationaryFeedbackLayout.sizeScale
                * (chip.item.region == .impact ? 1 : CombatFeedbackMotionSampler.statusSizeScale)
            _ = stationaryLayout.place(id: chip.item.id, size: CGSize(
                width: chip.reservationSize.width * sizeScale,
                height: chip.reservationSize.height * sizeScale,
            ), region: chip.item.region, bottomInset: bottomInset)
        }
        let date = Date.now
        // Resolve after all placements, since new arrivals can push earlier slots.
        let slotsByID = Dictionary(uniqueKeysWithValues: stationaryLayout.slots.map { ($0.id, $0) })
        for chip in orderedLayers {
            chip.slot = slotsByID[chip.item.id]
            guard let slot = chip.slot else { continue }
            // Fitting geometry stays fixed between layout updates; only push and rise vary per frame.
            chip.basePosition = stationaryLayout.position(for: slot, push: 0, rise: 0, bottomInset: bottomInset)
            let elapsed = (chip.item.pausedAt ?? date).timeIntervalSince(chip.item.firstScheduledAt)
            chip.lanePush.retarget(to: slot.initialCenterY - slot.rect.midY, at: elapsed)
        }
    }

    private func tickStationary(at date: Date) {
        var evicted: Set<Int> = []
        for (index, chip) in orderedLayers.enumerated() {
            guard let slot = chip.slot else { continue }
            let sample = chip.motionTrack.sample(for: chip.item, at: date)
            let state = sample.animation
            let elapsed = sample.elapsed
            let scale = slot.fitScale * state.scale
            let position = CGPoint(
                x: chip.basePosition.x,
                y: chip.basePosition.y - chip.lanePush.offset(at: elapsed) - riseDistance * state.riseProgress,
            )
            let edgeOpacity = StationaryFeedbackLayout.edgeOpacity(centerY: position.y, in: bounds)
            if edgeOpacity == 0 {
                evicted.insert(chip.item.id)
            }
            updateLayer(chip.layer, position: position, scale: scale, opacity: Float(state.opacity * edgeOpacity), index: index)
            let shadowOpacity = sample.shadowOpacity
            if chip.layer.shadowOpacity != shadowOpacity {
                chip.layer.shadowOpacity = shadowOpacity
            }
            updateShine(for: chip, state: state, flashOpacity: sample.flashOpacity)
        }
        guard !evicted.isEmpty else { return }
        for id in evicted {
            recycleLayer(id: id)
        }
        orderedLayers.removeAll { evicted.contains($0.item.id) }
        lastLayoutBounds = nil
        updateMotionClock()
        onEvict?(evicted)
    }

    private func updateLayer(_ layer: CALayer, position: CGPoint, scale: CGFloat, opacity: Float, index: Int) {
        if layer.position != position {
            layer.position = position
        }
        let transform = CATransform3DMakeScale(scale, scale, 1)
        if !CATransform3DEqualToTransform(layer.transform, transform) {
            layer.transform = transform
        }
        if layer.opacity != opacity {
            layer.opacity = opacity
        }
        if layer.zPosition != CGFloat(index) {
            layer.zPosition = CGFloat(index)
        }
    }

    private func updateShine(for chip: ChipLayer, state: CombatFeedbackAnimationState, flashOpacity: Float) {
        if let shine = shineLayers[ObjectIdentifier(chip.layer)], shine.mask?.contents != nil {
            let isFinished = state.shineProgress >= 1 && flashOpacity == 0
            // Finished glints need no layer writes until a merge or critical hit restarts them.
            if isFinished, shine.isHidden {
                return
            }
            if shine.isHidden != isFinished {
                shine.isHidden = isFinished
            }
            if let gradient = shine.sublayers?.first {
                let isHidden = state.shineProgress >= 1
                if gradient.isHidden != isHidden {
                    gradient.isHidden = isHidden
                }
                let x = (-0.35 + state.shineProgress * 1.7) * chip.layer.bounds.width
                if gradient.position.x != x {
                    gradient.position.x = x
                }
            }
            if let flash = shine.sublayers?.last, flash.opacity != flashOpacity {
                flash.opacity = flashOpacity
            }
        }
    }
}

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
        displayLink?.isPaused = false
    }

    static func unregister(_ view: CombatFeedbackRasterUIView) {
        hosts.removeValue(forKey: ObjectIdentifier(view))
        if hosts.isEmpty {
            displayLink?.isPaused = true
        }
    }

    #if DEBUG
    static func isRegistered(_ view: CombatFeedbackRasterUIView) -> Bool {
        hosts[ObjectIdentifier(view)]?.view === view
    }
    #endif

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
