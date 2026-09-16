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

    public init(
        id: String,
        mode: SimulationGameMode,
        containerID: String,
        containerTitle: String,
        stepIndex: Int,
        displayTitle: String,
        enemyID: String,
        enemyLevel: Int,
        isBoss: Bool,
        keywordBias: Keyword? = nil,
    ) {
        self.id = id
        self.mode = mode
        self.containerID = containerID
        self.containerTitle = containerTitle
        self.stepIndex = stepIndex
        self.displayTitle = displayTitle
        self.enemyID = enemyID
        self.enemyLevel = enemyLevel
        self.isBoss = isBoss
        self.keywordBias = keywordBias
    }
}

public struct ModeProgressionTracker: Sendable {
    public let steps: [ModeProgressionStep]

    public init(steps: [ModeProgressionStep]) {
        self.steps = steps
    }

    public static func campaign(chapters: [Chapter] = GameContent.chapters) -> Self {
        var result: [ModeProgressionStep] = []
        for chapter in chapters {
            let battleStages = chapter.stages.filter(\.encounter.isCombat)
            for stage in battleStages {
                guard let enemyID = stage.resolvedBattleEnemyID(worldSeed: 1),
                      let enemy = GameContent.enemy(matching: enemyID)
                else { continue }

                let enemyLevel = EncounterLevelResolver.journeyEnemyLevel(for: stage, in: chapter)
                let step = ModeProgressionStep(
                    id: "campaign-\(chapter.id)-\(stage.id)",
                    mode: .campaign,
                    containerID: chapter.id,
                    containerTitle: "Chapter \(chapter.number): \(chapter.title)",
                    stepIndex: stage.stageNumber,
                    displayTitle: "Stage \(chapter.number)-\(stage.stageNumber)",
                    enemyID: enemy.id,
                    enemyLevel: enemyLevel,
                    isBoss: enemy.isBoss,
                )
                result.append(step)
            }
        }
        return Self(steps: result)
    }

    public static func spire(spires: [SpireDefinition] = GameContent.spires) -> Self {
        var result: [ModeProgressionStep] = []
        for spire in spires {
            let floors = GameContent.spireFloors(for: spire.id)
            for floor in floors {
                let isBoss = GameContent.enemy(matching: floor.enemyID)?.isBoss == true
                let enemyLevel = EncounterLevelResolver.spireEnemyLevel(for: floor)
                let step = ModeProgressionStep(
                    id: "spire-\(spire.id.rawValue)-floor\(floor.floor)",
                    mode: .spire,
                    containerID: spire.id.rawValue,
                    containerTitle: spire.title,
                    stepIndex: floor.floor,
                    displayTitle: "\(spire.title) Floor \(floor.floor)",
                    enemyID: floor.enemyID,
                    enemyLevel: enemyLevel,
                    isBoss: isBoss,
                    keywordBias: spire.keyword,
                )
                result.append(step)
            }
        }
        return Self(steps: result)
    }

    public static func labyrinth(maxDepth: Int = 10) -> Self {
        var result: [ModeProgressionStep] = []
        let trashPool = LabyrinthCatalog.trashEnemyIDs
        let bossPool = LabyrinthCatalog.bossEnemyIDs
        guard !trashPool.isEmpty, !bossPool.isEmpty else {
            return Self(steps: [])
        }
        for depth in 1 ... maxDepth {
            let isBoss = depth == maxDepth
            let enemyID = isBoss
                ? bossPool[(depth - 1) % bossPool.count]
                : trashPool[(depth - 1) % trashPool.count]
            let step = ModeProgressionStep(
                id: "labyrinth-depth-\(depth)",
                mode: .labyrinth,
                containerID: "labyrinth",
                containerTitle: "The Labyrinth",
                stepIndex: depth,
                displayTitle: "Depth \(depth)",
                enemyID: enemyID,
                enemyLevel: max(1, depth),
                isBoss: isBoss,
            )
            result.append(step)
        }
        return Self(steps: result)
    }
}
