import Foundation
import TrinketCore

/// Per-round runtime counters and one-shot draw/gold owner flags.
/// Resets at the start of each player turn.
public struct BattleTurnCadence: Equatable, Hashable, Sendable {
    public var cardsPlayed: [BattleParticipant: Int]
    public var skillCardsPlayed: [BattleParticipant: Int]
    public var freezeCardsPlayed: [BattleParticipant: Int]
    public var burnManaRestored: [String: Int]
    public var spendManaDrawOwners: Set<BattleParticipant>
    public var healthLossDrawOwners: Set<BattleParticipant>
    public var goldDrawOwners: Set<BattleParticipant>

    public init(
        cardsPlayed: [BattleParticipant: Int] = [:],
        skillCardsPlayed: [BattleParticipant: Int] = [:],
        freezeCardsPlayed: [BattleParticipant: Int] = [:],
        burnManaRestored: [String: Int] = [:],
        spendManaDrawOwners: Set<BattleParticipant> = [],
        healthLossDrawOwners: Set<BattleParticipant> = [],
        goldDrawOwners: Set<BattleParticipant> = []
    ) {
        self.cardsPlayed = cardsPlayed
        self.skillCardsPlayed = skillCardsPlayed
        self.freezeCardsPlayed = freezeCardsPlayed
        self.burnManaRestored = burnManaRestored
        self.spendManaDrawOwners = spendManaDrawOwners
        self.healthLossDrawOwners = healthLossDrawOwners
        self.goldDrawOwners = goldDrawOwners
    }

    public mutating func reset() {
        self = Self()
    }
}
