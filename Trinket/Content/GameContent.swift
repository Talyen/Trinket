enum GameContent {
    static let itemBaseTypes: [ItemBaseType] = [
        ItemBaseType(id: "crossbow", name: "Crossbow", slot: .weapon),
        ItemBaseType(id: "dagger", name: "Dagger", slot: .weapon),
        ItemBaseType(id: "double_axe", name: "Double Axe", slot: .weapon),
        ItemBaseType(id: "flail", name: "Flail", slot: .weapon),
        ItemBaseType(id: "greatsword", name: "Greatsword", slot: .weapon),
        ItemBaseType(id: "hatchet", name: "Hatchet", slot: .weapon),
        ItemBaseType(id: "kite_shield", name: "Kite Shield", slot: .weapon),
        ItemBaseType(id: "longbow", name: "Longbow", slot: .weapon),
        ItemBaseType(id: "longsword", name: "Longsword", slot: .weapon),
        ItemBaseType(id: "mace", name: "Mace", slot: .weapon),
        ItemBaseType(id: "maul", name: "Maul", slot: .weapon),
        ItemBaseType(id: "recurve_bow", name: "Recurve Bow", slot: .weapon),
        ItemBaseType(id: "shortbow", name: "Shortbow", slot: .weapon),
        ItemBaseType(id: "shortsword", name: "Shortsword", slot: .weapon),
        ItemBaseType(id: "spellbook", name: "Spellbook", slot: .weapon),
        ItemBaseType(id: "staff", name: "Staff", slot: .weapon),
        ItemBaseType(id: "wand", name: "Wand", slot: .weapon),
        ItemBaseType(id: "leather_armor", name: "Leather Armor", slot: .armor),
        ItemBaseType(id: "plate_armor", name: "Plate Armor", slot: .armor),
        ItemBaseType(id: "emerald_amulet", name: "Emerald Amulet", slot: .trinket),
        ItemBaseType(id: "emerald_ring", name: "Emerald Ring", slot: .trinket),
        ItemBaseType(id: "ruby_amulet", name: "Ruby Amulet", slot: .trinket),
        ItemBaseType(id: "ruby_ring", name: "Ruby Ring", slot: .trinket),
        ItemBaseType(id: "sapphire_amulet", name: "Sapphire Amulet", slot: .trinket),
        ItemBaseType(id: "sapphire_ring", name: "Sapphire Ring", slot: .trinket),
        ItemBaseType(id: "topaz_amulet", name: "Topaz Amulet", slot: .trinket),
        ItemBaseType(id: "topaz_ring", name: "Topaz Ring", slot: .trinket)
    ]

    static let sampleInventoryItems: [InventoryItem] = itemBaseTypes.flatMap { base in
        Rarity.allCases.map { rarity in
            InventoryItem(
                id: "\(base.id)-\(rarity.rawValue)",
                baseType: base,
                rarity: rarity,
                displayName: base.name,
                affixes: [.placeholder]
            )
        }
    }

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
