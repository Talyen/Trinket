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
            let roster = store.roster
            guard let spire = GameContent.spires.first(where: {
                SpireAttunement.evaluate(hero: roster.activeHero, companion: roster.activeCompanion, spire: $0).isReady
                    && store.spires.highestClearedFloor(for: $0.id.rawValue) < $0.floorCount
            }) else { throw PlaythroughFailure.unsupported("party is not attuned to an unfinished Spire") }
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
            let loadout = store.roster.equipmentLoadout(for: combatant)
            if let item = store.inventory.items.first(where: {
                store.roster.equippedCombatantID(for: $0.id) == nil
                    && loadout.canEquip($0, in: $0.baseType.defaultEquipmentSlot, inventory: store.inventory.items)
            }) {
                try await perform(.equip(combatant: combatant.id, item: item.id))
            }
        }
        for definition in GameContent.homesteadNodes where store.homestead.isUnlocked(definition) {
            guard let tier = store.homestead.nextTier(for: definition),
                  store.homestead.canAfford(tier, roster: store.roster) else { continue }
            try await perform(.upgrade(definition.id.rawValue, tier.tier))
            return
        }
    }
}
