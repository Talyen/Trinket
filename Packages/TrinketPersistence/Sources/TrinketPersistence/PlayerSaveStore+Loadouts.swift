import TrinketContent

@MainActor
public extension PlayerSaveStore {
    func editCombatant(_ edit: CombatantLoadoutEdit, for combatantID: String) -> SaveActionAttempt<RosterEditResult> {
        persistRosterEdit(logging: "Failed to persist roster edits") { save in
            save.roster.applyLoadoutEdit(edit, for: combatantID, inventory: save.inventory.items, access: contentAccess)
        }
    }

    @discardableResult
    func selectParty(heroID: String? = nil, companionID: String? = nil) -> SaveActionAttempt<RosterEditResult> {
        persistRosterEdit(logging: "Failed to persist party selection") { save in
            save.roster.applyPartySelection(heroID: heroID, companionID: companionID, access: contentAccess)
        }
    }
}
