import SwiftUI

@MainActor
@Observable
final class PlayerRosterStore {
    private let saveStore: PlayerSaveStore

    var current: PlayerRosterState {
        get { saveStore.roster }
        set { saveStore.roster = newValue }
    }

    init(saveStore: PlayerSaveStore) {
        self.saveStore = saveStore
    }

    var heroes: [Combatant] {
        current.configuredCombatants(
            GameContent.heroes.filter { current.isUnlocked($0) }
        )
    }

    var pets: [Combatant] {
        current.configuredCombatants(
            GameContent.pets.filter { current.isUnlocked($0) }
        )
    }

    var collectionHeroes: [Combatant] {
        current.configuredCombatants(GameContent.heroes)
    }

    var collectionPets: [Combatant] {
        current.configuredCombatants(GameContent.pets)
    }

    func isUnlocked(_ combatant: Combatant) -> Bool {
        current.isUnlocked(combatant)
    }

    func progression(for combatant: Combatant) -> CombatantProgression {
        current.progression(for: combatant)
    }

    func loadout(for combatant: Combatant) -> AbilityLoadout {
        current.loadout(for: combatant)
    }

    func setLoadout(_ loadout: AbilityLoadout, for combatant: Combatant) {
        var updated = current
        updated.setLoadout(loadout, for: combatant)
        current = updated
    }

    func equipmentLoadout(for combatant: Combatant) -> EquipmentLoadout {
        current.equipmentLoadout(for: combatant)
    }

    func setEquipmentLoadout(_ loadout: EquipmentLoadout, for combatant: Combatant) {
        var updated = current
        updated.setEquipmentLoadout(loadout, for: combatant)
        current = updated
    }

    func setActiveHero(_ hero: Combatant) {
        var updated = current
        updated.setActiveHero(hero)
        current = updated
    }

    func setActivePet(_ pet: Combatant) {
        var updated = current
        updated.setActivePet(pet)
        current = updated
    }

    func grantExperience(_ amount: Int, to combatant: Combatant) {
        var updated = current
        updated.grantExperience(amount, to: combatant)
        current = updated
    }

    func grantGold(_ amount: Int) {
        var updated = current
        updated.grantGold(amount)
        current = updated
    }

    func equippedItem(for slot: ItemSlot, combatant: Combatant, inventory: PlayerInventoryState) -> InventoryItem? {
        current.equippedItem(for: slot, combatant: combatant, inventory: inventory)
    }

    func configuredCombatants(_ combatants: [Combatant]) -> [Combatant] {
        current.configuredCombatants(combatants)
    }

    func configuredCombatant(_ combatant: Combatant) -> Combatant {
        current.configuredCombatant(combatant)
    }
}
