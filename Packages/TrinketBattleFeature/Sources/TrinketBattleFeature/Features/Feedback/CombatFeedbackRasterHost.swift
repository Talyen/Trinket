import QuartzCore
import SwiftUI
import TrinketDesignSystem
import TrinketFeatureSupport
import UIKit

struct CombatFeedbackRasterSlot: View {
    @Environment(\.layoutDirection) private var layoutDirection

    let combatantID: String
    let displayScale: CGFloat

    var body: some View {
        CombatFeedbackRasterHost(
            combatantID: combatantID,
            layoutDirection: layoutDirection,
            displayScale: displayScale,
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct CombatFeedbackRasterHost: UIViewRepresentable {
    let combatantID: String
    let layoutDirection: LayoutDirection
    let displayScale: CGFloat

    func makeUIView(context _: Context) -> CombatFeedbackRasterUIView {
        let view = CombatFeedbackRasterUIView()
        CombatFeedbackChipBridge.register(
            view,
            combatantID: combatantID,
            layoutDirection: layoutDirection,
            displayScale: displayScale,
        )
        return view
    }

    func updateUIView(_ uiView: CombatFeedbackRasterUIView, context _: Context) {
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
        var retiringOpacity = 1.0
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
        let motionItem: CombatFeedbackItem
        let placements: [Placement]
        let topRetention: CGFloat
    }

    private struct Placement {
        var offset: CGPoint
        let fitScale: CGFloat
    }

    private var groups: [Group] = []
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
                if existing.item.retiringAt == nil, let retiringAt = item.retiringAt {
                    existing.retiringOpacity = CombatFeedbackMotionSampler.state(for: existing.item, at: retiringAt).opacity
                }
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
        groups = grouped.values.sorted { Self.chipLayerOrder($0[0], $1[0]) }.map { layers in
            let layers = layers.sorted {
                if $0.item.presentationIndex == $1.item.presentationIndex {
                    return $0.item.id < $1.item.id
                }
                return $0.item.presentationIndex < $1.item.presentationIndex
            }
            let sizes = layers.map(\.layer.bounds.size)
            let fits = sizes.map { size in
                min(
                    1,
                    max(0, bounds.width - 16) / max(1, size.width * BattleMotion.chipMaximumScale),
                    max(0, bounds.height - 16) / max(1, size.height * BattleMotion.chipMaximumScale),
                )
            }
            let placements = placements(sizes: sizes, fits: fits)
            let topRetention = zip(sizes, placements).map { size, placement in
                size.height * placement.fitScale * 0.25 - placement.offset.y
            }.max() ?? 0
            var motionItem = layers[0].item
            motionItem.lastUpdatedAt = layers.compactMap(\.item.lastUpdatedAt).max()
            return Group(layers: layers, motionItem: motionItem, placements: placements, topRetention: topRetention)
        }
    }

    private func placements(sizes: [CGSize], fits: [CGFloat]) -> [Placement] {
        let gap: CGFloat = 6
        let availableWidth = max(0, bounds.width - 16) / BattleMotion.chipMaximumScale
        var rows: [[Int]] = []
        var row: [Int] = []
        var width: CGFloat = 0
        for index in sizes.indices {
            let chipWidth = sizes[index].width * fits[index]
            if !row.isEmpty, width + gap + chipWidth > availableWidth {
                rows.append(row)
                row = []
                width = 0
            }
            width += (row.isEmpty ? 0 : gap) + chipWidth
            row.append(index)
        }
        if !row.isEmpty {
            rows.append(row)
        }
        var placements: [Placement] = []
        var height: CGFloat = 0
        for row in rows {
            let rowWidth = row.reduce(CGFloat.zero) { $0 + sizes[$1].width * fits[$1] }
                + CGFloat(row.count - 1) * gap
            let rowHeight = row.map { sizes[$0].height * fits[$0] }.max() ?? 0
            var x = -rowWidth / 2
            for index in row {
                let chipWidth = sizes[index].width * fits[index]
                placements.append(Placement(
                    offset: CGPoint(x: x + chipWidth / 2, y: height + rowHeight / 2),
                    fitScale: fits[index],
                ))
                x += chipWidth + gap
            }
            height += rowHeight + gap
        }
        height = max(0, height - gap)
        return placements.map { placement in
            var centered = placement
            centered.offset.y -= height / 2
            return centered
        }
    }

    fileprivate func tickMotion(at date: Date) {
        guard !bounds.isEmpty else { return }
        withLayerActionsDisabled {
            for (groupIndex, group) in groups.enumerated() {
                let representative = group.motionItem
                let state = CombatFeedbackMotionSampler.state(for: representative, at: date)
                let progress = BattleMotion.chipMotionProgress(
                    elapsed: max(0, date.timeIntervalSince(representative.firstScheduledAt)),
                )
                let endY = max(bounds.height * 0.04, group.topRetention * BattleMotion.chipPopEndScale)
                let centerY = bounds.midY - max(0, bounds.midY - endY) * progress
                for (index, chip) in group.layers.enumerated() {
                    let placement = group.placements[index]
                    let scale = placement.fitScale * state.scale
                    let retention = chip.layer.bounds.height * scale * 0.25
                    let y = centerY + placement.offset.y * state.scale
                    chip.layer.position = CGPoint(
                        x: bounds.midX + placement.offset.x * state.scale,
                        y: min(bounds.height - retention, max(retention, y)),
                    )
                    chip.layer.transform = CATransform3DMakeScale(scale, scale, 1)
                    chip.layer.zPosition = CGFloat(groupIndex)
                    chip.layer.opacity = Float(state.opacity * chip.retiringOpacity)
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
