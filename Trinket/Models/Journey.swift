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
    let flavorText: String
    let encounter: StageEncounter
    let rewards: StageReward
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
