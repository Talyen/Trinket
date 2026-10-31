import Testing
import TrinketContent
import TrinketContentTestSupport

struct ItemAffixCatalogTests {
    @Test(arguments: [
        (
            "tattered_pages",
            "Every other turn, lose 1 Health and draw 2 cards.",
            CombatTraitTriggers { $0.forbiddenKnowledge = true },
            CombatTraitTriggers { $0.burnDamageDrawChancePercent = 0.10 },
            "Burn damage has a 10% chance to draw a card",
        ),
        (
            "tattered_pages",
            "Draw 2 cards every other turn.",
            CombatTraitTriggers { $0.drawEveryOtherTurn = 2 },
            CombatTraitTriggers { $0.burnDamageDrawChancePercent = 0.10 },
            "Burn damage has a 10% chance to draw a card",
        ),
        (
            "groves_favor",
            "Restore 2 Health each turn.",
            CombatTraitTriggers { $0.healthPerTurn = 2 },
            CombatTraitTriggers { $0.healthPerTurn = 2 },
            "Restore 2 Health every other turn",
        ),
        (
            "companions_collar",
            "Draw an additional Companion card each turn.",
            CombatTraitTriggers {
                $0.spendManaBlockFlat = 2
                $0.companionCardsPerTurn = 1
            },
            CombatTraitTriggers {
                $0.spendManaBlockFlat = 2
                $0.healCompanionDrawsCompanionCard = true
            },
            "Once per turn, healing your Companion draws a Companion card",
        ),
    ])
    func `saved affix migrations update behavior and descriptions while preserving other rolls`(
        affixID: String, oldDescription: String, oldTriggers: CombatTraitTriggers,
        expectedTriggers: CombatTraitTriggers, expectedDescription: String,
    ) throws {
        let definition = try #require(GameContent.itemAffixDefinition(matching: affixID))
        let old = ItemAffixPower(description: oldDescription, triggers: oldTriggers)
        let decoded = try ItemAffixPowerCoding.decode(ItemAffixPowerCoding.encode([old]))
        let item = try ItemFixtures.makeBareItem(
            affixID, affixes: [definition.resolved(for: .basic)], affixPowers: decoded,
        )
        #expect(item.resolvedPower(at: 0) == ItemAffixPower(description: expectedDescription, triggers: expectedTriggers))
        #expect(item.displayedAffixes.first?.description == expectedDescription)
    }

    @Test func `saved patient edge power migrates to block crit without losing rolls`() throws {
        let catalog = try #require(GameContent.unique(matching: "the_patient_edge"))
        try #require(catalog.affixes.first?.id == "the_patient_edge")
        let old = ItemAffixPower(
            description: "Old held card text.", modifiers: [],
            triggers: CombatTraitTriggers { $0.heldCardNextAttackDamage = 3 },
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
        #expect(power.description == "Blocking an attack makes your next manually played attack Critically Hit")
    }

    @Test func `each affix defines basic and astral powers`() throws {
        for definition in GameContent.itemAffixDefinitions {
            if definition.slot == .trinket {
                try #expect(definition.basic == definition.astral)
                try #expect(definition.basic.triggers != CombatTraitTriggers() || !definition.basic.modifiers.isEmpty)
                continue
            }
            try #expect(
                !definition.basic.modifiers.isEmpty || definition.basic.triggers != CombatTraitTriggers(),
                "\(definition.id) basic power",
            )
            try #expect(
                !definition.astral.modifiers.isEmpty || definition.astral.triggers != CombatTraitTriggers(),
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
        try #expect(executionPower.description == "Deal 6 additional damage if the enemy is below 30% Health")

        let uncappedPower = try #require(item.resolvedPower(at: 1))
        try #expect(uncappedPower.triggers.companionLeechSharePercent == 2)
        try #expect(uncappedPower.description == "Your ally receives 100% of the Health you restore with Leech")
        try #expect(item.displayedAffixes.map(\.description) == [
            "Deal 6 additional damage if the enemy is below 30% Health",
            "Your ally receives 100% of the Health you restore with Leech",
        ])
    }
}
