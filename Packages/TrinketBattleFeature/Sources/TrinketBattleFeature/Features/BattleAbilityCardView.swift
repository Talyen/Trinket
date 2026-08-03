import BattleEngine
import SwiftUI
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureSupport

struct BattleAbilityCardView: View {
    let card: BattleCard
    let isPlayable: Bool
    let width: CGFloat
    let height: CGFloat
    let restingRotation: CGFloat
    let restingOffsetY: CGFloat
    var configuration: BattleHandMotionConfiguration = .init()
    let restingCenter: CGPoint
    let hapticsEnabled: Bool
    /// When equal to `card.id`, mirrors the Auto Battle tap-lift rise.
    var autoLiftCardID: Int?
    let onInspect: () -> Void
    let onPlay: (CardActivationRequest) -> Bool
    let onInteractionChanged: (Bool) -> Void
    var onAttackWindUp: (() -> Void)?
    var onAttackCancel: (() -> Void)?

    @State private var dragTranslation: CGSize = .zero
    @State private var predictedEndTranslation: CGSize = .zero
    @State private var isPlayArmed = false
    @State private var didExceedTapSlop = false
    @State private var interactionResolution: InteractionResolution = .idle
    @State private var inspectionTask: Task<Void, Never>?
    @State private var didAnnounceWindUp = false
    @State private var playArmFeedbackToken = 0
    @State private var inspectFeedbackToken = 0
    @State private var denyFeedbackToken = 0
    @State private var didAnnounceDeny = false
    @State private var isTapLifting = false
    @State private var tapLiftTask: Task<Void, Never>?

    private enum InteractionResolution {
        case idle
        case pressing
        case dragging
        case inspecting
    }

    private var isDragging: Bool {
        switch interactionResolution {
        case .pressing, .dragging:
            true
        case .idle, .inspecting:
            false
        }
    }

    private var playDragThreshold: CGFloat {
        configuration.playDragThreshold
    }

    var body: some View {
        BattleAbilityCardFace(artworkName: card.ability.artReference?.imageName)
            .equatable()
            .frame(width: width, height: height)
            .opacity(isPlayable ? 1 : 0.45)
            .brightness(isPlayArmed ? configuration.armedBrightness : 0)
            .overlay {
                if isPlayArmed, configuration.showArmedRing {
                    TrinketDesign.cardShape
                        .stroke(
                            TrinketDesign.Colors.accent.opacity(configuration.armedRingOpacity),
                            lineWidth: configuration.armedRingLineWidth
                        )
                }
            }
            // Match CardCastEffectsLayer: scale → rotate → offset/position.
            .scaleEffect(x: activeScale.width, y: activeScale.height)
            .rotationEffect(.degrees(activeRotation), anchor: .bottom)
            .rotation3DEffect(
                .degrees(isDragging ? verticalTilt : 0),
                axis: (x: 1, y: 0, z: 0),
                anchor: .bottom,
                perspective: configuration.perspective
            )
            .offset(activeOffset)
            .offset(tapLiftOffset)
            .shadow(
                color: isDragging ? TrinketDesign.Colors.Overlay.dragShadow.opacity(0.55) : .clear,
                radius: configuration.cardHeldShadowRadius,
                y: configuration.cardHeldShadowY
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged(updateDrag)
                    .onEnded(endDrag)
            )
            .trinketSensoryFeedback(
                .selection,
                trigger: playArmFeedbackToken,
                enabled: hapticsEnabled
            )
            .trinketSensoryFeedback(
                .selection,
                trigger: inspectFeedbackToken,
                enabled: hapticsEnabled
            )
            .trinketSensoryFeedback(
                .warning,
                trigger: denyFeedbackToken,
                enabled: hapticsEnabled
            )
            .onDisappear {
                cancelInspection()
                cancelTapLift()
                onInteractionChanged(false)
            }
            .onAppear {
                syncAutoLift(autoLiftCardID)
            }
            .onChange(of: autoLiftCardID) { _, liftCardID in
                syncAutoLift(liftCardID)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier(AccessibilityID.Battle.handCard(card.ability.id))
            .accessibilityLabel(card.ability.name)
    }

    private var activeOffset: CGSize {
        let resting = restingTranslation
        return CGSize(
            width: resting.width + (isDragging ? dragTranslation.width : 0),
            height: resting.height + (isDragging ? dragTranslation.height : 0)
        )
    }

    /// Pop-up applied briefly when a tap starts a play, before the dissolve
    /// takes over. Matches the overlay handoff order (applied after rotation/3D).
    private var tapLiftOffset: CGSize {
        guard isTapLifting else { return .zero }
        return CGSize(width: 0, height: -height * configuration.tapLiftHeight)
    }

    private var restingTranslation: CGSize {
        CGSize(width: 0, height: height * configuration.restingYFraction + restingOffsetY)
    }

    private var activeRotation: Double {
        guard isDragging else { return restingRotation }
        return restingRotation + BattleHandLayout.heldTilt(
            translation: dragTranslation,
            predictedEndTranslation: predictedEndTranslation,
            cardWidth: width,
            maximumDegrees: configuration.effectiveHeldTiltDegrees
        )
    }

    private var verticalTilt: Double {
        min(
            max(
                Double(-dragTranslation.height / height) * configuration.verticalTiltGain,
                -configuration.verticalTiltClamp
            ),
            configuration.verticalTiltClamp
        )
    }

    private var heldScale: CGSize {
        guard isDragging else { return CGSize(width: 1, height: 1) }
        var base = configuration.cardHeldScale
        if isPlayArmed {
            base += configuration.armedScaleBoost
        }
        return CGSize(width: base, height: base)
    }

    private var activeScale: CGSize {
        heldScale
    }

    private func updateDrag(_ value: DragGesture.Value) {
        guard interactionResolution != .inspecting else { return }

        if interactionResolution == .idle {
            withAnimation(configuration.cardPress) {
                // The state transition drives the held-card scale and shadow.
                interactionResolution = .pressing
            }
            onInteractionChanged(true)
            scheduleInspection()
        }
        if !didExceedTapSlop,
           BattleHandLayout.exceedsTapSlop(
               translation: value.translation,
               minimumDistance: configuration.dragMinimumDistance
           ) {
            didExceedTapSlop = true
            cancelInspection()
            interactionResolution = .dragging
            if !didAnnounceWindUp, isPlayable {
                didAnnounceWindUp = true
                onAttackWindUp?()
            }
        }
        dragTranslation = BattleHandLayout.presentationTranslation(
            value.translation,
            isPlayable: isPlayable,
            threshold: playDragThreshold,
            denyOvershootFactor: configuration.denyOvershootFactor,
            denyWidthDamp: configuration.denyWidthDamp
        )
        predictedEndTranslation = value.predictedEndTranslation

        let armed = BattleHandLayout.shouldRemainPlayArmed(
            translation: value.translation,
            isPlayable: isPlayable,
            threshold: playDragThreshold,
            playArmReleaseRatio: configuration.playArmReleaseRatio,
            armedHorizontalAllowance: configuration.armedHorizontalAllowance,
            currentlyArmed: isPlayArmed
        )
        if armed != isPlayArmed {
            if armed {
                playArmFeedbackToken &+= 1
            }
            withAnimation(configuration.cardLift) {
                isPlayArmed = armed
            }
        }

        if !isPlayable {
            let release = value.predictedEndTranslation.height < value.translation.height
                ? value.predictedEndTranslation
                : value.translation
            let crossedDenyThreshold = -release.height >= playDragThreshold
                && -release.height > abs(release.width)
            if crossedDenyThreshold, !didAnnounceDeny {
                didAnnounceDeny = true
                denyFeedbackToken &+= 1
            } else if !crossedDenyThreshold {
                didAnnounceDeny = false
            }
        }
    }

    private func endDrag(_ value: DragGesture.Value) {
        guard interactionResolution != .inspecting else {
            cancelInspection()
            interactionResolution = .idle
            onInteractionChanged(false)
            return
        }
        cancelInspection()

        let isTap = BattleHandLayout.isTapGesture(
            translation: value.translation,
            didExceedTapSlop: didExceedTapSlop,
            minimumDistance: configuration.dragMinimumDistance
        )
        if isTap {
            if isPlayable {
                beginTapPlay()
            } else {
                returnDrag()
            }
            return
        }

        let shouldPlay = BattleHandLayout.shouldPlay(
            translation: value.translation,
            predictedEndTranslation: value.predictedEndTranslation,
            isPlayable: isPlayable,
            threshold: playDragThreshold
        )
        if shouldPlay {
            beginPlay()
            return
        }
        returnDrag()
    }

    private func beginInspection() {
        guard interactionResolution == .pressing,
              BattleHandLayout.shouldOpenAbilityDetail(
                  didRecognizeLongPress: true,
                  translation: dragTranslation,
                  didExceedTapSlop: didExceedTapSlop,
                  minimumDistance: configuration.dragMinimumDistance
              )
        else { return }

        cancelInspection()
        interactionResolution = .inspecting
        inspectFeedbackToken &+= 1
        resetVisualState()
        onInteractionChanged(false)
        onInspect()
    }

    private func scheduleInspection() {
        cancelInspection()
        let duration = configuration.detailLongPressDuration
        inspectionTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            beginInspection()
        }
    }

    private func cancelInspection() {
        inspectionTask?.cancel()
        inspectionTask = nil
    }

    private func returnDrag() {
        cancelInspection()
        resetVisualState()
        interactionResolution = .idle
        onInteractionChanged(false)
    }

    private func resetVisualState() {
        if didAnnounceWindUp {
            didAnnounceWindUp = false
            onAttackCancel?()
        }
        withAnimation(configuration.cardReturn) {
            dragTranslation = .zero
            predictedEndTranslation = .zero
            isPlayArmed = false
            didExceedTapSlop = false
            isTapLifting = false
        }
        cancelTapLift()
    }

    private func beginPlay() {
        // Layout math matches the unrotated scale+offset center the cast overlay
        // positions to (avoids per-frame geometry probe invalidation while dragging).
        let center = BattleHandLayout.releaseCenter(
            restingCenter: restingCenter,
            dragTranslation: dragTranslation
        )
        let request = CardActivationRequest(
            artworkName: card.ability.artReference?.imageName,
            center: center,
            size: CGSize(width: width, height: height),
            rotation: CGFloat(activeRotation * .pi / 180),
            verticalTilt: CGFloat(verticalTilt),
            scale: heldScale.width,
            perspective: configuration.perspective,
            keywords: card.ability.keywords
        )
        publishPlay(request)
    }

    private func publishPlay(_ request: CardActivationRequest) {
        cancelInspection()
        let hadWindUp = didAnnounceWindUp
        didAnnounceWindUp = false
        // End parent-held state before publishing the hand mutation. Otherwise
        // this card's onDisappear performs nested state work during sibling reflow.
        onInteractionChanged(false)
        let didPlay = onPlay(request)
        if didPlay {
            cancelTapLift()
            return
        }
        didAnnounceWindUp = hadWindUp
        returnDrag()
    }
}

private extension BattleAbilityCardView {
    func beginTapPlay() {
        guard tapLiftTask == nil else { return }
        withAnimation(configuration.tapLift) {
            isTapLifting = true
        }
        cancelTapLift()
        tapLiftTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(configuration.tapLiftPlayDelay))
            guard !Task.isCancelled else { return }
            publishTapPlay()
        }
    }

    func syncAutoLift(_ liftCardID: Int?) {
        let shouldLift = liftCardID == card.id
        guard shouldLift != isTapLifting else { return }
        if shouldLift {
            // Cancel a manual tap-lift task so Auto and tap cannot double-play.
            cancelTapLift()
        }
        withAnimation(configuration.tapLift) {
            isTapLifting = shouldLift
        }
    }

    func publishTapPlay() {
        let request = CardActivationRequest(
            artworkName: card.ability.artReference?.imageName,
            center: CGPoint(
                x: restingCenter.x + tapLiftOffset.width,
                y: restingCenter.y + tapLiftOffset.height
            ),
            size: CGSize(width: width, height: height),
            rotation: restingRotation * .pi / 180,
            verticalTilt: 0,
            scale: 1,
            perspective: configuration.perspective,
            keywords: card.ability.keywords
        )
        publishPlay(request)
    }

    func cancelTapLift() {
        tapLiftTask?.cancel()
        tapLiftTask = nil
    }
}

struct BattleAbilityCardFace: View, Equatable {
    let artworkName: String?

    @ScaledMetric(relativeTo: .title) private var placeholderIconSize =
        TrinketDesign.Metrics.cardPlaceholderIconPointSize

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.artworkName == rhs.artworkName
    }

    var body: some View {
        Group {
            if let artworkName {
                Image.preparedAsset(named: artworkName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .decorativePreparedArtwork()
            } else {
                ZStack {
                    TrinketDesign.CardPlaceholderStyle.ability.color.opacity(0.18)
                    Image(systemName: TrinketDesign.CardPlaceholderStyle.ability.symbolName)
                        .font(.system(size: placeholderIconSize, weight: .semibold))
                        .foregroundStyle(TrinketDesign.CardPlaceholderStyle.ability.color)
                }
            }
        }
        .clipShape(TrinketDesign.cardShape)
        .trinketCardSurface()
    }
}
