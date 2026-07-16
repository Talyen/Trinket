import QuartzCore
import SwiftUI
import TrinketDesignSystem
import UIKit

/// UIKit-backed chip host. Always mounted and refreshed through
/// `CombatFeedbackChipBridge` so chip publishes skip SwiftUI invalidation.
struct CombatFeedbackRasterSlot: View {
    let combatantID: String
    let dynamicTypeSize: DynamicTypeSize
    let displayScale: CGFloat

    var body: some View {
        CombatFeedbackRasterHost(
            combatantID: combatantID,
            dynamicTypeSize: dynamicTypeSize,
            displayScale: displayScale
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct CombatFeedbackRasterHost: UIViewRepresentable {
    let combatantID: String
    let dynamicTypeSize: DynamicTypeSize
    let displayScale: CGFloat

    func makeUIView(context _: Context) -> CombatFeedbackRasterUIView {
        let view = CombatFeedbackRasterUIView()
        CombatFeedbackChipBridge.register(
            view,
            combatantID: combatantID,
            dynamicTypeSize: dynamicTypeSize,
            displayScale: displayScale
        )
        return view
    }

    func updateUIView(_ uiView: CombatFeedbackRasterUIView, context _: Context) {
        CombatFeedbackChipBridge.register(
            uiView,
            combatantID: combatantID,
            dynamicTypeSize: dynamicTypeSize,
            displayScale: displayScale
        )
    }

    static func dismantleUIView(_ uiView: CombatFeedbackRasterUIView, coordinator _: ()) {
        CombatFeedbackChipBridge.unregister(uiView)
    }
}

final class CombatFeedbackRasterUIView: UIView {
    private struct ChipLayer {
        let imageView: UIImageView
        var canvasItem: CombatFeedbackCanvasItem
        var recipe: CombatFeedbackMotionRecipe
        var jitter: CGFloat
        var laneOffset: CGFloat
        var rasterIdentity: ObjectIdentifier?
    }

    private var displayLink: CADisplayLink?
    private var layers: [ChipLayer] = []
    private var presentedCanvasIDs: [Int] = []

    /// True while any chip is mounted (used by the bridge flush filter).
    var isPresenting: Bool {
        !layers.isEmpty
    }

    /// First presented canvas item, if any (compat for single-chip diagnostics).
    var canvasItem: CombatFeedbackCanvasItem? {
        layers.first?.canvasItem
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

    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        if newWindow == nil {
            stopDisplayLink()
        }
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

        let nextIDs = chips.map(\.canvasItem.id)
        guard nextIDs != presentedCanvasIDs else {
            for index in chips.indices where index < layers.count {
                layers[index].canvasItem = chips[index].canvasItem
            }
            return
        }
        presentedCanvasIDs = nextIDs

        let validChips = chips.compactMap { chip -> (CombatFeedbackCanvasItem, CombatFeedbackRaster)? in
            guard let raster = chip.raster else { return nil }
            return (chip.canvasItem, raster)
        }
        guard !validChips.isEmpty else {
            clearLayers()
            stopDisplayLink()
            return
        }

        rebuildLayers(from: validChips)
        if displayLink == nil {
            startDisplayLink()
        }
        tick()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        for layer in layers {
            layer.imageView.center = CGPoint(x: bounds.midX, y: bounds.midY)
        }
    }

    private func rebuildLayers(from chips: [(CombatFeedbackCanvasItem, CombatFeedbackRaster)]) {
        clearLayers()
        for (canvasItem, raster) in chips {
            let imageView = UIImageView()
            imageView.contentMode = .scaleToFill
            imageView.isUserInteractionEnabled = false
            imageView.image = UIImage(
                cgImage: raster.image,
                scale: raster.displayScale,
                orientation: .up
            )
            imageView.bounds = CGRect(origin: .zero, size: raster.pointSize)
            imageView.center = CGPoint(x: bounds.midX, y: bounds.midY)
            addSubview(imageView)

            let recipe = TrinketMotion.Battle.chip(for: canvasItem.item.feedbackClass)
            let jitter = CombatFeedbackLayout.horizontalOffset(
                seed: canvasItem.item.spawnSeed,
                jitter: recipe.horizontalJitter
            )
            let laneOffset = CombatFeedbackLayout.presentationOffset(
                index: canvasItem.item.presentationIndex
            )
            layers.append(ChipLayer(
                imageView: imageView,
                canvasItem: canvasItem,
                recipe: recipe,
                jitter: jitter,
                laneOffset: laneOffset,
                rasterIdentity: ObjectIdentifier(raster)
            ))
        }
    }

    private func clearLayers() {
        for layer in layers {
            layer.imageView.removeFromSuperview()
        }
        layers.removeAll(keepingCapacity: true)
        presentedCanvasIDs = []
    }

    private func startDisplayLink() {
        stopDisplayLink()
        let link = CADisplayLink(target: self, selector: #selector(handleDisplayLink))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func handleDisplayLink() {
        tick()
    }

    private func tick() {
        guard !layers.isEmpty else { return }
        let now = Date()
        for layer in layers {
            let item = layer.canvasItem.item
            let state = CombatFeedbackMotionSampler.state(
                for: item,
                recipe: layer.recipe,
                at: now
            )
            layer.imageView.alpha = state.opacity
            layer.imageView.transform = CGAffineTransform.identity
                .translatedBy(
                    x: state.horizontalOffset + layer.jitter,
                    y: state.verticalOffset + layer.laneOffset
                )
                .rotated(by: CGFloat(state.rotation * .pi / 180))
                .scaledBy(x: state.scale, y: state.scale)
        }
    }
}
