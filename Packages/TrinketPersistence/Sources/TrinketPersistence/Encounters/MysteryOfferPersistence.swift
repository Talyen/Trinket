import Foundation
import TrinketContent
import TrinketCore

public enum MysteryOfferPersistence {
    public static func prepare(
        event: MysteryEvent,
        stage: Stage,
        labyrinthNodeID: String?,
        save: inout PlayerSave,
        using randomNumberGenerator: inout some RandomNumberGenerator,
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
        let location: EncounterIdentity.Location = labyrinthNodeID.map { .labyrinth(nodeID: $0) }
            ?? .journey(stageID: stage.id)
        guard let rewardLevel = EncounterIdentity(location: location, save: save).rewardLevel(in: save) else {
            throw MysteryOfferError.unavailableEncounter
        }
        let level = MysteryEffectApplier.resolvedEncounterLevel(stage: stage, labyrinthNodeID: labyrinthNodeID, save: save)
        let bonuses = labyrinthNodeID.map { save.labyrinth.effects(for: $0) } ?? .zero
        save.homestead.settleProduction(at: Date(), roster: save.roster)
        let offers = event.choices.map { choice in
            let saved = previous.first { $0.choiceID == choice.id }
            let offer: MysteryOffer = if let saved, MysteryEffectApplier.isAvailable(saved.item, in: save.inventory) {
                saved
            } else {
                MysteryEffectApplier.resolveOffer(
                    choice: choice,
                    encounterID: stage.id,
                    encounterLevel: level,
                    rewardLevel: rewardLevel,
                    save: save,
                    bonuses: bonuses,
                    using: &randomNumberGenerator,
                )
            }
            return MysteryOffer(
                choiceID: choice.id,
                item: offer.item,
                bonus: boundedBonus(offer.bonus, level: level, experiencePercent: bonuses.experienceEarnedPercent, save: save),
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
        let grantDate = save.homestead.lastProductionAt
        // Candidate-commit: item grant + bonus + markCleared + payload clear
        // apply atomically. `apply` is item-first (duplicate item grants
        // nothing, including no bonus), so the failure path discards the
        // candidate with no partial gold/material/XP mutation.
        var candidate = save
        let result = MysteryEffectApplier.apply(offer, save: &candidate, at: grantDate)
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

    private static func clear(stageID: String, labyrinthNodeID: String?, save: inout PlayerSave) {
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

    private static func boundedBonus(
        _ bonus: MysteryRewardBonus,
        level: Int,
        experiencePercent: Int,
        save: PlayerSave,
    ) -> MysteryRewardBonus {
        RewardSettlementPolicy.settle(
            bonus,
            inputs: RewardSettlementInputs(
                save: save,
                hero: save.roster.activeHero,
                companion: save.roster.activeCompanion,
                at: save.homestead.lastProductionAt,
            ),
            replacementExperience: RewardExperiencePolicy.encounterAward(
                encounterLevel: level,
                roster: save.roster,
                percent: experiencePercent,
            ),
        )
    }
}
