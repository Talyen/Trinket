import Foundation
import SwiftUI
import TrinketContent
import TrinketDesignSystem

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

struct StageMapMessage: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

extension Stage {
    var mapLabel: String {
        "Stage \(chapterNumber)-\(stageNumber)"
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
        if let recruit = recruitCombatant {
            return recruit.artReference
        }
        return nil
    }

    var encounterArtReference: EncounterArtReference? {
        if case .battle = encounter { return nil }
        if case .mysteryEvent = encounter {
            // Recruit mysteries use combatant portrait art (3:4), not encounter art.
            if recruitCombatant != nil { return nil }
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
            if let recruit = recruitCombatant {
                return recruit.name
            }
            return mysteryEvent?.title ?? "Mystery"
        }
    }
}

extension StageEncounter {
    var artAspectRatio: CGFloat {
        switch self {
        case .battle:
            return 1
        case let .mysteryEvent(eventID):
            if let event = GameContent.mysteryEvent(matching: eventID), event.isRecruit {
                return 3.0 / 4.0
            }
            return 4.0 / 3.0
        case .event, .shop, .rest:
            return 4.0 / 3.0
        }
    }

    var mapTint: Color {
        switch self {
        case .battle:
            return TrinketDesign.Colors.encounterBattle
        case .event, .mysteryEvent:
            return TrinketDesign.Colors.encounterEvent
        case .shop:
            return TrinketDesign.Colors.encounterShop
        case .rest:
            return TrinketDesign.Colors.encounterRest
        }
    }
}
