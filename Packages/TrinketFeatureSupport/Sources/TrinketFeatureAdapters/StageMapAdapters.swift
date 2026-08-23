import Foundation
import SwiftUI
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureContracts
import TrinketFeatureSupport
import TrinketPersistence

public extension View {
    /// OK-only alert presenting an optional `StageMapMessage`.
    func trinketMessageAlert(_ message: Binding<StageMapMessage?>) -> some View {
        alert(
            message.wrappedValue?.title ?? "",
            isPresented: Binding(
                get: { message.wrappedValue != nil },
                set: { isPresented in
                    if !isPresented {
                        message.wrappedValue = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message.wrappedValue?.message ?? "")
        }
    }
}

public extension StageSelectRowPresentation where Item == Stage {
    /// Campaign Stage Select rows for incomplete stages.
    ///
    /// Keep map artwork tied to the authored recruit event. The configured recruit
    /// can resolve to a fallback only when the player takes the stage action;
    /// resolving it here would change card artwork as roster state settles during navigation.
    static func stageRows(
        for chapter: Chapter,
        progress: JourneyProgressState,
        worldSeed: UInt64
    ) -> [Self] {
        chapter.stages
            .filter { !progress.isCompleted($0) }
            .map { stage in
                Self(
                    item: stage,
                    isActive: progress.isActive(stage),
                    activeEyebrow: stage.mapLabel,
                    mapLabel: stage.mapLabel,
                    title: stage.encounterSubjectName(worldSeed: worldSeed),
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
                    actionAccessibilityID: AccessibilityID.Play.stageAction(
                        chapter: stage.chapterNumber,
                        stage: stage.stageNumber
                    ),
                    activeDetailAccessibilityID: AccessibilityID.Play.activeStageDetail,
                    partyControlAccessibilityID: AccessibilityID.Play.stagePartyControl
                )
            }
    }

    private static func artworkAccessibilityID(for stage: Stage) -> String {
        if stage.encounter.isCombat {
            return AccessibilityID.Play.enemyArt(
                chapter: stage.chapterNumber,
                stage: stage.stageNumber
            )
        }
        if case .mysteryEvent = stage.encounter {
            return AccessibilityID.Play.mysteryArt(
                chapter: stage.chapterNumber,
                stage: stage.stageNumber
            )
        }
        if stage.encounter.eventID != nil {
            return AccessibilityID.Play.mysteryArt(
                chapter: stage.chapterNumber,
                stage: stage.stageNumber
            )
        }
        return AccessibilityID.Play.encounterArt(
            chapter: stage.chapterNumber,
            stage: stage.stageNumber
        )
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

public extension [SpireDefinition] {
    func orderedForSpiresHub(
        progress: PlayerSpiresState,
        isUnlocked: (SpireDefinition) -> Bool
    ) -> [SpireDefinition] {
        enumerated()
            .sorted { left, right in
                let leftCleared = Swift.min(
                    progress.highestClearedFloor(for: left.element.id.rawValue),
                    left.element.floorCount
                )
                let rightCleared = Swift.min(
                    progress.highestClearedFloor(for: right.element.id.rawValue),
                    right.element.floorCount
                )
                if leftCleared != rightCleared {
                    return leftCleared > rightCleared
                }

                let leftUnlocked = isUnlocked(left.element)
                let rightUnlocked = isUnlocked(right.element)
                if leftUnlocked != rightUnlocked {
                    return leftUnlocked
                }

                return left.offset < right.offset
            }
            .map(\.element)
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
            partyControlAccessibilityID: AccessibilityID.Play.labyrinthPartyControl(nodeID: node.id)
        )
    }
}
