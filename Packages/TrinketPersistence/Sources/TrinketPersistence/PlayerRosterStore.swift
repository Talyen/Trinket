import Foundation
import Observation
import TrinketContent
import TrinketCore

@MainActor
@Observable
public final class PlayerRosterStore {
    private let saveStore: PlayerSaveStore

    public var current: PlayerRosterState {
        get { saveStore.roster }
        set { saveStore.roster = newValue }
    }

    public init(saveStore: PlayerSaveStore) {
        self.saveStore = saveStore
    }

    public var heroes: [Combatant] {
        current.battleConfiguredCombatants(
            GameContent.heroes.filter { current.isUnlocked($0) }
        )
    }

    public var pets: [Combatant] {
        current.battleConfiguredCombatants(
            GameContent.pets.filter { current.isUnlocked($0) }
        )
    }

    public var collectionHeroes: [Combatant] {
        current.configuredCombatants(GameContent.heroes)
    }

    public var collectionPets: [Combatant] {
        current.configuredCombatants(GameContent.pets)
    }

    public func isUnlocked(_ combatant: Combatant) -> Bool {
        current.isUnlocked(combatant)
    }

    public func progression(for combatant: Combatant) -> CombatantProgression {
        current.progression(for: combatant)
    }

    public func loadout(for combatant: Combatant) -> AbilityLoadout {
        current.loadout(for: combatant)
    }

    public func setLoadout(_ loadout: AbilityLoadout, for combatant: Combatant) {
        var updated = current
        updated.setLoadout(loadout, for: combatant)
        current = updated
    }

    public func equipmentLoadout(for combatant: Combatant) -> EquipmentLoadout {
        current.equipmentLoadout(for: combatant)
    }

    public func setEquipmentLoadout(_ loadout: EquipmentLoadout, for combatant: Combatant) {
        var updated = current
        updated.setEquipmentLoadout(loadout, for: combatant)
        current = updated
    }

    public func setActiveHero(_ hero: Combatant) {
        var updated = current
        updated.setActiveHero(hero)
        current = updated
    }

    public func setActivePet(_ pet: Combatant) {
        var updated = current
        updated.setActivePet(pet)
        current = updated
    }

    public func grantExperience(_ amount: Int, to combatant: Combatant) {
        var updated = current
        updated.grantExperience(amount, to: combatant)
        current = updated
    }

    public func grantGold(_ amount: Int) {
        var updated = current
        updated.grantGold(amount)
        current = updated
    }

    public func equippedItem(
        for slot: ItemSlot,
        combatant: Combatant,
        inventory: PlayerInventoryState
    ) -> InventoryItem? {
        current.equippedItem(for: slot, combatant: combatant, inventory: inventory)
    }

    public func configuredCombatants(_ combatants: [Combatant]) -> [Combatant] {
        current.configuredCombatants(combatants)
    }

    public func configuredCombatant(_ combatant: Combatant) -> Combatant {
        current.configuredCombatant(combatant)
    }

    public func battleConfiguredCombatant(_ combatant: Combatant) -> Combatant {
        current.battleConfiguredCombatant(combatant)
    }

    public var activeHero: Combatant {
        heroes.first { $0.id == current.activeHeroID } ??
            heroes.first ??
            collectionHeroes[0]
    }

    public var activePet: Combatant {
        pets.first { $0.id == current.activePetID } ??
            pets.first ??
            collectionPets[0]
    }
}
