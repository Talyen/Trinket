struct VisibleStageDeck {
    let cards: [StageDeckCard]
    let scrollTargetID: String?

    init(chapters: [Chapter], chapter: Chapter, progress: JourneyProgressState) {
        let stages = chapter.stages
        guard !stages.isEmpty else {
            cards = []
            scrollTargetID = nil
            return
        }

        let gateChapter = Self.gateChapter(after: chapter, in: chapters)
        let gateScrollID = StageMapID.chapterGate(for: gateChapter)

        let activeIndex = progress.activeStageID.flatMap { activeStageID in
            stages.firstIndex { $0.id == activeStageID }
        }

        var visibleCards: [StageDeckCard] = []
        if let activeIndex {
            let previousIndex = activeIndex - 1
            if stages.indices.contains(previousIndex) {
                visibleCards.append(.stage(VisibleStageNode(
                    stage: stages[previousIndex],
                    state: Self.state(for: stages[previousIndex], progress: progress)
                )))
            }

            visibleCards.append(.stage(VisibleStageNode(
                stage: stages[activeIndex],
                state: .active
            )))

            let nextIndex = activeIndex + 1
            if stages.indices.contains(nextIndex) {
                visibleCards.append(.stage(VisibleStageNode(
                    stage: stages[nextIndex],
                    state: .future
                )))
            } else {
                visibleCards.append(.chapterGate(gateChapter))
            }

            scrollTargetID = stages[activeIndex].id
        } else {
            let lastCompletedIndex = stages.lastIndex { progress.isCompleted($0) } ?? stages.startIndex
            let previousIndex = max(stages.startIndex, lastCompletedIndex - 1)
            if previousIndex != lastCompletedIndex {
                visibleCards.append(.stage(VisibleStageNode(
                    stage: stages[previousIndex],
                    state: Self.state(for: stages[previousIndex], progress: progress)
                )))
            }

            visibleCards.append(.stage(VisibleStageNode(
                stage: stages[lastCompletedIndex],
                state: Self.state(for: stages[lastCompletedIndex], progress: progress)
            )))
            visibleCards.append(.chapterGate(gateChapter))
            scrollTargetID = gateScrollID
        }

        cards = visibleCards
    }

    private static func gateChapter(after chapter: Chapter, in chapters: [Chapter]) -> Chapter {
        GameContent.nextChapter(after: chapter) ?? placeholderGateChapter(after: chapter)
    }

    private static func placeholderGateChapter(after chapter: Chapter) -> Chapter {
        let nextNumber = chapter.number + 1
        return Chapter(
            id: StageMapID.placeholderGate(afterChapterNumber: nextNumber),
            number: nextNumber,
            title: "",
            theme: chapter.theme,
            stages: []
        )
    }

    private static func state(for stage: Stage, progress: JourneyProgressState) -> StageNodeState {
        if progress.isActive(stage) { return .active }
        if progress.isCompleted(stage) {
            return progress.isLastCompleted(stage) ? .justCompleted : .completed
        }
        return .future
    }
}
