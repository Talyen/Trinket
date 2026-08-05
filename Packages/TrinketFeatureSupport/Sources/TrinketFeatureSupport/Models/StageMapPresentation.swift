import Foundation
import SwiftUI
import TrinketContent
import TrinketDesignSystem

public enum StageMapID {
    public static func stageAction(for stage: Stage) -> String {
        "Stage \(stage.chapterNumber)-\(stage.stageNumber) Action"
    }
}

/// View-only data shared by linear Play surfaces such as Campaign stages and Spire floors.
public struct StageSelectRowPresentation<Item: Identifiable>: Identifiable {
    public let item: Item
    public let isActive: Bool
    public let activeEyebrow: String
    public let mapLabel: String
    public let title: String
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

public extension Stage {
    var mapLabel: String {
        "Stage \(chapterNumber)-\(stageNumber)"
    }

    /// Single card meta line: stage index plus encounter type (no type icon).
    var mapMetaLabel: String {
        "\(mapLabel) · \(encounterTypeTitle)"
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
