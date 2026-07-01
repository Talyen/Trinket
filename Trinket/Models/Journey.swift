import SwiftUI

enum ChapterTheme: String, Codable, Hashable {
    case verdantForest

    var tint: Color {
        switch self {
        case .verdantForest:
            return Color.green
        }
    }

    var secondaryTint: Color {
        switch self {
        case .verdantForest:
            return Color.mint
        }
    }
}

struct Chapter: Identifiable, Hashable {
    let id: String
    let number: Int
    let title: String
    let theme: ChapterTheme
    let stages: [Stage]
}

struct Stage: Identifiable, Hashable {
    let id: String
    let chapterID: String
    let chapterNumber: Int
    let stageNumber: Int
    let title: String
    let flavorText: String
    let encounter: StageEncounter
    let rewards: StageReward

    var displayTitle: String {
        "Stage \(chapterNumber)-\(stageNumber): \(title)"
    }
}

enum StageEncounter: Hashable {
    case battle(enemyID: String)
    case event
    case shop
    case rest

    var title: String {
        switch self {
        case .battle:
            return "Battle"
        case .event:
            return "Event"
        case .shop:
            return "Shop"
        case .rest:
            return "Rest"
        }
    }

    var symbolName: String {
        switch self {
        case .battle:
            return "bolt.fill"
        case .event:
            return "sparkles"
        case .shop:
            return "bag.fill"
        case .rest:
            return "tent.fill"
        }
    }

    var primaryActionTitle: String {
        switch self {
        case .battle:
            return "Battle"
        case .event:
            return "Continue"
        case .shop:
            return "Shop"
        case .rest:
            return "Rest"
        }
    }

    var battleEnemyID: String? {
        if case let .battle(enemyID) = self {
            return enemyID
        }
        return nil
    }
}

struct StageReward: Hashable {
    let gold: Int
    let experience: Int
    let itemTemplateIDs: [String]
    let materialRewards: [ResourceAmount]

    init(
        gold: Int,
        experience: Int,
        itemTemplateIDs: [String],
        materialRewards: [ResourceAmount] = []
    ) {
        self.gold = gold
        self.experience = experience
        self.itemTemplateIDs = itemTemplateIDs
        self.materialRewards = materialRewards
    }

    static let empty = StageReward(gold: 0, experience: 0, itemTemplateIDs: [])

    var hasRewards: Bool {
        gold > 0 || experience > 0 || !itemTemplateIDs.isEmpty || !materialRewards.isEmpty
    }
}

struct JourneyProgressState: Codable, Equatable {
    var activeChapterID: String
    var activeStageID: String?
    var completedStageIDs: Set<String>
    var claimedRewardStageIDs: Set<String>
    var lastCompletedStageID: String?

    static let initial = JourneyProgressState(
        activeChapterID: "chapter-1",
        activeStageID: "chapter-1-stage-1",
        completedStageIDs: [],
        claimedRewardStageIDs: [],
        lastCompletedStageID: nil
    )

    func isActive(_ stage: Stage) -> Bool {
        activeStageID == stage.id
    }

    func isCompleted(_ stage: Stage) -> Bool {
        completedStageIDs.contains(stage.id)
    }

    func isLastCompleted(_ stage: Stage) -> Bool {
        lastCompletedStageID == stage.id
    }

    func hasClaimedRewards(for stage: Stage) -> Bool {
        claimedRewardStageIDs.contains(stage.id)
    }

    mutating func markRewardsClaimed(for stage: Stage) {
        claimedRewardStageIDs.insert(stage.id)
    }

    mutating func complete(_ stage: Stage, in chapters: [Chapter]) {
        completedStageIDs.insert(stage.id)
        lastCompletedStageID = stage.id

        if let nextStage = Self.nextStage(after: stage, in: chapters) {
            activeChapterID = nextStage.chapterID
            activeStageID = nextStage.id
        } else {
            activeStageID = nil
        }
    }

    static func nextStage(after stage: Stage, in chapters: [Chapter]) -> Stage? {
        guard let chapterIndex = chapters.firstIndex(where: { $0.id == stage.chapterID }),
              let stageIndex = chapters[chapterIndex].stages.firstIndex(where: { $0.id == stage.id })
        else { return nil }

        let chapter = chapters[chapterIndex]
        let nextStageIndex = stageIndex + 1
        if chapter.stages.indices.contains(nextStageIndex) {
            return chapter.stages[nextStageIndex]
        }

        let nextChapterIndex = chapterIndex + 1
        guard chapters.indices.contains(nextChapterIndex) else { return nil }
        return chapters[nextChapterIndex].stages.first
    }
}
