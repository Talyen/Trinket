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

    public var activeHero: Combatant {
        heroes.first { $0.id == current.activeHeroID } ??
            heroes.first ??
            GameContent.heroes.first { $0.id == PlayerRosterState.starterHeroID } ??
            collectionHeroes[0]
    }

    public var activePet: Combatant {
        pets.first { $0.id == current.activePetID } ??
            pets.first ??
            GameContent.pets.first { $0.id == PlayerRosterState.starterPetID } ??
            collectionPets[0]
    }
}
