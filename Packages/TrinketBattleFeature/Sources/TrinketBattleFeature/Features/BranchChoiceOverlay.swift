import BattleEngine
import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

/// Modal pick-one presentation for branchable cards: the played card fans into
/// one ghost copy per outcome branch, each ringed by its keyword shine. Tap a
/// copy to commit; tap the scrim to cancel; hold a copy to read just that
/// branch's effect text.
struct BranchChoiceOverlay: View {
    let presentation: BranchChoicePresentation
    let onChoose: (Int, CardActivationRequest) -> Void
    let onCancel: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isFanned = false
    @State private var pressedIndex: Int?
    @State private var detailIndex: Int?

    private var cardWidth: CGFloat {
        presentation.cardSize.width
    }

    private var cardHeight: CGFloat {
        presentation.cardSize.height
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                TrinketDesign.Colors.Overlay.cinematicDim.opacity(isFanned ? 0.55 : 0)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onCancel)

                ForEach(presentation.choices.indices, id: \.self) { index in
                    choiceCopy(index, in: geometry.size)
                }

                if let detailIndex {
                    detailBubble(for: detailIndex, in: geometry.size)
                }
            }
        }
        .onAppear {
            guard !isFanned else { return }
            if reduceMotion {
                isFanned = true
            } else {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                    isFanned = true
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(named: "Cancel") { onCancel() }
    }

    // MARK: - Layout

    /// Raised anchor so the fan clears the hand lane, horizontally clamped to
    /// stay on screen when the source card sits near an edge.
    private func anchor(in size: CGSize) -> CGPoint {
        CGPoint(
            x: min(max(presentation.sourceCenter.x, cardWidth), size.width - cardWidth),
            y: max(presentation.sourceCenter.y - cardHeight * 1.15, cardHeight * 0.9)
        )
    }

    private func fanOffset(_ index: Int) -> CGPoint {
        let count = presentation.choices.count
        let spread = cardWidth * 0.62
        switch count {
        case ..<2:
            return .zero
        case 2:
            return CGPoint(x: index == 0 ? -spread : spread, y: 0)
        case 3:
            switch index {
            case 0: return CGPoint(x: -spread * 1.05, y: cardHeight * 0.22)
            case 1: return CGPoint(x: 0, y: -cardHeight * 0.3)
            default: return CGPoint(x: spread * 1.05, y: cardHeight * 0.22)
            }
        default:
            let total = CGFloat(count - 1)
            return CGPoint(x: (CGFloat(index) - total / 2) * spread, y: 0)
        }
    }

    private func fanRotationDegrees(_ index: Int) -> CGFloat {
        fanOffset(index).x < 0 ? -7 : 7
    }

    private func fanRotation(_ index: Int) -> Angle {
        .degrees(fanRotationDegrees(index))
    }

    private func copyPosition(_ index: Int, in size: CGSize) -> CGPoint {
        let offset = fanOffset(index)
        let target = anchor(in: size)
        let point = CGPoint(x: target.x + offset.x, y: target.y + offset.y)
        return isFanned ? point : presentation.sourceCenter
    }

    // MARK: - Pieces

    @ViewBuilder
    private func choiceCopy(_ index: Int, in size: CGSize) -> some View {
        let choice = presentation.choices[index]
        let isPressed = pressedIndex == index && isFanned

        Button {
            commit(index, in: size)
        } label: {
            BattleAbilityCardFace(artworkName: presentation.artworkName)
                .frame(width: cardWidth, height: cardHeight)
                .overlay {
                    KeywordShineBorder(colors: shineColors(choice), lineWidth: 2)
                }
                .overlay(alignment: .topLeading) {
                    keywordChip(choice)
                        .padding(6)
                }
                .shadow(
                    color: shineColors(choice).first?.opacity(0.45) ?? .clear,
                    radius: isPressed ? 14 : 8,
                    y: 2
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 1.06 : isFanned ? 1 : 0.6)
        .opacity(isFanned ? 1 : 0)
        .rotationEffect(isFanned ? fanRotation(index) : .radians(presentation.rotation))
        .position(copyPosition(index, in: size))
        .onLongPressGesture(minimumDuration: 0.5) {
            detailIndex = detailIndex == index ? nil : index
            pressedIndex = nil
        } onPressingChanged: { pressing in
            pressedIndex = pressing ? index : nil
        }
        .sensoryFeedback(.selection, trigger: isPressed) { wasPressed, isPressed in
            !wasPressed && isPressed
        }
        .accessibilityLabel(choice.summary)
        .accessibilityHint("Double tap to choose this outcome")
    }

    private func keywordChip(_ choice: AbilityBranchChoice) -> some View {
        let style = visualStyle(choice)
        return Image(systemName: style.symbolName)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(style.color)
            .padding(5)
            .background(Circle().fill(style.subtleBackgroundColor))
            .overlay(Circle().strokeBorder(style.borderColor, lineWidth: 1))
    }

    private func detailBubble(for index: Int, in size: CGSize) -> some View {
        let position = copyPosition(index, in: size)
        return Text(presentation.choices[index].summary)
            .font(.footnote.weight(.medium))
            .multilineTextAlignment(.center)
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(TrinketDesign.Colors.elevated, in: Capsule())
            .overlay(Capsule().strokeBorder(TrinketDesign.Colors.subtleStroke, lineWidth: 1))
            .frame(maxWidth: cardWidth * 1.7)
            .position(x: position.x, y: position.y + cardHeight * 0.72)
            .onTapGesture { detailIndex = nil }
            .zIndex(1)
    }

    // MARK: - Helpers

    private func commit(_ index: Int, in size: CGSize) {
        guard isFanned else { return }
        let request = CardActivationRequest(
            artworkName: presentation.artworkName,
            center: copyPosition(index, in: size),
            size: presentation.cardSize,
            rotation: fanRotationDegrees(index) * .pi / 180,
            verticalTilt: 0,
            scale: 1,
            perspective: TrinketMotion.Battle.cardPerspective,
            keywords: Array(presentation.choices[index].keywords.prefix(3))
        )
        onChoose(index, request)
    }

    private func shineColors(_ choice: AbilityBranchChoice) -> [Color] {
        let colors = choice.keywords.prefix(2).map(\.visualStyle.color)
        return colors.isEmpty ? [TrinketDesign.Colors.accent] : colors
    }

    private func visualStyle(_ choice: AbilityBranchChoice) -> Keyword.VisualStyle {
        choice.keywords.first.map(\.visualStyle) ?? .physical
    }
}
