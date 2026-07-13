import Foundation
import SwiftUI
import TrinketContent
import TrinketDesignSystem
import TrinketPersistence

enum StageMapID {
    static func chapterGate(for chapter: Chapter) -> String {
        "chapter-gate-\(chapter.id)"
    }

    static func placeholderGate(afterChapterNumber number: Int) -> String {
        "chapter-gate-placeholder-\(number)"
    }

    static func stageNode(for stage: Stage) -> String {
        "Stage \(stage.chapterNumber)-\(stage.stageNumber) Node"
    }

    static func stageAction(for stage: Stage) -> String {
        "Stage \(stage.chapterNumber)-\(stage.stageNumber) Action"
    }

    static func chapterLocked(_ chapter: Chapter) -> String {
        "Chapter \(chapter.number) Locked"
    }
}

enum StageNodeState: Equatable {
    case completed
    case justCompleted
    case active
    case future
}

struct ChapterStageRowPresentation: Identifiable, Equatable {
    let stage: Stage
    let state: StageNodeState
    let connectorBefore: PathConnectorState?
    let connectorAfter: PathConnectorState?
    let isBoss: Bool

    var id: String {
        stage.id
    }

    var isCompleted: Bool {
        state == .completed || state == .justCompleted
    }

    var isActionable: Bool {
        state == .active
    }

    var accessibilityStatus: String {
        switch state {
        case .completed, .justCompleted:
            "Completed"
        case .active:
            "Current stage"
        case .future:
            "Not reached"
        }
    }

    static func rows(
        for chapter: Chapter,
        progress: JourneyProgressState
    ) -> [ChapterStageRowPresentation] {
        let states = chapter.stages.map {
            JourneyMapPresentation.stageNodeState(for: $0, progress: progress)
        }

        return chapter.stages.enumerated().map { index, stage in
            let state = states[index]
            let connectorBefore: PathConnectorState? = index == chapter.stages.startIndex
                ? nil
                : (state == .future ? .future : .progressed)
            let connectorAfter: PathConnectorState? = index == chapter.stages.index(before: chapter.stages.endIndex)
                ? nil
                : (states[index + 1] == .future ? .future : .progressed)

            return ChapterStageRowPresentation(
                stage: stage,
                state: state,
                connectorBefore: connectorBefore,
                connectorAfter: connectorAfter,
                isBoss: stage.isBossEncounter
            )
        }
    }
}

struct StageMapMessage: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

extension Stage {
    var mapLabel: String {
        "Stage \(chapterNumber)-\(stageNumber)"
    }

    /// Single card meta line: stage index plus encounter type (no type icon).
    var mapMetaLabel: String {
        "\(mapLabel) · \(encounterTypeTitle)"
    }

    var mysteryEvent: MysteryEvent? {
        guard let eventID = encounter.mysteryEventID else { return nil }
        return GameContent.mysteryEvent(matching: eventID)
    }

    var recruitCombatant: Combatant? {
        guard let event = mysteryEvent else { return nil }
        return GameContent.combatant(forMysteryEvent: event)
    }

    var encounterCombatantArtReference: CombatantArtReference? {
        if case let .battle(enemyID) = encounter {
            return GameContent.enemy(matching: enemyID)?.combatant.artReference
        }
        return nil
    }

    var encounterArtReference: EncounterArtReference? {
        if case .battle = encounter {
            return nil
        }
        if case .mysteryEvent = encounter {
            if let recruit = recruitCombatant {
                let artID = recruit.role == .companion
                    ? "mystery-recruit-companions"
                    : "mystery-recruit-heroes"
                return ArtCatalog.encounterArtByID[artID]
            }
            guard let artID = mysteryEvent?.artID else { return nil }
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
        case .mysteryEvent:
            if recruitCombatant != nil {
                return "Mystery"
            }
            return mysteryEvent?.title ?? "Mystery"
        }
    }

    var encounterTypeTitle: String {
        if isBossEncounter {
            return "Boss"
        }
        if recruitCombatant != nil {
            return "Recruit"
        }
        return encounter.title
    }

    var isBossEncounter: Bool {
        guard let enemyID = encounter.battleEnemyID else { return false }
        return GameContent.enemy(matching: enemyID)?.isBoss == true
    }
}

extension StageEncounter {
    var artAspectRatio: CGFloat {
        4.0 / 3.0
    }

    var mapTint: Color {
        switch self {
        case .battle:
            TrinketDesign.Colors.encounterBattle
        case .event, .mysteryEvent:
            TrinketDesign.Colors.encounterEvent
        case .shop:
            TrinketDesign.Colors.encounterShop
        case .rest:
            TrinketDesign.Colors.encounterRest
        }
    }
}
