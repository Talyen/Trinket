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
            id: "knight",
            name: "Knight",
            role: .hero,
            maxHealth: 10,
            abilityChoices: AbilityChoices(
                basics: [.bash, .shieldBash],
                skills: [.smite, .spikedShield],
                ultimates: [.blessedAegis, .crystalBulwark]
            )
        ),
        Combatant(
            id: "rogue",
            name: "Rogue",
            role: .hero,
            maxHealth: 8,
            abilityChoices: AbilityChoices(
                basics: [.stab, .blackjack],
                skills: [.poisonDagger, .serratedEdge],
                ultimates: [.hemorrhage, .steal]
            )
        ),
        Combatant(
            id: "wizard",
            name: "Wizard",
            role: .hero,
            maxHealth: 7,
            abilityChoices: AbilityChoices(
                basics: [.kindling, .rayOfFrost],
                skills: [.fireball, .frostbolt],
                ultimates: [.meteor, .glacialWard]
            )
        ),
        Combatant(
            id: "alchemist",
            name: "Alchemist",
            role: .hero,
            maxHealth: 9,
            abilityChoices: AbilityChoices(
                basics: [.antivenomPotion, .smellingSalts],
                skills: [.healthPotion, .manaPotion],
                ultimates: [.panaceaPotion, .wishingPotion]
            )
        ),
        Combatant(
            id: "druid",
            name: "Druid",
            role: .hero,
            maxHealth: 11,
            abilityChoices: AbilityChoices(
                basics: [.apple, .bread],
                skills: [.briarShield, .graspingVines],
                ultimates: [.bloodthorn, .pixie]
            )
        ),
        Combatant(
            id: "ranger",
            name: "Ranger",
            role: .hero,
            maxHealth: 8,
            abilityChoices: AbilityChoices(
                basics: [.bountyShot, .fireArrow],
                skills: [.venomArrow, .sapArrow],
                ultimates: [.packTactics, .concussiveShot]
            )
        ),
        Combatant(
            id: "warlock",
            name: "Warlock",
            role: .hero,
            maxHealth: 7,
            abilityChoices: AbilityChoices(
                basics: [.willOWisp, .fangs],
                skills: [.bloodOffering, .darkPact],
                ultimates: [.raiseSkeleton, .faustianBargain]
            )
        ),
        Combatant(
            id: "wildcard",
            name: "Wildcard",
            role: .hero,
            maxHealth: 10,
            abilityChoices: AbilityChoices(
                basics: [.gold, .wishingWell],
                skills: [.haste, .libraryOwl],
                ultimates: [.wish, .goldenRetriever]
            )
        )
    ]

    static let pets = [
        Combatant(
            id: "bear",
            name: "Bear",
            role: .pet,
            maxHealth: 9,
            abilityChoices: AbilityChoices(
                basics: [.bash, .block],
                skills: [.spikedShield, .sunderArmor],
                ultimates: [.crystalBulwark, .thornMail]
            )
        ),
        Combatant(
            id: "frost_whelp",
            name: "Frost Whelp",
            role: .pet,
            maxHealth: 6,
            abilityChoices: AbilityChoices(
                basics: [.rayOfFrost, .fangs],
                skills: [.frostbolt, .coldSnap],
                ultimates: [.glacialWard, .concussiveShot]
            )
        ),
        Combatant(
            id: "imp",
            name: "Imp",
            role: .pet,
            maxHealth: 6,
            abilityChoices: AbilityChoices(
                basics: [.willOWisp, .fangs],
                skills: [.darkPact, .fireball],
                ultimates: [.combustion, .faustianBargain]
            )
        ),
        Combatant(
            id: "lizard_scout",
            name: "Lizard Scout",
            role: .pet,
            maxHealth: 7,
            abilityChoices: AbilityChoices(
                basics: [.stab, .blackjack],
                skills: [.serratedEdge, .poisonDagger],
                ultimates: [.hemorrhage, .steal]
            )
        ),
        Combatant(
            id: "panther",
            name: "Panther",
            role: .pet,
            maxHealth: 7,
            abilityChoices: AbilityChoices(
                basics: [.slash, .fangs],
                skills: [.serratedEdge, .haste],
                ultimates: [.packTactics, .hemorrhage]
            )
        ),
        Combatant(
            id: "phoenix",
            name: "Phoenix",
            role: .pet,
            maxHealth: 6,
            abilityChoices: AbilityChoices(
                basics: [.kindling, .willOWisp],
                skills: [.fireball, .cauterize],
                ultimates: [.phoenixFeather, .combustion]
            )
        ),
        Combatant(
            id: "wolf",
            name: "Wolf",
            role: .pet,
            maxHealth: 6,
            abilityChoices: AbilityChoices(
                basics: [.slash, .fangs],
                skills: [.serratedEdge, .venomFangs],
                ultimates: [.packTactics, .concussiveShot]
            )
        )
    ]

    static let trainingSlime = Combatant(
        id: "training-slime",
        name: "Training Slime",
        role: .enemy,
        maxHealth: 35,
        abilityChoices: AbilityChoices(
            basics: [.slash, .shieldBash],
            skills: [.spikedShield, .smite],
            ultimates: [.crystalBulwark, .judgment]
        )
    )
}

extension Combatant {
    static var heroes: [Combatant] { GameContent.heroes }
    static var pets: [Combatant] { GameContent.pets }
    static var trainingSlime: Combatant { GameContent.trainingSlime }
}
