import Foundation
import Testing
import TrinketContent

struct ItemAffixCatalogTests {
    @Test func affixIDsAreUnique() throws {
        let ids = GameContent.itemAffixDefinitions.map(\.id)
        try #expect(Set(ids).count == ids.count)
    }

    @Test func combatReactionAffixIDsResolveToCatalogTitles() throws {
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

    @Test func legacyNestedAffixReactionsDecodeWithMissingKeysDefaulted() throws {
        let data = Data(#"[{"description":"Legacy","modifiers":[],"triggers":{"affixReactions":{"gainManaBlockFlat":2}}}]"#.utf8)

        let powers = try ItemAffixPowerCoding.decode(data)
        let power = try #require(powers.first)

        try #expect(power.triggers.gainManaBlockFlat == 2)
        try #expect(power.triggers.leechHealingMultiplier == 1)
        try #expect(power.triggers.dodgeDealStunFlat == 0)
    }

    @Test func eachAffixHasPositiveWeightAndKeywords() throws {
        for definition in GameContent.itemAffixDefinitions {
            try #expect(definition.weight > 0, "\(definition.id) should have positive weight")
            try #expect(!definition.keywords.isEmpty, "\(definition.id)) should declare keywords")
        }
    }

    @Test func itemAffixesDoNotGrantPrimaryStats() {
        for definition in GameContent.itemAffixDefinitions {
            for power in [definition.basic, definition.astral] {
                for modifier in power.modifiers {
                    switch modifier {
                    case .strength, .agility, .toughness, .intellect, .wisdom:
                        Issue.record("\(definition.id) grants primary stats via \(modifier)")
                    default:
                        break
                    }
                }
            }
        }
    }

    @Test func eachAffixDefinesBasicAndAstralPowers() throws {
        for definition in GameContent.itemAffixDefinitions {
            try #expect(!definition.basic.description.isEmpty, "\(definition.id)) basic description")
            try #expect(!definition.astral.description.isEmpty, "\(definition.id)) astral description")
            try #expect(
                !definition.basic.modifiers.isEmpty || definition.basic.triggers != CombatTraitTriggers(),
                "\(definition.id)) basic power"
            )
            try #expect(
                !definition.astral.modifiers.isEmpty || definition.astral.triggers != CombatTraitTriggers(),
                "\(definition.id)) astral power"
            )
        }
    }

    @Test func eachItemBaseTypeHasEligibleAffixPool() throws {
        for baseType in GameContent.itemBaseTypes {
            let eligible = GameContent.itemAffixDefinitions.filter { definition in
                definition.slot == baseType.slot &&
                    !definition.keywords.isDisjoint(with: baseType.keywordAffinities)
            }
            try #expect(!eligible.isEmpty, "\(baseType.id)) should have at least one eligible affix")
        }
    }

    @Test func weaponBaseTypesDeclareExpectedEquipKinds() throws {
        let byKind = Dictionary(grouping: GameContent.itemBaseTypes.filter { $0.slot == .weapon }) {
            $0.weaponKind
        }

        try #expect(Set(byKind[.oneHanded, default: []].map(\.id)) == [
            "dagger", "flail", "hatchet", "longsword", "mace", "shortsword", "wand",
        ])
        try #expect(Set(byKind[.twoHanded, default: []].map(\.id)) == [
            "crossbow", "double_axe", "greatsword", "longbow", "maul", "recurve_bow", "shortbow", "staff",
        ])
        try #expect(Set(byKind[.offHand, default: []].map(\.id)) == ["kite_shield", "spellbook"])
        try #expect(GameContent.itemBaseTypes.filter { $0.slot != .weapon }.allSatisfy { $0.weaponKind == nil })
    }

    @Test func twoHandedPowerScalingDoublesMagnitudesWithoutThresholdsOrCaps() throws {
        let crossbow = try #require(GameContent.itemBaseTypes.first { $0.id == "crossbow" })
        let executioners = try #require(GameContent.itemAffixDefinition(matching: "executioners"))
        let symbiosis = try #require(GameContent.itemAffixDefinition(matching: "symbiosis"))
        let item = InventoryItem(
            id: "scaled-crossbow",
            baseType: crossbow,
            rarity: .astral,
            displayName: crossbow.name,
            affixes: [
                executioners.resolved(for: .astral),
                symbiosis.resolved(for: .astral),
            ],
            affixPowers: [executioners.astral, symbiosis.astral]
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

    @Test func revisedAffixesUseConsistentLeechWording() throws {
        let byID = Dictionary(uniqueKeysWithValues: GameContent.itemAffixDefinitions.map { ($0.id, $0) })

        let bloodstone = try #require(byID["bloodstone"])
        try #expect(bloodstone.basic.description == "Leech restores 1 additional Health.")
        try #expect(bloodstone.basic.modifiers == [.leechHealing(1)])

        let lifeweave = try #require(byID["lifeweave"])
        try #expect(lifeweave.basic.description == "Restore 1 additional Health when you Leech.")
        try #expect(lifeweave.basic.modifiers == [.leechHealing(1)])

        let stunning = try #require(byID["stunning"])
        try #expect(stunning.title == "Stunning")
        try #expect(stunning.basic.description == "Increase Stun damage by 1.")
        try #expect(byID["shocking"] == nil)
    }

    @Test func thinKeywordAffixesUseExpectedCopy() throws {
        let byID = Dictionary(uniqueKeysWithValues: GameContent.itemAffixDefinitions.map { ($0.id, $0) })

        let knockout = try #require(byID["knockout"])
        try #expect(knockout.basic.description == "Deal 3 Physical damage when you Stun the enemy.")

        let shredding = try #require(byID["shredding"])
        try #expect(shredding.basic.description == "Ignore 10% of enemy mitigation.")

        let absolving = try #require(byID["absolving"])
        try #expect(absolving.basic.description == "Cleanse 1 status effect when you deal Holy damage.")

        let retaliatory = try #require(byID["retaliatory"])
        try #expect(retaliatory.basic.description == "Reflect 10% of damage taken.")

        let riposte = try #require(byID["riposte"])
        try #expect(riposte.keywords == [.physical, .dodge])
        try #expect(riposte.basic.description == "Deal 3 additional damage on your next attack after Dodging.")
    }

    @Test func underrepresentedKeywordAffixesUseExpectedCopy() throws {
        let byID = Dictionary(uniqueKeysWithValues: GameContent.itemAffixDefinitions.map { ($0.id, $0) })

        let disrupting = try #require(byID["disrupting"])
        try #expect(disrupting.basic.description == "Purge 1 status effect when you Stun the enemy.")
        try #expect(disrupting.astral.description == "Purge all status effects when you Stun the enemy.")

        let unmaking = try #require(byID["unmaking"])
        try #expect(unmaking.basic.description == "Purge 1 status effect from the enemy when you Critically Hit.")

        let gilded = try #require(byID["gilded"])
        try #expect(gilded.basic.modifiers == [.goldGainedPercent(0.10)])

        let blur = try #require(byID["blur"])
        try #expect(blur.basic.description == "Gain 15% Dodge chance while below 50% Health.")
    }
}
