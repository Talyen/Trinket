import Foundation
import Observation
import TrinketContent
import TrinketPersistence

enum MysteryEncounterPhase: Equatable {
    case reading
    case revealing
}

@MainActor
@Observable
final class MysteryEncounterSession: Identifiable {
    nonisolated var id: String {
        stage.id
    }

    let stage: Stage
    /// When set, completion clears a Labyrinth node instead of a journey stage.
    let labyrinthNodeID: String?
    let event: MysteryEvent
    let combatant: Combatant?
    private(set) var phase: MysteryEncounterPhase = .reading
    private(set) var unlockedCombatantID: String?
    private(set) var isResolvingChoice = false

    var showsReveal: Bool {
        phase == .revealing && unlockedCombatantID != nil
    }

    init(
        stage: Stage,
        event: MysteryEvent,
        combatant: Combatant?,
        labyrinthNodeID: String? = nil
    ) {
        self.stage = stage
        self.event = event
        self.combatant = combatant
        self.labyrinthNodeID = labyrinthNodeID
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
