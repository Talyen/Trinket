import TrinketCore

/// Hero or companion experience row shared by battle and encounter reward reveals.
public struct RewardRevealExperienceAward: Identifiable, Sendable {
    public let id: String
    public let combatantName: String
    public let artworkName: String?
    public let progressionBefore: CombatantProgression
    public let progressionAfter: CombatantProgression
    public let experienceAward: Int
    public let accessibilityIdentifier: String?

    public init(
        id: String,
        combatantName: String,
        artworkName: String? = nil,
        progressionBefore: CombatantProgression,
        progressionAfter: CombatantProgression,
        experienceAward: Int,
        accessibilityIdentifier: String? = nil,
    ) {
        self.id = id
        self.combatantName = combatantName
        self.artworkName = artworkName
        self.progressionBefore = progressionBefore
        self.progressionAfter = progressionAfter
        self.experienceAward = experienceAward
        self.accessibilityIdentifier = accessibilityIdentifier
    }
}
