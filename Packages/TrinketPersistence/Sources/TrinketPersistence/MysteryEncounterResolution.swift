import TrinketContent
import TrinketCore

public struct MysteryEncounterRequest: Sendable {
    public let encounter: EncounterIdentity
    public let stage: Stage
    public let event: MysteryEvent
    public let displayedOffers: [MysteryOffer]

    public init(encounter: EncounterIdentity, stage: Stage, event: MysteryEvent, displayedOffers: [MysteryOffer]) {
        self.encounter = encounter
        self.stage = stage
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
    ) -> Result<MysteryChoiceOutcome, MysteryChoiceFailure> {
        guard request.encounter.isPlayable(in: save), request.stage.id == request.encounter.stageID,
              let choice = choiceID
              .flatMap({ id in request.event.choices.first { $0.id == id } }) ?? (choiceID == nil ? request.event.choices.first : nil)
        else { return .failure(.unavailable) }
        if choice.effects.contains(.corruptItem) {
            return ItemCorruption.eligibleTargets(in: save.inventory).isEmpty ? .failure(.unavailable) : .success(.selectCorruptItem)
        }
        if choice.effects.contains(.leave) {
            complete(request, save: &save)
            return .success(.dismiss)
        }
        if choice.itemPool != nil {
            return resolveOffer(choice: choice, request: request, save: &save, using: &randomNumberGenerator)
        }
        guard let rewardLevel = request.encounter.rewardLevel(in: save) else { return .failure(.unavailable) }
        var candidate = save
        let bonuses = request.encounter.labyrinthNodeID.map { save.labyrinth.effects(for: $0) } ?? .zero
        let result = MysteryEffectApplier.apply(
            choice.effects, stageID: request.stage.id, choiceID: choice.id,
            encounterLevel: MysteryEffectApplier.resolvedEncounterLevel(
                stage: request.stage, labyrinthNodeID: request.encounter.labyrinthNodeID, save: save,
            ),
            rewardLevel: rewardLevel,
            save: &candidate, using: &randomNumberGenerator,
            goldFoundPercent: bonuses.goldFoundPercent, experienceEarnedPercent: bonuses.experienceEarnedPercent,
            materialsFoundPercent: bonuses.materialsFoundPercent,
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
        complete(request, save: &candidate)
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
        complete(request, save: &candidate)
        save = candidate
        return .success(.corruptionReveal(result))
    }

    private static func resolveOffer(
        choice: MysteryChoice,
        request: MysteryEncounterRequest,
        save: inout PlayerSave,
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> Result<MysteryChoiceOutcome, MysteryChoiceFailure> {
        do {
            var candidate = save
            let prepared = try MysteryOfferPersistence.prepare(
                event: request.event, stage: request.stage, labyrinthNodeID: request.encounter.labyrinthNodeID,
                save: &candidate, using: &randomNumberGenerator,
            )
            if prepared != request.displayedOffers {
                save = candidate
                return .success(.refreshedOffers(prepared))
            }
            guard let offer = prepared.first(where: { $0.choiceID == choice.id }) else { return .failure(.unavailable) }
            let result = MysteryOfferPersistence.claim(
                offer, stage: request.stage, labyrinthNodeID: request.encounter.labyrinthNodeID, save: &candidate,
            )
            guard result.grantedItems.count == 1 else { return .failure(.unavailable) }
            save = candidate
            return .success(.reward(result))
        } catch {
            return .failure(.unavailable)
        }
    }

    private static func complete(_ request: MysteryEncounterRequest, save: inout PlayerSave) {
        if request.event.id == GameContent.corruptionAltarEventID || request.event.choices
            .contains(where: { $0.effects.contains(.corruptItem) }) {
            ItemCorruptionApplier.recordCorruptionAltarEncounter(save: &save)
        } else {
            ItemCorruptionApplier.noteMysteryCompleted(save: &save)
        }
        StageCompletion.completeEncounter(
            stage: request.stage, labyrinthNodeID: request.encounter.labyrinthNodeID,
            hero: save.roster.activeHero, companion: save.roster.activeCompanion,
            in: GameContent.chapters, save: &save,
        )
    }
}
