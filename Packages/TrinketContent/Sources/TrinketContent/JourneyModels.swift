import Foundation
import TrinketCore

public enum ChapterTheme: String, Codable, Hashable, Sendable {
    case forest
    case dungeon
    case desert
    case tundra
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
    public let encounter: StageEncounter
    public let rewards: StageReward

    public init(
        id: String,
        chapterID: String,
        chapterNumber: Int,
        stageNumber: Int,
        encounter: StageEncounter,
        rewards: StageReward
    ) {
        self.id = id
        self.chapterID = chapterID
        self.chapterNumber = chapterNumber
        self.stageNumber = stageNumber
        self.encounter = encounter
        self.rewards = rewards
    }

    /// Authored battle enemy, or the seeded pick for `randomBattle` stages.
    public var resolvedBattleEnemyID: String? {
        if let enemyID = encounter.battleEnemyID {
            return enemyID
        }
        guard case .randomBattle = encounter else { return nil }
        return GameContent.pickRandomNonBossEnemyID(forStageID: id)
    }
}

public enum StageEncounter: Hashable, Sendable {
    case battle(enemyID: String)
    case randomBattle
    case event
    case shop
    case rest
    case mysteryEvent(eventID: String)
    case recruit(eventID: String)

    /// Sentinel recruit event id: resolve from eligible companions only.
    public static let randomCompanionRecruitID = "random-companion"

    public var title: String {
        switch self {
        case .battle, .randomBattle:
            "Battle"
        case .event:
            "Event"
        case .shop:
            "Shop"
        case .rest:
            "Rest"
        case .mysteryEvent:
            "Mystery"
        case .recruit:
            "Recruit"
        }
    }

    public var symbolName: String {
        switch self {
        case .battle, .randomBattle:
            "bolt.fill"
        case .event:
            "sparkles"
        case .shop:
            "bag.fill"
        case .rest:
            "tent.fill"
        case .mysteryEvent:
            "sparkles"
        case let .recruit(eventID):
            GameContent.recruitEncounterSymbolName(forEventID: eventID)
        }
    }

    public var primaryActionTitle: String {
        switch self {
        case .battle, .randomBattle:
            "Battle"
        case .event:
            "Continue"
        case .shop:
            "Shop"
        case .rest:
            "Rest"
        case .mysteryEvent:
            "Approach"
        case .recruit:
            "Recruit"
        }
    }

    public var isCombat: Bool {
        switch self {
        case .battle, .randomBattle:
            true
        case .event, .shop, .rest, .mysteryEvent, .recruit:
            false
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
            return eventID.isEmpty ? nil : eventID
        }
        return nil
    }

    public var recruitEventID: String? {
        if case let .recruit(eventID) = self {
            return eventID
        }
        return nil
    }

    public var eventID: String? {
        mysteryEventID ?? {
            guard let recruitEventID else { return nil }
            return recruitEventID.isEmpty || recruitEventID == Self.randomCompanionRecruitID
                ? nil
                : recruitEventID
        }()
    }
}

public struct StageReward: Hashable, Sendable {
    public let gold: Int
    public let itemTemplateIDs: [String]
    public let materialRewards: [ResourceAmount]

    public static let empty = StageReward(gold: 0, itemTemplateIDs: [], materialRewards: [])

    public init(gold: Int, itemTemplateIDs: [String], materialRewards: [ResourceAmount] = []) {
        self.gold = gold
        self.itemTemplateIDs = itemTemplateIDs
        self.materialRewards = materialRewards
    }
}
