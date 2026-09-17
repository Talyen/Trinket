import Foundation
import TrinketContent
import TrinketCore

public enum MysteryOfferPersistence {
    struct MysteryLevelInputs {
        let rewardLevel: Int
        let encounterLevel: Int
        let bonuses: LabyrinthModifierEffects
    }

    static func levelInputs(
        stage: Stage,
        labyrinthNodeID: String?,
        save: PlayerSave,
    ) -> MysteryLevelInputs? {
        let location: EncounterIdentity.Location = labyrinthNodeID.map { .labyrinth(nodeID: $0) }
            ?? .journey(stageID: stage.id)
        guard let rewardLevel = EncounterIdentity(location: location, save: save).rewardLevel(in: save) else {
            return nil
        }
        let encounterLevel = MysteryEffectApplier.resolvedEncounterLevel(
            stage: stage, labyrinthNodeID: labyrinthNodeID, save: save,
        )
        let bonuses = labyrinthNodeID.map { save.labyrinth.effects(for: $0) } ?? .zero
        return MysteryLevelInputs(rewardLevel: rewardLevel, encounterLevel: encounterLevel, bonuses: bonuses)
    }

    public static func prepare(
        event: MysteryEvent,
        stage: Stage,
        labyrinthNodeID: String?,
        save: inout PlayerSave,
        using randomNumberGenerator: inout some RandomNumberGenerator,
        at date: Date = Date(),
    ) throws -> [MysteryOffer] {
        guard event.choices.contains(where: { $0.itemPool != nil }) else { return [] }
        guard isPlayable(stage: stage, labyrinthNodeID: labyrinthNodeID, save: save) else {
            throw MysteryOfferError.unavailableEncounter
        }
        let payload = payload(stageID: stage.id, labyrinthNodeID: labyrinthNodeID, save: save)
        let snapshot = try payload.map { try JSONDecoder().decode(MysteryOfferSnapshot.self, from: $0) }
        let previous = if let snapshot, snapshot.eventID == event.id {
            try snapshot.resolvedOffers()
        } else {
            [MysteryOffer]()
        }
        guard let inputs = levelInputs(stage: stage, labyrinthNodeID: labyrinthNodeID, save: save) else {
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
            if let saved, MysteryEffectApplier.isAvailable(saved.item, in: save.inventory) {
                return saved
            }
            return MysteryEffectApplier.resolveOffer(
                choice: choice,
                encounterID: stage.id,
                encounterLevel: level,
                rewardLevel: rewardLevel,
                save: save,
                bonuses: bonuses,
                using: &randomNumberGenerator,
            )
        }
        if offers != previous {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            let data = try encoder.encode(MysteryOfferSnapshot(eventID: event.id, offers: offers))
            setPayload(data, stageID: stage.id, labyrinthNodeID: labyrinthNodeID, save: &save)
        }
        return offers
    }

    public static func claim(
        _ offer: MysteryOffer,
        stage: Stage,
        labyrinthNodeID: String?,
        save: inout PlayerSave,
        at date: Date = Date(),
    ) -> MysteryEffectResult {
        guard isPlayable(stage: stage, labyrinthNodeID: labyrinthNodeID, save: save) else { return MysteryEffectResult() }
        guard let payload = payload(stageID: stage.id, labyrinthNodeID: labyrinthNodeID, save: save) else {
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
        // Settle against the tap-time clock (default now) so the grant matches
        // wallet state at claim, not preview-time production.
        let grantDate = date
        // Candidate-commit: item grant + bonus + markCleared + payload clear
        // apply atomically. `apply` is item-first (duplicate item grants
        // nothing, including no bonus), so the failure path discards the
        // candidate with no partial gold/material/XP mutation.
        // The stored bonus is raw; settle it against wallet caps now so the
        // grant matches wallet state at tap time rather than preview time.
        var candidate = save
        candidate.homestead.settleProduction(at: grantDate, roster: candidate.roster)
        guard let inputs = levelInputs(stage: stage, labyrinthNodeID: labyrinthNodeID, save: candidate) else {
            return MysteryEffectResult()
        }
        let level = inputs.encounterLevel
        let bonuses = inputs.bonuses
        let settledOffer = MysteryOffer(
            choiceID: offer.choiceID,
            item: offer.item,
            bonus: MysteryEffectApplier.settledBonus(
                offer.bonus,
                encounterLevel: level,
                save: candidate,
                experiencePercent: bonuses.experienceEarnedPercent,
                at: grantDate,
            ),
        )
        let result = MysteryEffectApplier.apply(settledOffer, save: &candidate, at: grantDate)
        guard result.grantedItems.count == 1 else { return result }
        if let labyrinthNodeID {
            candidate.labyrinth.markCleared(nodeID: labyrinthNodeID, eligibleRecruitEventIDs: candidate.roster.eligibleRecruitEventIDs)
        } else {
            candidate.journey.markRewardsClaimed(for: stage)
            candidate.journey.complete(stage, in: GameContent.chapters)
        }
        ItemCorruptionApplier.noteMysteryCompleted(save: &candidate)
        clear(stageID: stage.id, labyrinthNodeID: labyrinthNodeID, save: &candidate)
        save = candidate
        return result
    }

    static func clear(stageID: String, labyrinthNodeID: String?, save: inout PlayerSave) {
        setPayload(nil, stageID: stageID, labyrinthNodeID: labyrinthNodeID, save: &save)
    }

    private static func isPlayable(stage: Stage, labyrinthNodeID: String?, save: PlayerSave) -> Bool {
        let location: EncounterIdentity.Location = labyrinthNodeID.map { .labyrinth(nodeID: $0) }
            ?? .journey(stageID: stage.id)
        return EncounterIdentity(location: location, save: save).isPlayable(in: save)
    }

    private static func payload(stageID: String, labyrinthNodeID: String?, save: PlayerSave) -> Data? {
        if let labyrinthNodeID {
            return save.labyrinth.nodes[labyrinthNodeID]?.mysteryOffersPayload
        }
        return save.journey.mysteryOfferPayloads[stageID]
    }

    private static func setPayload(_ data: Data?, stageID: String, labyrinthNodeID: String?, save: inout PlayerSave) {
        if let labyrinthNodeID {
            save.labyrinth.nodes[labyrinthNodeID]?.mysteryOffersPayload = data
        } else {
            save.journey.mysteryOfferPayloads[stageID] = data
        }
    }
}
