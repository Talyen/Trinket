import Foundation
import SwiftUI
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureSupport
import TrinketPersistence

public enum JourneyMapPresentation {
    public static func gateChapter(after chapter: Chapter, in chapters: [Chapter]) -> Chapter {
        guard let chapterIndex = chapters.firstIndex(where: { $0.id == chapter.id }),
              chapters.indices.contains(chapterIndex + 1)
        else { return placeholderGateChapter(after: chapter) }
        return chapters[chapterIndex + 1]
    }

    public static func placeholderGateChapter(after chapter: Chapter) -> Chapter {
        let nextNumber = chapter.number + 1
        return Chapter(
            id: StageMapID.placeholderGate(afterChapterNumber: nextNumber),
            number: nextNumber,
            title: "",
            theme: chapter.theme,
            stages: []
        )
    }

    public static func stageNodeState(for stage: Stage, progress: JourneyProgressState) -> StageNodeState {
        if progress.isActive(stage) {
            return .active
        }
        if progress.isCompleted(stage) {
            return progress.isLastCompleted(stage) ? .justCompleted : .completed
        }
        return .future
    }

    public static func chapterRows(
        chapters: [Chapter],
        chapter: Chapter,
        progress: JourneyProgressState
    ) -> [ChapterJourneyRow] {
        chapter.stages.compactMap { stage -> ChapterJourneyRow? in
            let state = stageNodeState(for: stage, progress: progress)
            guard state != .completed, state != .justCompleted else { return nil }
            return .stage(stage, state)
        } + [.chapterGate(gateChapter(after: chapter, in: chapters))]
    }
}

public enum ChapterJourneyRow: Identifiable {
    case stage(Stage, StageNodeState)
    case chapterGate(Chapter)

    public var id: String {
        switch self {
        case let .stage(stage, _):
            stage.id
        case let .chapterGate(chapter):
            StageMapID.chapterGate(for: chapter)
        }
    }
}

public extension ChapterStageRowPresentation {
    static func rows(
        for chapter: Chapter,
        progress: JourneyProgressState
    ) -> [Self] {
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

            return Self(
                stage: stage,
                state: state,
                connectorBefore: connectorBefore,
                connectorAfter: connectorAfter,
                isBoss: stage.isBossEncounter
            )
        }
    }
}

public extension StageSelectRowPresentation where Item == SpireFloor {
    static func spireRows(
        for spire: SpireDefinition,
        floors: [SpireFloor],
        progress: PlayerSpiresState
    ) -> [Self] {
        let highestCleared = progress.highestClearedFloor(for: spire.id.rawValue)
        guard highestCleared < spire.floorCount else { return [] }

        let activeFloor = progress.activeFloor(
            for: spire.id.rawValue,
            floorCount: spire.floorCount
        )

        return floors.compactMap { floor in
            guard floor.floor > highestCleared,
                  let enemy = GameContent.enemy(matching: floor.enemyID)
            else { return nil }

            let encounter = StageEncounter.battle(enemyID: floor.enemyID)
            let encounterTypeTitle = enemy.isBoss ? "Boss" : encounter.title
            let mapLabel = "Floor \(floor.floor)"
            return Self(
                item: floor,
                isActive: floor.floor == activeFloor,
                activeEyebrow: "\(mapLabel) · \(encounterTypeTitle)",
                mapLabel: mapLabel,
                title: enemy.combatant.name,
                activeDetailLines: [],
                encounterTypeTitle: encounterTypeTitle,
                symbolName: encounter.symbolName,
                tint: encounter.mapTint,
                primaryActionTitle: "Battle",
                showsPartyPicker: true,
                isArtworkInteractive: true,
                rowAccessibilityID: AccessibilityID.Play.spireFloor(
                    spire.id.rawValue,
                    floor: floor.floor
                ),
                artworkAccessibilityID: AccessibilityID.Play.spireFloorEnemyArt(
                    spire.id.rawValue,
                    floor: floor.floor
                ),
                actionAccessibilityID: AccessibilityID.Play.spireBeginFloor(
                    spire.id.rawValue,
                    floor: floor.floor
                ),
                activeDetailAccessibilityID: AccessibilityID.Play.spireActiveFloorDetail(
                    spire.id.rawValue
                ),
                partyControlAccessibilityID: AccessibilityID.Play.spirePartyControl(
                    spire.id.rawValue
                )
            )
        }
    }
}

public extension LabyrinthMapPresentation {
    static func floorNodes(
        for cluster: LabyrinthCluster,
        in state: PlayerLabyrinthState
    ) -> [LabyrinthNode] {
        cluster.nodeIDs.compactMap { state.nodes[$0] }.sorted {
            let left = $0.gridPosition ?? LabyrinthGridPosition(row: 0, column: 1)
            let right = $1.gridPosition ?? LabyrinthGridPosition(row: 0, column: 1)
            return left.row == right.row ? left.column < right.column : left.row < right.row
        }
    }

    static func state(
        for node: LabyrinthNode,
        in labyrinth: PlayerLabyrinthState
    ) -> LabyrinthMapNodeState {
        if node.isCleared {
            return .cleared
        }
        return labyrinth.isNodeReachable(node.id) ? .reachable : .locked
    }
}
