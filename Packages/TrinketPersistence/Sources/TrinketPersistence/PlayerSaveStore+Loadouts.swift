@MainActor
public extension PlayerSaveStore {
    func editCombatant(_ edit: CombatantLoadoutEdit, for combatantID: String) -> RosterEditResult {
        persistRosterEdit(logging: "Failed to persist roster edits") { save in
            save.applyLoadoutEdit(edit, for: combatantID, access: contentAccess)
        }
    }

    @discardableResult
    func selectParty(heroID: String? = nil, companionID: String? = nil) -> RosterEditResult {
        persistRosterEdit(logging: "Failed to persist party selection") { save in
            save.applyPartySelection(heroID: heroID, companionID: companionID, access: contentAccess)
        }
    }
}
