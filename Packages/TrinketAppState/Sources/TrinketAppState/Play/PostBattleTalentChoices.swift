import Foundation
import TrinketContent
import TrinketCore
import TrinketPersistence

/// Transient choice and confirmation state after a settled battle. Save-backed
/// eligibility remains authoritative, including when points are spent elsewhere.
@MainActor
struct PostBattleTalentChoices {
    private struct Confirmation {
        let id = UUID()
        let combatantID: String
    }

    private var queuedCombatantIDs: [String] = []
    private var confirmation: Confirmation?

    var confirmationID: UUID? {
        confirmation?.id
    }

    func currentCombatantID(in roster: PlayerRosterState) -> String? {
        confirmation?.combatantID
            ?? queuedCombatantIDs.first { roster.hasUnlockableTalent(for: $0) }
    }

    mutating func queue(
        for combatants: [Combatant],
        progressionsBefore: [String: CombatantProgression],
        deferredProgressions: [String: CombatantProgression],
        roster: PlayerRosterState,
    ) {
        let before = progressionsBefore.merging(deferredProgressions) { _, deferred in deferred }
        queuedCombatantIDs = combatants.compactMap { combatant in
            guard let previous = before[combatant.id] else { return nil }
            let current = roster.progression(for: combatant)
            guard current.totalTalentPoints > previous.totalTalentPoints,
                  roster.hasUnlockableTalent(for: combatant.id)
            else { return nil }
            return combatant.id
        }
    }

    mutating func choose(nodeID: String, treeID: String, in playerSave: PlayerSaveStore) -> TalentUnlockResult {
        prune(in: playerSave.roster)
        guard let combatantID = currentCombatantID(in: playerSave.roster) else {
            return .unavailable
        }
        let result = playerSave.unlockTalent(nodeID: nodeID, treeID: treeID, for: combatantID)
        if result == .unlocked {
            confirmation = Confirmation(combatantID: combatantID)
            if !playerSave.roster.hasUnlockableTalent(for: combatantID) {
                queuedCombatantIDs.removeAll { $0 == combatantID }
            }
        }
        return result
    }

    mutating func finishConfirmation(id: UUID, roster: PlayerRosterState) {
        guard confirmation?.id == id else { return }
        confirmation = nil
        prune(in: roster)
    }

    mutating func dismiss() {
        confirmation = nil
        queuedCombatantIDs.removeAll(keepingCapacity: true)
    }

    private mutating func prune(in roster: PlayerRosterState) {
        queuedCombatantIDs.removeAll { !roster.hasUnlockableTalent(for: $0) }
    }
}
