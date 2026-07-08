import Foundation
import TrinketContent
import TrinketPersistence

enum CollectionSearch {
    struct Results: Equatable {
        var heroes: [Combatant]
        var pets: [Combatant]
        var items: [InventoryItem]

        var isEmpty: Bool {
            heroes.isEmpty && pets.isEmpty && items.isEmpty
        }
    }

    static func results(
        for rawQuery: String,
        heroesCatalog: [Combatant] = GameContent.heroes,
        petsCatalog: [Combatant] = GameContent.pets,
        rosterState: PlayerRosterState,
        inventoryState: PlayerInventoryState
    ) -> Results {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return Results(heroes: [], pets: [], items: [])
        }

        return Results(
            heroes: matchingCombatants(from: heroesCatalog, query: query, rosterState: rosterState),
            pets: matchingCombatants(from: petsCatalog, query: query, rosterState: rosterState),
            items: inventoryState.items.filter { matchesItem($0, query: query) }
        )
    }

    static func matchesCombatant(_ combatant: Combatant, query: String) -> Bool {
        combatant.name.localizedCaseInsensitiveContains(query)
    }

    static func matchesItem(
        _ item: InventoryItem,
        query: String,
        includeAffixes: Bool = false
    ) -> Bool {
        if item.displayName.localizedCaseInsensitiveContains(query)
            || item.baseType.name.localizedCaseInsensitiveContains(query) {
            return true
        }

        guard includeAffixes else { return false }

        return item.affixes.contains { affix in
            affix.title.localizedCaseInsensitiveContains(query)
                || affix.description.localizedCaseInsensitiveContains(query)
                || affix.keywords.contains { keyword in
                    keyword.rawValue.localizedCaseInsensitiveContains(query)
                }
        }
    }

    private static func matchingCombatants(
        from catalog: [Combatant],
        query: String,
        rosterState: PlayerRosterState
    ) -> [Combatant] {
        rosterState.configuredCombatants(catalog).filter {
            rosterState.isUnlocked($0) && matchesCombatant($0, query: query)
        }
    }
}
