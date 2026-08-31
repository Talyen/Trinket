import AVFoundation
import SwiftUI
import TrinketDesignSystem
import TrinketFeatureSupport
import UIKit

struct UltimateInFrameView: View {
    let highlight: BattleUltimateInFramePresentation
    let effectsVolume: Double

    @State private var showVideo = false
    @State private var videoTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                keywordHighlight
                if showVideo, let player = BattleCinematicPlayer.shared.player(
                    for: highlight.actorID,
                    abilityID: highlight.abilityID,
                ) {
                    InFrameCinematicVideoView(player: player)
                        .transition(.opacity)
                }
            }
            .animation(.easeIn(duration: 0.18), value: showVideo)
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
            .clipShape(TrinketDesign.cardShape)
            .overlay {
                TrinketDesign.cardShape.strokeBorder(TrinketDesign.Colors.subtleStroke, lineWidth: 1)
                    .opacity(0.6)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            start()
        }
        .onDisappear {
            cleanup()
        }
        .onChange(of: highlight.id) { _, _ in
            cleanup()
            start()
        }
    }

    private var hasVideo: Bool {
        BattleCinematicPlayer.shared.hasVideo(for: highlight.actorID, abilityID: highlight.abilityID)
    }

    private var keywordHighlight: some View {
        ZStack {
            TrinketDesign.cardShape
                .fill(highlight.keyword.visualStyle.color.opacity(0.38))
            TrinketDesign.cardShape
                .fill(TrinketDesign.Colors.Overlay.paper.opacity(0.06))
        }
    }

    private func start() {
        guard hasVideo else {
            return
        }
        videoTask?.cancel()
        videoTask = Task { @MainActor in
            let ready = await BattleCinematicPlayer.shared.whenReady(
                actorID: highlight.actorID,
                abilityID: highlight.abilityID,
            )
            guard !Task.isCancelled else { return }
            guard ready else { return }
            showVideo = true
            BattleCinematicPlayer.shared.play(
                actorID: highlight.actorID,
                abilityID: highlight.abilityID,
                effectsVolume: effectsVolume,
                rate: Float(BattleMotion.ultimateCinematicPlaybackSpeed),
            ) {}
        }
    }

    private func cleanup() {
        videoTask?.cancel()
        videoTask = nil
        if hasVideo {
            BattleCinematicPlayer.shared.pause(actorID: highlight.actorID, abilityID: highlight.abilityID)
        }
        showVideo = false
    }
}

struct InFrameCinematicVideoView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context _: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PlayerLayerView, context _: Context) {
        uiView.playerLayer.player = player
    }
}

final class PlayerLayerView: UIView {
    override static var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        guard let playerLayer = layer as? AVPlayerLayer else {
            preconditionFailure("PlayerLayerView.layerClass must be AVPlayerLayer")
        }
        return playerLayer
    }
}
