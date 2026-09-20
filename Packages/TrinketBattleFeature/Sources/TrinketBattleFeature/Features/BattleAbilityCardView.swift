import BattleEngine
import SwiftUI
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureSupport

struct BattleAbilityCardView: View {
    let card: BattleCard
    let isPlayable: Bool
    let isDetailPresented: Bool
    let width: CGFloat
    let height: CGFloat
    let restingRotation: CGFloat
    let restingOffsetY: CGFloat
    let restingCenter: CGPoint
    let hapticsEnabled: Bool
    let onInspect: () -> Void
    let onPlay: (CardActivationRequest) -> Bool
    let onPlayDenied: () -> Void
    let onInteractionChanged: (Bool) -> Void
    var onLift: ((BattleCardCuePresentationMode) -> Void)?
    var onLiftCancel: (() -> Void)?

    @State private var dragTranslation: CGSize = .zero
    @State private var didExceedTapSlop = false
    @State private var interactionResolution: InteractionResolution = .idle
    @State private var didAnnounceWindUp = false
    @State private var availabilityFeedbackToken = 0
    @State private var inspectFeedbackToken = 0
    @State private var denyFeedbackToken = 0
    @State private var didAnnounceDeny = false
    @State private var didReportPlayDenied = false
    @GestureState private var isGestureActive = false
    @Environment(\.scenePhase) private var scenePhase

    private enum InteractionResolution {
        case idle
        case pressing
        case dragging
        case inspecting
        case cancelled
    }

    private var isHeld: Bool {
        switch interactionResolution {
        case .pressing, .dragging, .inspecting:
            true
        case .idle, .cancelled:
            false
        }
    }

    var body: some View {
        BattleAbilityCardFace(
            artworkName: card.ability.artReference?.imageName,
            width: width,
            height: height,
        )
        .equatable()
        .frame(width: width, height: height)
        .overlay { availabilityBorder }
        .animation(isHeld ? BattleMotion.cardLift : BattleMotion.cardReturn) { content in
            content
                .scaleEffect(x: heldScale.width, y: heldScale.height)
                .shadow(
                    color: isHeld ? TrinketDesign.Colors.Overlay.dragShadow.opacity(0.55) : .clear,
                    radius: BattleMotion.cardHeldShadowRadius,
                    y: BattleMotion.cardHeldShadowY,
                )
        }
        .rotationEffect(.degrees(activeRotation), anchor: .bottom)
        .rotation3DEffect(
            .degrees(verticalTilt),
            axis: (x: 1, y: 0, z: 0),
            anchor: .bottom,
            perspective: BattleMotion.cardPerspective,
        )
        .offset(activeOffset)
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named(BattleHandView.coordinateSpaceName))
                .updating($isGestureActive) { _, isActive, _ in
                    isActive = true
                }
                .onChanged(updateDrag)
                .onEnded(endDrag)
                .simultaneously(
                    with: LongPressGesture(
                        minimumDuration: BattleMotion.cardInspectHoldDuration,
                        maximumDistance: BattleCardGesturePolicy.dragMinimumDistance,
                    )
                    .onEnded { _ in beginInspection() },
                ),
        )
        .trinketSensoryFeedback(
            .impact(weight: .medium),
            trigger: inspectFeedbackToken,
            enabled: hapticsEnabled,
        )
        .trinketSensoryFeedback(
            .warning,
            trigger: denyFeedbackToken,
            enabled: hapticsEnabled,
        )
        .onDisappear {
            cancelInteraction()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase != .active else { return }
            cancelInteraction()
        }
        .onChange(of: isGestureActive) { wasActive, isActive in
            guard wasActive, !isActive,
                  interactionResolution != .idle,
                  interactionResolution != .inspecting else { return }
            returnDrag()
        }
        .onChange(of: isDetailPresented) { _, isPresented in
            guard !isPresented, interactionResolution == .inspecting else { return }
            returnDrag()
        }
        .onChange(of: isPlayable) { _, playable in
            if playable {
                availabilityFeedbackToken &+= 1
            } else if interactionResolution != .inspecting {
                cancelInteraction()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(card.ability.name)
        .accessibilityHint(isPlayable ? "Double tap to play this card" : "Not playable")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { requestPlay(.tap) }
        .accessibilityAction(named: "Inspect card") {
            guard interactionResolution == .idle else { return }
            presentInspection()
        }
        .accessibilityIdentifier(AccessibilityID.Battle.handCard(card.ability.id))
    }

    private var activeOffset: CGSize {
        let resting = restingTranslation
        return CGSize(
            width: resting.width + (isHeld ? dragTranslation.width : 0),
            height: resting.height + (isHeld ? dragTranslation.height : 0),
        )
    }

    private var restingTranslation: CGSize {
        CGSize(width: 0, height: height * BattleHandLayout.restingYFraction + restingOffsetY)
    }

    private var activeRotation: Double {
        guard isHeld else { return restingRotation }
        return restingRotation + BattleCardGesturePolicy.heldTilt(
            translation: dragTranslation,
            cardWidth: width,
            maximumDegrees: BattleMotion.cardHeldTiltDegrees,
        )
    }

    private var verticalTilt: Double {
        min(
            max(
                Double(-dragTranslation.height / height) * BattleMotion.cardVerticalTiltGain,
                -BattleMotion.cardVerticalTiltClamp,
            ),
            BattleMotion.cardVerticalTiltClamp,
        )
    }

    private var heldScale: CGSize {
        let scale = isHeld ? CGFloat(BattleMotion.cardHeldScale) : 1
        return CGSize(width: scale, height: scale)
    }

    private func updateDrag(_ value: DragGesture.Value) {
        guard scenePhase == .active,
              interactionResolution != .inspecting,
              interactionResolution != .cancelled else { return }

        if interactionResolution == .idle {
            interactionResolution = .pressing
            onInteractionChanged(true)
        }
        if !didExceedTapSlop,
           BattleCardGesturePolicy.exceedsTapSlop(translation: value.translation) {
            didExceedTapSlop = true
            interactionResolution = .dragging
            announceWindUpIfNeeded(mode: .preview)
        }
        dragTranslation = BattleCardGesturePolicy.presentationTranslation(
            value.translation,
            isPlayable: isPlayable,
            threshold: BattleCardGesturePolicy.playDragThreshold,
        )
        if !isPlayable {
            let crossedDenyThreshold = BattleCardGesturePolicy.shouldPlay(
                translation: value.translation,
                isPlayable: true,
            )
            if crossedDenyThreshold, !didAnnounceDeny {
                didAnnounceDeny = true
                reportPlayDeniedIfNeeded()
            } else if !crossedDenyThreshold {
                didAnnounceDeny = false
            }
        }
    }

    private func endDrag(_ value: DragGesture.Value) {
        guard scenePhase == .active,
              interactionResolution == .pressing || interactionResolution == .dragging else { return }
        dragTranslation = BattleCardGesturePolicy.presentationTranslation(value.translation, isPlayable: isPlayable)

        let isTap = BattleCardGesturePolicy.isTapGesture(
            translation: value.translation,
            didExceedTapSlop: didExceedTapSlop,
            minimumDistance: BattleCardGesturePolicy.dragMinimumDistance,
        )
        if isTap {
            requestPlay(.tap)
            return
        }

        let shouldPlay = BattleCardGesturePolicy.shouldPlay(
            translation: value.translation,
            isPlayable: true,
            threshold: BattleCardGesturePolicy.playDragThreshold,
        )
        if shouldPlay {
            requestPlay(.drag)
            return
        }
        returnDrag()
    }

    private func beginInspection() {
        guard interactionResolution == .pressing, !didExceedTapSlop else { return }
        presentInspection()
    }

    private func presentInspection() {
        guard scenePhase == .active, !isDetailPresented else { return }
        interactionResolution = .inspecting
        onInteractionChanged(true)
        inspectFeedbackToken &+= 1
        // Sheet dismissal owns the held appearance after the gesture hands off inspection.
        onInspect()
    }

    private func cancelInteraction() {
        returnDrag()
        // Ignore any remaining callbacks from the interrupted touch until it ends.
        if isGestureActive {
            interactionResolution = .cancelled
        }
    }

    private func returnDrag() {
        withAnimation(BattleMotion.cardReturn) {
            resetVisualState()
            interactionResolution = .idle
        }
        onInteractionChanged(false)
    }

    private func resetVisualState() {
        cancelAnnouncedWindUp()
        dragTranslation = .zero
        didExceedTapSlop = false
        didAnnounceDeny = false
        didReportPlayDenied = false
    }

    private enum PlayIntent {
        case tap
        case drag
    }

    private func requestPlay(_ intent: PlayIntent) {
        guard scenePhase == .active, !isDetailPresented,
              interactionResolution != .inspecting,
              interactionResolution != .cancelled else { return }
        guard isPlayable else {
            reportPlayDeniedIfNeeded()
            returnDrag()
            return
        }
        switch intent {
        case .tap: beginTapPlay()
        case .drag: beginPlay()
        }
    }

    private func beginPlay() {
        let center = BattleHandLayout.releaseCenter(
            restingCenter: restingCenter,
            dragTranslation: dragTranslation,
        )
        let request = CardActivationRequest(
            artworkName: card.ability.artReference?.imageName,
            center: center,
            size: CGSize(width: width, height: height),
            rotation: CGFloat(activeRotation * .pi / 180),
            verticalTilt: CGFloat(verticalTilt),
            scale: heldScale.width,
            perspective: BattleMotion.cardPerspective,
            keywords: card.ability.presentationKeywords,
        )
        publishPlay(request)
    }

    private func publishPlay(_ request: CardActivationRequest) {
        guard isPlayable else {
            reportPlayDeniedIfNeeded()
            returnDrag()
            return
        }
        let hadWindUp = didAnnounceWindUp
        didAnnounceWindUp = false
        interactionResolution = .idle
        onInteractionChanged(false)
        let didPlay = onPlay(request)
        if didPlay {
            resetVisualState()
            return
        }
        didAnnounceWindUp = hadWindUp
        returnDrag()
    }
}

private extension BattleAbilityCardView {
    var availabilityBorder: some View {
        TrinketDesign.cardShape
            .strokeBorder(
                TrinketDesign.Colors.accent.opacity(
                    isPlayable ? BattleMotion.cardReadyRingOpacity : 0,
                ),
                lineWidth: BattleMotion.cardReadyRingLineWidth,
            )
            .animation(TrinketMotion.Interaction.stateChange, value: isPlayable)
            .overlay {
                TrinketDesign.cardShape
                    .strokeBorder(TrinketDesign.Colors.accent, lineWidth: BattleMotion.cardReadyRingLineWidth)
                    .keyframeAnimator(initialValue: 0.0, trigger: availabilityFeedbackToken) { content, opacity in
                        content.opacity(isPlayable ? opacity : 0)
                    } keyframes: { _ in
                        LinearKeyframe(BattleMotion.cardReadyPulseOpacity, duration: 0.08)
                        CubicKeyframe(0, duration: TrinketMotion.Interaction.confirmationDuration)
                    }
            }
            .allowsHitTesting(false)
    }

    func beginTapPlay() {
        announceWindUpIfNeeded(mode: .tapCommit)
        beginPlay()
    }

    func announceWindUpIfNeeded(mode: BattleCardCuePresentationMode) {
        guard !didAnnounceWindUp, isPlayable else { return }
        didAnnounceWindUp = true
        onLift?(mode)
    }

    func cancelAnnouncedWindUp() {
        guard didAnnounceWindUp else { return }
        didAnnounceWindUp = false
        onLiftCancel?()
    }

    func reportPlayDeniedIfNeeded() {
        guard !isPlayable, !didReportPlayDenied else { return }
        didReportPlayDenied = true
        denyFeedbackToken &+= 1
        onPlayDenied()
    }
}

struct BattleAbilityCardFace: View, Equatable {
    let artworkName: String?
    var width: CGFloat?
    var height: CGFloat?
    var borderOpacity: Double = 1

    var body: some View {
        Group {
            if let artworkName {
                let image = Image.preparedAsset(named: artworkName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .decorativePreparedArtwork()
                if let width, let height {
                    image
                        .frame(width: width, height: height)
                        .clipped()
                } else {
                    image
                }
            } else {
                if let width, let height {
                    PlaceholderArtwork(.ability)
                        .frame(width: width, height: height)
                } else {
                    PlaceholderArtwork(.ability)
                }
            }
        }
        .combatantCardChrome(borderOpacity: borderOpacity)
    }
}
