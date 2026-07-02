import SwiftUI

struct StageDeckView: View {
    @Environment(AppState.self) private var appState

    let deck: VisibleStageDeck
    let scrollAnimation: Animation?
    let onStageTap: (Stage) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading, spacing: 0) {
                ScrollView(.horizontal) {
                    LazyHStack(alignment: .top, spacing: 14) {
                        ForEach(Array(deck.cards.enumerated()), id: \.element.id) { index, card in
                            StageDeckCardView(
                                card: card,
                                onStageTap: onStageTap
                            )
                            .containerRelativeFrame(.horizontal) { length, _ in
                                min(max(length * 0.62, 228), 280)
                            }
                            .overlay(alignment: .topTrailing) {
                                if index < deck.cards.count - 1 {
                                    StageRouteConnectorSegment(tint: connectorTint(after: card))
                                        .offset(x: 21, y: 34)
                                }
                            }
                            .id(card.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollIndicators(.hidden)
                .contentMargins(.horizontal, TrinketDesign.Metrics.contentMargin, for: .scrollContent)
                .scrollTargetBehavior(.viewAligned)
            }
            .padding(.top, 18)
            .padding(.bottom, 28)
            .onAppear {
                scrollToDeckTarget(with: proxy)
            }
            .onChange(of: deck.scrollTargetID) { _, _ in
                scrollToDeckTarget(with: proxy)
            }
            .onChange(of: appState.journey.mapScrollRequest?.id) { _, _ in
                guard let request = appState.journey.mapScrollRequest else { return }
                withAnimation(scrollAnimation) {
                    proxy.scrollTo(request.targetID, anchor: .center)
                }
                appState.journey.clearMapScrollRequest(request)
            }
        }
    }

    private func scrollToDeckTarget(with proxy: ScrollViewProxy) {
        guard let target = deck.scrollTargetID else { return }
        DispatchQueue.main.async {
            withAnimation(scrollAnimation) {
                proxy.scrollTo(target, anchor: .center)
            }
        }
    }

    private func connectorTint(after card: StageDeckCard) -> Color {
        switch card {
        case let .stage(node):
            switch node.state {
            case .completed, .justCompleted:
                return TrinketDesign.Colors.success.opacity(0.48)
            case .active:
                return node.stage.encounter.mapTint.opacity(0.38)
            case .future:
                return Color.secondary.opacity(0.22)
            }
        case .chapterGate:
            return Color.secondary.opacity(0.22)
        }
    }
}

private struct StageRouteConnectorSegment: View {
    let tint: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(tint)
            .frame(width: 28, height: 3)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

struct StageDeckCardView: View {
    let card: StageDeckCard
    let onStageTap: (Stage) -> Void

    var body: some View {
        switch card {
        case let .stage(node):
            if node.state == .active {
                StageNodeView(
                    stage: node.stage,
                    state: node.state,
                    onPrimaryAction: {
                        onStageTap(node.stage)
                    }
                )
                .accessibilityElement(children: .contain)
                .accessibilityLabel(accessibilityLabel(for: node))
            } else {
                StageNodeView(stage: node.stage, state: node.state)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier(StageMapID.stageNode(for: node.stage))
                    .accessibilityLabel(accessibilityLabel(for: node))
            }
        case let .chapterGate(chapter):
            ChapterGateCardView(chapter: chapter)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(StageMapID.chapterLocked(chapter))
                .accessibilityLabel("Chapter \(chapter.number), locked")
        }
    }

    private func accessibilityLabel(for node: VisibleStageNode) -> String {
        let fullLabel = "Stage \(node.stage.chapterNumber)-\(node.stage.stageNumber)"
        switch node.state {
        case .active:
            return "\(fullLabel), active \(node.stage.encounter.title)"
        case .completed, .justCompleted:
            return "\(fullLabel), complete"
        case .future:
            return "\(fullLabel), locked"
        }
    }
}
