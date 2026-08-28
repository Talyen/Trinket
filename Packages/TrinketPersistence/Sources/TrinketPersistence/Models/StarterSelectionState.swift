import TrinketContent

public enum StarterSelectionPhase: String, Equatable, Sendable {
    case chooseHero
    case chooseCompanion
    case complete
}

public struct StarterSelectionState: Equatable, Sendable {
    public private(set) var phase: StarterSelectionPhase
    public private(set) var heroID: String?

    public init(phase: StarterSelectionPhase, heroID: String? = nil) {
        switch phase {
        case .chooseHero:
            self.phase = .chooseHero
            self.heroID = nil
        case .chooseCompanion:
            if let heroID, GameContent.starterHeroIDs.contains(heroID) {
                self.phase = .chooseCompanion
                self.heroID = heroID
            } else {
                self.phase = .chooseHero
                self.heroID = nil
            }
        case .complete:
            self.phase = .complete
            self.heroID = nil
        }
    }

    public static let fresh = Self(phase: .chooseHero)
    public static let complete = Self(phase: .complete)
}
