import TrinketContent
import TrinketPersistence

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
    var encounterCombatantArtReference: CombatantArtReference? {
        guard case let .battle(enemyID) = encounter else { return nil }
        return GameContent.enemy(matching: enemyID)?.combatant.artReference
    }

    var encounterArtReference: EncounterArtReference? {
        if case .battle = encounter { return nil }
        if case let .mysteryEvent(eventID) = encounter {
            guard let artID = GameContent.mysteryEvent(matching: eventID)?.artID else { return nil }
            return ArtCatalog.encounterArtByID[artID]
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
        case let .mysteryEvent(eventID):
            return GameContent.mysteryEvent(matching: eventID)?.title ?? "Mystery"
        }
    }
}
