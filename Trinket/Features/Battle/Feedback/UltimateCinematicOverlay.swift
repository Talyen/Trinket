import AVFoundation
import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import UIKit

/// Full-screen Ultimate cinematic overlay (Hero/Companion). Uses ability art immediately,
/// then crossfades to a preloaded video when available.
struct UltimateCinematicOverlay: View {
    let cinematic: BattleCinematicPresentation
    let canSkip: Bool
    let effectsVolume: Double
    let namespace: Namespace.ID
    let onPlaying: () -> Void
    let onRequestSkip: () -> Void
    let onAutoFinish: (Int) -> Void
    let onCollapseFinished: (Int) -> Void

    @State private var scrimOpacity = 0.0
    @State private var contentOpacity = 0.0
    @State private var showVideo = false
    @State private var skipHintVisible = false
    @State private var didFinish = false
    @State private var collapseTask: Task<Void, Never>?
    @State private var fallbackHoldTask: Task<Void, Never>?
    @State private var skipHintTask: Task<Void, Never>?
    @ScaledMetric(relativeTo: .largeTitle) private var fallbackStarSize: CGFloat = 64

    private var ability: Ability? {
        AbilityCatalog.ability(id: cinematic.abilityID)
    }

    var body: some View {
        ZStack {
            TrinketDesign.Colors.Overlay.cinematicDim
                .opacity(scrimOpacity * 0.72)
                .ignoresSafeArea()
                .allowsHitTesting(cinematic.phase != .collapsing)

            cinematicContent
                .opacity(contentOpacity)
                .matchedGeometryEffect(
                    id: "ultimate-source-\(cinematic.actorID)",
                    in: namespace,
                    isSource: false
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if canSkip, skipHintVisible, cinematic.phase == .playing {
                VStack {
                    Spacer()
                    Text("Tap to skip")
                        .trinketTypography(.badge)
                        .foregroundStyle(TrinketDesign.Colors.Overlay.paper.opacity(0.9))
                        .trinketGlassChip(.emphasis)
                        .padding(.bottom, 36)
                }
                .transition(.opacity)
                .allowsHitTesting(false)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard canSkip else { return }
            onRequestSkip()
        }

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
            // Teardown can cancel the sleep task; flush so presentationHoldCount still clears.
            if shouldFlushCollapse {
                onCollapseFinished(collapseID)
            }
        }
    }

    private var cinematicContent: some View {
        GeometryReader { geometry in
            let frame = Self.portraitFrame(in: geometry.size)
            ZStack {
                artLayer
                    .frame(width: frame.width, height: frame.height)
                    .clipShape(RoundedRectangle(
                        cornerRadius: 0,
                        style: .continuous
                    ))

                if showVideo, let player = BattleCinematicPlayer.shared.player(for: cinematic.abilityID) {
                    CinematicVideoView(player: player)
                        .frame(width: frame.width, height: frame.height)
                        .clipShape(RoundedRectangle(
                            cornerRadius: 0,
                            style: .continuous
                        ))
                        .transition(.opacity)
                }

                VStack {
                    Spacer()
                    Text(cinematic.abilityName)
                        .trinketTypography(.sectionDisplay)
                        .foregroundStyle(TrinketDesign.Colors.Overlay.paper)
                        .shadow(radius: 8)
                        .padding(.bottom, 28)
                }
                .frame(width: frame.width, height: frame.height)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var artLayer: some View {
        if let artRef = ability?.artReference {
            Image.preparedAsset(named: artRef.imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                cinematic.keyword.visualStyle.color.opacity(0.35)
                Image(systemName: "star.fill")
                    .font(.system(size: fallbackStarSize, weight: .bold))
                    .foregroundStyle(TrinketDesign.Colors.Overlay.paper)
            }
        }
    }

    private func runEnter() {
        withAnimation(TrinketMotion.Battle.scrim) {
            scrimOpacity = 1
        }
        withAnimation(TrinketMotion.Battle.ultimateExpand) {
            contentOpacity = 1
        }
        onPlaying()
        let didStartVideo = attemptVideoReveal()
        // Always arm a watchdog — video end/failure notifications can stall forever
        // with skip policy `.never`, soft-locking battle input and deferred victory.
        scheduleFallbackHold(forVideo: didStartVideo)
        scheduleSkipHint()
    }

    private func runExit() {
        guard !didFinish else { return }
        didFinish = true
        fallbackHoldTask?.cancel()
        fallbackHoldTask = nil
        skipHintTask?.cancel()
        skipHintTask = nil
        BattleCinematicPlayer.shared.pause(abilityID: cinematic.abilityID)
        withAnimation(TrinketMotion.Battle.ultimateCollapseAnimation) {
            scrimOpacity = 0
            contentOpacity = 0
            showVideo = false
            skipHintVisible = false
        }
        let collapseID = cinematic.id
        collapseTask?.cancel()
        collapseTask = Task { @MainActor in
            let clock = SuspendingClock()
            let duration = TrinketMotion.Battle.ultimateCollapse
            try? await clock.sleep(for: .seconds(duration), tolerance: .milliseconds(20))
            guard !Task.isCancelled else { return }
            onCollapseFinished(collapseID)
        }
    }

    @discardableResult
    private func attemptVideoReveal() -> Bool {
        guard BattleCinematicPlayer.shared.hasVideo(for: cinematic.abilityID) else { return false }
        guard BattleCinematicPlayer.shared.isReady(for: cinematic.abilityID) else { return false }
        withAnimation(.easeInOut(duration: 0.2)) {
            showVideo = true
        }
        let cinematicID = cinematic.id
        BattleCinematicPlayer.shared.play(
            abilityID: cinematic.abilityID,
            effectsVolume: effectsVolume
        ) {
            guard !didFinish else { return }
            onAutoFinish(cinematicID)
        }
        return true
    }

    private func scheduleFallbackHold(forVideo: Bool = false) {
        fallbackHoldTask?.cancel()
        let cinematicID = cinematic.id
        let hold = forVideo
            ? max(
                TrinketMotion.Battle.ultimateFallbackHold,
                TrinketMotion.Battle.ultimateVideoWatchdog
            )
            : TrinketMotion.Battle.ultimateFallbackHold
        fallbackHoldTask = Task { @MainActor in
            let clock = SuspendingClock()
            try? await clock.sleep(for: .seconds(hold), tolerance: .milliseconds(40))
            guard !Task.isCancelled, !didFinish else { return }
            onAutoFinish(cinematicID)
        }
    }

    private func scheduleSkipHint() {
        guard canSkip else { return }
        skipHintTask?.cancel()
        skipHintTask = Task { @MainActor in
            let clock = SuspendingClock()
            try? await clock.sleep(
                for: .seconds(TrinketMotion.Battle.ultimateSkipLockout),
                tolerance: .milliseconds(20)
            )
            guard !Task.isCancelled, !didFinish, cinematic.phase != .collapsing else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                skipHintVisible = true
            }
        }
    }

    private func cancelPendingOverlayTasks() {
        collapseTask?.cancel()
        collapseTask = nil
        fallbackHoldTask?.cancel()
        fallbackHoldTask = nil
        skipHintTask?.cancel()
        skipHintTask = nil
    }

    private static func portraitFrame(in size: CGSize) -> CGSize {
        let targetAspect = 9.0 / 16.0
        let screenAspect = size.width / max(size.height, 1)
        if screenAspect > targetAspect {
            let height = size.height
            return CGSize(width: height * targetAspect, height: height)
        }
        let width = size.width
        return CGSize(width: width, height: width / targetAspect)
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
