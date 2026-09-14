import TrinketContent

// swiftformat:disable redundantRawValues - persisted starter phases must remain explicit
public enum StarterSelectionPhase: String, Codable, Equatable, Sendable {
    case chooseHero = "chooseHero"
    case chooseCompanion = "chooseCompanion"
    case complete
}

// swiftformat:enable redundantRawValues

public struct StarterSelectionState: Codable, Equatable, Sendable {
    public private(set) var phase: StarterSelectionPhase
    public private(set) var heroID: String?

    public init(phase: StarterSelectionPhase, heroID: String? = nil) {
        switch phase {
        case .chooseHero:
            self.phase = .chooseHero
            self.heroID = nil
        case .chooseCompanion:
            if let heroID, GameContent.hero(matching: heroID) != nil {
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
