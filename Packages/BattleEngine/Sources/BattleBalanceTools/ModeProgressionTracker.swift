import Foundation
import TrinketContent
import TrinketCore

public enum SimulationGameMode: String, CaseIterable, Codable, Sendable {
    case campaign
    case spire
    case labyrinth

    public var displayName: String {
        switch self {
        case .campaign: "Campaign"
        case .spire: "Spires"
        case .labyrinth: "Labyrinth"
        }
    }
}

public struct ModeProgressionStep: Identifiable, Equatable, Hashable, Codable, Sendable {
    public var id: String
    public var mode: SimulationGameMode
    public var containerID: String
    public var containerTitle: String
    public var stepIndex: Int
    public var displayTitle: String
    public var enemyID: String
    public var enemyLevel: Int
    public var isBoss: Bool
    public var keywordBias: Keyword?
}

public struct ModeProgressionTracker: Sendable {
    public let steps: [ModeProgressionStep]

    public static func campaign(chapters: [Chapter] = GameContent.chapters) -> Self {
        Self(steps: chapters.flatMap { chapter in
            chapter.stages.filter(\.encounter.isCombat).compactMap { stage in
                guard let enemyID = stage.resolvedBattleEnemyID(worldSeed: 1),
                      let enemy = GameContent.enemy(matching: enemyID)
                else { return nil }
                return ModeProgressionStep(
                    id: "campaign-\(chapter.id)-\(stage.id)",
                    mode: .campaign,
                    containerID: chapter.id,
                    containerTitle: "Chapter \(chapter.number): \(chapter.title)",
                    stepIndex: stage.stageNumber,
                    displayTitle: "Stage \(chapter.number)-\(stage.stageNumber)",
                    enemyID: enemy.id,
                    enemyLevel: EncounterLevelResolver.journeyEnemyLevel(for: stage, in: chapter),
                    isBoss: enemy.isBoss,
                )
            }
        })
    }

    public static func spire(spires: [SpireDefinition] = GameContent.spires) -> Self {
        Self(steps: spires.flatMap { spire in
            GameContent.spireFloors(for: spire.id).map { floor in
                ModeProgressionStep(
                    id: "spire-\(spire.id.rawValue)-floor\(floor.floor)",
                    mode: .spire,
                    containerID: spire.id.rawValue,
                    containerTitle: spire.title,
                    stepIndex: floor.floor,
                    displayTitle: "\(spire.title) Floor \(floor.floor)",
                    enemyID: floor.enemyID,
                    enemyLevel: EncounterLevelResolver.spireEnemyLevel(for: floor),
                    isBoss: GameContent.enemy(matching: floor.enemyID)?.isBoss == true,
                    keywordBias: spire.keyword,
                )
            }
        })
    }

    public static func labyrinth(maxDepth: Int = 10) -> Self {
        let trashPool = LabyrinthCatalog.trashEnemyIDs
        let bossPool = LabyrinthCatalog.bossEnemyIDs
        guard maxDepth > 0, !trashPool.isEmpty, !bossPool.isEmpty else {
            return Self(steps: [])
        }
        return Self(steps: (1 ... maxDepth).map { depth in
            let isBoss = depth == maxDepth
            return ModeProgressionStep(
                id: "labyrinth-depth-\(depth)",
                mode: .labyrinth,
                containerID: "labyrinth",
                containerTitle: "The Labyrinth",
                stepIndex: depth,
                displayTitle: "Depth \(depth)",
                enemyID: isBoss ? bossPool[(depth - 1) % bossPool.count] : trashPool[(depth - 1) % trashPool.count],
                enemyLevel: max(1, depth),
                isBoss: isBoss,
            )
        })
    }
}
