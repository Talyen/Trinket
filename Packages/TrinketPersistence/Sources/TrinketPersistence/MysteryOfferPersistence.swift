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
        let payload: Data?
        if let labyrinthNodeID {
            guard let node = save.labyrinth.nodes[labyrinthNodeID], !node.isCleared else {
                throw MysteryOfferError.unavailableEncounter
            }
            payload = node.mysteryOffersPayload
        } else {
            guard !save.journey.completedStageIDs.contains(stage.id) else {
                throw MysteryOfferError.unavailableEncounter
            }
            payload = save.journey.mysteryOfferPayloads[stage.id]
        }
        let snapshot = try payload.map { try JSONDecoder().decode(MysteryOfferSnapshot.self, from: $0) }
        let previous = if let snapshot, snapshot.eventID == event.id {
            try snapshot.resolvedOffers()
        } else {
            [MysteryOffer]()
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
            if let labyrinthNodeID {
                save.labyrinth.nodes[labyrinthNodeID]?.mysteryOffersPayload = data
            } else {
                save.journey.mysteryOfferPayloads[stage.id] = data
            }
        }
        return offers
    }

    public static func claim(
        _ offer: MysteryOffer,
        stage: Stage,
        labyrinthNodeID: String?,
        save: inout PlayerSave,
    ) -> MysteryEffectResult {
        let payload: Data?
        if let labyrinthNodeID {
            guard let node = save.labyrinth.nodes[labyrinthNodeID], !node.isCleared else { return MysteryEffectResult() }
            payload = node.mysteryOffersPayload
        } else {
            guard !save.journey.completedStageIDs.contains(stage.id) else { return MysteryEffectResult() }
            payload = save.journey.mysteryOfferPayloads[stage.id]
        }
        guard let payload else { return MysteryEffectResult() }
        let saved: [MysteryOffer]
        do {
            let snapshot = try JSONDecoder().decode(MysteryOfferSnapshot.self, from: payload)
            saved = try snapshot.resolvedOffers()
        } catch {
            return MysteryEffectResult()
        }
        guard saved.contains(offer) else { return MysteryEffectResult() }
        let grantDate = save.homestead.lastProductionAt
        let result = MysteryEffectApplier.apply(offer, save: &save, at: grantDate)
        guard result.grantedItems.count == 1 else { return result }
        if let labyrinthNodeID {
            save.labyrinth.markCleared(nodeID: labyrinthNodeID, eligibleRecruitEventIDs: save.roster.eligibleRecruitEventIDs)
        } else {
            save.journey.markRewardsClaimed(for: stage)
            save.journey.complete(stage, in: GameContent.chapters)
        }
        ItemCorruptionApplier.noteMysteryCompleted(save: &save)
        clear(stageID: stage.id, labyrinthNodeID: labyrinthNodeID, save: &save)
        return result
    }

    private static func clear(stageID: String, labyrinthNodeID: String?, save: inout PlayerSave) {
        if let labyrinthNodeID {
            save.labyrinth.nodes[labyrinthNodeID]?.mysteryOffersPayload = nil
        } else {
            save.journey.mysteryOfferPayloads[stageID] = nil
        }
    }

    private static func boundedBonus(
        _ bonus: MysteryRewardBonus,
        level: Int,
        experiencePercent: Int,
        save: PlayerSave,
    ) -> MysteryRewardBonus {
        switch bonus {
        case let .gold(amount):
            let reserved = PlayerRosterState.reservedGold(from: save.homestead.pendingProduction)
            let capacity = PlayerRosterState.availableGoldCapacity(gold: save.roster.gold, reservedGold: reserved)
            if capacity == 0 {
                return .experience(MysteryEffectApplier.experienceAward(
                    encounterLevel: level,
                    roster: save.roster,
                    percent: experiencePercent,
                ))
            }
            return .gold(min(amount, capacity))
        case let .experience(amount):
            return .experience(MysteryEffectApplier.sharedExperience(amount, roster: save.roster))
        case .material:
            return bonus
        }
    }
}
