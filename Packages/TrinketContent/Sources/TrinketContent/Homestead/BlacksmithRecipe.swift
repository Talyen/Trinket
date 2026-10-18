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
    public let researchID: String?

    private init(_ baseID: String, iron: Int, secondary: HomesteadResource = .wood, quantity: Int) {
        buildingID = .blacksmithForge
        requiredKeyword = nil
        researchID = nil
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

    public static func matching(_ id: String) -> Self? {
        (all + archery).first { $0.id == id }
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
        research: String? = nil,
    ) {
        self.id = id
        baseID = base
        buildingID = .archeryRange
        requiredKeyword = keyword
        researchID = research
        cost = [ResourceAmount(.wood, wood), ResourceAmount(.iron, iron), ResourceAmount(.hide, hide), ResourceAmount(.herbs, herbs)]
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
            research: "forest-field-notes",
        ),
        .init(
            "archery-longbow-bleed",
            base: "longbow",
            wood: 60,
            iron: 30,
            hide: 12,
            keyword: .bleed,
            research: "predator-anatomy",
        ),
        .init(
            "archery-crossbow-physical",
            base: "crossbow",
            wood: 48,
            iron: 48,
            keyword: .physical,
            research: "arms-and-armor",
        ),
    ]

    static func recipes(for building: HomesteadNodeID) -> [Self] {
        building == .blacksmithForge ? all : building == .archeryRange ? archery : []
    }
}
