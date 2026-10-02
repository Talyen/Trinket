import Foundation
import TrinketContent
import TrinketCore

public struct MysteryEncounterRequest: Sendable {
    public let encounter: EncounterIdentity
    public let event: MysteryEvent
    public let displayedOffers: [MysteryOffer]

    public init(encounter: EncounterIdentity, event: MysteryEvent, displayedOffers: [MysteryOffer]) {
        self.encounter = encounter
        self.event = event
        self.displayedOffers = displayedOffers
    }
}

public enum MysteryChoiceOutcome: Equatable {
    case reveal(unlockedCombatantID: String)
    case selectCorruptItem
    case corruptionReveal(ItemCorruptionDetail)
    case reward(MysteryEffectResult)
    case refreshedOffers([MysteryOffer])
    case dismiss
}

public enum MysteryChoiceFailure: Error {
    case unavailable
}

public enum MysteryEncounterResolution {
    public static func resolve(
        choiceID: String?,
        request: MysteryEncounterRequest,
        save: inout PlayerSave,
        using randomNumberGenerator: inout some RandomNumberGenerator,
        at date: Date = Date(),
    ) -> Result<MysteryChoiceOutcome, MysteryChoiceFailure> {
        guard request.encounter.isPlayable(in: save),
              let choice = choiceID
              .flatMap({ id in request.event.choices.first { $0.id == id } }) ?? (choiceID == nil ? request.event.choices.first : nil)
        else { return .failure(.unavailable) }
        if choice.effects.contains(.corruptItem) {
            return ItemCorruption.eligibleTargets(in: save.inventory).isEmpty ? .failure(.unavailable) : .success(.selectCorruptItem)
        }
        if choice.effects.contains(.leave) {
            guard complete(request, save: &save) else { return .failure(.unavailable) }
            return .success(.dismiss)
        }
        if choice.itemPool != nil {
            return resolveOffer(choice: choice, request: request, save: &save, using: &randomNumberGenerator, at: date)
        }
        guard let rewardLevel = request.encounter.rewardLevel(in: save),
              let encounterLevel = request.encounter.encounterLevel(in: save) else { return .failure(.unavailable) }
        var candidate = save
        let bonuses = request.encounter.modifierEffects(in: save)
        let result = MysteryEffectApplier.apply(
            choice.effects, stageID: request.encounter.stageID, choiceID: choice.id,
            encounterLevel: encounterLevel,
            rewardLevel: rewardLevel,
            save: &candidate, using: &randomNumberGenerator,
            goldFoundPercent: bonuses.goldFoundPercent, experienceEarnedPercent: bonuses.experienceEarnedPercent,
            materialsFoundPercent: bonuses.materialsFoundPercent, at: date,
        )
        let requiredItems = choice.effects.count(where: {
            if case .gainItem = $0 {
                true
            } else {
                false
            }
        })
        let requiredUnlocks = choice.effects.count(where: {
            if case .unlockCombatant = $0 {
                true
            } else {
                false
            }
        })
        guard result.grantedItems.count == requiredItems, result.unlockedCombatantIDs.count == requiredUnlocks,
              !result.isEmpty else { return .failure(.unavailable) }
        guard complete(request, save: &candidate) else { return .failure(.unavailable) }
        save = candidate
        if let unlocked = result.unlockedCombatantIDs.first {
            return .success(.reveal(unlockedCombatantID: unlocked))
        }
        return .success(.reward(result))
    }

    public static func corrupt(
        itemID: String,
        request: MysteryEncounterRequest,
        save: inout PlayerSave,
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> Result<MysteryChoiceOutcome, MysteryChoiceFailure> {
        guard request.encounter.isPlayable(in: save), request.event.choices.contains(where: { $0.effects.contains(.corruptItem) }) else {
            return .failure(.unavailable)
        }
        var candidate = save
        guard case let .success(result) = ItemCorruptionApplier.corrupt(itemID: itemID, save: &candidate, using: &randomNumberGenerator)
        else {
            return .failure(.unavailable)
        }
        guard complete(request, save: &candidate) else { return .failure(.unavailable) }
        save = candidate
        return .success(.corruptionReveal(result))
    }

    private static func resolveOffer(
        choice: MysteryChoice,
        request: MysteryEncounterRequest,
        save: inout PlayerSave,
        using randomNumberGenerator: inout some RandomNumberGenerator,
        at date: Date = Date(),
    ) -> Result<MysteryChoiceOutcome, MysteryChoiceFailure> {
        do {
            var candidate = save
            let prepared = try MysteryOfferPersistence.prepare(
                event: request.event, encounter: request.encounter,
                save: &candidate, using: &randomNumberGenerator, at: date,
            )
            if prepared != request.displayedOffers {
                save = candidate
                return .success(.refreshedOffers(prepared))
            }
            guard let offer = prepared.first(where: { $0.choiceID == choice.id }) else { return .failure(.unavailable) }
            let result = MysteryOfferPersistence.claim(
                offer, encounter: request.encounter,
                save: &candidate, at: date,
            )
            guard result.grantedItems.count == 1
                || InventoryDuplicatePolicy.containsDuplicate(of: offer.item, in: candidate.inventory.items)
            else { return .failure(.unavailable) }
            save = candidate
            return .success(.reward(result))
        } catch {
            return .failure(.unavailable)
        }
    }

    private static func complete(_ request: MysteryEncounterRequest, save: inout PlayerSave) -> Bool {
        guard NonCombatEncounterCompletion.complete(encounter: request.encounter, save: &save) == .completed else { return false }
        if request.event.id == GameContent.corruptionAltarEventID || request.event.choices
            .contains(where: { $0.effects.contains(.corruptItem) }) {
            ItemCorruptionApplier.recordCorruptionAltarEncounter(save: &save)
        } else {
            ItemCorruptionApplier.noteMysteryCompleted(save: &save)
        }
        MysteryOfferPersistence.clear(encounter: request.encounter, save: &save)
        return true
    }
}
