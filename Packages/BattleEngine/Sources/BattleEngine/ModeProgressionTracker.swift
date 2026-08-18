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
        keywordBias: Keyword? = nil
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

public struct CampaignProgressionTracker: Sendable {
    public let steps: [ModeProgressionStep]

    public init(chapters: [Chapter] = GameContent.chapters) {
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
                    isBoss: enemy.isBoss
                )
                result.append(step)
            }
        }
        steps = result
    }
}

public struct SpireProgressionTracker: Sendable {
    public let steps: [ModeProgressionStep]

    public init(spires: [SpireDefinition] = GameContent.spires) {
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
                    keywordBias: spire.keyword
                )
                result.append(step)
            }
        }
        steps = result
    }
}

public struct LabyrinthProgressionTracker: Sendable {
    public let steps: [ModeProgressionStep]

    public init(biomes: [LabyrinthBiomeDefinition] = GameContent.labyrinthBiomes, maxDepth: Int = 10) {
        var result: [ModeProgressionStep] = []
        for biome in biomes {
            for depth in 1 ... maxDepth {
                let isBoss = depth == maxDepth
                let enemyID = isBoss ? biome.bossEnemyID : (biome.enemyPool.first ?? "goblin")
                let enemyLevel = max(1, depth)
                let step = ModeProgressionStep(
                    id: "labyrinth-\(biome.id.rawValue)-depth\(depth)",
                    mode: .labyrinth,
                    containerID: biome.id.rawValue,
                    containerTitle: biome.title,
                    stepIndex: depth,
                    displayTitle: "\(biome.title) Depth \(depth)",
                    enemyID: enemyID,
                    enemyLevel: enemyLevel,
                    isBoss: isBoss,
                    keywordBias: biome.keywordBias
                )
                result.append(step)
            }
        }
        steps = result
    }
}
