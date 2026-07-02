import SwiftUI

enum StageMapID {
    static func chapterGate(for chapter: Chapter) -> String {
        "chapter-gate-\(chapter.id)"
    }

    static func placeholderGate(afterChapterNumber number: Int) -> String {
        "chapter-gate-placeholder-\(number)"
    }
}

struct MapScrollRequest: Identifiable, Equatable {
    let id = UUID()
    let targetID: String
}

enum StageNodeState: Equatable {
    case completed
    case justCompleted
    case active
    case future
}

struct VisibleStageNode: Identifiable {
    let stage: Stage
    let state: StageNodeState

    var id: String {
        stage.id
    }
}

enum StageDeckCard: Identifiable {
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

struct StageMapMessage: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

extension Stage {
    var mapLabel: String {
        "Stage \(chapterNumber)-\(stageNumber)"
    }
}

extension StageEncounter {
    var mapTint: Color {
        switch self {
        case .battle:
            return TrinketDesign.Colors.encounterBattle
        case .event:
            return TrinketDesign.Colors.encounterEvent
        case .shop:
            return TrinketDesign.Colors.encounterShop
        case .rest:
            return TrinketDesign.Colors.encounterRest
        }
    }
}
