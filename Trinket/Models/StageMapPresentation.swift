import SwiftUI

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

    var baseTint: Color {
        switch self {
        case .active:
            return .primary
        case .completed, .justCompleted:
            return TrinketDesign.Colors.success
        case .future:
            return .secondary
        }
    }

    var statusLabel: String {
        switch self {
        case .active:
            return "Active"
        case .completed, .justCompleted:
            return "Cleared"
        case .future:
            return "Locked"
        }
    }
}

struct StageNodeStyle {
    let tint: Color
    let symbolName: String
    let label: String

    static func style(for state: StageNodeState, encounter: StageEncounter) -> Self {
        switch state {
        case .active:
            StageNodeStyle(
                tint: encounter.mapTint,
                symbolName: encounter.symbolName,
                label: encounter.title
            )
        case .completed, .justCompleted:
            StageNodeStyle(
                tint: TrinketDesign.Colors.success,
                symbolName: "checkmark.circle.fill",
                label: "Cleared"
            )
        case .future:
            StageNodeStyle(
                tint: .secondary,
                symbolName: "lock.fill",
                label: "Locked"
            )
        }
    }
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
    var artAspectRatio: CGFloat {
        switch self {
        case .battle:
            return 1
        case .event, .shop, .rest:
            return 4.0 / 3.0
        }
    }

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
