import AVFoundation
import SwiftUI
import TrinketDesignSystem
import TrinketFeatureSupport
import UIKit

/// Full-screen Ultimate cinematic overlay (Hero/Companion). Video-only under a
/// diagonal split cover; unmapped casts never reach this view (session skips
/// them like animations-disabled).
struct UltimateCinematicOverlay: View {
    let cinematic: BattleCinematicPresentation
    let effectsVolume: Double
    var openingStyle: UltimateCinematicEnterStyle = .fade
    var exitStyle: UltimateCinematicExitStyle = .fade
    let onPlaying: () -> Void
    let onAutoFinish: (Int) -> Void
    let onCollapseFinished: (Int) -> Void

    @State private var splitProgress: CGFloat = 0
    @State private var showVideo = false
    @State private var didFinish = false
    @State private var collapseTask: Task<Void, Never>?
    @State private var fallbackHoldTask: Task<Void, Never>?
    @State private var videoRevealTask: Task<Void, Never>?
    /// Cover style follows the phase: opening style while revealing, exit style while closing.
    @State private var activeCoverStyle: UltimateCinematicExitStyle = .diagonalSplit

    var body: some View {
        ZStack {
            // Absorbs hits for the whole presentation even when cover panels are open.
            Color.clear
                .contentShape(Rectangle())

            cinematicContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            UltimateCinematicCoverView(style: activeCoverStyle, progress: splitProgress)
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
        .accessibilityIdentifier("Ultimate Cinematic \(cinematic.abilityName)")
        .battleFramePacingSignpost(
            BattleFramePacingSignposts.Name.ultimateCinematic,
            isActive: true
        )
        .onAppear {
            runEnter()
        }
        .onChange(of: cinematic.phase) { _, phase in
            if phase == .collapsing {
                runExit()
            }
        }
        .onDisappear {
            let shouldFlushCollapse = didFinish
            let collapseID = cinematic.id
            cancelPendingOverlayTasks()
            // Teardown can cancel the sleep task; flush so spectacle.presentationHoldCount still clears.
            if shouldFlushCollapse {
                onCollapseFinished(collapseID)
            }
        }
    }

    private var cinematicContent: some View {
        GeometryReader { geometry in
            ZStack {
                if showVideo, let player = BattleCinematicPlayer.shared.player(
                    for: cinematic.actorID,
                    abilityID: cinematic.abilityID
                ) {
                    CinematicVideoView(player: player)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
    }

    private func runEnter() {
        onPlaying()
        startVideoRevealIfNeeded()
    }

    private func runExit() {
        guard !didFinish else { return }
        didFinish = true
        fallbackHoldTask?.cancel()
        fallbackHoldTask = nil
        videoRevealTask?.cancel()
        videoRevealTask = nil
        BattleCinematicPlayer.shared.pause(
            actorID: cinematic.actorID,
            abilityID: cinematic.abilityID
        )

        let collapseID = cinematic.id
        // Already sealed (never opened / ready-failed): skip a dead close beat.
        if splitProgress <= 0.001 {
            onCollapseFinished(collapseID)
            return
        }

        // Keep the video layer mounted while closing so ability art never flashes underneath.
        activeCoverStyle = exitStyle
        withAnimation(TrinketMotion.Battle.ultimateSplitClosePlaybackAnimation) {
            splitProgress = 0
        }
        collapseTask?.cancel()
        collapseTask = Task { @MainActor in
            let clock = SuspendingClock()
            let duration = TrinketMotion.Battle.ultimateSplitCloseAtPlayback
            try? await clock.sleep(for: .seconds(duration), tolerance: .milliseconds(20))
            guard !Task.isCancelled else { return }
            onCollapseFinished(collapseID)
        }
    }

    private func startVideoRevealIfNeeded() {
        let actorID = cinematic.actorID
        let abilityID = cinematic.abilityID
        let cinematicID = cinematic.id
        guard BattleCinematicPlayer.shared.hasVideo(
            for: actorID,
            abilityID: abilityID
        ) else {
            onAutoFinish(cinematicID)
            return
        }
        videoRevealTask?.cancel()
        videoRevealTask = Task { @MainActor in
            let ready = await BattleCinematicPlayer.shared.whenReady(
                actorID: actorID,
                abilityID: abilityID
            )
            guard !Task.isCancelled, !didFinish else { return }
            guard ready else {
                onAutoFinish(cinematicID)
                return
            }
            showVideo = true
            BattleCinematicPlayer.shared.play(
                actorID: actorID,
                abilityID: abilityID,
                effectsVolume: effectsVolume,
                rate: Float(TrinketMotion.Battle.ultimateCinematicPlaybackSpeed)
            ) {
                guard !didFinish else { return }
                onAutoFinish(cinematicID)
            }
            activeCoverStyle = openingStyle.coverStyle
            withAnimation(TrinketMotion.Battle.ultimateSplitOpenPlaybackAnimation) {
                splitProgress = 1
            }
            scheduleVideoWatchdog()
        }
    }

    private func scheduleVideoWatchdog() {
        fallbackHoldTask?.cancel()
        let cinematicID = cinematic.id
        let hold = TrinketMotion.Battle.ultimateVideoWatchdog
        fallbackHoldTask = Task { @MainActor in
            let clock = SuspendingClock()
            try? await clock.sleep(for: .seconds(hold), tolerance: .milliseconds(40))
            guard !Task.isCancelled, !didFinish else { return }
            onAutoFinish(cinematicID)
        }
    }

    private func cancelPendingOverlayTasks() {
        collapseTask?.cancel()
        collapseTask = nil
        fallbackHoldTask?.cancel()
        fallbackHoldTask = nil
        videoRevealTask?.cancel()
        videoRevealTask = nil
    }
}

/// Thin AVPlayerLayer host without system playback chrome.
struct CinematicVideoView: UIViewRepresentable {
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
    // UIKit requires `class` (not `static`) for `layerClass` overrides.
    // swiftlint:disable:next static_over_final_class
    override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        // UIStyleCheck: allow - AVPlayerLayer host requires UIView subclass cast
        guard let playerLayer = layer as? AVPlayerLayer else {
            preconditionFailure("PlayerLayerView.layerClass must be AVPlayerLayer")
        }
        return playerLayer
    }
}
