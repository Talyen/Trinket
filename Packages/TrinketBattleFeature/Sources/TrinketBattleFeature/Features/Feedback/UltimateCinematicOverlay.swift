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
    let onPlaying: () -> Void
    let onAutoFinish: (Int) -> Void
    let onCollapseFinished: (Int) -> Void

    @State private var splitProgress: CGFloat = 0
    @State private var showVideo = false
    @State private var didFinish = false
    @State private var collapseTask: Task<Void, Never>?
    @State private var fallbackHoldTask: Task<Void, Never>?
    @State private var videoRevealTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            // Absorbs hits for the whole presentation even when cover panels are open.
            Color.clear
                .contentShape(Rectangle())

            cinematicContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            DiagonalCinematicSplitCover(progress: splitProgress)
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
        withAnimation(TrinketMotion.Battle.ultimateSplitCloseAnimation) {
            splitProgress = 0
        }
        collapseTask?.cancel()
        collapseTask = Task { @MainActor in
            let clock = SuspendingClock()
            let duration = TrinketMotion.Battle.ultimateSplitClose
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
                effectsVolume: effectsVolume
            ) {
                guard !didFinish else { return }
                onAutoFinish(cinematicID)
            }
            withAnimation(TrinketMotion.Battle.ultimateSplitOpenAnimation) {
                splitProgress = 1
            }
            scheduleVideoWatchdog()
        }
    }

    private func scheduleVideoWatchdog() {
        fallbackHoldTask?.cancel()
        let cinematicID = cinematic.id
        let hold = max(
            TrinketMotion.Battle.ultimateFallbackHold,
            TrinketMotion.Battle.ultimateVideoWatchdog
        )
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

/// Two cinematicDim half-planes that peel apart along a diagonal seam.
private struct DiagonalCinematicSplitCover: View {
    var progress: CGFloat

    /// Top-left → bottom-right slash (~40° from vertical).
    private static let angleDegrees: CGFloat = 40
    private static let travelFactor: CGFloat = 0.6
    private static let seamWidth: CGFloat = 3

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let travel = max(size.width, size.height) * Self.travelFactor
            let angle = Self.angleDegrees * .pi / 180
            let normal = CGVector(dx: cos(angle), dy: -sin(angle))
            let offset = travel * progress
            coverLayers(size: size, normal: normal, offset: offset)
                .frame(width: size.width, height: size.height)
        }
    }

    @ViewBuilder
    private func coverLayers(size: CGSize, normal: CGVector, offset: CGFloat) -> some View {
        let primaryOffset = CGSize(width: -normal.dx * offset, height: -normal.dy * offset)
        let secondaryOffset = CGSize(width: normal.dx * offset, height: normal.dy * offset)
        ZStack {
            halfPlane(isPrimary: true)
                .offset(primaryOffset)
            halfPlane(isPrimary: false)
                .offset(secondaryOffset)
            seam(size: size)
        }
    }

    private func halfPlane(isPrimary: Bool) -> some View {
        DiagonalCinematicHalfPlane(isPrimary: isPrimary, angleDegrees: Self.angleDegrees)
            .fill(TrinketDesign.Colors.Overlay.cinematicDim)
    }

    private func seam(size: CGSize) -> some View {
        let seamOpacity = Double(
            max(0, 1 - progress) * (0.35 + 0.65 * min(progress * 4, 1))
        )
        let paper = TrinketDesign.Colors.Overlay.paper
        return Capsule()
            .fill(
                LinearGradient(
                    colors: [paper.opacity(0), paper.opacity(0.55), paper.opacity(0)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: hypot(size.width, size.height) * 1.2, height: Self.seamWidth)
            .rotationEffect(.degrees(Double(Self.angleDegrees)))
            .opacity(seamOpacity)
            .allowsHitTesting(false)
    }
}

/// Half-plane on one side of a diagonal cut through the screen center.
private struct DiagonalCinematicHalfPlane: Shape {
    var isPrimary: Bool
    var angleDegrees: CGFloat

    func path(in rect: CGRect) -> Path {
        let angle = angleDegrees * .pi / 180
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let along = CGVector(dx: sin(angle), dy: cos(angle))
        let normal = CGVector(dx: cos(angle), dy: -sin(angle))
        let extent = max(rect.width, rect.height) * 2.2
        let a = CGPoint(x: center.x - along.dx * extent, y: center.y - along.dy * extent)
        let b = CGPoint(x: center.x + along.dx * extent, y: center.y + along.dy * extent)
        let sign: CGFloat = isPrimary ? -1 : 1
        let c = CGPoint(x: b.x + normal.dx * extent * sign, y: b.y + normal.dy * extent * sign)
        let d = CGPoint(x: a.x + normal.dx * extent * sign, y: a.y + normal.dy * extent * sign)
        var path = Path()
        path.move(to: a)
        path.addLine(to: b)
        path.addLine(to: c)
        path.addLine(to: d)
        path.closeSubpath()
        return path
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
