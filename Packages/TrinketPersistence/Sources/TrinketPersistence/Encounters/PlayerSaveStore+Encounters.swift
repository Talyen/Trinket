import Foundation
import TrinketContent
import TrinketCore

public enum MysteryEncounterAction {
    case choice(String?)
    case corruptItem(String)
}

@MainActor
public extension PlayerSaveStore {
    func prepareShop(encounter: EncounterIdentity) -> SaveTransactionResult<ShopStock, ShopPurchaseFailure> {
        persistTransaction(logging: "Failed to prepare shop stock") { save, recordReceipt in
            let prepared = ShopStockPersistence.prepare(encounter: encounter, save: &save)
            guard case let .success(stock) = prepared else { return prepared }
            if stock.offers.isEmpty {
                guard NonCombatEncounterCompletion.complete(
                    encounter: encounter, save: &save, access: contentAccess, recordReceipt: recordReceipt,
                ) == .completed else { return .failure(.invalidOffer) }
            }
            return .success(stock)
        }
    }

    func purchaseShopOffer(offerID: String, encounter: EncounterIdentity) -> SaveTransactionResult<InventoryItem, ShopPurchaseFailure> {
        persistTransaction(logging: "Failed to purchase shop offer") { save, recordReceipt in
            ShopPurchaseApplier.purchase(offerID: offerID, encounter: encounter, save: &save, recordReceipt: recordReceipt)
        }
    }

    func finishShop(encounter: EncounterIdentity) -> SaveTransactionResult<Void, EncounterCompletionFailure> {
        persistTransaction(logging: "Failed to leave shop") { save, recordReceipt in
            guard NonCombatEncounterCompletion.complete(
                encounter: encounter, save: &save, access: contentAccess, recordReceipt: recordReceipt,
            ) == .completed else { return .failure(.unavailable) }
            return .success(())
        }
    }

    func prepareMysteryEncounter(
        event: MysteryEvent, encounter: EncounterIdentity,
        using random: inout some RandomNumberGenerator, at date: Date = Date(),
    ) -> SaveTransactionResult<[MysteryOffer], MysteryChoiceFailure> {
        persistTransaction(logging: "Failed to open mystery encounter") { save in
            guard encounter.isPlayable(in: save), Self.pinMysteryEvent(event.id, encounter: encounter, save: &save)
            else { return .failure(.unavailable) }
            guard event.id != GameContent.corruptionAltarEventID,
                  !event.choices.contains(where: { $0.effects.contains(.corruptItem) }) else { return .success([]) }
            do {
                return try .success(MysteryOfferPersistence.prepare(
                    event: event,
                    encounter: encounter,
                    save: &save,
                    using: &random,
                    at: date,
                ))
            } catch {
                return .failure(.unavailable)
            }
        }
    }

    func resolveMysteryEncounter(
        _ request: MysteryEncounterRequest, action: MysteryEncounterAction,
        using random: inout some RandomNumberGenerator, at date: Date = Date(),
    ) -> SaveTransactionResult<MysteryChoiceOutcome, MysteryChoiceFailure> {
        persistTransaction(logging: "Failed to resolve mystery encounter") { save, recordReceipt in
            let before = save
            let result = switch action {
            case let .choice(id):
                MysteryEncounterResolution.resolve(choiceID: id, request: request, save: &save, using: &random, at: date)
            case let .corruptItem(id):
                MysteryEncounterResolution.corrupt(itemID: id, request: request, save: &save, using: &random)
            }
            if case .success = result {
                // One encounter receipt includes its choice and completion payout.
                // They share a claim, so separate receipts would deduplicate each other.
                let claim = request.encounter.isPlayable(in: save) ? nil : request.encounter.economicClaim
                recordReceipt(.reward(from: before, to: save, claim: claim))
            }
            return result
        }
    }
}

extension PlayerSaveStore {
    private static func pinMysteryEvent(_ eventID: String, encounter: EncounterIdentity, save: inout PlayerSave) -> Bool {
        switch encounter.location {
        case let .voyage(runID, nodeID):
            guard save.voyage.node(runID: runID, nodeID: nodeID)?.mysteryEventID == nil else { return true }
            save.voyage.updateNode(runID: runID, nodeID: nodeID) { $0.mysteryEventID = eventID }
            return true
        case let .labyrinth(nodeID):
            return MysteryEventPinApplier.pinLabyrinthEvent(nodeID: nodeID, eventID: eventID, save: &save)
        case let .journey(stageID):
            guard GameContent.stage(id: stageID)?.mysteryEvent == nil else { return true }
            return MysteryEventPinApplier.pinJourneyEvent(stageID: stageID, eventID: eventID, save: &save)
        }
    }
}

extension EncounterIdentity {
    var economicClaim: CloudEconomicAction.Claim {
        switch location {
        case let .journey(id): .journey(id)
        case let .labyrinth(id): .labyrinth(seed: worldSeed, nodeID: id)
        case let .voyage(runID, nodeID): .voyage(runID: runID, nodeID: nodeID)
        }
    }
}
