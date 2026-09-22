import TrinketCore

public struct BlacksmithRecipe: Identifiable, Hashable, Sendable {
    public let id: String
    public let baseID: String
    public let cost: [ResourceAmount]

    private init(_ baseID: String, iron: Int, secondary: HomesteadResource = .wood, quantity: Int) {
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
        all.first { $0.id == id }
    }
}
