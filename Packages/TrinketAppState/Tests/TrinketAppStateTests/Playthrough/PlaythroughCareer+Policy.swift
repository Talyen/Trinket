import Foundation
import TrinketContent
import TrinketCore
@testable import TrinketAppState
@testable import TrinketPersistence

extension PlaythroughCareer {
    func enterNextEncounter() async throws {
        switch scenario.mode {
        case "campaign":
            guard let stageID = store.journey.activeStageID else {
                throw PlaythroughFailure.unsupported("Campaign complete before attempt objective")
            }
            try await perform(.campaign(stageID, combatRandom.next()))
        case "labyrinth":
            if !store.labyrinth.hasEntered {
                try await perform(.enterLabyrinth)
            }
            guard let node = store.labyrinth.reachableNodeIDs().sorted().first(where: {
                store.labyrinth.node(id: $0)?.type != .entrance
            }) else { throw PlaythroughFailure.unsupported("no reachable Labyrinth node") }
            try await perform(.labyrinth(node, combatRandom.next()))
        case "contracts":
            if store.contracts.offers.isEmpty {
                try await perform(.contracts(refresh: false))
            }
            guard let offer = store.contracts.offer(for: .easy) else { throw PlaythroughFailure.unsupported("missing easy Contract") }
            try await perform(.contract(offer.id, combatRandom.next()))
        case "spires":
            guard let spire = GameContent.spires.first(where: {
                store.spires.highestClearedFloor(for: $0.id.rawValue) < $0.floorCount
            }) else { throw PlaythroughFailure.unsupported("no unfinished Spire") }
            try await perform(.spire(
                spire.id.rawValue,
                store.spires.highestClearedFloor(for: spire.id.rawValue) + 1,
                combatRandom.next(),
            ))
        default: throw PlaythroughFailure.unsupported("mode \(scenario.mode)")
        }
    }

    func resolvePendingChoice() async throws -> Bool {
        if let id = play.currentPostBattleTalentCombatantID {
            try await chooseTalent(for: id)
            return true
        }
        if let mystery = play.encounters.activeMysteryEncounter {
            if mystery.showsCorruptItemChoice, let item = mystery.corruptibleItems.first {
                try await perform(.corrupt(item.id))
            } else if mystery.canResolveChoice {
                try await perform(.mystery(mystery.event.choices.first?.id))
            } else {
                try await perform(.finishMystery)
            }
            return true
        }
        if let shop = play.encounters.activeShopEncounter {
            if let offer = shop.offers.first(where: {
                ShopPurchaseApplier.availability(offerID: $0.id, encounter: shop.encounter, save: store.currentSave).canPurchase
            }) {
                try await perform(.shop(offer.id))
            }
            try await perform(.finishShop)
            return true
        }
        return false
    }

    func invest() async throws {
        if scenario.policy == "rotation-v1" {
            let roster = store.roster
            let heroes = roster.heroes.filter { roster.isUnlocked($0) && store.contentAccess.allowsCombatant($0.id) }
            let companions = roster.companions.filter { roster.isUnlocked($0) && store.contentAccess.allowsCombatant($0.id) }
            if let hero = heroes.min(by: { roster.progression(for: $0).level < roster.progression(for: $1).level }),
               let companion = companions.min(by: { roster.progression(for: $0).level < roster.progression(for: $1).level }) {
                try await perform(.party(hero: hero.id, companion: companion.id))
            }
        }
        for combatant in [store.roster.activeHero, store.roster.activeCompanion] {
            while let upgrade = SimulationEquipmentPolicy.nextUpgrade(
                for: combatant,
                inventory: store.inventory.items,
                loadout: store.roster.equipmentLoadout(for: combatant),
                reservedItemIDs: Set(store.inventory.items.compactMap { item in
                    guard let owner = store.roster.equippedCombatantID(for: item.id), owner != combatant.id else { return nil }
                    return item.id
                }),
            ) {
                try await perform(.equipInSlot(combatant: combatant.id, item: upgrade.itemID, slot: upgrade.slot))
            }
        }
        for definition in GameContent.homesteadNodes {
            guard let tier = store.homestead.nextTier(for: definition),
                  store.homestead.canAfford(tier, gold: store.roster.gold) else { continue }
            try await perform(.upgrade(definition.id.rawValue, tier.tier))
            return
        }
    }
}
