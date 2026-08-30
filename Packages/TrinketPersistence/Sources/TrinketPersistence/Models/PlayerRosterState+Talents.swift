import Foundation
import TrinketContent
import TrinketCore

public extension PlayerRosterState {
    func unlockedTalents(for combatantID: String) -> Set<String> {
        unlockedTalents[combatantID] ?? []
    }

    func unlockedTalents(for combatant: Combatant) -> Set<String> {
        unlockedTalents(for: combatant.id)
    }

    mutating func setUnlockedTalents(_ talents: Set<String>, for combatantID: String) {
        unlockedTalents[combatantID] = talents
    }

    mutating func setUnlockedTalents(_ talents: Set<String>, for combatant: Combatant) {
        setUnlockedTalents(talents, for: combatant.id)
    }

    func availableTalentPoints(for combatantID: String) -> Int {
        let prog = progressions[combatantID] ?? .initial
        let unlockedCount = unlockedTalents(for: combatantID).count
        return prog.availableTalentPoints(unlockedCount: unlockedCount)
    }

    func availableTalentPoints(for combatant: Combatant) -> Int {
        availableTalentPoints(for: combatant.id)
    }

    @discardableResult
    mutating func unlockTalent(
        node: TalentNode,
        inTree tree: TalentTree,
        for combatantID: String,
    ) -> Bool {
        var currentUnlocked = unlockedTalents(for: combatantID)
        let points = availableTalentPoints(for: combatantID)

        guard tree.canUnlock(node: node, unlockedNodeIDs: currentUnlocked, availablePoints: points) else {
            return false
        }

        currentUnlocked.insert(node.id)
        setUnlockedTalents(currentUnlocked, for: combatantID)
        return true
    }

    mutating func resetTalents(for combatantID: String) {
        unlockedTalents.removeValue(forKey: combatantID)
    }
}
