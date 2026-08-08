import Foundation
import SwiftUI
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureSupport
import TrinketPersistence

public extension StageSelectRowPresentation where Item == Stage {
    /// Campaign Stage Select rows for incomplete stages.
    ///
    /// Keep map artwork tied to the authored recruit event. The configured recruit
    /// can resolve to a fallback only when the player takes the stage action;
    /// resolving it here would change card artwork as roster state settles during navigation.
    static func stageRows(
        for chapter: Chapter,
        progress: JourneyProgressState
    ) -> [Self] {
        chapter.stages
            .filter { !progress.isCompleted($0) }
            .map { stage in
                Self(
                    item: stage,
                    isActive: progress.isActive(stage),
                    activeEyebrow: stage.mapLabel,
                    mapLabel: stage.mapLabel,
                    title: stage.encounterSubjectName,
                    encounterTypeTitle: stage.encounterTypeTitle,
                    symbolName: stage.encounter.symbolName,
                    tint: stage.encounter.mapTint,
                    primaryActionTitle: stage.encounter.primaryActionTitle,
                    showsPartyPicker: stage.encounter.isCombat,
                    isArtworkInteractive: stage.encounter.isCombat,
                    rowAccessibilityID: AccessibilityID.Play.stageRow(
                        chapter: stage.chapterNumber,
                        stage: stage.stageNumber
                    ),
                    artworkAccessibilityID: artworkAccessibilityID(for: stage),
                    actionAccessibilityID: StageMapID.stageAction(for: stage),
                    activeDetailAccessibilityID: AccessibilityID.Play.activeStageDetail,
                    partyControlAccessibilityID: AccessibilityID.Play.stagePartyControl
                )
            }
    }

    private static func artworkAccessibilityID(for stage: Stage) -> String {
        if stage.encounter.isCombat {
            return "\(stage.mapLabel) Enemy Art"
        }
        if case .mysteryEvent = stage.encounter {
            return "\(stage.mapLabel) Mystery Art"
        }
        if stage.encounter.eventID != nil {
            return "\(stage.mapLabel) Mystery Art"
        }
        return "\(stage.mapLabel) Encounter Art"
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

public extension StageSelectRowPresentation where Item == LabyrinthNode {
    static func labyrinthRow(
        for node: LabyrinthNode,
        type: LabyrinthNodeType,
        title: String,
        isArtworkInteractive: Bool
    ) -> Self {
        let mapLabel = "Floor \(node.depth)"
        return Self(
            item: node,
            isActive: true,
            activeEyebrow: mapLabel,
            mapLabel: mapLabel,
            title: title,
            encounterTypeTitle: type.title,
            symbolName: LabyrinthMapPresentation.symbolName(
                for: type,
                recruitEventID: node.recruitEventID
            ),
            tint: LabyrinthMapPresentation.tint(for: type),
            primaryActionTitle: LabyrinthMapPresentation.actionTitle(for: node, type: type),
            showsPartyPicker: type.isCombat,
            isArtworkInteractive: isArtworkInteractive,
            rowAccessibilityID: AccessibilityID.Play.labyrinthNode(node.id),
            artworkAccessibilityID: AccessibilityID.Play.labyrinthNodeArtwork(node.id),
            actionAccessibilityID: AccessibilityID.Play.labyrinthInspectorAction(node.id),
            activeDetailAccessibilityID: AccessibilityID.Play.labyrinthNodeInspector,
            partyControlAccessibilityID: "Labyrinth Node \(node.id) Party Control"
        )
    }
}

public extension LabyrinthMapPresentation {
    static func floorNodes(
        for cluster: LabyrinthCluster,
        in state: PlayerLabyrinthState
    ) -> [LabyrinthNode] {
        cluster.nodeIDs.compactMap { state.nodes[$0] }.sorted {
            LabyrinthGridPosition.isOrderedBefore(
                $0.gridPosition ?? LabyrinthGridPosition(row: 0, column: 1),
                $1.gridPosition ?? LabyrinthGridPosition(row: 0, column: 1)
            )
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
