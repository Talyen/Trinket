import QuartzCore
import SwiftUI
import TrinketDesignSystem
import TrinketFeatureSupport
import UIKit

struct CombatFeedbackRasterSlot: View {
    @Environment(\.layoutDirection) private var layoutDirection

    let combatantID: String
    let cardHeight: CGFloat
    var isPartyMember = false
    let displayScale: CGFloat

    var body: some View {
        CombatFeedbackRasterHost(
            combatantID: combatantID,
            cardHeight: cardHeight,
            isPartyMember: isPartyMember,
            layoutDirection: layoutDirection,
            displayScale: displayScale,
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct CombatFeedbackRasterHost: UIViewRepresentable {
    let combatantID: String
    let cardHeight: CGFloat
    var isPartyMember = false
    let layoutDirection: LayoutDirection
    let displayScale: CGFloat

    func makeUIView(context _: Context) -> CombatFeedbackRasterUIView {
        let view = CombatFeedbackRasterUIView()
        view.cardHeight = cardHeight
        view.isPartyMember = isPartyMember
        CombatFeedbackChipBridge.register(
            view,
            combatantID: combatantID,
            layoutDirection: layoutDirection,
            displayScale: displayScale,
        )
        return view
    }

    func updateUIView(_ uiView: CombatFeedbackRasterUIView, context _: Context) {
        uiView.cardHeight = cardHeight
        uiView.isPartyMember = isPartyMember
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
        let rasterIdentity: ObjectIdentifier

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

    private var layersByID: [Int: ChipLayer] = [:]
    private var orderedLayers: [ChipLayer] = []
    private var reusableLayers: [CALayer] = []
    private struct Group {
        let layers: [ChipLayer]
        let offsets: [CGPoint]
        let height: CGFloat
        let fitScale: CGFloat
    }

    private var groups: [Group] = []
    var isPartyMember = false
    var cardHeight: CGFloat = 0
    #if DEBUG
    var debugLastAppliedChips: [CombatFeedbackItem] = []
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
    static var isMotionClockPaused: Bool {
        CombatFeedbackChipMotionClock.isPaused
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
            if let existing = layersByID[item.id],
               existing.rasterIdentity == ObjectIdentifier(raster) {
                existing.item = item
                continue
            }
            recycleLayer(id: item.id)
            insert(item: item, raster: raster)
        }

        orderedLayers = layersByID.values.sorted(by: Self.chipLayerOrder)
        layoutGroups()

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
        layoutGroups()
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

    private func layoutGroups() {
        let grouped = Dictionary(grouping: orderedLayers, by: { $0.item.actionGroupID })
        groups = grouped.values.sorted { $0[0].item.availableAt < $1[0].item.availableAt }.map { layers in
            let layers = layers.sorted {
                if $0.item.presentationIndex == $1.item.presentationIndex {
                    return $0.item.id < $1.item.id
                }
                return $0.item.presentationIndex < $1.item.presentationIndex
            }
            let gap: CGFloat = 6
            let width = layers.reduce(CGFloat.zero) { $0 + $1.layer.bounds.width + gap } - gap
            let rowCount = width * BattleMotion.chipMaximumScale <= bounds.width - 16 ? 1 : min(2, layers.count)
            let columns = (layers.count + rowCount - 1) / rowCount
            var offsets: [CGPoint] = []
            var height: CGFloat = 0
            var widest: CGFloat = 0
            for start in stride(from: 0, to: layers.count, by: columns) {
                let row = layers[start ..< min(start + columns, layers.count)]
                let rowWidth = row.reduce(CGFloat.zero) { $0 + $1.layer.bounds.width + gap } - gap
                let rowHeight = row.map(\.layer.bounds.height).max() ?? 0
                var x = -rowWidth / 2
                for chip in row {
                    offsets.append(CGPoint(x: x + chip.layer.bounds.width / 2, y: height + rowHeight / 2))
                    x += chip.layer.bounds.width + gap
                }
                height += rowHeight + gap
                widest = max(widest, rowWidth)
            }
            height = max(0, height - gap)
            offsets = offsets.map { CGPoint(x: $0.x, y: $0.y - height / 2) }
            let fit = min(
                1,
                max(0, bounds.width - 16) / max(1, widest * BattleMotion.chipMaximumScale),
                max(0, bounds.height - 16) / max(1, height * BattleMotion.chipMaximumScale),
            )
            return Group(layers: layers, offsets: offsets, height: height, fitScale: fit)
        }
    }

    fileprivate func tickMotion(at date: Date) {
        guard !bounds.isEmpty else { return }
        let current = groups.last(where: { $0.layers[0].item.retiringAt == nil })
        let currentHeight = (current?.height ?? 0) * (current?.fitScale ?? 1) * BattleMotion.chipMaximumScale
        let currentTravel = isPartyMember ? min(24, cardHeight * 0.12) : cardHeight * BattleMotion.chipTravelFraction
        let currentProgress = current.map {
            BattleMotion.chipMotionProgress(elapsed: max(0, date.timeIntervalSince($0.layers[0].item.firstScheduledAt)))
        } ?? 0
        let currentY = max(8 + currentHeight / 2, bounds.midY - currentTravel * currentProgress)
        withLayerActionsDisabled {
            for group in groups {
                let representative = group.layers[0].item
                let height = group.height * group.fitScale * BattleMotion.chipMaximumScale
                let desiredY = representative.retiringAt == nil ? currentY : currentY - currentHeight / 2 - height / 2 - 6
                let centerY = min(bounds.height - height / 2 - 8, max(height / 2 + 8, desiredY))
                for (index, chip) in group.layers.enumerated() {
                    let state = CombatFeedbackMotionSampler.state(for: chip.item, at: date)
                    let scale = group.fitScale * state.scale
                    let offset = group.offsets[index]
                    chip.layer.position = CGPoint(
                        x: bounds.midX + offset.x * group.fitScale * BattleMotion.chipMaximumScale,
                        y: centerY + offset.y * group.fitScale * BattleMotion.chipMaximumScale,
                    )
                    chip.layer.transform = CATransform3DMakeScale(scale, scale, 1)
                    let overlapsCurrent = representative.retiringAt != nil
                        && centerY + height / 2 > currentY - currentHeight / 2 - 6
                    chip.layer.opacity = overlapsCurrent ? 0 : Float(state.opacity)
                    let criticalElapsed = chip.item.criticalAt.map { max(0, date.timeIntervalSince($0)) } ?? 1
                    chip.layer.shadowOpacity = Float(max(0, 1 - criticalElapsed / 0.3))
                }
            }
        }
    }

    private static func chipLayerOrder(_ lhs: ChipLayer, _ rhs: ChipLayer) -> Bool {
        let lhsItem = lhs.item
        let rhsItem = rhs.item
        if lhsItem.availableAt == rhsItem.availableAt {
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
        withLayerActionsDisabled {
            chipLayer.contents = raster.image
            chipLayer.shadowColor = TrinketDesign.Colors.accentEmphasized.resolve(in: EnvironmentValues()).cgColor
            chipLayer.shadowRadius = 4
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

        layersByID[item.id] = ChipLayer(
            layer: chipLayer,
            item: item,
            rasterIdentity: rasterID,
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

    private func withLayerActionsDisabled(_ updates: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        updates()
        CATransaction.commit()
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
