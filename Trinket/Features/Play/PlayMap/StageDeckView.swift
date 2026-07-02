import SwiftUI

struct StageDeckView: View {
    @Environment(AppState.self) private var appState

    let deck: VisibleStageDeck
    let scrollAnimation: Animation?
    let onStageTap: (Stage) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading, spacing: 18) {
                Text("Current Path")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)

                ScrollView(.horizontal) {
                    LazyHStack(alignment: .center, spacing: 14) {
                        ForEach(deck.cards) { card in
                            StageDeckCardView(
                                card: card,
                                onStageTap: onStageTap
                            )
                            .containerRelativeFrame(.horizontal) { length, _ in
                                min(max(length - 56, 292), 340)
                            }
                            .id(card.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollIndicators(.hidden)
                .contentMargins(.horizontal, 20, for: .scrollContent)
                .scrollTargetBehavior(.viewAligned)
            }
            .padding(.top, 22)
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
}

struct StageDeckCardView: View {
    let card: StageDeckCard
    let onStageTap: (Stage) -> Void

    var body: some View {
        switch card {
        case let .stage(node):
            if node.state == .active {
                Button {
                    onStageTap(node.stage)
                } label: {
                    StageNodeView(stage: node.stage, state: node.state)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("Stage \(node.stage.chapterNumber)-\(node.stage.stageNumber) Node")
                .accessibilityLabel(accessibilityLabel(for: node))
                .accessibilityHint("Opens the stage preview.")
            } else {
                StageNodeView(stage: node.stage, state: node.state)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("Stage \(node.stage.chapterNumber)-\(node.stage.stageNumber) Node")
                    .accessibilityLabel(accessibilityLabel(for: node))
            }
        case let .chapterGate(chapter):
            ChapterGateCardView(chapter: chapter)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("Chapter \(chapter.number) Locked")
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
