import BattleEngine
import SwiftUI
import TrinketContent
import TrinketDesignSystem

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
    /// Lab-only forced drag (cancel-replay). When non-nil, gestures are disabled.
    var forcedDragTranslation: CGSize?
    /// Lab/harness: bump while forced-dragging to commit via production `beginPlay`.
    var forcedPlayCommitGeneration: Int = 0
    let onTap: () -> Void
    let onPlay: (CardActivationRequest) -> Bool
    let onInteractionChanged: (Bool) -> Void
    var onAttackWindUp: (() -> Void)?
    var onAttackCancel: (() -> Void)?
    /// Clears harness forced-drag after a synthetic play commit is consumed.
    var onForcedPlayConsumed: (() -> Void)?

    @State private var dragTranslation: CGSize = .zero
    @State private var predictedEndTranslation: CGSize = .zero
    @State private var isDragging = false
    @State private var isPlayArmed = false
    @State private var didExceedTapSlop = false
    @State private var didAnnounceWindUp = false
    @State private var playArmFeedbackToken = 0
    @State private var denyFeedbackToken = 0
    @State private var didAnnounceDeny = false
    @State private var lastConsumedForcedPlayGeneration = 0

    private var playDragThreshold: CGFloat {
        configuration.playDragThreshold
    }

    private var effectiveDragTranslation: CGSize {
        forcedDragTranslation ?? dragTranslation
    }

    private var isActivelyHeld: Bool {
        forcedDragTranslation != nil || isDragging
    }

    var body: some View {
        BattleAbilityCardFace(artworkName: card.ability.artReference?.imageName)
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
                .degrees(isActivelyHeld ? verticalTilt : 0),
                axis: (x: 1, y: 0, z: 0),
                anchor: .bottom,
                perspective: configuration.perspective
            )
            .offset(activeOffset)
            .shadow(
                color: isActivelyHeld ? TrinketDesign.Colors.Overlay.dragShadow.opacity(0.55) : .clear,
                radius: isActivelyHeld ? configuration.cardHeldShadowRadius : 0,
                y: isActivelyHeld ? configuration.cardHeldShadowY : 0
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged(updateDrag)
                    .onEnded(endDrag)
            )
            .allowsHitTesting(forcedDragTranslation == nil)
            .trinketSensoryFeedback(
                .selection,
                trigger: playArmFeedbackToken,
                enabled: hapticsEnabled
            )
            .trinketSensoryFeedback(
                .warning,
                trigger: denyFeedbackToken,
                enabled: hapticsEnabled
            )
            .onChange(of: forcedDragTranslation) { _, forced in
                guard let forced else {
                    isPlayArmed = false
                    if didAnnounceWindUp {
                        didAnnounceWindUp = false
                        onAttackCancel?()
                    }
                    onInteractionChanged(false)
                    return
                }
                if !didExceedTapSlop,
                   BattleHandLayout.exceedsTapSlop(
                       translation: forced,
                       minimumDistance: configuration.dragMinimumDistance
                   ) {
                    didExceedTapSlop = true
                    if !didAnnounceWindUp {
                        didAnnounceWindUp = true
                        onAttackWindUp?()
                    }
                }
                let armed = BattleHandLayout.shouldRemainPlayArmed(
                    translation: forced,
                    isPlayable: isPlayable,
                    threshold: playDragThreshold,
                    playArmReleaseRatio: configuration.playArmReleaseRatio,
                    armedHorizontalAllowance: configuration.armedHorizontalAllowance,
                    currentlyArmed: isPlayArmed
                )
                if armed, !isPlayArmed {
                    playArmFeedbackToken &+= 1
                }
                isPlayArmed = armed
                onInteractionChanged(true)
            }
            .onChange(of: forcedPlayCommitGeneration) { _, generation in
                guard generation > lastConsumedForcedPlayGeneration,
                      forcedDragTranslation != nil else { return }
                lastConsumedForcedPlayGeneration = generation
                beginPlay()
                onForcedPlayConsumed?()
            }
            .onDisappear {
                onInteractionChanged(false)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier(AccessibilityID.Battle.handCard(card.ability.id))
            .accessibilityLabel(card.ability.name)
    }

    private var activeOffset: CGSize {
        let resting = restingTranslation
        return CGSize(
            width: resting.width + (isActivelyHeld ? effectiveDragTranslation.width : 0),
            height: resting.height + (isActivelyHeld ? effectiveDragTranslation.height : 0)
        )
    }

    private var restingTranslation: CGSize {
        CGSize(width: 0, height: height * configuration.restingYFraction + restingOffsetY)
    }

    private var activeRotation: Double {
        guard isActivelyHeld else { return restingRotation }
        return restingRotation + BattleHandLayout.heldTilt(
            translation: effectiveDragTranslation,
            predictedEndTranslation: predictedEndTranslation,
            cardWidth: width,
            maximumDegrees: configuration.effectiveHeldTiltDegrees
        )
    }

    private var verticalTilt: Double {
        min(
            max(
                Double(-effectiveDragTranslation.height / height) * configuration.verticalTiltGain,
                -configuration.verticalTiltClamp
            ),
            configuration.verticalTiltClamp
        )
    }

    private var heldScale: CGSize {
        guard isActivelyHeld else { return CGSize(width: 1, height: 1) }
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
        guard forcedDragTranslation == nil else { return }
        if !isDragging {
            withAnimation(configuration.cardPress) {
                isDragging = true
            }
            onInteractionChanged(true)
        }
        if !didExceedTapSlop,
           BattleHandLayout.exceedsTapSlop(
               translation: value.translation,
               minimumDistance: configuration.dragMinimumDistance
           ) {
            didExceedTapSlop = true
            if !didAnnounceWindUp {
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
        guard forcedDragTranslation == nil else { return }
        let isTap = BattleHandLayout.isTapGesture(
            translation: value.translation,
            didExceedTapSlop: didExceedTapSlop,
            minimumDistance: configuration.dragMinimumDistance
        )
        if isTap {
            onTap()
            returnDrag()
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

    private func returnDrag() {
        if didAnnounceWindUp {
            didAnnounceWindUp = false
            onAttackCancel?()
        }
        withAnimation(configuration.cardReturn) {
            dragTranslation = .zero
            predictedEndTranslation = .zero
            isPlayArmed = false
            isDragging = false
            didExceedTapSlop = false
        }
        onInteractionChanged(false)
    }

    private func beginPlay() {
        // Layout math matches the unrotated scale+offset center the cast overlay
        // positions to (avoids per-frame geometry probe invalidation while dragging).
        let center = BattleHandLayout.releaseCenter(
            restingCenter: restingCenter,
            dragTranslation: effectiveDragTranslation
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
        let didPlay = onPlay(request)
        if didPlay {
            // Cast commits swing via BattleView; clear wind-up flag without cancel.
            didAnnounceWindUp = false
            onInteractionChanged(false)
            return
        }
        returnDrag()
    }
}

struct BattleAbilityCardFace: View {
    let artworkName: String?

    @ScaledMetric(relativeTo: .title) private var placeholderIconSize: CGFloat = 38

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
