import Foundation
import Observation
import TrinketContent
import TrinketPersistence

enum MysteryEncounterPhase: Equatable, Sendable {
    case reading
    case revealing
}

@MainActor
@Observable
final class MysteryEncounterSession: Identifiable {
    var id: String { stage.id }

    let stage: Stage
    let event: MysteryEvent
    let combatant: Combatant?
    private(set) var phase: MysteryEncounterPhase = .reading
    private(set) var unlockedCombatantID: String?
    private(set) var isResolvingChoice = false

    var showsReveal: Bool {
        phase == .revealing && unlockedCombatantID != nil
    }

    init(stage: Stage, event: MysteryEvent, combatant: Combatant?) {
        self.stage = stage
        self.event = event
        self.combatant = combatant
    }
}

extension MysteryEncounterSession {
    func markChoiceStarted() {
        isResolvingChoice = true
    }

    func presentReveal(unlockedCombatantID: String) {
        self.unlockedCombatantID = unlockedCombatantID
        phase = .revealing
        isResolvingChoice = false
    }

    func markResolvedWithoutReveal() {
        isResolvingChoice = false
    }
}
