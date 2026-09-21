import QuartzCore
import SwiftUI
import TrinketDesignSystem
import TrinketFeatureSupport
import UIKit

struct CombatFeedbackRasterSlot: View {
    @Environment(\.layoutDirection) private var layoutDirection

    let combatantID: String
    let displayScale: CGFloat
    let bottomInset: CGFloat

    var body: some View {
        CombatFeedbackRasterHost(
            combatantID: combatantID,
            layoutDirection: layoutDirection,
            displayScale: displayScale,
            bottomInset: bottomInset,
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct CombatFeedbackRasterHost: UIViewRepresentable {
    let combatantID: String
    let layoutDirection: LayoutDirection
    let displayScale: CGFloat
    let bottomInset: CGFloat

    func makeUIView(context _: Context) -> CombatFeedbackRasterUIView {
        let view = CombatFeedbackRasterUIView()
        view.bottomInset = bottomInset
        CombatFeedbackChipBridge.register(
            view,
            combatantID: combatantID,
            layoutDirection: layoutDirection,
            displayScale: displayScale,
        )
        return view
    }

    func updateUIView(_ uiView: CombatFeedbackRasterUIView, context _: Context) {
        uiView.bottomInset = bottomInset
        CombatFeedbackChipBridge.register(
            uiView,
            combatantID: combatantID,
            layoutDirection: layoutDirection,
            displayScale: displayScale,
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
        var rasterIdentity: ObjectIdentifier
        var reservationSize: CGSize = .zero
        var lanePush = StationaryFeedbackPush()

        init(
            layer: CALayer,
            item: CombatFeedbackItem,
            rasterIdentity: ObjectIdentifier,
        ) {
            self.layer = layer
            self.item = item
            self.rasterIdentity = rasterIdentity
        }
    }

    static let preallocatedSlotCount = 12

    var bottomInset: CGFloat = 0
    var onEvict: ((Set<Int>) -> Void)?
    private var stationaryLayout = StationaryFeedbackLayout()
    private var shineLayers: [ObjectIdentifier: CALayer] = [:]
    private var layersByID: [Int: ChipLayer] = [:]
    private var orderedLayers: [ChipLayer] = []
    private var reusableLayers: [CALayer] = []
    #if DEBUG
    var debugLastAppliedChips: [CombatFeedbackItem] = []
    var debugVisibleChipIDs: Set<Int> {
        Set(layersByID.keys)
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
    func apply(chips: [(item: CombatFeedbackItem, raster: CombatFeedbackRaster?)]) {
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
        debugLastAppliedChips = validChips.map(\.0)
        #endif
        let nextIDs = Set(validChips.map(\.0.id))
        for id in Array(layersByID.keys) where !nextIDs.contains(id) {
            recycleLayer(id: id)
        }

        for (item, raster) in validChips {
            if let existing = layersByID[item.id] {
                if existing.rasterIdentity != ObjectIdentifier(raster) {
                    withLayerActionsDisabled {
                        configureRaster(raster, on: existing.layer)
                    }
                    existing.rasterIdentity = ObjectIdentifier(raster)
                }
                existing.item = item
                continue
            }
            recycleLayer(id: item.id)
            insert(item: item, raster: raster)
        }

        orderedLayers = layersByID.values.sorted(by: Self.chipLayerOrder)
        layoutStationary()

        tickMotion(at: .now)
        if layersByID.isEmpty || orderedLayers.allSatisfy({ $0.item.pausedAt != nil }) {
            CombatFeedbackChipMotionClock.unregister(self)
        } else {
            CombatFeedbackChipMotionClock.register(self)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !bounds.isEmpty else { return }
        layoutStationary()
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        withLayerActionsDisabled {
            for layer in layersByID.values {
                layer.layer.position = center
                if layer.layer.isHidden {
                    layer.layer.isHidden = false
                }
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

        let chip = ChipLayer(layer: chipLayer, item: item, rasterIdentity: rasterID)
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
        stationaryLayout.retain(ids: Set(orderedLayers.map(\.item.id)), in: bounds)
        for chip in orderedLayers {
            let sizeScale = StationaryFeedbackLayout.sizeScale
                * (chip.item.region == .impact ? 1 : CombatFeedbackMotionSampler.statusSizeScale)
            _ = stationaryLayout.place(id: chip.item.id, size: CGSize(
                width: chip.reservationSize.width * sizeScale,
                height: chip.reservationSize.height * sizeScale,
            ), region: chip.item.region)
        }
        let date = Date.now
        for chip in orderedLayers {
            guard let slot = stationaryLayout.slots.first(where: { $0.id == chip.item.id }) else { continue }
            let elapsed = (chip.item.pausedAt ?? date).timeIntervalSince(chip.item.firstScheduledAt)
            chip.lanePush.retarget(to: slot.initialCenterY - slot.rect.midY, at: elapsed)
        }
    }

    private func tickStationary(at date: Date) {
        var evicted: Set<Int> = []
        for (index, chip) in orderedLayers.enumerated() {
            guard let slot = stationaryLayout.slots.first(where: { $0.id == chip.item.id }) else { continue }
            let state = CombatFeedbackMotionSampler.state(for: chip.item, at: date)
            let now = chip.item.pausedAt ?? date
            let elapsed = now.timeIntervalSince(chip.item.firstScheduledAt)
            let scale = slot.fitScale * state.scale
            let position = stationaryLayout.position(
                for: slot,
                renderedSize: CGSize(width: chip.layer.bounds.width * scale, height: chip.layer.bounds.height * scale),
                push: chip.lanePush.offset(at: elapsed),
                rise: min(CombatFeedbackMotionSampler.riseDistance, max(0, bounds.height / 2 - 12)) * state.riseProgress,
                bottomInset: bottomInset,
            )
            chip.layer.position = position
            let edgeOpacity = StationaryFeedbackLayout.edgeOpacity(centerY: position.y, in: bounds)
            if edgeOpacity == 0 {
                evicted.insert(chip.item.id)
            }
            chip.layer.transform = CATransform3DMakeScale(scale, scale, 1)
            chip.layer.opacity = Float(state.opacity * edgeOpacity)
            chip.layer.zPosition = CGFloat(index)
            let criticalElapsed = chip.item.criticalAt.map { max(0, now.timeIntervalSince($0)) } ?? 1
            chip.layer.shadowOpacity = Float(1 - BattleMotion.smoothProgress(criticalElapsed / 0.48))
            if let shine = shineLayers[ObjectIdentifier(chip.layer)] {
                let flashOpacity = Float(0.8 * (1 - BattleMotion.smoothProgress(criticalElapsed / 0.14)))
                shine.isHidden = state.shineProgress >= 1 && flashOpacity == 0
                shine.sublayers?.first?.isHidden = state.shineProgress >= 1
                shine.sublayers?.last?.opacity = flashOpacity
                let x = -0.35 + state.shineProgress * 1.7
                shine.sublayers?.first?.position.x = x * chip.layer.bounds.width
            }
        }
        for id in evicted {
            recycleLayer(id: id)
        }
        orderedLayers.removeAll { evicted.contains($0.item.id) }
        if !evicted.isEmpty {
            onEvict?(evicted)
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
