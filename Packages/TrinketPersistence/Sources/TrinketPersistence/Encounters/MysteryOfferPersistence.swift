import Foundation
import TrinketContent
import TrinketCore

public enum MysteryOfferPersistence {
    static func mergedPayload(preferred: Data?, other: Data?) -> Data? {
        guard let preferred, let other else { return preferred ?? other }
        if hasReadableOffers(preferred) {
            return preferred
        }
        return hasReadableOffers(other) ? other : preferred
    }

    private static func hasReadableOffers(_ data: Data) -> Bool {
        do {
            let snapshot = try JSONDecoder().decode(MysteryOfferSnapshot.self, from: data)
            return try snapshot.resolvedOffers().count == snapshot.offers.count
        } catch {
            return false
        }
    }

    struct MysteryLevelInputs {
        let rewardLevel: Int
        let encounterLevel: Int
        let bonuses: LabyrinthModifierEffects
    }

    static func levelInputs(
        stage: Stage,
        labyrinthNodeID: String?,
        encounter: EncounterIdentity? = nil,
        save: PlayerSave,
    ) -> MysteryLevelInputs? {
        let identity = identity(stageID: stage.id, labyrinthNodeID: labyrinthNodeID, encounter: encounter, save: save)
        guard let rewardLevel = identity.rewardLevel(in: save) else {
            return nil
        }
        let encounterLevel = identity.encounterLevel(stage: stage, in: save)
        let bonuses = identity.modifierEffects(in: save)
        return MysteryLevelInputs(rewardLevel: rewardLevel, encounterLevel: encounterLevel, bonuses: bonuses)
    }

    public static func prepare(
        event: MysteryEvent,
        stage: Stage,
        labyrinthNodeID: String?,
        encounter: EncounterIdentity? = nil,
        save: inout PlayerSave,
        using randomNumberGenerator: inout some RandomNumberGenerator,
        at date: Date = Date(),
    ) throws -> [MysteryOffer] {
        guard event.choices.contains(where: { $0.itemPool != nil }) else { return [] }
        guard isPlayable(stage: stage, labyrinthNodeID: labyrinthNodeID, encounter: encounter, save: save) else {
            throw MysteryOfferError.unavailableEncounter
        }
        let payload = payload(stageID: stage.id, labyrinthNodeID: labyrinthNodeID, encounter: encounter, save: save)
        let snapshot = try payload.map { try JSONDecoder().decode(MysteryOfferSnapshot.self, from: $0) }
        let previous = if let snapshot, snapshot.eventID == event.id {
            try snapshot.resolvedOffers()
        } else {
            [MysteryOffer]()
        }
        guard let inputs = levelInputs(stage: stage, labyrinthNodeID: labyrinthNodeID, encounter: encounter, save: save) else {
            throw MysteryOfferError.unavailableEncounter
        }
        let rewardLevel = inputs.rewardLevel
        let level = inputs.encounterLevel
        let bonuses = inputs.bonuses
        save.homestead.settleProduction(at: date, roster: save.roster)
        // Non-pool choices (leave, corrupt-only, unlock-only) resolve through
        // the direct-effects path, so only pooled choices produce offers.
        let offers: [MysteryOffer] = event.choices.compactMap { choice in
            let saved = previous.first { $0.choiceID == choice.id }
            guard let offer = saved ?? MysteryEffectApplier.resolveOffer(
                choice: choice,
                encounterID: stage.id,
                encounterLevel: level,
                rewardLevel: rewardLevel,
                save: save,
                bonuses: bonuses,
                using: &randomNumberGenerator,
            ) else { return nil }
            if saved != nil {
                return offer
            }
            return MysteryOffer(
                choiceID: offer.choiceID, item: offer.item,
                bonus: MysteryEffectApplier.settledBonus(
                    offer.bonus, encounterLevel: level, save: save,
                    experiencePercent: bonuses.experienceEarnedPercent, at: date,
                ),
            )
        }
        if offers != previous {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            let data = try encoder.encode(MysteryOfferSnapshot(eventID: event.id, offers: offers))
            setPayload(data, stageID: stage.id, labyrinthNodeID: labyrinthNodeID, encounter: encounter, save: &save)
        }
        return offers
    }

    public static func claim(
        _ offer: MysteryOffer,
        stage: Stage,
        labyrinthNodeID: String?,
        encounter: EncounterIdentity? = nil,
        save: inout PlayerSave,
        at date: Date = Date(),
    ) -> MysteryEffectResult {
        guard isPlayable(stage: stage, labyrinthNodeID: labyrinthNodeID, encounter: encounter, save: save)
        else { return MysteryEffectResult() }
        guard let payload = payload(stageID: stage.id, labyrinthNodeID: labyrinthNodeID, encounter: encounter, save: save) else {
            return MysteryEffectResult()
        }
        let saved: [MysteryOffer]
        do {
            let snapshot = try JSONDecoder().decode(MysteryOfferSnapshot.self, from: payload)
            saved = try snapshot.resolvedOffers()
        } catch {
            return MysteryEffectResult()
        }
        guard saved.contains(offer) else { return MysteryEffectResult() }
        // Validate and grant at one production date on a candidate, so stale
        // offers cannot grant partial rewards or complete the encounter.
        let grantDate = date
        var candidate = save
        candidate.homestead.settleProduction(at: grantDate, roster: candidate.roster)
        guard let inputs = levelInputs(stage: stage, labyrinthNodeID: labyrinthNodeID, encounter: encounter, save: candidate) else {
            return MysteryEffectResult()
        }
        let level = inputs.encounterLevel
        let bonuses = inputs.bonuses
        let result = MysteryEffectApplier.apply(
            offer, save: &candidate, at: grantDate,
            goldOverflowExperience: RewardExperiencePolicy.encounterAward(
                encounterLevel: level, roster: candidate.roster, percent: bonuses.experienceEarnedPercent,
            ),
            allowOwnedItem: true,
        )
        guard result.grantedItems.count == 1 || InventoryDuplicatePolicy.containsDuplicate(of: offer.item, in: candidate.inventory.items)
        else { return result }
        if let encounter, case let .voyage(runID, nodeID) = encounter.location {
            _ = VoyageCompletion.completeNode(runID: runID, nodeID: nodeID, save: &candidate)
        } else if let labyrinthNodeID {
            candidate.labyrinth.markCleared(nodeID: labyrinthNodeID, eligibleRecruitEventIDs: candidate.roster.eligibleRecruitEventIDs)
        } else {
            candidate.journey.markRewardsClaimed(for: stage)
            candidate.journey.complete(stage, in: GameContent.chapters)
        }
        ItemCorruptionApplier.noteMysteryCompleted(save: &candidate)
        clear(stageID: stage.id, labyrinthNodeID: labyrinthNodeID, encounter: encounter, save: &candidate)
        save = candidate
        return result
    }

    static func clear(stageID: String, labyrinthNodeID: String?, encounter: EncounterIdentity? = nil, save: inout PlayerSave) {
        setPayload(nil, stageID: stageID, labyrinthNodeID: labyrinthNodeID, encounter: encounter, save: &save)
    }

    private static func identity(
        stageID: String,
        labyrinthNodeID: String?,
        encounter: EncounterIdentity?,
        save: PlayerSave,
    ) -> EncounterIdentity {
        encounter ?? EncounterIdentity(location: labyrinthNodeID.map { .labyrinth(nodeID: $0) } ?? .journey(stageID: stageID), save: save)
    }

    private static func isPlayable(stage: Stage, labyrinthNodeID: String?, encounter: EncounterIdentity?, save: PlayerSave) -> Bool {
        identity(stageID: stage.id, labyrinthNodeID: labyrinthNodeID, encounter: encounter, save: save).isPlayable(in: save)
    }

    private static func payload(stageID: String, labyrinthNodeID: String?, encounter: EncounterIdentity?, save: PlayerSave) -> Data? {
        switch identity(stageID: stageID, labyrinthNodeID: labyrinthNodeID, encounter: encounter, save: save).location {
        case let .journey(id): save.journey.mysteryOfferPayloads[id]
        case let .labyrinth(id): save.labyrinth.nodes[id]?.mysteryOffersPayload
        case let .voyage(runID, nodeID): save.voyage.node(runID: runID, nodeID: nodeID)?.mysteryOffersPayload
        }
    }

    private static func setPayload(
        _ data: Data?,
        stageID: String,
        labyrinthNodeID: String?,
        encounter: EncounterIdentity?,
        save: inout PlayerSave,
    ) {
        switch identity(stageID: stageID, labyrinthNodeID: labyrinthNodeID, encounter: encounter, save: save).location {
        case let .journey(id): save.journey.mysteryOfferPayloads[id] = data
        case let .labyrinth(id): save.labyrinth.nodes[id]?.mysteryOffersPayload = data
        case let .voyage(runID, nodeID): save.voyage.updateNode(runID: runID, nodeID: nodeID) { $0.mysteryOffersPayload = data }
        }
    }
}
