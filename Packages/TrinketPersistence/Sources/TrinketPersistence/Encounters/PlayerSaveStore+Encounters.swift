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
        encounter: EncounterIdentity, forcedEventID: String? = nil,
        using random: inout some RandomNumberGenerator, at date: Date = Date(),
    ) -> SaveTransactionResult<PreparedMysteryEncounter, MysteryChoiceFailure> {
        persistTransaction(logging: "Failed to open mystery encounter") { save in
            guard encounter.isPlayable(in: save),
                  let event = encounter.mysteryEvent(in: save, forcedEventID: forcedEventID, access: contentAccess),
                  event.unlockCombatantID.map(contentAccess.allowsCombatant) ?? true
            else { return .failure(.unavailable) }
            encounter.pinMysteryEvent(event.id, save: &save)
            guard event.id != GameContent.corruptionAltarEventID,
                  !event.choices.contains(where: { $0.effects.contains(.corruptItem) }) else { return .success(PreparedMysteryEncounter(
                event: event,
                offers: [],
            )) }
            do {
                let offers = try MysteryOfferPersistence.prepare(
                    event: event,
                    encounter: encounter,
                    save: &save,
                    using: &random,
                    at: date,
                )
                return .success(PreparedMysteryEncounter(event: event, offers: offers))
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
            guard let event = request.encounter.mysteryEvent(in: save, access: contentAccess),
                  event.id == request.eventID,
                  event.unlockCombatantID.map(contentAccess.allowsCombatant) ?? true
            else { return .failure(.unavailable) }
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

extension EncounterIdentity {
    var economicClaim: CloudEconomicAction.Claim {
        switch location {
        case let .journey(id): .journey(id)
        case let .labyrinth(id): .labyrinth(seed: worldSeed, nodeID: id)
        case let .voyage(runID, nodeID): .voyage(runID: runID, nodeID: nodeID)
        }
    }
}
