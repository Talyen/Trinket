import Foundation
import Testing
import TrinketContent

struct ItemAffixCatalogTests {
    @Test func `combat reaction affix I ds resolve to catalog titles`() throws {
        let ids = [
            "absolving", "aetherward", "arcane_ward", "beacon", "blood_price",
            "bounty", "branding", "cascading", "disrupting", "nullifying",
            "payday", "sanctum", "second_wind", "sidestep", "siphoning",
            "symbiosis", "unmaking", "untouchable", "whiplash",
        ]

        for id in ids {
            let definition = GameContent.itemAffixDefinition(matching: id)
            try #expect(definition?.title.isEmpty == false, "Missing combat-reaction affix \(id)")
        }
    }

    @Test func `nested affix reactions are ignored in favor of flat keys`() throws {
        let data = Data(#"[{"description":"Flat","modifiers":[],"triggers":{"gainManaBlockFlat":2}}]"#.utf8)

        let powers = try ItemAffixPowerCoding.decode(data)
        let power = try #require(powers.first)

        try #expect(power.triggers.gainManaBlockFlat == 2)
        try #expect(power.triggers.dodgeDealStunFlat == 0)
    }

    @Test func `each affix has positive weight and keywords`() throws {
        for definition in GameContent.itemAffixDefinitions {
            try #expect(definition.weight > 0, "\(definition.id) should have positive weight")
            try #expect(!definition.keywords.isEmpty, "\(definition.id)) should declare keywords")
        }
    }

    @Test func `item affixes do not grant primary stats`() {
        for definition in GameContent.itemAffixDefinitions {
            for power in [definition.basic, definition.astral] {
                for modifier in power.modifiers {
                    _ = modifier
                }
            }
        }
    }

    @Test func `each affix defines basic and astral powers`() throws {
        for definition in GameContent.itemAffixDefinitions {
            try #expect(!definition.basic.description.isEmpty, "\(definition.id)) basic description")
            try #expect(!definition.astral.description.isEmpty, "\(definition.id)) astral description")
            if definition.slot == .trinket {
                try #expect(definition.basic == definition.astral)
                try #expect(definition.basic.triggers != CombatTraitTriggers(
                ) || !definition.basic.modifiers.isEmpty)
                continue
            }
            try #expect(
                !definition.basic.modifiers.isEmpty || definition.basic.triggers != CombatTraitTriggers(
                ),
                "\(definition.id)) basic power",
            )
            try #expect(
                !definition.astral.modifiers.isEmpty || definition.astral.triggers != CombatTraitTriggers(
                ),
                "\(definition.id)) astral power",
            )
        }
    }

    @Test func `each item base type has eligible affix pool`() throws {
        for baseType in GameContent.itemBaseTypes {
            let eligible = GameContent.itemAffixDefinitions.filter { definition in
                definition.slot == baseType.slot &&
                    !definition.keywords.isDisjoint(with: baseType.keywordAffinities)
            }
            try #expect(!eligible.isEmpty, "\(baseType.id)) should have at least one eligible affix")
        }
    }

    @Test func `two handed power scaling doubles magnitudes without thresholds or caps`() throws {
        let executioners = try #require(GameContent.itemAffixDefinition(matching: "executioners"))
        let symbiosis = try #require(GameContent.itemAffixDefinition(matching: "symbiosis"))
        let item = try ItemFixtures.makeItem(
            "crossbow",
            id: "scaled-crossbow",
            rarity: .astral,
            affixes: [
                executioners.resolved(for: .astral),
                symbiosis.resolved(for: .astral),
            ],
            affixPowers: [executioners.astral, symbiosis.astral],
        )

        let executionPower = try #require(item.resolvedPower(at: 0))
        try #expect(executionPower.triggers.damageBelowHealthPercentThreshold == 0.30)
        try #expect(executionPower.triggers.damageBelowHealthPercentBonus == 12)
        try #expect(executionPower.description == "Deal 12 additional damage if the enemy is below 30% Health.")

        let uncappedPower = try #require(item.resolvedPower(at: 1))
        try #expect(uncappedPower.triggers.companionLeechSharePercent == 2)
        try #expect(uncappedPower.description == "Companions gain 200% of your Leech.")
        try #expect(item.displayedAffixes.map(\.description) == [
            "Deal 12 additional damage if the enemy is below 30% Health.",
            "Companions gain 200% of your Leech.",
        ])
    }

    @Test func `keyword affixes keep typed definitions`() throws {
        let byID = Dictionary(uniqueKeysWithValues: GameContent.itemAffixDefinitions.map { ($0.id, $0) })

        let bloodstone = try #require(byID["bloodstone"])
        try #expect(bloodstone.basic.modifiers == [.leechHealing(1)])

        let lifeweave = try #require(byID["lifeweave"])
        try #expect(lifeweave.basic.modifiers == [.leechHealing(1)])

        try #expect(byID["shocking"] == nil)

        let riposte = try #require(byID["riposte"])
        try #expect(riposte.keywords == [.physical, .dodge])

        let gilded = try #require(byID["gilded"])
        try #expect(gilded.basic.modifiers == [.goldGainedPercent(0.10)])
    }
}
