import BattleEngine
import SwiftUI
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

struct BoonChoiceOverlay: View {
    let offer: BoonOffer
    let onSelect: (String) -> Void
    @State private var committingChoiceID: String?
    @State private var isRevealed = false
    @State private var choiceCenters: [String: CGPoint] = [:]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                TrinketDesign.Colors.Overlay.ink.opacity(0.72)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())

                KeywordPlasmaBackground(
                    sources: plasmaSources(in: geometry.size),
                    isMotionActive: true
                )

                VStack(spacing: 20) {
                    header

                    VStack(spacing: 12) {
                        ForEach(offer.choices) { choice in
                            BoonChoiceCard(
                                choice: choice,
                                isSelected: committingChoiceID == choice.id,
                                isOtherSelected: committingChoiceID != nil && committingChoiceID != choice.id,
                                onCenterChange: { updateCenter($0, for: choice.id) },
                                onSelect: { handleSelect(choice.id) }
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .scaleEffect(isRevealed ? 1.0 : 0.94)
                .opacity(isRevealed ? 1.0 : 0.0)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
            .coordinateSpace(.named(BoonChoiceCoordinateSpace.name))
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(TrinketMotion.Reward.reveal) {
                isRevealed = true
            }
        }
        .transition(.opacity)
        .id(offer.id)
        .accessibilityIdentifier(AccessibilityID.Battle.boonChoice)
        .accessibilityElement(children: .contain)
    }

    private func handleSelect(_ choiceID: String) {
        guard committingChoiceID == nil else { return }
        withAnimation(TrinketMotion.Interaction.selection) {
            committingChoiceID = choiceID
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))
            onSelect(choiceID)
        }
    }

    private func updateCenter(_ center: CGPoint, for choiceID: String) {
        guard choiceCenters[choiceID] != center else { return }
        choiceCenters[choiceID] = center
    }

    private func plasmaSources(in size: CGSize) -> [KeywordPlasmaBackground.Source] {
        guard size.width > 0, size.height > 0 else { return [] }
        let measured = offer.choices.compactMap { choice -> KeywordPlasmaBackground.Source? in
            guard let center = choiceCenters[choice.id] else { return nil }
            return KeywordPlasmaBackground.Source(
                keywords: choice.boon.category.keywords,
                focalPoint: UnitPoint(
                    x: center.x / size.width,
                    y: center.y / size.height
                )
            )
        }
        if !measured.isEmpty { return measured }
        let fallbackY: [CGFloat] = [0.42, 0.62]
        return offer.choices.enumerated().compactMap { index, choice in
            guard index < fallbackY.count else { return nil }
            return KeywordPlasmaBackground.Source(
                keywords: choice.boon.category.keywords,
                focalPoint: UnitPoint(x: 0.5, y: fallbackY[index])
            )
        }
    }

    private var header: some View {
        Text("Pick a Boon")
            .trinketTypography(.screenTitle)
            .foregroundStyle(TrinketDesign.Colors.Overlay.paper)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
}

private struct BoonChoiceCard: View {
    let choice: BoonChoice
    let isSelected: Bool
    let isOtherSelected: Bool
    let onCenterChange: (CGPoint) -> Void
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                Text(choice.boon.name)
                    .font(.system(size: 20, weight: .heavy, design: .serif))
                    .keywordShine(Set(choice.boon.category.keywords))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                KeywordDescriptionText(text: choice.boon.description)
                    .trinketTypography(.body)
                    .foregroundStyle(TrinketDesign.Colors.Overlay.paper.opacity(0.92))
                    .multilineTextAlignment(.leading)
                    .lineLimit(4)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                TrinketDesign.Colors.Overlay.paper.opacity(0.12),
                                TrinketDesign.Colors.Overlay.ink.opacity(0.50),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                KeywordShineBorder(
                    keywords: Array(choice.boon.category.keywords),
                    cornerRadius: 18,
                    lineWidth: isSelected ? 2.5 : 1.4,
                    isMotionActive: true
                )
                .shadow(
                    color: primaryKeywordColor.opacity(isSelected ? 0.9 : 0.25),
                    radius: isSelected ? 16 : 6
                )
            }
        }
        .buttonStyle(BoonCardButtonStyle())
        .opacity(isOtherSelected ? 0.25 : 1.0)
        .scaleEffect(isSelected ? 1.03 : (isOtherSelected ? 0.96 : 1.0))
        .animation(TrinketMotion.Interaction.selection, value: isSelected)
        .animation(TrinketMotion.Interaction.selection, value: isOtherSelected)
        .onGeometryChange(for: CGPoint.self) { geometry in
            let frame = geometry.frame(in: .named(BoonChoiceCoordinateSpace.name))
            return CGPoint(x: frame.midX, y: frame.midY)
        } action: { center in
            onCenterChange(center)
        }
        .accessibilityLabel("\(choice.boon.name). \(choice.boon.description)\(isSelected ? ". Selected" : "")")
        .accessibilityHint(isSelected ? "Selected" : "Select this Boon")
        .accessibilityIdentifier(AccessibilityID.Battle.boon(choice.id))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var primaryKeywordColor: Color {
        choice.boon.category.keywords.first?.visualStyle.color ?? TrinketDesign.Colors.accent
    }
}

private enum BoonChoiceCoordinateSpace {
    static let name = "BoonChoiceOverlay"
}

private struct BoonCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1.0)
            .animation(TrinketMotion.Interaction.press, value: configuration.isPressed)
    }
}
