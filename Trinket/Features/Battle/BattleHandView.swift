import BattleEngine
import SwiftUI
import TrinketContent
import TrinketDesignSystem

struct BattleHandView: View {
    let cards: [BattleCard]
    let isPlayable: (BattleCard) -> Bool
    let onTap: (BattleCard) -> Void
    let onPlay: (BattleCard) -> Bool
    let hapticsEnabled: Bool

    var body: some View {
        GeometryReader { geometry in
            let layout = BattleHandLayout.metrics(
                containerWidth: geometry.size.width,
                cardCount: cards.count
            )

            ZStack(alignment: .bottom) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    BattleAbilityCardView(
                        card: card,
                        isPlayable: isPlayable(card),
                        width: layout.cardWidth,
                        height: layout.cardHeight,
                        restingRotation: BattleHandLayout.rotation(index: index, cardCount: cards.count),
                        restingOffsetY: BattleHandLayout.restingOffsetY(index: index, cardCount: cards.count),
                        playDragThreshold: BattleHandLayout.playDragThreshold,
                        hapticsEnabled: hapticsEnabled,
                        onTap: { onTap(card) },
                        onPlay: { onPlay(card) }
                    )
                    .offset(
                        x: BattleHandLayout.cardOffsetX(
                            index: index,
                            metrics: layout,
                            containerWidth: geometry.size.width
                        )
                    )
                    .zIndex(Double(index))
                    .transition(
                        .asymmetric(
                            insertion: .offset(
                                x: card.owner == .hero ? -64 : 64,
                                y: 78
                            )
                            .combined(with: .opacity)
                            .combined(with: .scale(scale: 0.88))
                            .animation(
                                TrinketMotion.Battle.handReflow
                                    .delay(Double(index) * TrinketMotion.Battle.cardDrawStagger)
                            ),
                            removal: .opacity
                        )
                    )
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .bottom)
            .animation(TrinketMotion.Battle.handReflow, value: cards.map(\.id))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Battle.hand)
    }
}

struct BattleAbilityCardView: View {
    let card: BattleCard
    let isPlayable: Bool
    let width: CGFloat
    let height: CGFloat
    let restingRotation: CGFloat
    let restingOffsetY: CGFloat
    let playDragThreshold: CGFloat
    let hapticsEnabled: Bool
    let onTap: () -> Void
    let onPlay: () -> Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragTranslation: CGSize = .zero
    @State private var predictedEndTranslation: CGSize = .zero
    @State private var isDragging = false
    @State private var isPlayArmed = false
    @State private var playArmFeedbackToken = 0
    @State private var playFeedbackToken = 0
    @State private var denyFeedbackToken = 0
    @State private var didAnnounceDeny = false
    @State private var isPlaying = false
    @State private var playTranslation: CGSize = .zero
    @State private var playTask: Task<Void, Never>?
    @ScaledMetric(relativeTo: .title) private var placeholderIconSize: CGFloat = 38

    var body: some View {
        let ownerLabel = card.owner == .hero ? "Hero" : "Pet"
        artFace
            .frame(width: width, height: height)
            .clipShape(TrinketDesign.cardShape)
            .trinketCardSurface()
            .opacity(isPlaying ? 0.08 : isPlayable ? 1 : 0.45)
            .overlay {
                RoundedRectangle(cornerRadius: TrinketDesign.Corners.card, style: .continuous)
                    .stroke(
                        isPlayArmed
                            ? card.ability.damageKeyword.visualStyle.color.opacity(0.82)
                            : .clear,
                        lineWidth: isPlayArmed ? 2 : 0
                    )
                    .allowsHitTesting(false)
            }
            .rotationEffect(.degrees(activeRotation), anchor: isDragging ? .center : .bottom)
            .rotation3DEffect(
                .degrees(isDragging && !reduceMotion ? verticalTilt : 0),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.35
            )
            .offset(activeOffset)
            .scaleEffect(x: activeScale.width, y: activeScale.height)
            .shadow(
                color: isDragging ? TrinketDesign.Colors.Overlay.dragShadow : .clear,
                radius: isDragging ? TrinketMotion.Battle.cardHeldShadowRadius : 0,
                y: isDragging ? TrinketMotion.Battle.cardHeldShadowY : 0
            )
            .zIndex(isDragging ? 100 : 0)
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
                .warning,
                trigger: denyFeedbackToken,
                enabled: hapticsEnabled
            )
            .trinketSensoryFeedback(
                .impact(weight: .medium),
                trigger: playFeedbackToken,
                enabled: hapticsEnabled
            )
            .onDisappear {
                playTask?.cancel()
            }
            .accessibilityIdentifier(AccessibilityID.Battle.handCard(card.ability.id))
            .accessibilityLabel("\(card.ability.name), \(ownerLabel)")
            .accessibilityHint(isPlayable ? "Tap for details. Drag up to play." : "Cannot play now")
            .accessibilityAddTraits(isDragging ? [] : .isButton)
    }

    private var activeOffset: CGSize {
        if isPlaying {
            CGSize(
                width: playTranslation.width * 0.6,
                height: playTranslation.height - height * 0.95
            )
        } else if isDragging {
            dragTranslation
        } else {
            CGSize(width: 0, height: height * 0.25 + restingOffsetY)
        }
    }

    private var activeRotation: Double {
        guard isDragging, !isPlaying else { return isPlaying ? 0 : restingRotation }
        guard !reduceMotion else { return 0 }
        return BattleHandLayout.heldTilt(
            translation: dragTranslation,
            predictedEndTranslation: predictedEndTranslation,
            cardWidth: width,
            maximumDegrees: TrinketMotion.Battle.cardMaximumTiltDegrees
        )
    }

    private var verticalTilt: Double {
        min(max(Double(-dragTranslation.height / height) * 4, -4), 4)
    }

    private var heldScale: CGSize {
        guard isDragging, !reduceMotion else { return CGSize(width: 1, height: 1) }
        let base = TrinketMotion.Battle.cardHeldScale
        let distance = hypot(dragTranslation.width, dragTranslation.height)
        let stretch = min(distance / 400, 1) * TrinketMotion.Battle.cardMaximumStretch
        if abs(dragTranslation.width) > abs(dragTranslation.height) {
            return CGSize(width: base + stretch, height: base - stretch)
        }
        return CGSize(width: base - stretch, height: base + stretch)
    }

    private var activeScale: CGSize {
        if isPlaying {
            return CGSize(width: 1.06, height: 1.06)
        }
        return heldScale
    }

    private func updateDrag(_ value: DragGesture.Value) {
        guard !isPlaying else { return }
        if !isDragging {
            withAnimation(reduceMotion ? nil : TrinketMotion.Battle.cardPress) {
                isDragging = true
            }
        }
        dragTranslation = BattleHandLayout.presentationTranslation(
            value.translation,
            isPlayable: isPlayable,
            threshold: playDragThreshold
        )
        predictedEndTranslation = value.predictedEndTranslation

        let armed = isPlayable && BattleHandLayout.shouldPlay(
            translation: value.translation,
            predictedEndTranslation: value.predictedEndTranslation,
            isPlayable: true,
            threshold: playDragThreshold
        )
        if armed != isPlayArmed {
            if armed {
                playArmFeedbackToken &+= 1
            }
            withAnimation(reduceMotion ? nil : TrinketMotion.Battle.cardLift) {
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
        guard !isPlaying else { return }
        let isTap = abs(value.translation.width) < BattleHandLayout.dragMinimumDistance
            && abs(value.translation.height) < BattleHandLayout.dragMinimumDistance
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
            beginPlay(from: value.translation)
            return
        }
        returnDrag()
    }

    private func returnDrag() {
        withAnimation(
            reduceMotion
                ? TrinketMotion.Battle.cardReturnReducedMotion
                : TrinketMotion.Battle.cardReturn
        ) {
            dragTranslation = .zero
            predictedEndTranslation = .zero
            isPlayArmed = false
            isDragging = false
        }
    }

    private func beginPlay(from translation: CGSize) {
        playTranslation = translation
        playFeedbackToken &+= 1
        isPlayArmed = false
        isDragging = false
        withAnimation(reduceMotion ? TrinketMotion.Battle.reduceMotion : TrinketMotion.Battle.cardCommit) {
            isPlaying = true
            dragTranslation = .zero
            predictedEndTranslation = .zero
        }

        playTask?.cancel()
        playTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(TrinketMotion.Battle.cardCommitDelay))
            guard !Task.isCancelled else { return }
            let didPlay = onPlay()
            if !didPlay {
                withAnimation(TrinketMotion.Battle.cardReturnReducedMotion) {
                    isPlaying = false
                    playTranslation = .zero
                    isDragging = false
                }
            }
        }
    }

    @ViewBuilder
    private var artFace: some View {
        if let artRef = card.ability.artReference {
            Image(artRef.imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .accessibilityHidden(true)
        } else {
            ZStack {
                TrinketDesign.CardPlaceholderStyle.ability.color.opacity(0.18)
                Image(systemName: TrinketDesign.CardPlaceholderStyle.ability.symbolName)
                    .font(.system(size: placeholderIconSize, weight: .semibold))
                    .foregroundStyle(TrinketDesign.CardPlaceholderStyle.ability.color)
                    .accessibilityHidden(true)
            }
        }
    }
}
