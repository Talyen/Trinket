import BattleEngine
import SwiftUI
import TrinketContent
import TrinketDesignSystem

/// Fan pose captured at pickup so hand reflow cannot retarget a held card.
private struct HeldCardLayoutSnapshot: Equatable {
    var width: CGFloat
    var height: CGFloat
    var restingRotation: CGFloat
    var restingOffsetY: CGFloat
    var restingCenter: CGPoint
    var fanOffsetX: CGFloat
}

struct BattleHandView: View {
    let cards: [BattleCard]
    let isPlayable: (BattleCard) -> Bool
    let onTap: (BattleCard) -> Void
    let onPlay: (BattleCard, CardActivationRequest) -> Bool
    let hapticsEnabled: Bool
    let battleFrame: CGRect
    var configuration: BattleHandMotionConfiguration = .init()
    /// Lab-only: when set, that card presents as dragged to this translation.
    var forcedDragTranslation: (cardID: Int, translation: CGSize)?
    /// Fires when any hand card press/drag begins or ends (including tap-to-detail).
    var onCardInteractionChanged: ((Bool) -> Void)?

    var body: some View {
        GeometryReader { geometry in
            let layout = BattleHandLayout.metrics(
                containerWidth: geometry.size.width,
                cardCount: cards.count,
                configuration: configuration
            )
            let cardIDs = cards.map(\.id)

            ZStack(alignment: .bottom) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    let liveSnapshot = HeldCardLayoutSnapshot(
                        width: layout.cardWidth,
                        height: layout.cardHeight,
                        restingRotation: BattleHandLayout.rotation(
                            index: index,
                            cardCount: cards.count,
                            fanAngleStep: configuration.fanAngleStep
                        ),
                        restingOffsetY: BattleHandLayout.restingOffsetY(
                            index: index,
                            cardCount: cards.count,
                            fanLiftStep: configuration.fanLiftStep
                        ),
                        restingCenter: BattleHandLayout.restingCenter(
                            index: index,
                            metrics: layout,
                            cardCount: cards.count,
                            containerFrame: battleFrame,
                            configuration: configuration
                        ),
                        fanOffsetX: BattleHandLayout.cardOffsetX(
                            index: index,
                            metrics: layout,
                            containerWidth: geometry.size.width
                        )
                    )
                    let snapshot = heldLayoutSnapshots[card.id] ?? liveSnapshot
                    let isHeld = activeCardID == card.id

                    BattleAbilityCardView(
                        card: card,
                        isPlayable: isPlayable(card),
                        width: snapshot.width,
                        height: snapshot.height,
                        restingRotation: snapshot.restingRotation,
                        restingOffsetY: snapshot.restingOffsetY,
                        configuration: configuration,
                        restingCenter: snapshot.restingCenter,
                        hapticsEnabled: hapticsEnabled,
                        forcedDragTranslation: forcedDragTranslation?.cardID == card.id
                            ? forcedDragTranslation?.translation
                            : nil,
                        onTap: { onTap(card) },
                        onPlay: { command in onPlay(card, command) },
                        onInteractionChanged: { isActive in
                            if isActive {
                                // Freeze the pose from the interaction start frame so later
                                // draws / reflow cannot rewrite the held card's fan.
                                if heldLayoutSnapshots[card.id] == nil {
                                    heldLayoutSnapshots[card.id] = liveSnapshot
                                }
                                activeCardID = card.id
                                onCardInteractionChanged?(true)
                            } else if activeCardID == card.id {
                                activeCardID = nil
                                heldLayoutSnapshots.removeValue(forKey: card.id)
                                onCardInteractionChanged?(false)
                            }
                        }
                    )
                    .offset(x: snapshot.fanOffsetX)
                    .zIndex(isHeld ? 100 : Double(index))
                    // Held cards skip reflow animation; the rest of the fan may settle.
                    .animation(isHeld ? nil : configuration.handReflow, value: cardIDs)
                    .transition(
                        .asymmetric(
                            insertion: .offset(
                                x: card.owner == .hero
                                    ? -configuration.dealInsertOffsetX
                                    : configuration.dealInsertOffsetX,
                                y: configuration.dealInsertOffsetY
                            )
                            .combined(with: .opacity)
                            .combined(with: .scale(scale: configuration.dealInsertScale))
                            .animation(
                                configuration.handReflow
                                    .delay(Double(index) * configuration.cardDrawStagger)
                            ),
                            removal: .identity
                        )
                    )
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .bottom)
        }

        .accessibilityIdentifier(AccessibilityID.Battle.hand)
    }

    @State private var activeCardID: Int?
    @State private var heldLayoutSnapshots: [Int: HeldCardLayoutSnapshot] = [:]

    /// Production entry point (default motion configuration).
    init(
        cards: [BattleCard],
        isPlayable: @escaping (BattleCard) -> Bool,
        onTap: @escaping (BattleCard) -> Void,
        onPlay: @escaping (BattleCard, CardActivationRequest) -> Bool,
        hapticsEnabled: Bool,
        battleFrame: CGRect,
        onCardInteractionChanged: ((Bool) -> Void)? = nil
    ) {
        self.init(
            cards: cards,
            isPlayable: isPlayable,
            onTap: onTap,
            onPlay: onPlay,
            hapticsEnabled: hapticsEnabled,
            battleFrame: battleFrame,
            configuration: .init(),
            forcedDragTranslation: nil,
            onCardInteractionChanged: onCardInteractionChanged
        )
    }

    init(
        cards: [BattleCard],
        isPlayable: @escaping (BattleCard) -> Bool,
        onTap: @escaping (BattleCard) -> Void,
        onPlay: @escaping (BattleCard, CardActivationRequest) -> Bool,
        hapticsEnabled: Bool,
        battleFrame: CGRect,
        configuration: BattleHandMotionConfiguration,
        forcedDragTranslation: (cardID: Int, translation: CGSize)? = nil,
        onCardInteractionChanged: ((Bool) -> Void)? = nil
    ) {
        self.cards = cards
        self.isPlayable = isPlayable
        self.onTap = onTap
        self.onPlay = onPlay
        self.hapticsEnabled = hapticsEnabled
        self.battleFrame = battleFrame
        self.configuration = configuration
        self.forcedDragTranslation = forcedDragTranslation
        self.onCardInteractionChanged = onCardInteractionChanged
    }
}

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
    let onTap: () -> Void
    let onPlay: (CardActivationRequest) -> Bool
    let onInteractionChanged: (Bool) -> Void

    @State private var dragTranslation: CGSize = .zero
    @State private var predictedEndTranslation: CGSize = .zero
    @State private var isDragging = false
    @State private var isPlayArmed = false
    @State private var didExceedTapSlop = false
    @State private var playArmFeedbackToken = 0
    @State private var denyFeedbackToken = 0
    @State private var didAnnounceDeny = false

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
                color: isActivelyHeld ? TrinketDesign.Colors.Overlay.dragShadow : .clear,
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
                    onInteractionChanged(false)
                    return
                }
                let armed = BattleHandLayout.shouldRemainPlayArmed(
                    translation: forced,
                    isPlayable: isPlayable,
                    threshold: playDragThreshold,
                    playArmReleaseRatio: configuration.playArmReleaseRatio,
                    armedHorizontalAllowance: configuration.armedHorizontalAllowance,
                    currentlyArmed: isPlayArmed
                )
                isPlayArmed = armed
                onInteractionChanged(true)
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
