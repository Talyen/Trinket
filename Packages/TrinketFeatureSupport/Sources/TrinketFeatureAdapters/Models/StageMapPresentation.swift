import Foundation
import SwiftUI
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureSupport
import TrinketPersistence

public enum StageMapID {
    public static func chapterGate(for chapter: Chapter) -> String {
        "chapter-gate-\(chapter.id)"
    }

    public static func placeholderGate(afterChapterNumber number: Int) -> String {
        "chapter-gate-placeholder-\(number)"
    }

    public static func stageNode(for stage: Stage) -> String {
        "Stage \(stage.chapterNumber)-\(stage.stageNumber) Node"
    }

    public static func stageAction(for stage: Stage) -> String {
        "Stage \(stage.chapterNumber)-\(stage.stageNumber) Action"
    }

    public static func chapterLocked(_ chapter: Chapter) -> String {
        "Chapter \(chapter.number) Locked"
    }
}

public enum StageNodeState: Equatable {
    case completed
    case justCompleted
    case active
    case future
}

public struct ChapterStageRowPresentation: Identifiable, Equatable {
    public let stage: Stage
    public let state: StageNodeState
    public let connectorBefore: PathConnectorState?
    public let connectorAfter: PathConnectorState?
    public let isBoss: Bool

    public var id: String {
        stage.id
    }

    public var isCompleted: Bool {
        state == .completed || state == .justCompleted
    }

    public var isActionable: Bool {
        state == .active
    }

    public var accessibilityStatus: String {
        switch state {
        case .completed, .justCompleted:
            "Completed"
        case .active:
            "Current stage"
        case .future:
            "Not reached"
        }
    }

    public static func rows(
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

/// View-only data shared by linear Play surfaces such as Campaign stages and Spire floors.
public struct StageSelectRowPresentation<Item: Identifiable>: Identifiable {
    public let item: Item
    public let isActive: Bool
    public let activeEyebrow: String
    public let mapLabel: String
    public let title: String
    public let activeDetailLines: [String]
    public let encounterTypeTitle: String
    public let symbolName: String
    public let tint: Color
    public let primaryActionTitle: String
    public let showsPartyPicker: Bool
    public let isArtworkInteractive: Bool
    public let rowAccessibilityID: String
    public let artworkAccessibilityID: String
    public let actionAccessibilityID: String
    public let activeDetailAccessibilityID: String
    public let partyControlAccessibilityID: String

    public var id: Item.ID {
        item.id
    }

    public init(
        item: Item,
        isActive: Bool,
        activeEyebrow: String,
        mapLabel: String,
        title: String,
        activeDetailLines: [String],
        encounterTypeTitle: String,
        symbolName: String,
        tint: Color,
        primaryActionTitle: String,
        showsPartyPicker: Bool,
        isArtworkInteractive: Bool,
        rowAccessibilityID: String,
        artworkAccessibilityID: String,
        actionAccessibilityID: String,
        activeDetailAccessibilityID: String,
        partyControlAccessibilityID: String
    ) {
        self.item = item
        self.isActive = isActive
        self.activeEyebrow = activeEyebrow
        self.mapLabel = mapLabel
        self.title = title
        self.activeDetailLines = activeDetailLines
        self.encounterTypeTitle = encounterTypeTitle
        self.symbolName = symbolName
        self.tint = tint
        self.primaryActionTitle = primaryActionTitle
        self.showsPartyPicker = showsPartyPicker
        self.isArtworkInteractive = isArtworkInteractive
        self.rowAccessibilityID = rowAccessibilityID
        self.artworkAccessibilityID = artworkAccessibilityID
        self.actionAccessibilityID = actionAccessibilityID
        self.activeDetailAccessibilityID = activeDetailAccessibilityID
        self.partyControlAccessibilityID = partyControlAccessibilityID
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

public extension Stage {
    var mapLabel: String {
        "Stage \(chapterNumber)-\(stageNumber)"
    }

    /// Single card meta line: stage index plus encounter type (no type icon).
    var mapMetaLabel: String {
        "\(mapLabel) · \(encounterTypeTitle)"
    }

    var mysteryEvent: MysteryEvent? {
        if let eventID = encounter.mysteryEventID {
            return GameContent.mysteryEvent(matching: eventID)
        }
        guard let eventID = encounter.recruitEventID else { return nil }
        return GameContent.recruitEvent(matching: eventID)
    }

    var recruitCombatant: Combatant? {
        guard case .recruit = encounter else { return nil }
        guard let event = mysteryEvent else { return nil }
        return GameContent.combatant(forMysteryEvent: event)
    }

    var encounterCombatantArtReference: CombatantArtReference? {
        guard let enemyID = resolvedBattleEnemyID else { return nil }
        return GameContent.enemy(matching: enemyID)?.combatant.artReference
    }

    var encounterArtReference: EncounterArtReference? {
        if encounter.isCombat {
            return nil
        }
        if encounter.eventID != nil {
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
            GameContent.enemy(matching: enemyID)?.name ?? "Unknown Enemy"
        case .randomBattle:
            resolvedBattleEnemyID.flatMap { GameContent.enemy(matching: $0)?.name } ?? "Battle"
        case .event:
            GameContent.encounterArtTitle(for: self) ?? "Mystery"
        case .shop:
            GameContent.encounterArtTitle(for: self) ?? "Merchant"
        case .rest:
            GameContent.encounterArtTitle(for: self) ?? "Moonwell"
        case .mysteryEvent:
            mysteryEvent?.title ?? "Mystery"
        case .recruit:
            "Mystery"
        }
    }

    var encounterTypeTitle: String {
        if isBossEncounter {
            return "Boss"
        }
        return encounter.title
    }

    var isBossEncounter: Bool {
        guard let enemyID = encounter.battleEnemyID else { return false }
        return GameContent.enemy(matching: enemyID)?.isBoss == true
    }
}

public extension StageEncounter {
    var artAspectRatio: CGFloat {
        4.0 / 3.0
    }

    var mapTint: Color {
        switch self {
        case .battle, .randomBattle:
            TrinketDesign.Colors.encounterBattle
        case .event, .mysteryEvent, .recruit:
            TrinketDesign.Colors.encounterEvent
        case .shop:
            TrinketDesign.Colors.encounterShop
        case .rest:
            TrinketDesign.Colors.encounterRest
        }
    }
}
