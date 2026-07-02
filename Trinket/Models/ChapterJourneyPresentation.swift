import SwiftUI

struct ChapterJourneyPresentation {
    let chapter: Chapter
    let rows: [ChapterJourneyRow]
    let scrollTargetID: String?

    init(chapters: [Chapter], chapter: Chapter, progress: JourneyProgressState) {
        self.chapter = chapter
        rows = chapter.stages.compactMap { stage -> ChapterJourneyRow? in
            let state = Self.state(for: stage, progress: progress)
            guard state != .completed, state != .justCompleted else { return nil }

            return .stage(VisibleStageNode(
                stage: stage,
                state: state
            ))
        } + [.chapterGate(Self.gateChapter(after: chapter, in: chapters))]
        scrollTargetID = progress.activeStageID
    }

    private static func gateChapter(after chapter: Chapter, in chapters: [Chapter]) -> Chapter {
        guard let chapterIndex = chapters.firstIndex(where: { $0.id == chapter.id }),
              chapters.indices.contains(chapterIndex + 1)
        else { return placeholderGateChapter(after: chapter) }
        return chapters[chapterIndex + 1]
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

enum ChapterJourneyRow: Identifiable {
    case stage(VisibleStageNode)
    case chapterGate(Chapter)

    var id: String {
        switch self {
        case let .stage(node):
            return node.id
        case let .chapterGate(chapter):
            return StageMapID.chapterGate(for: chapter)
        }
    }
}

extension Stage {
    var encounterArtReference: EncounterArtReference? {
        if case let .battle(enemyID) = encounter {
            guard let combatantArt = GameContent.enemy(matching: enemyID)?.combatant.artReference else {
                return nil
            }
            return EncounterArtReference(
                imageName: combatantArt.imageName,
                thumbnailImageName: combatantArt.thumbnailImageName,
                accessibilityLabel: combatantArt.accessibilityLabel
            )
        }

        guard let artID = GameContent.encounterArtID(for: self) else { return nil }
        return ArtCatalog.encounterArtByID[artID]
    }

    var encounterSubjectName: String {
        switch encounter {
        case let .battle(enemyID):
            return GameContent.enemy(matching: enemyID)?.name ?? "Unknown Enemy"
        case .event:
            return GameContent.encounterArtTitle(for: self) ?? "Mystery"
        case .shop:
            return GameContent.encounterArtTitle(for: self) ?? "Merchant"
        case .rest:
            return GameContent.encounterArtTitle(for: self) ?? "Moonwell"
        }
    }
}
