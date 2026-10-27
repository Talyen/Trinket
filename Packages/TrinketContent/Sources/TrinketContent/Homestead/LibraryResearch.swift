import Foundation

public struct ResearchProject: Identifiable, Hashable, Sendable {
    public enum Objective: Hashable, Sendable {
        case defeat(String)

        fileprivate func isSatisfied(in history: LibraryProgress) -> Bool {
            switch self {
            case let .defeat(id): history.defeatedEnemyIDs.contains(id)
            }
        }
    }

    public let id: String
    public let minimumLibraryTier: Int
    public let objectives: [Objective]
    public let recipeID: String?

    private init(_ id: String, tier: Int, objectives: [Objective], recipe: String? = nil) {
        precondition((1 ... 3).contains(objectives.count))
        self.id = id
        minimumLibraryTier = tier
        self.objectives = objectives
        recipeID = recipe
    }

    public static let all: [Self] = [
        .init(
            "forest-field-notes",
            tier: 1,
            objectives: [.defeat("slime"), .defeat("goblin"), .defeat("the_blight_treant")],
            recipe: "archery-shortbow-poison",
        ),
        .init(
            "predator-anatomy",
            tier: 2,
            objectives: [.defeat("giant_spider"), .defeat("giant_snake"), .defeat("dire_wolf")],
            recipe: "archery-longbow-bleed",
        ),
        .init(
            "arms-and-armor",
            tier: 3,
            objectives: [.defeat("goblin"), .defeat("bandit"), .defeat("living_armor")],
            recipe: "archery-crossbow-physical",
        ),
        .init("serrated-steel", tier: 1, objectives: [.defeat("bandit"), .defeat("dire_wolf")], recipe: "blacksmith-greatsword-bleed"),
        .init("consecrated-arms", tier: 2, objectives: [.defeat("cleric"), .defeat("paladin")], recipe: "blacksmith-mace-holy"),
        .init(
            "shieldcraft",
            tier: 3,
            objectives: [.defeat("living_armor"), .defeat("stone_golem")],
            recipe: "blacksmith-kite-shield-block",
        ),
        .init(
            "reinforced-leather",
            tier: 1,
            objectives: [.defeat("goblin"), .defeat("living_armor")],
            recipe: "outfitter-leather-armor-block",
        ),
        .init(
            "venomproof-leather",
            tier: 2,
            objectives: [.defeat("giant_spider"), .defeat("giant_snake")],
            recipe: "outfitter-leather-armor-poison",
        ),
        .init(
            "sanguine-leather",
            tier: 3,
            objectives: [.defeat("vampire"), .defeat("blood_cultist")],
            recipe: "outfitter-leather-armor-leech",
        ),
    ]

    public static func matching(_ id: String) -> Self? {
        all.first { $0.id == id }
    }

    public func progress(in history: LibraryProgress) -> [Bool] {
        objectives.map { $0.isSatisfied(in: history) }
    }
}

/// Earned facts and unlocks are monotonic within a save/reset epoch.
public struct LibraryProgress: Codable, Equatable, Sendable {
    public let version: Int
    public var backfillVersion: Int
    public private(set) var encounteredEnemyIDs: Set<String>
    public private(set) var defeatedEnemyIDs: Set<String>
    public private(set) var completedResearchIDs: Set<String>
    public private(set) var unlockedRecipeIDs: Set<String>

    public init() {
        version = 1
        backfillVersion = 0
        encounteredEnemyIDs = []
        defeatedEnemyIDs = []
        completedResearchIDs = []
        unlockedRecipeIDs = []
    }

    public mutating func encounter(_ id: String) {
        guard GameContent.enemy(matching: id) != nil else { return }
        encounteredEnemyIDs.insert(id)
    }

    public mutating func defeat(_ id: String) {
        guard GameContent.enemy(matching: id) != nil else { return }
        encounteredEnemyIDs.insert(id)
        defeatedEnemyIDs.insert(id)
    }

    public mutating func merge(_ other: Self) {
        encounteredEnemyIDs.formUnion(other.encounteredEnemyIDs)
        defeatedEnemyIDs.formUnion(other.defeatedEnemyIDs)
        encounteredEnemyIDs.formUnion(defeatedEnemyIDs)
        completedResearchIDs.formUnion(other.completedResearchIDs)
        unlockedRecipeIDs.formUnion(other.unlockedRecipeIDs)
        backfillVersion = max(backfillVersion, other.backfillVersion)
    }

    @discardableResult
    public mutating func evaluate(libraryTier: Int) -> [String] {
        var completed: [String] = []
        for project in ResearchProject.all where !completedResearchIDs.contains(project.id) {
            guard libraryTier >= project.minimumLibraryTier,
                  project.objectives.allSatisfy({ $0.isSatisfied(in: self) })
            else { continue }
            completedResearchIDs.insert(project.id)
            if let recipeID = project.recipeID {
                unlockedRecipeIDs.insert(recipeID)
            }
            completed.append(project.id)
        }
        return completed
    }
}
