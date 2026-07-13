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
    let onAutoFinish: () -> Void
    let onCollapseFinished: () -> Void

    @State private var scrimOpacity = 0.0
    @State private var contentOpacity = 0.0
    @State private var showVideo = false
    @State private var skipHintVisible = false
    @State private var didFinish = false
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
        .onAppear {
            runEnter()
        }
        .onChange(of: cinematic.phase) { _, phase in
            if phase == .collapsing {
                runExit()
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
            Image(artRef.imageName)
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
        if !didStartVideo {
            scheduleFallbackHold()
        }
        scheduleSkipHint()
    }

    private func runExit() {
        guard !didFinish else { return }
        didFinish = true
        BattleCinematicPlayer.shared.pause(abilityID: cinematic.abilityID)
        withAnimation(TrinketMotion.Battle.ultimateCollapseAnimation) {
            scrimOpacity = 0
            contentOpacity = 0
            showVideo = false
            skipHintVisible = false
        }
        Task { @MainActor in
            let clock = SuspendingClock()
            let duration = TrinketMotion.Battle.ultimateCollapse
            try? await clock.sleep(for: .seconds(duration), tolerance: .milliseconds(20))
            onCollapseFinished()
        }
    }

    @discardableResult
    private func attemptVideoReveal() -> Bool {
        guard BattleCinematicPlayer.shared.hasVideo(for: cinematic.abilityID) else { return false }
        guard BattleCinematicPlayer.shared.isReady(for: cinematic.abilityID) else { return false }
        withAnimation(.easeInOut(duration: 0.2)) {
            showVideo = true
        }
        BattleCinematicPlayer.shared.play(
            abilityID: cinematic.abilityID,
            effectsVolume: effectsVolume
        ) {
            guard !didFinish else { return }
            onAutoFinish()
        }
        return true
    }

    private func scheduleFallbackHold() {
        Task { @MainActor in
            let clock = SuspendingClock()
            let hold = TrinketMotion.Battle.ultimateFallbackHold
            try? await clock.sleep(for: .seconds(hold), tolerance: .milliseconds(40))
            guard !didFinish else { return }
            onAutoFinish()
        }
    }

    private func scheduleSkipHint() {
        guard canSkip else { return }
        Task { @MainActor in
            let clock = SuspendingClock()
            try? await clock.sleep(
                for: .seconds(TrinketMotion.Battle.ultimateSkipLockout),
                tolerance: .milliseconds(20)
            )
            guard !didFinish, cinematic.phase != .collapsing else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                skipHintVisible = true
            }
        }
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
