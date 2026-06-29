enum GameContent {
    static let itemBaseTypes = [
        ItemBaseType(
            id: "ember-wand",
            name: "Ember Wand",
            slot: .weapon,
            symbolName: "wand.and.sparkles"
        ),
        ItemBaseType(
            id: "leather-gloves",
            name: "Leather Gloves",
            slot: .armor,
            symbolName: "hands.sparkles.fill"
        ),
        ItemBaseType(
            id: "river-charm",
            name: "River Charm",
            slot: .trinket,
            symbolName: "drop.fill"
        ),
        ItemBaseType(
            id: "iron-sword",
            name: "Iron Sword",
            slot: .weapon,
            symbolName: "sword.fill"
        )
    ]

    static let sampleInventoryItems = [
        InventoryItem(
            id: "ember-wand",
            baseType: itemBaseTypes[0],
            displayName: "Kindled Ember Wand",
            affixes: [
                ItemAffix(id: "ember-wand-affix-1", title: "Warm Focus", description: "+3% fire-themed ability power."),
                ItemAffix(id: "ember-wand-affix-2", title: "Bright Edge", description: "Basic attacks feel slightly sharper."),
                ItemAffix(id: "ember-wand-affix-3", title: "Cinder Memory", description: "A reminder that item effects are visual-only for now.")
            ]
        ),
        InventoryItem(
            id: "leather-gloves",
            baseType: itemBaseTypes[1],
            displayName: "Patient Leather Gloves",
            affixes: [
                ItemAffix(id: "leather-gloves-affix-1", title: "Steady Grip", description: "+2 placeholder handling."),
                ItemAffix(id: "leather-gloves-affix-2", title: "Soft Stitching", description: "Comfortable enough for long idle battles.")
            ]
        ),
        InventoryItem(
            id: "river-charm",
            baseType: itemBaseTypes[2],
            displayName: "River Charm of Sparks",
            affixes: [
                ItemAffix(id: "river-charm-affix-1", title: "Lucky Current", description: "+1 placeholder luck."),
                ItemAffix(id: "river-charm-affix-2", title: "Blue Glimmer", description: "Adds a cool-toned visual identity."),
                ItemAffix(id: "river-charm-affix-3", title: "Polished Loop", description: "Fits the shared Trinket slot."),
                ItemAffix(id: "river-charm-affix-4", title: "Quiet Weight", description: "No combat effect is applied yet.")
            ]
        ),
        InventoryItem(
            id: "iron-sword",
            baseType: itemBaseTypes[3],
            displayName: "Plain Iron Sword",
            affixes: [
                ItemAffix(id: "iron-sword-affix-1", title: "Reliable", description: "A clean baseline weapon for layout testing.")
            ]
        )
    ]

    static let heroes = [
        Combatant(
            id: "paladin",
            name: "Paladin",
            role: .hero,
            maxHealth: 10,
            abilityChoices: AbilityChoices(
                basics: [.strike, .shieldJab],
                skills: [.smite, .guardingBlow],
                ultimates: [.radiantCrash, .oathbreaker]
            )
        ),
        Combatant(
            id: "rogue",
            name: "Rogue",
            role: .hero,
            maxHealth: 8,
            abilityChoices: AbilityChoices(
                basics: [.quickCut, .strike],
                skills: [.smite, .guardingBlow],
                ultimates: [.oathbreaker, .radiantCrash]
            )
        ),
        Combatant(
            id: "mage",
            name: "Mage",
            role: .hero,
            maxHealth: 7,
            abilityChoices: AbilityChoices(
                basics: [.ember, .strike],
                skills: [.firebolt, .kindle],
                ultimates: [.meteor, .inferno]
            )
        )
    ]

    static let pets = [
        Combatant(
            id: "wolf",
            name: "Wolf",
            role: .pet,
            maxHealth: 6,
            abilityChoices: AbilityChoices(
                basics: [.strike, .quickCut],
                skills: [.smite, .guardingBlow],
                ultimates: [.radiantCrash, .oathbreaker]
            )
        ),
        Combatant(
            id: "hawk",
            name: "Hawk",
            role: .pet,
            maxHealth: 5,
            abilityChoices: AbilityChoices(
                basics: [.quickCut, .strike],
                skills: [.guardingBlow, .smite],
                ultimates: [.oathbreaker, .radiantCrash]
            )
        ),
        Combatant(
            id: "drake",
            name: "Drake",
            role: .pet,
            maxHealth: 7,
            abilityChoices: AbilityChoices(
                basics: [.ember, .strike],
                skills: [.firebolt, .kindle],
                ultimates: [.meteor, .inferno]
            )
        )
    ]

    static let trainingSlime = Combatant(
        id: "training-slime",
        name: "Training Slime",
        role: .enemy,
        maxHealth: 35,
        abilityChoices: AbilityChoices(
            basics: [.strike, .shieldJab],
            skills: [.guardingBlow, .smite],
            ultimates: [.oathbreaker, .radiantCrash]
        )
    )
}

extension Combatant {
    static var heroes: [Combatant] { GameContent.heroes }
    static var pets: [Combatant] { GameContent.pets }
    static var trainingSlime: Combatant { GameContent.trainingSlime }
}
