import SwiftUI
import TrinketContent

struct ChapterJourneyPresentation {
    let chapter: Chapter
    let rows: [ChapterJourneyRow]
    let scrollTargetID: String?

    init(chapters: [Chapter], chapter: Chapter, progress: JourneyProgressState) {
        self.chapter = chapter
        rows = chapter.stages.compactMap { stage -> ChapterJourneyRow? in
            let state = JourneyMapPresentation.stageNodeState(for: stage, progress: progress)
            guard state != .completed, state != .justCompleted else { return nil }

            return .stage(VisibleStageNode(
                stage: stage,
                state: state
            ))
        } + [.chapterGate(JourneyMapPresentation.gateChapter(after: chapter, in: chapters))]
        scrollTargetID = JourneyMapPresentation.scrollFocusID(
            for: progress,
            chapter: chapter,
            chapters: chapters
        )
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
