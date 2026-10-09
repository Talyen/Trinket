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

    public static func prepare(
        event: MysteryEvent,
        encounter: EncounterIdentity,
        save: inout PlayerSave,
        using randomNumberGenerator: inout some RandomNumberGenerator,
        at date: Date = Date(),
    ) throws -> [MysteryOffer] {
        guard event.choices.contains(where: { $0.itemPool != nil }) else { return [] }
        guard encounter.isPlayable(in: save) else {
            throw MysteryOfferError.unavailableEncounter
        }
        let payload = payload(encounter: encounter, save: save)
        let snapshot = try payload.map { try JSONDecoder().decode(MysteryOfferSnapshot.self, from: $0) }
        let previous = if let snapshot, snapshot.eventID == event.id {
            try snapshot.resolvedOffers()
        } else {
            [MysteryOffer]()
        }
        guard let rewardLevel = encounter.rewardLevel(in: save),
              let level = encounter.encounterLevel(in: save) else {
            throw MysteryOfferError.unavailableEncounter
        }
        let bonuses = encounter.modifierEffects(in: save)
        save.homestead.settleProduction(at: date, roster: save.roster)
        // Non-pool choices (leave, corrupt-only, unlock-only) resolve through
        // the direct-effects path, so only pooled choices produce offers.
        let offers: [MysteryOffer] = event.choices.compactMap { choice in
            let saved = previous.first { $0.choiceID == choice.id }
            guard let offer = saved ?? MysteryEffectApplier.resolveOffer(
                choice: choice,
                encounterID: encounter.stageID,
                encounterLevel: level,
                rewardLevel: rewardLevel,
                save: save,
                bonuses: bonuses,
                using: &randomNumberGenerator,
            ) else { return nil }
            if saved != nil, offer.homesteadReward == nil {
                return offer
            }
            var remainders = save.homestead.rewardRemainders ?? .zero
            let nominal = offer.homesteadReward?.resolve(remainders: &remainders) ?? offer.bonus
            return MysteryOffer(
                choiceID: offer.choiceID, item: offer.item,
                bonus: MysteryEffectApplier.settledBonus(
                    nominal, encounterLevel: level, save: save,
                    experiencePercent: bonuses.experienceEarnedPercent, at: date,
                ),
                homesteadReward: offer.homesteadReward,
            )
        }
        if offers != previous {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            let data = try encoder.encode(MysteryOfferSnapshot(eventID: event.id, offers: offers))
            setPayload(data, encounter: encounter, save: &save)
        }
        return offers
    }

    public static func claim(
        _ offer: MysteryOffer,
        encounter: EncounterIdentity,
        save: inout PlayerSave,
        at date: Date = Date(),
    ) -> MysteryEffectResult {
        guard encounter.isPlayable(in: save),
              let payload = payload(encounter: encounter, save: save) else { return MysteryEffectResult() }
        do {
            let snapshot = try JSONDecoder().decode(MysteryOfferSnapshot.self, from: payload)
            guard try snapshot.resolvedOffers().contains(offer) else { return MysteryEffectResult() }
        } catch {
            return MysteryEffectResult()
        }
        // Validate and grant at one production date on a candidate, so stale
        // offers cannot grant partial rewards or complete the encounter.
        let grantDate = date
        var candidate = save
        candidate.homestead.settleProduction(at: grantDate, roster: candidate.roster)
        guard let level = encounter.encounterLevel(in: candidate) else {
            return MysteryEffectResult()
        }
        let bonuses = encounter.modifierEffects(in: candidate)
        guard MysteryEffectApplier.hasCurrentHomesteadReward(offer, save: candidate) else { return MysteryEffectResult() }
        let result = MysteryEffectApplier.apply(
            offer, save: &candidate, at: grantDate,
            goldOverflowExperience: RewardExperiencePolicy.encounterAward(
                encounterLevel: level, roster: candidate.roster, percent: bonuses.experienceEarnedPercent,
            ),
            allowOwnedItem: true,
        )
        guard result.grantedItems.count == 1 || InventoryDuplicatePolicy.containsDuplicate(of: offer.item, in: candidate.inventory.items)
        else { return result }
        guard NonCombatEncounterCompletion.complete(
            encounter: encounter, grantingEncounterRewards: false, save: &candidate,
            recordReceipt: { _ in },
        ) == .completed else { return MysteryEffectResult() }
        clear(encounter: encounter, save: &candidate)
        ItemCorruptionApplier.noteMysteryCompleted(save: &candidate)
        save = candidate
        return result
    }

    static func clear(encounter: EncounterIdentity, save: inout PlayerSave) {
        setPayload(nil, encounter: encounter, save: &save)
    }

    private static func payload(encounter: EncounterIdentity, save: PlayerSave) -> Data? {
        switch encounter.location {
        case let .journey(id): save.journey.mysteryOfferPayloads[id]
        case let .labyrinth(id): save.labyrinth.nodes[id]?.mysteryOffersPayload
        case let .voyage(runID, nodeID): save.voyage.node(runID: runID, nodeID: nodeID)?.mysteryOffersPayload
        }
    }

    private static func setPayload(
        _ data: Data?,
        encounter: EncounterIdentity,
        save: inout PlayerSave,
    ) {
        switch encounter.location {
        case let .journey(id): save.journey.mysteryOfferPayloads[id] = data
        case let .labyrinth(id): save.labyrinth.nodes[id]?.mysteryOffersPayload = data
        case let .voyage(runID, nodeID): save.voyage.updateNode(runID: runID, nodeID: nodeID) { $0.mysteryOffersPayload = data }
        }
    }
}

struct MysteryOfferSnapshot: Codable {
    let version: Int
    let eventID: String
    let offers: [StoredOffer]

    init(eventID: String, offers: [MysteryOffer]) {
        version = 2
        self.eventID = eventID
        self.offers = offers.map(StoredOffer.init)
    }

    func resolvedOffers() throws -> [MysteryOffer] {
        guard version == 2 else { throw MysteryOfferError.invalidSnapshot }
        return try offers.compactMap { try $0.resolve() }
    }

    struct StoredOffer: Codable {
        let choiceID: String
        let bonus: MysteryRewardBonus
        let homesteadReward: HomesteadMysteryReward?
        let item: StoredInventoryItem

        init(_ offer: MysteryOffer) {
            choiceID = offer.choiceID
            bonus = offer.bonus
            homesteadReward = offer.homesteadReward
            item = StoredInventoryItem(offer.item)
        }

        /// Nil when the offer's item is homeless (unknown base): the option
        /// is dropped while surviving offers resolve. Invalid bonuses still
        /// throw so a tampered payload cannot mint rewards.
        func resolve() throws -> MysteryOffer? {
            guard bonus.amount >= 0 else { throw MysteryOfferError.invalidSnapshot }
            if case let .goldAndExperience(gold, experience, nominalGold, fullOverflowExperience) = bonus {
                guard gold >= 0, experience >= 0, nominalGold >= gold,
                      fullOverflowExperience >= experience else { throw MysteryOfferError.invalidSnapshot }
            }
            guard let item = item.resolved() else { return nil }
            if let reward = homesteadReward {
                guard reward.resource == .gold || reward.resource == .gems, reward.amount >= 0,
                      (0 ... 100).contains(reward.percent) else { throw MysteryOfferError.invalidSnapshot }
            }
            return MysteryOffer(choiceID: choiceID, item: item, bonus: bonus, homesteadReward: homesteadReward)
        }
    }
}

enum MysteryOfferError: Error {
    case invalidSnapshot
    case unavailableEncounter
}
