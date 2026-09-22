public struct ContentAccessPolicy: Equatable, Sendable {
    public static let free = Self(hasFullGame: false)
    public static let fullGame = Self(hasFullGame: true)
    public static let freeHeroIDs = ["knight", "ranger", "rogue", "wizard"]
    public static let freeCompanionIDs = ["wolf", "bear", "frost_whelp", "library_owl"]
    public static let freeCampaignChapterCount = 3
    public static let freeLabyrinthFloorCount = 3
    public static let freeSpireFloorCount = 10

    public let hasFullGame: Bool

    private init(hasFullGame: Bool) {
        self.hasFullGame = hasFullGame
    }

    public func allowsChapter(_ number: Int) -> Bool {
        number > 0 && (hasFullGame || number <= Self.freeCampaignChapterCount)
    }

    public func allowsLabyrinthFloor(_ floor: Int) -> Bool {
        floor > 0 && (hasFullGame || floor <= Self.freeLabyrinthFloorCount)
    }

    public func allowsSpireFloor(_ floor: Int) -> Bool {
        floor > 0 && (hasFullGame || floor <= Self.freeSpireFloorCount)
    }

    public func allowsCombatant(_ id: String) -> Bool {
        hasFullGame || Self.isFreeCombatant(id)
    }

    public static let freeCombatantIDs: Set<String> = Set(freeHeroIDs).union(freeCompanionIDs)

    public static func isFreeCombatant(_ id: String) -> Bool {
        freeCombatantIDs.contains(id)
    }

    public static func freeFirst(_ combatants: [Combatant]) -> [Combatant] {
        var free: [Combatant] = []
        var paid: [Combatant] = []
        for combatant in combatants {
            if isFreeCombatant(combatant.id) {
                free.append(combatant)
            } else {
                paid.append(combatant)
            }
        }
        return free + paid
    }
}
