import TrinketCore

public struct EquipmentRecipe: Identifiable, Hashable, Sendable {
    public static func astralWeightBonusPercent(blacksmithTier: Int) -> Int {
        (max(1, min(4, blacksmithTier)) - 1) * 10
    }

    public let id: String
    public let baseID: String
    public let cost: [ResourceAmount]
    public let buildingID: HomesteadNodeID
    public let requiredKeyword: Keyword?
    public var researchID: String? {
        ResearchProject.researchID(forRecipeID: id)
    }

    private init(_ baseID: String, iron: Int, secondary: HomesteadResource = .wood, quantity: Int) {
        buildingID = .blacksmithForge
        requiredKeyword = nil
        id = "blacksmith-\(baseID)"
        self.baseID = baseID
        cost = [ResourceAmount(.iron, iron), ResourceAmount(secondary, quantity)]
    }

    public var baseType: ItemBaseType {
        guard let base = GameContent.itemBaseType(matching: baseID) else {
            preconditionFailure("Blacksmith recipe requires catalog base \(baseID)")
        }
        return base
    }

    public static let all: [Self] = [
        .init("dagger", iron: 24, quantity: 12),
        .init("shortsword", iron: 24, quantity: 12),
        .init("longsword", iron: 32, quantity: 16),
        .init("greatsword", iron: 40, quantity: 20),
        .init("hatchet", iron: 24, quantity: 12),
        .init("double_axe", iron: 40, quantity: 20),
        .init("mace", iron: 32, quantity: 16),
        .init("flail", iron: 32, quantity: 16),
        .init("maul", iron: 40, quantity: 20),
        .init("kite_shield", iron: 32, quantity: 16),
        .init("plate_armor", iron: 40, secondary: .hide, quantity: 20),
    ]

    private static let recipesByID = Dictionary(
        (all + archery + outfitter + focusedBlacksmith).map { ($0.id, $0) },
        uniquingKeysWith: { first, _ in first },
    )

    public static func matching(_ id: String) -> Self? {
        recipesByID[id]
    }
}

public typealias BlacksmithRecipe = EquipmentRecipe

public extension EquipmentRecipe {
    private init(
        _ id: String,
        base: String,
        wood: Int,
        iron: Int = 0,
        hide: Int = 0,
        herbs: Int = 0,
        keyword: Keyword? = nil,
        building: HomesteadNodeID = .archeryRange,
        gems: Int = 0,
        stone: Int = 0,
    ) {
        self.id = id
        baseID = base
        buildingID = building
        requiredKeyword = keyword
        cost = [
            ResourceAmount(.wood, wood),
            ResourceAmount(.iron, iron),
            ResourceAmount(.hide, hide),
            ResourceAmount(.herbs, herbs),
            ResourceAmount(.gems, gems),
            ResourceAmount(.stone, stone),
        ]
        .filter { $0.quantity > 0 }
    }

    static let archery: [Self] = [
        .init("archery-shortbow", base: "shortbow", wood: 32, iron: 16),
        .init("archery-longbow", base: "longbow", wood: 40, iron: 20),
        .init("archery-recurve-bow", base: "recurve_bow", wood: 40, iron: 20),
        .init("archery-crossbow", base: "crossbow", wood: 32, iron: 32),
        .init("archery-quiver", base: "quiver", wood: 16, hide: 32),
        .init(
            "archery-shortbow-poison",
            base: "shortbow",
            wood: 48,
            iron: 24,
            herbs: 8,
            keyword: .poison,
        ),
        .init(
            "archery-longbow-bleed",
            base: "longbow",
            wood: 60,
            iron: 30,
            hide: 12,
            keyword: .bleed,
        ),
        .init(
            "archery-crossbow-physical",
            base: "crossbow",
            wood: 48,
            iron: 48,
            keyword: .physical,
        ),
    ]

    static func recipes(for building: HomesteadNodeID) -> [Self] {
        switch building {
        case .blacksmithForge: all + focusedBlacksmith
        case .archeryRange: archery
        case .woolTailoring: outfitter
        default: []
        }
    }
}

public extension EquipmentRecipe {
    static let outfitter: [Self] = [
        .init("outfitter-leather-armor", base: "leather_armor", wood: 20, hide: 40, building: .woolTailoring),
        .init(
            "outfitter-leather-armor-block",
            base: "leather_armor",
            wood: 30,
            iron: 12,
            hide: 60,
            keyword: .block,
            building: .woolTailoring,
        ),
        .init(
            "outfitter-leather-armor-poison",
            base: "leather_armor",
            wood: 30,
            hide: 60,
            herbs: 12,
            keyword: .poison,
            building: .woolTailoring,
        ),
        .init(
            "outfitter-leather-armor-leech",
            base: "leather_armor",
            wood: 30,
            hide: 60,
            keyword: .leech,
            building: .woolTailoring,
            gems: 12,
        ),
    ]
    static let focusedBlacksmith: [Self] = [
        .init(
            "blacksmith-greatsword-bleed",
            base: "greatsword",
            wood: 30,
            iron: 60,
            hide: 12,
            keyword: .bleed,
            building: .blacksmithForge,
        ),
        .init(
            "blacksmith-mace-holy",
            base: "mace",
            wood: 24,
            iron: 48,
            keyword: .holy,
            building: .blacksmithForge,
            gems: 8,
        ),
        .init(
            "blacksmith-kite-shield-block",
            base: "kite_shield",
            wood: 24,
            iron: 48,
            keyword: .block,
            building: .blacksmithForge,
            stone: 8,
        ),
    ]
}
