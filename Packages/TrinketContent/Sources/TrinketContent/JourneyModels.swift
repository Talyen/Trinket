import Foundation
import TrinketCore

public enum ChapterTheme: String, Codable, Hashable, Sendable {
    case verdantForest
}

public struct Chapter: Identifiable, Hashable, Sendable {
    public let id: String
    public let number: Int
    public let title: String
    public let theme: ChapterTheme
    public let stages: [Stage]

    public init(id: String, number: Int, title: String, theme: ChapterTheme, stages: [Stage]) {
        self.id = id
        self.number = number
        self.title = title
        self.theme = theme
        self.stages = stages
    }
}

public struct Stage: Identifiable, Hashable, Sendable {
    public let id: String
    public let chapterID: String
    public let chapterNumber: Int
    public let stageNumber: Int
    public let flavorText: String
    public let encounter: StageEncounter
    public let rewards: StageReward

    public init(
        id: String,
        chapterID: String,
        chapterNumber: Int,
        stageNumber: Int,
        flavorText: String,
        encounter: StageEncounter,
        rewards: StageReward
    ) {
        self.id = id
        self.chapterID = chapterID
        self.chapterNumber = chapterNumber
        self.stageNumber = stageNumber
        self.flavorText = flavorText
        self.encounter = encounter
        self.rewards = rewards
    }
}

public enum StageEncounter: Hashable, Sendable {
    case battle(enemyID: String)
    case event
    case shop
    case rest
    case mysteryEvent(eventID: String)

    public var title: String {
        switch self {
        case .battle:
            return "Battle"
        case .event:
            return "Event"
        case .shop:
            return "Shop"
        case .rest:
            return "Rest"
        case .mysteryEvent:
            return "Mystery"
        }
    }

    public var symbolName: String {
        switch self {
        case .battle:
            return "bolt.fill"
        case .event:
            return "sparkles"
        case .shop:
            return "bag.fill"
        case .rest:
            return "tent.fill"
        case .mysteryEvent:
            return "sparkles"
        }
    }

    public var primaryActionTitle: String {
        switch self {
        case .battle:
            return "Battle"
        case .event:
            return "Continue"
        case .shop:
            return "Shop"
        case .rest:
            return "Rest"
        case .mysteryEvent:
            return "Investigate"
        }
    }

    public var battleEnemyID: String? {
        if case let .battle(enemyID) = self {
            return enemyID
        }
        return nil
    }

    public var mysteryEventID: String? {
        if case let .mysteryEvent(eventID) = self {
            return eventID
        }
        return nil
    }
}

public struct StageReward: Hashable, Sendable {
    public let gold: Int
    public let itemTemplateIDs: [String]
    public let materialRewards: [ResourceAmount]

    public init(
        gold: Int,
        itemTemplateIDs: [String],
        materialRewards: [ResourceAmount] = []
    ) {
        self.gold = gold
        self.itemTemplateIDs = itemTemplateIDs
        self.materialRewards = materialRewards
    }

    public static let empty = StageReward(gold: 0, itemTemplateIDs: [])

    public var hasRewards: Bool {
        gold > 0 || !itemTemplateIDs.isEmpty || !materialRewards.isEmpty
    }
}
