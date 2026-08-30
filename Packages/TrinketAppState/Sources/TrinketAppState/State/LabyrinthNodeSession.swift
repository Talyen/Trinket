import Foundation
import Observation

public struct CampfirePartyMember: Equatable, Sendable, Identifiable {
    public let combatantID: String
    public let name: String
    public let currentHealth: Int
    public let maxHealth: Int
    public let healedHealth: Int

    public var id: String {
        combatantID
    }

    public init(
        combatantID: String,
        name: String,
        currentHealth: Int,
        maxHealth: Int,
        healedHealth: Int,
    ) {
        self.combatantID = combatantID
        self.name = name
        self.currentHealth = currentHealth
        self.maxHealth = maxHealth
        self.healedHealth = healedHealth
    }
}

@MainActor
@Observable
public final class LabyrinthNodeSession: Identifiable {
    nonisolated public var id: String {
        nodeID
    }

    public let nodeID: String
    public let depth: Int
    public let party: [CampfirePartyMember]
    public private(set) var failureMessage: String?

    public init(nodeID: String, depth: Int, party: [CampfirePartyMember]) {
        self.nodeID = nodeID
        self.depth = depth
        self.party = party
    }

    func markFailed(_ message: String) {
        failureMessage = message
    }

    func clearFailure() {
        failureMessage = nil
    }

    var healedRunHealthByCombatantID: [String: Int] {
        Dictionary(uniqueKeysWithValues: party.map { ($0.combatantID, $0.healedHealth) })
    }
}
