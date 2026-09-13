import BattleEngine
import SwiftUI
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureSupport

// swiftlint:disable:next type_body_length - battle card owns press/drag/inspect/tap lifecycle
struct BattleAbilityCardView: View {
    let card: BattleCard
    let isPlayable: Bool
    let width: CGFloat
    let height: CGFloat
    let restingRotation: CGFloat
    let restingOffsetY: CGFloat
    let restingCenter: CGPoint
    let hapticsEnabled: Bool
    var autoLiftCardID: Int?
    let onInspect: () -> Void
    let onPlay: (CardActivationRequest) -> Bool
    let onPlayDenied: () -> Void
    let onInteractionChanged: (Bool) -> Void
    var onLift: ((BattleCardCuePresentationMode) -> Void)?
    var onLiftCancel: (() -> Void)?

    @State private var dragTranslation: CGSize = .zero
    @State private var predictedEndTranslation: CGSize = .zero
    @State private var isPlayArmed = false
    @State private var didExceedTapSlop = false
    @State private var interactionResolution: InteractionResolution = .idle
    @State private var inspectionTask: Task<Void, Never>?
    @State private var pressCommitted = false
    @State private var pressCommitTask: Task<Void, Never>?
    @State private var didAnnounceWindUp = false
    @State private var playArmFeedbackToken = 0
    @State private var availabilityFeedbackToken = 0
    @State private var inspectFeedbackToken = 0
    @State private var denyFeedbackToken = 0
    @State private var didAnnounceDeny = false
    @State private var didReportPlayDenied = false
    @State private var isTapLifting = false
    @GestureState private var isGestureActive = false

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

    private var isScaleCommitted: Bool {
        pressCommitted || didExceedTapSlop
    }

    private var playDragThreshold: CGFloat {
        BattleHandLayout.playDragThreshold
    }

    var body: some View {
        BattleAbilityCardFace(artworkName: card.ability.artReference?.imageName)
            .equatable()
            .frame(width: width, height: height)
            .overlay { availabilityBorder }
            .scaleEffect(x: activeScale.width, y: activeScale.height)
            .animation(BattleMotion.cardPress, value: isGestureActive)
            .rotationEffect(.degrees(activeRotation), anchor: .bottom)
            .rotation3DEffect(
                .degrees(isScaleCommitted ? verticalTilt : 0),
                axis: (x: 1, y: 0, z: 0),
                anchor: .bottom,
                perspective: BattleMotion.cardPerspective,
            )
            .offset(activeOffset)
            .offset(tapLiftOffset)
            .shadow(
                color: isScaleCommitted ? TrinketDesign.Colors.Overlay.dragShadow.opacity(0.55) : .clear,
                radius: BattleMotion.cardHeldShadowRadius,
                y: BattleMotion.cardHeldShadowY,
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isGestureActive) { _, isActive, _ in
                        isActive = true
                    }
                    .onChanged(updateDrag)
                    .onEnded(endDrag),
            )
            .trinketSensoryFeedback(
                .selection,
                trigger: playArmFeedbackToken,
                enabled: hapticsEnabled,
            )
            .trinketSensoryFeedback(
                .selection,
                trigger: inspectFeedbackToken,
                enabled: hapticsEnabled,
            )
            .trinketSensoryFeedback(
                .warning,
                trigger: denyFeedbackToken,
                enabled: hapticsEnabled,
            )
            .onDisappear {
                cancelAnnouncedWindUp()
                cancelInspection()
                cancelPressCommit()
                onInteractionChanged(false)
            }
            .onAppear {
                syncAutoLift(autoLiftCardID)
            }
            .onChange(of: autoLiftCardID) { _, liftCardID in
                syncAutoLift(liftCardID)
            }
            .onChange(of: isGestureActive) { wasActive, isActive in
                guard wasActive, !isActive, interactionResolution != .idle else { return }
                returnDrag()
            }
            .onChange(of: isPlayable) { _, playable in
                if playable {
                    availabilityFeedbackToken &+= 1
                } else {
                    returnDrag()
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(card.ability.name)
            .accessibilityHint(isPlayable ? "Double tap to play this card" : "Not playable")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { requestPlay(.tap) }
            .accessibilityIdentifier(AccessibilityID.Battle.handCard(card.ability.id))
    }

    private var activeOffset: CGSize {
        let resting = restingTranslation
        return CGSize(
            width: resting.width + (isDragging ? dragTranslation.width : 0),
            height: resting.height + (isDragging ? dragTranslation.height : 0),
        )
    }

    private var tapLiftOffset: CGSize {
        guard isTapLifting else { return .zero }
        return CGSize(width: 0, height: -height * BattleMotion.tapLiftHeightFraction)
    }

    private var restingTranslation: CGSize {
        CGSize(width: 0, height: height * BattleHandLayout.restingYFraction + restingOffsetY)
    }

    private var activeRotation: Double {
        guard isDragging else { return restingRotation }
        return restingRotation + BattleHandLayout.heldTilt(
            translation: dragTranslation,
            predictedEndTranslation: predictedEndTranslation,
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
        guard isScaleCommitted else {
            let scale = isGestureActive ? TrinketMotion.Interaction.artworkCardPressedScale : 1
            return CGSize(width: scale, height: scale)
        }
        var base = CGFloat(BattleMotion.cardHeldScale)
        if isPlayArmed {
            base += BattleMotion.cardArmedScaleBoost
        }
        return CGSize(width: base, height: base)
    }

    private var activeScale: CGSize {
        heldScale
    }

    private func updateDrag(_ value: DragGesture.Value) {
        guard interactionResolution != .inspecting else { return }

        if interactionResolution == .idle {
            interactionResolution = .pressing
            onInteractionChanged(true)
            scheduleInspection()
            schedulePressCommit()
        }
        if !didExceedTapSlop,
           BattleHandLayout.exceedsTapSlop(
               translation: value.translation,
               minimumDistance: BattleHandLayout.dragMinimumDistance,
           ) {
            didExceedTapSlop = true
            cancelInspection()
            commitPressImmediately()
            interactionResolution = .dragging
            announceWindUpIfNeeded(mode: .preview)
        }
        dragTranslation = BattleHandLayout.presentationTranslation(
            value.translation,
            isPlayable: isPlayable,
            threshold: playDragThreshold,
        )
        predictedEndTranslation = value.predictedEndTranslation

        let armed = BattleHandLayout.shouldRemainPlayArmed(
            translation: value.translation,
            isPlayable: isPlayable,
            threshold: playDragThreshold,
            currentlyArmed: isPlayArmed,
        )
        if armed != isPlayArmed {
            if armed {
                playArmFeedbackToken &+= 1
            }
            withAnimation(BattleMotion.cardLift) {
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
                reportPlayDeniedIfNeeded()
            } else if !crossedDenyThreshold {
                didAnnounceDeny = false
            }
        }
    }

    private func endDrag(_ value: DragGesture.Value) {
        guard interactionResolution != .inspecting else {
            returnDrag()
            return
        }
        cancelInspection()
        cancelPressCommit()

        let isTap = BattleHandLayout.isTapGesture(
            translation: value.translation,
            didExceedTapSlop: didExceedTapSlop,
            minimumDistance: BattleHandLayout.dragMinimumDistance,
        )
        if isTap {
            requestPlay(.tap)
            return
        }

        let shouldPlay = BattleHandLayout.shouldPlay(
            translation: value.translation,
            predictedEndTranslation: value.predictedEndTranslation,
            isPlayable: true,
            threshold: playDragThreshold,
        )
        if shouldPlay {
            requestPlay(.drag)
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
                  minimumDistance: BattleHandLayout.dragMinimumDistance,
              )
        else { return }

        cancelInspection()
        cancelPressCommit()
        interactionResolution = .inspecting
        inspectFeedbackToken &+= 1
        resetVisualState()
        onInteractionChanged(false)
        onInspect()
    }

    private func scheduleInspection() {
        cancelInspection()
        let duration = BattleMotion.cardInspectHoldDuration
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

    private func schedulePressCommit() {
        cancelPressCommit()
        let delay = BattleMotion.cardPressCommitDelay
        pressCommitTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            guard interactionResolution == .pressing else { return }
            withAnimation(BattleMotion.cardPress) {
                pressCommitted = true
            }
        }
    }

    private func cancelPressCommit() {
        pressCommitTask?.cancel()
        pressCommitTask = nil
    }

    private func commitPressImmediately() {
        cancelPressCommit()
        guard !pressCommitted else { return }
        withAnimation(BattleMotion.cardPress) {
            pressCommitted = true
        }
    }

    private func returnDrag() {
        cancelInspection()
        cancelPressCommit()
        resetVisualState()
        interactionResolution = .idle
        onInteractionChanged(false)
    }

    private func resetVisualState() {
        cancelAnnouncedWindUp()
        withAnimation(BattleMotion.cardReturn) {
            dragTranslation = .zero
            predictedEndTranslation = .zero
            isPlayArmed = false
            didExceedTapSlop = false
            isTapLifting = false
            pressCommitted = false
        }
        didAnnounceDeny = false
        didReportPlayDenied = false
        cancelPressCommit()
    }

    private enum PlayIntent {
        case tap
        case drag
    }

    private func requestPlay(_ intent: PlayIntent) {
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
        cancelInspection()
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
                    isPlayArmed ? BattleMotion.cardArmedRingOpacity : (isPlayable ? BattleMotion.cardReadyRingOpacity : 0),
                ),
                lineWidth: isPlayArmed ? BattleMotion.cardArmedRingLineWidth : BattleMotion.cardReadyRingLineWidth,
            )
            .animation(TrinketMotion.Interaction.stateChange, value: isPlayable)
            .overlay {
                TrinketDesign.cardShape
                    .strokeBorder(TrinketDesign.Colors.accent, lineWidth: BattleMotion.cardReadyRingLineWidth)
                    .keyframeAnimator(initialValue: 0.0, trigger: availabilityFeedbackToken) { content, opacity in
                        content.opacity(isPlayable && !isPlayArmed ? opacity : 0)
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

    func syncAutoLift(_ liftCardID: Int?) {
        let shouldLift = liftCardID == card.id
        guard shouldLift != isTapLifting else { return }
        if shouldLift {
            announceWindUpIfNeeded(mode: .preview)
        } else {
            didAnnounceWindUp = false
        }
        withAnimation(BattleMotion.tapLift) {
            isTapLifting = shouldLift
        }
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

    var body: some View {
        Group {
            if let artworkName {
                Image.preparedAsset(named: artworkName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .decorativePreparedArtwork()
            } else {
                PlaceholderArtwork(.ability)
            }
        }
        .combatantCardChrome()
    }
}
