import Foundation
import TrinketCore

enum MysteryEventPool {
    static let all: [MysteryEvent] = [
        manaBerries,
        enchantedSpring,
        fungalGrotto,
        wisdomTree,
        fairyRing,
        ancientAltar,
        hiddenCache,
        overgrownTemple,
        abandonedStudy,
        mysteriousTome,
        crystalGeode,
        meteoriteCrash,
        forgottenHoard,
        sacredGrove,
        mountainPass,
        murkyPond,
        necromancersOffer,
        medicinalHerbGarden,
        crystalGarden,
        huntersLodge,
        roadsideCenser,
        thePhoenix,
        theWolf,
        corruptionAltar,
    ]

    static func makeEvent(
        id: String,
        title: String,
        narrative: String,
        artID: String?,
        choices: [(id: String, label: String, effects: [MysteryEffect])],
    ) -> MysteryEvent {
        MysteryEvent(
            id: id,
            title: title,
            narrative: narrative,
            artID: artID,
            choices: choices.map { MysteryChoice(id: $0.id, label: $0.label, effects: $0.effects) },
        )
    }

    static func item(
        _ baseTypeID: String,
        trinkets: Set<String> = [],
        uniques: Set<String> = [],
        guaranteedAffixIDs: [String] = [],
    ) -> MysteryEffect {
        .gainItem(MysteryItemPool(
            baseTypeID: baseTypeID,
            trinketIDs: trinkets,
            uniqueIDs: uniques,
            guaranteedAffixIDs: guaranteedAffixIDs,
        ))
    }

    static let corruptionAltarID = "corruption-altar"

    private static let eventsByID: [String: MysteryEvent] = Dictionary(
        uniqueKeysWithValues: all.map { ($0.id, $0) },
    )

    static func event(matching id: String) -> MysteryEvent? {
        eventsByID[id]
    }

    static func pickMysteryEvent(
        context: MysteryEventPickContext,
        using randomNumberGenerator: inout some RandomNumberGenerator,
    ) -> MysteryEvent {
        let nonAltar = all.filter { $0.id != corruptionAltarID }
        let canOfferAltar = context.allowsCorruptionAltar
            && context.hasEligibleCorruptTarget
            && context.corruptionAltarCooldownRemaining == 0
        let altarRoll = Int.random(
            in: 1 ... 100,
            using: &randomNumberGenerator,
        )
        if canOfferAltar,
           altarRoll <= MysteryEventPickContext.corruptionAltarReadyChancePercent,
           let altar = event(matching: corruptionAltarID) {
            return altar
        }
        guard let event = nonAltar.randomElement(using: &randomNumberGenerator) else {
            preconditionFailure("MysteryEventPool must contain non-altar events")
        }
        return event
    }
}
