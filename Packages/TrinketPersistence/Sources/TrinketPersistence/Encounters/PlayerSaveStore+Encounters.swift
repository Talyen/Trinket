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
        persistAction(claim: encounter.economicClaim, logging: "Failed to prepare shop stock") { save in
            let prepared = ShopStockPersistence.prepare(encounter: encounter, save: &save)
            guard case let .success(stock) = prepared else { return prepared }
            if stock.offers.isEmpty {
                guard NonCombatEncounterCompletion.complete(
                    encounter: encounter, save: &save, access: contentAccess,
                ) == .completed else { return .failure(.invalidOffer) }
            }
            return .success(stock)
        }
    }

    func purchaseShopOffer(offerID: String, encounter: EncounterIdentity) -> SaveTransactionResult<InventoryItem, ShopPurchaseFailure> {
        let stock: ShopStock
        do {
            guard let prepared = try ShopStockPersistence.stock(encounter: encounter, save: currentSave)
            else { return .rejected(.invalidOffer) }
            stock = prepared
        } catch {
            return .rejected(.invalidOffer)
        }
        guard let offer = stock.offers.first(where: { $0.id == offerID }) else { return .rejected(.invalidOffer) }
        return persistAction(kind: .shop(encounter, .init(offer)), logging: "Failed to purchase shop offer") { save in
            ShopPurchaseApplier.purchase(offerID: offerID, encounter: encounter, save: &save)
        }
    }

    func finishShop(encounter: EncounterIdentity) -> SaveTransactionResult<Void, EncounterCompletionFailure> {
        persistAction(claim: encounter.economicClaim, logging: "Failed to leave shop") { save in
            guard ShopStockPersistence.isShop(encounter: encounter, save: save), NonCombatEncounterCompletion.complete(
                encounter: encounter, save: &save, access: contentAccess,
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
        persistAction(claim: request.encounter.economicClaim, logging: "Failed to resolve mystery encounter") { save in
            guard let event = request.encounter.mysteryEvent(in: save, access: contentAccess),
                  event.id == request.eventID,
                  event.unlockCombatantID.map(contentAccess.allowsCombatant) ?? true
            else { return .failure(.unavailable) }
            return switch action {
            case let .choice(id):
                MysteryEncounterResolution.resolve(
                    choiceID: id, request: request, save: &save, using: &random, at: date, access: contentAccess,
                )
            case let .corruptItem(id):
                MysteryEncounterResolution.corrupt(itemID: id, request: request, save: &save, using: &random, access: contentAccess)
            }
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
