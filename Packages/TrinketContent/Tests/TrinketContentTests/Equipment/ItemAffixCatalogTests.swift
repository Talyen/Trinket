import Foundation
import Testing
import TrinketContent
import TrinketContentTestSupport

struct ItemAffixCatalogTests {
    @Test func `saved forbidden knowledge powers use the new draw count and description`() throws {
        let definition = try #require(GameContent.itemAffixDefinition(matching: "tattered_pages"))
        let oldPowers = [
            ItemAffixPower(
                description: "Every other turn, lose 1 Health and draw 2 cards.", modifiers: [],
                triggers: CombatTraitTriggers(mana: ManaTriggers(forbiddenKnowledge: true)),
            ),
            ItemAffixPower(
                description: "Draw 2 cards every other turn.", modifiers: [],
                triggers: CombatTraitTriggers(mana: ManaTriggers(drawEveryOtherTurn: 2)),
            ),
        ]
        for old in oldPowers {
            let decoded = try ItemAffixPowerCoding.decode(ItemAffixPowerCoding.encode([old]))
            let item = try ItemFixtures.makeBareItem(
                "tattered_pages", affixes: [definition.resolved(for: .basic)], affixPowers: decoded,
            )
            let power = try #require(item.resolvedPower(at: 0))
            #expect(power.triggers.forbiddenKnowledge)
            #expect(power.triggers.drawEveryOtherTurn == 0)
            #expect(power.description == "Every other turn, lose 1 Health and draw a card")
            #expect(item.displayedAffixes.first?.description == power.description)
        }
    }

    @Test func `saved verdant renewal shows its alternate turn cadence`() throws {
        let definition = try #require(GameContent.itemAffixDefinition(matching: "groves_favor"))
        let old = ItemAffixPower(
            description: "Restore 2 Health each turn.", modifiers: [],
            triggers: CombatTraitTriggers(healing: HealingTriggers(healthPerTurn: 2)),
        )
        let decoded = try ItemAffixPowerCoding.decode(ItemAffixPowerCoding.encode([old]))
        let item = try ItemFixtures.makeBareItem(
            "groves_favor", affixes: [definition.resolved(for: .basic)], affixPowers: decoded,
        )
        let power = try #require(item.resolvedPower(at: 0))
        #expect(power.triggers.healthPerTurn == 2)
        #expect(power.description == "Restore 2 Health every other turn.")
        #expect(item.displayedAffixes.first?.description == power.description)
    }

    @Test func `saved loyal companion power migrates to heal draw without losing other rolls`() throws {
        let definition = try #require(GameContent.itemAffixDefinition(matching: "companions_collar"))
        let old = ItemAffixPower(
            description: "Draw an additional Companion card each turn.", modifiers: [],
            triggers: CombatTraitTriggers(mana: ManaTriggers(spendManaBlockFlat: 2, companionCardsPerTurn: 1)),
        )
        let decoded = try ItemAffixPowerCoding.decode(ItemAffixPowerCoding.encode([old]))
        let item = try ItemFixtures.makeBareItem(
            "companions_collar", affixes: [definition.resolved(for: .basic)], affixPowers: decoded,
        )
        let power = try #require(item.resolvedPower(at: 0))
        #expect(power.triggers.companionCardsPerTurn == 0)
        #expect(power.triggers.companionCardsEveryOtherTurn == 0)
        #expect(power.triggers.healCompanionDrawsCompanionCard)
        #expect(power.triggers.spendManaBlockFlat == 2)
        #expect(power.description == "Once per turn, healing your Companion draws a Companion card.")
        #expect(item.displayedAffixes.first?.description == "Once per turn, healing your Companion draws a Companion card.")
    }

    @Test func `saved patient edge power migrates to block crit without losing rolls`() throws {
        let catalog = try #require(GameContent.unique(matching: "the_patient_edge"))
        try #require(catalog.affixes.first?.id == "the_patient_edge")
        let old = ItemAffixPower(
            description: "Old held card text.", modifiers: [],
            triggers: CombatTraitTriggers(attack: AttackTriggers(heldCardNextAttackDamage: 3)),
        )
        let decoded = try ItemAffixPowerCoding.decode(ItemAffixPowerCoding.encode([old]))
        let item = InventoryItem(
            id: catalog.id,
            templateID: catalog.templateID,
            baseType: catalog.baseType,
            rarity: catalog.rarity,
            displayName: catalog.displayName,
            affixes: catalog.affixes,
            affixPowers: decoded,
        )
        let power = try #require(item.resolvedPower(at: 0))
        #expect(power.triggers.heldCardNextAttackDamage == 0)
        #expect(power.triggers.partnerFirstAttackDamage == 0)
        #expect(power.triggers.blockPreparesCritical)
        #expect(power.description == "Blocking an attack makes your next attack Critically Hit.")
    }

    @Test func `nested affix reactions are ignored in favor of flat keys`() throws {
        let data = Data(#"[{"description":"Flat","modifiers":[],"triggers":{"gainManaBlockFlat":2}}]"#.utf8)

        let powers = try ItemAffixPowerCoding.decode(data)
        let power = try #require(powers.first)

        try #expect(power.triggers.gainManaBlockFlat == 2)
        try #expect(power.triggers.dodgeDealStunFlat == 0)
    }

    /// Runtime mirror of codegen rejects (_validate_keywords/_validate_weight):
    /// cheap defense for hand-edited affix definitions.
    @Test func `each affix has positive weight and keywords`() throws {
        for definition in GameContent.itemAffixDefinitions {
            try #expect(definition.weight > 0, "\(definition.id) should have positive weight")
            try #expect(!definition.keywords.isEmpty, "\(definition.id) should declare keywords")
        }
    }

    /// Runtime mirror of codegen's `validate_affix_reachability`: eligibility is
    /// a slot match plus a shared keyword, so an affix no base of its slot can
    /// host never enters a roll pool and skews the weights that remain.
    @Test func `each affix can roll on some base of its slot`() throws {
        let basesBySlot = Dictionary(grouping: GameContent.itemBaseTypes, by: \.slot)
        for definition in GameContent.itemAffixDefinitions {
            let hosts = basesBySlot[definition.slot] ?? []
            try #expect(
                hosts.contains { !definition.keywords.isDisjoint(with: $0.keywordAffinities) },
                "\(definition.id) should be rollable on a \(definition.slot) base",
            )
        }
    }

    @Test func `each affix defines basic and astral powers`() throws {
        for definition in GameContent.itemAffixDefinitions {
            try #expect(!definition.basic.description.isEmpty, "\(definition.id) basic description")
            try #expect(!definition.astral.description.isEmpty, "\(definition.id) astral description")
            if definition.slot == .trinket {
                try #expect(definition.basic == definition.astral)
                try #expect(definition.basic.triggers != CombatTraitTriggers(
                ) || !definition.basic.modifiers.isEmpty)
                continue
            }
            try #expect(
                !definition.basic.modifiers.isEmpty || definition.basic.triggers != CombatTraitTriggers(
                ),
                "\(definition.id) basic power",
            )
            try #expect(
                !definition.astral.modifiers.isEmpty || definition.astral.triggers != CombatTraitTriggers(
                ),
                "\(definition.id) astral power",
            )
            // Non-trinket affixes with real magnitudes must resolve astral
            // stronger than basic; trigger-only affixes are exempt.
            let isTriggerOnly = definition.basic.modifiers.isEmpty && definition.astral.modifiers.isEmpty
            if !isTriggerOnly {
                try #expect(definition.basic != definition.astral, "\(definition.id)")
            }
        }
    }

    @Test func `each item base type has eligible affix pool`() throws {
        for baseType in GameContent.itemBaseTypes {
            let eligible = ItemFixtures.eligibleAffixes(forBaseType: baseType)
            try #expect(!eligible.isEmpty, "\(baseType.id) should have at least one eligible affix")
        }
    }

    @Test func `two handed power scaling doubles magnitudes without thresholds or caps`() throws {
        let executioners = try #require(GameContent.itemAffixDefinition(matching: "executioners"))
        let symbiosis = try #require(GameContent.itemAffixDefinition(matching: "symbiosis"))
        let item = try ItemFixtures.makeBareItem(
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
        try #expect(executionPower.triggers.damageBelowHealthPercentBonus == 6)
        try #expect(executionPower.description == "Deal 6 additional damage if the enemy is below 30% Health.")

        let uncappedPower = try #require(item.resolvedPower(at: 1))
        try #expect(uncappedPower.triggers.companionLeechSharePercent == 2)
        try #expect(uncappedPower.description == "Your ally receives 100% of the Health you restore with Leech.")
        try #expect(item.displayedAffixes.map(\.description) == [
            "Deal 6 additional damage if the enemy is below 30% Health.",
            "Your ally receives 100% of the Health you restore with Leech.",
        ])
    }
}
