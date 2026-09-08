import TrinketContent

public enum FullGameOfferOrigin: Hashable, Identifiable, Sendable {
    case campaign(chapter: Int)
    case spire(SpireID, floor: Int)
    case labyrinth(floor: Int)
    case combatant(String)
    case options

    public var id: Self {
        self
    }
}
