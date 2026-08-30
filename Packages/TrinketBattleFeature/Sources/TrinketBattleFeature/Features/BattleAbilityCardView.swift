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
    let restingCenter: CGPoint
    let hapticsEnabled: Bool
    var autoLiftCardID: Int?
    let onInspect: () -> Void
    let onPlay: (CardActivationRequest) -> Bool
    let onPlayDenied: () -> Void
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
    @State private var didReportPlayDenied = false
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
        BattleHandLayout.playDragThreshold
    }

    private var faceOpacity: Double {
        isPlayable ? 1 : 0.45
    }

    var body: some View {
        BattleAbilityCardFace(artworkName: card.ability.artReference?.imageName)
            .equatable()
            .frame(width: width, height: height)
            .opacity(faceOpacity)
            .overlay {
                if isPlayArmed {
                    TrinketDesign.cardShape
                        .stroke(
                            TrinketDesign.Colors.accent.opacity(BattleMotion.cardArmedRingOpacity),
                            lineWidth: BattleMotion.cardArmedRingLineWidth,
                        )
                }
            }
            .scaleEffect(x: activeScale.width, y: activeScale.height)
            .rotationEffect(.degrees(activeRotation), anchor: .bottom)
            .rotation3DEffect(
                .degrees(isDragging ? verticalTilt : 0),
                axis: (x: 1, y: 0, z: 0),
                anchor: .bottom,
                perspective: BattleMotion.cardPerspective,
            )
            .offset(activeOffset)
            .offset(tapLiftOffset)
            .shadow(
                color: isDragging ? TrinketDesign.Colors.Overlay.dragShadow.opacity(0.55) : .clear,
                radius: BattleMotion.cardHeldShadowRadius,
                y: BattleMotion.cardHeldShadowY,
            )
            .gesture(
                DragGesture(minimumDistance: 0)
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
            .accessibilityLabel(card.ability.name)
            .accessibilityHint("Double tap to play this card")
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
        guard isDragging else { return CGSize(width: 1, height: 1) }
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
            withAnimation(BattleMotion.cardPress) {
                interactionResolution = .pressing
            }
            onInteractionChanged(true)
            scheduleInspection()
        }
        if !didExceedTapSlop,
           BattleHandLayout.exceedsTapSlop(
               translation: value.translation,
               minimumDistance: BattleHandLayout.dragMinimumDistance,
           ) {
            didExceedTapSlop = true
            cancelInspection()
            interactionResolution = .dragging
            announceWindUpIfNeeded()
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
                denyFeedbackToken &+= 1
                reportPlayDeniedIfNeeded()
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
            minimumDistance: BattleHandLayout.dragMinimumDistance,
        )
        if isTap {
            if isPlayable {
                beginTapPlay()
            } else {
                reportPlayDeniedIfNeeded()
                returnDrag()
            }
            return
        }

        let shouldPlay = BattleHandLayout.shouldPlay(
            translation: value.translation,
            predictedEndTranslation: value.predictedEndTranslation,
            isPlayable: isPlayable,
            threshold: playDragThreshold,
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
                  minimumDistance: BattleHandLayout.dragMinimumDistance,
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

    private func returnDrag() {
        cancelInspection()
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
        }
        didReportPlayDenied = false
        cancelTapLift()
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
            keywords: card.ability.keywords,
        )
        publishPlay(request)
    }

    private func publishPlay(_ request: CardActivationRequest) {
        cancelInspection()
        let hadWindUp = didAnnounceWindUp
        didAnnounceWindUp = false
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
    func beginTapPlay() {
        guard tapLiftTask == nil else { return }
        announceWindUpIfNeeded()
        withAnimation(BattleMotion.tapLift) {
            isTapLifting = true
        }
        cancelTapLift()
        tapLiftTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(BattleMotion.tapLiftPlayDelay))
            guard !Task.isCancelled else { return }
            publishTapPlay()
        }
    }

    func syncAutoLift(_ liftCardID: Int?) {
        let shouldLift = liftCardID == card.id
        guard shouldLift != isTapLifting else { return }
        if shouldLift {
            cancelTapLift()
            announceWindUpIfNeeded()
        } else {
            didAnnounceWindUp = false
        }
        withAnimation(BattleMotion.tapLift) {
            isTapLifting = shouldLift
        }
    }

    func publishTapPlay() {
        let request = CardActivationRequest(
            artworkName: card.ability.artReference?.imageName,
            center: CGPoint(
                x: restingCenter.x + tapLiftOffset.width,
                y: restingCenter.y + tapLiftOffset.height,
            ),
            size: CGSize(width: width, height: height),
            rotation: restingRotation * .pi / 180,
            verticalTilt: 0,
            scale: 1,
            perspective: BattleMotion.cardPerspective,
            keywords: card.ability.keywords,
        )
        publishPlay(request)
    }

    func cancelTapLift() {
        tapLiftTask?.cancel()
        tapLiftTask = nil
    }

    func announceWindUpIfNeeded() {
        guard !didAnnounceWindUp, isPlayable else { return }
        didAnnounceWindUp = true
        onAttackWindUp?()
    }

    func cancelAnnouncedWindUp() {
        guard didAnnounceWindUp else { return }
        didAnnounceWindUp = false
        onAttackCancel?()
    }

    func reportPlayDeniedIfNeeded() {
        guard !isPlayable, !didReportPlayDenied else { return }
        didReportPlayDenied = true
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
        .clipShape(TrinketDesign.cardShape)
        .overlay {
            TrinketDesign.cardShape.strokeBorder(TrinketDesign.Colors.subtleStroke, lineWidth: 1)
        }
    }
}
