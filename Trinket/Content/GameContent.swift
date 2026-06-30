enum GameContent {
    static let itemBaseTypes: [ItemBaseType] = [
        ItemBaseType(id: "crossbow", name: "Crossbow", slot: .weapon, keywordAffinities: [.physical, .bleed, .poison]),
        ItemBaseType(id: "dagger", name: "Dagger", slot: .weapon, keywordAffinities: [.physical, .poison, .bleed, .leech]),
        ItemBaseType(id: "double_axe", name: "Double Axe", slot: .weapon, keywordAffinities: [.physical, .bleed, .leech]),
        ItemBaseType(id: "flail", name: "Flail", slot: .weapon, keywordAffinities: [.physical, .stun, .armor]),
        ItemBaseType(id: "greatsword", name: "Greatsword", slot: .weapon, keywordAffinities: [.physical, .bleed, .stun]),
        ItemBaseType(id: "hatchet", name: "Hatchet", slot: .weapon, keywordAffinities: [.physical, .bleed, .leech]),
        ItemBaseType(id: "kite_shield", name: "Kite Shield", slot: .weapon, keywordAffinities: [.block, .armor, .stun]),
        ItemBaseType(id: "longbow", name: "Longbow", slot: .weapon, keywordAffinities: [.physical, .bleed, .poison]),
        ItemBaseType(id: "longsword", name: "Longsword", slot: .weapon, keywordAffinities: [.physical, .bleed, .holy]),
        ItemBaseType(id: "mace", name: "Mace", slot: .weapon, keywordAffinities: [.physical, .stun, .holy]),
        ItemBaseType(id: "maul", name: "Maul", slot: .weapon, keywordAffinities: [.physical, .stun, .armor]),
        ItemBaseType(id: "recurve_bow", name: "Recurve Bow", slot: .weapon, keywordAffinities: [.physical, .bleed, .nature]),
        ItemBaseType(id: "shortbow", name: "Shortbow", slot: .weapon, keywordAffinities: [.physical, .bleed, .poison]),
        ItemBaseType(id: "shortsword", name: "Shortsword", slot: .weapon, keywordAffinities: [.physical, .bleed]),
        ItemBaseType(id: "spellbook", name: "Spellbook", slot: .weapon, keywordAffinities: [.burn, .freeze, .holy, .nature, .gold]),
        ItemBaseType(id: "staff", name: "Staff", slot: .weapon, keywordAffinities: [.burn, .freeze, .holy, .nature, .block]),
        ItemBaseType(id: "wand", name: "Wand", slot: .weapon, keywordAffinities: [.burn, .freeze, .holy, .poison]),
        ItemBaseType(id: "leather_armor", name: "Leather Armor", slot: .armor, keywordAffinities: [.armor, .health, .poison, .leech]),
        ItemBaseType(id: "plate_armor", name: "Plate Armor", slot: .armor, keywordAffinities: [.block, .armor, .health, .holy]),
        ItemBaseType(id: "emerald_amulet", name: "Emerald Amulet", slot: .trinket, keywordAffinities: [.nature, .poison, .health]),
        ItemBaseType(id: "emerald_ring", name: "Emerald Ring", slot: .trinket, keywordAffinities: [.nature, .poison, .health]),
        ItemBaseType(id: "ruby_amulet", name: "Ruby Amulet", slot: .trinket, keywordAffinities: [.burn, .health, .leech]),
        ItemBaseType(id: "ruby_ring", name: "Ruby Ring", slot: .trinket, keywordAffinities: [.burn, .health, .leech]),
        ItemBaseType(id: "sapphire_amulet", name: "Sapphire Amulet", slot: .trinket, keywordAffinities: [.freeze, .block, .armor]),
        ItemBaseType(id: "sapphire_ring", name: "Sapphire Ring", slot: .trinket, keywordAffinities: [.freeze, .block, .armor]),
        ItemBaseType(id: "topaz_amulet", name: "Topaz Amulet", slot: .trinket, keywordAffinities: [.holy, .gold, .stun]),
        ItemBaseType(id: "topaz_ring", name: "Topaz Ring", slot: .trinket, keywordAffinities: [.holy, .gold, .stun])
    ]

    static let itemAffixDefinitions: [ItemAffixDefinition] = [
        ItemAffixDefinition(
            id: "keen-edge",
            title: "Keen Edge",
            slot: .weapon,
            keywords: [.physical],
            weight: 12,
            basic: ItemAffixPower(description: "+1 Physical damage.", effect: nil),
            astral: ItemAffixPower(description: "+3 Physical damage.", effect: nil)
        ),
        ItemAffixDefinition(
            id: "serrated",
            title: "Serrated",
            slot: .weapon,
            keywords: [.bleed],
            weight: 10,
            basic: ItemAffixPower(description: "Bleed 1 for 2 ticks.", effect: .damageOverTime(.bleed, 1, 2)),
            astral: ItemAffixPower(description: "Bleed 2 for 3 ticks.", effect: .damageOverTime(.bleed, 2, 3))
        ),
        ItemAffixDefinition(
            id: "venomous",
            title: "Venomous",
            slot: .weapon,
            keywords: [.poison],
            weight: 10,
            basic: ItemAffixPower(description: "Poison 1 for 2 ticks.", effect: .damageOverTime(.poison, 1, 2)),
            astral: ItemAffixPower(description: "Poison 2 for 3 ticks.", effect: .damageOverTime(.poison, 2, 3))
        ),
        ItemAffixDefinition(
            id: "scorching",
            title: "Scorching",
            slot: .weapon,
            keywords: [.burn],
            weight: 10,
            basic: ItemAffixPower(description: "Burn 1 for 2 ticks.", effect: .damageOverTime(.burn, 1, 2)),
            astral: ItemAffixPower(description: "Burn 2 for 3 ticks.", effect: .damageOverTime(.burn, 2, 3))
        ),
        ItemAffixDefinition(
            id: "concussive",
            title: "Concussive",
            slot: .weapon,
            keywords: [.stun, .physical],
            weight: 8,
            basic: ItemAffixPower(description: "Stun for 1 action.", effect: .prevention(.stun, 1)),
            astral: ItemAffixPower(description: "Stun for 2 actions.", effect: .prevention(.stun, 2))
        ),
        ItemAffixDefinition(
            id: "blessed",
            title: "Blessed",
            slot: .weapon,
            keywords: [.holy],
            weight: 8,
            basic: ItemAffixPower(description: "+1 Holy damage.", effect: nil),
            astral: ItemAffixPower(description: "+3 Holy damage.", effect: nil)
        ),
        ItemAffixDefinition(
            id: "frostbound",
            title: "Frostbound",
            slot: .weapon,
            keywords: [.freeze],
            weight: 8,
            basic: ItemAffixPower(description: "Freeze for 1 action.", effect: .prevention(.freeze, 1)),
            astral: ItemAffixPower(description: "Freeze for 2 actions.", effect: .prevention(.freeze, 2))
        ),
        ItemAffixDefinition(
            id: "thorned",
            title: "Thorned",
            slot: .weapon,
            keywords: [.nature, .bleed],
            weight: 8,
            basic: ItemAffixPower(description: "Nature and Bleed attacks gain +1 damage.", effect: nil),
            astral: ItemAffixPower(description: "Nature and Bleed attacks gain +3 damage.", effect: nil)
        ),
        ItemAffixDefinition(
            id: "guarding",
            title: "Guarding",
            slot: .weapon,
            keywords: [.block],
            weight: 8,
            basic: ItemAffixPower(description: "Block 2 for 2 ticks.", effect: .shield(.block, 2, 2)),
            astral: ItemAffixPower(description: "Block 5 for 3 ticks.", effect: .shield(.block, 5, 3))
        ),
        ItemAffixDefinition(
            id: "sundering",
            title: "Sundering",
            slot: .weapon,
            keywords: [.armor, .physical],
            weight: 8,
            basic: ItemAffixPower(description: "Armor effects are 15% stronger.", effect: nil),
            astral: ItemAffixPower(description: "Armor effects are 35% stronger.", effect: nil)
        ),
        ItemAffixDefinition(
            id: "staggering",
            title: "Staggering",
            slot: .weapon,
            keywords: [.stun],
            weight: 8,
            basic: ItemAffixPower(description: "Stun effects gain +1 damage.", effect: nil),
            astral: ItemAffixPower(description: "Stun effects gain +3 damage.", effect: nil)
        ),
        ItemAffixDefinition(
            id: "shieldbreaker",
            title: "Shieldbreaker",
            slot: .weapon,
            keywords: [.block, .armor],
            weight: 8,
            basic: ItemAffixPower(description: "Block and Armor effects are 15% stronger.", effect: nil),
            astral: ItemAffixPower(description: "Block and Armor effects are 35% stronger.", effect: nil)
        ),
        ItemAffixDefinition(
            id: "vampiric",
            title: "Vampiric",
            slot: .weapon,
            keywords: [.leech],
            weight: 8,
            basic: ItemAffixPower(description: "Leech 10% for 2 ticks.", effect: .leech(.leech, 0.10, 2)),
            astral: ItemAffixPower(description: "Leech 25% for 3 ticks.", effect: .leech(.leech, 0.25, 3))
        ),
        ItemAffixDefinition(
            id: "reinforced",
            title: "Reinforced",
            slot: .armor,
            keywords: [.armor],
            weight: 12,
            basic: ItemAffixPower(description: "Armor 20% for 2 ticks.", effect: .mitigation(.armor, 0.20, 2)),
            astral: ItemAffixPower(description: "Armor 45% for 3 ticks.", effect: .mitigation(.armor, 0.45, 3))
        ),
        ItemAffixDefinition(
            id: "bulwark",
            title: "Bulwark",
            slot: .armor,
            keywords: [.block],
            weight: 12,
            basic: ItemAffixPower(description: "Block 3 for 2 ticks.", effect: .shield(.block, 3, 2)),
            astral: ItemAffixPower(description: "Block 7 for 3 ticks.", effect: .shield(.block, 7, 3))
        ),
        ItemAffixDefinition(
            id: "vital",
            title: "Vital",
            slot: .armor,
            keywords: [.health],
            weight: 10,
            basic: ItemAffixPower(description: "+2 Health.", effect: nil),
            astral: ItemAffixPower(description: "+6 Health.", effect: nil)
        ),
        ItemAffixDefinition(
            id: "sanctified",
            title: "Sanctified",
            slot: .armor,
            keywords: [.holy, .block],
            weight: 8,
            basic: ItemAffixPower(description: "Holy effects grant Block 2.", effect: nil),
            astral: ItemAffixPower(description: "Holy effects grant Block 5.", effect: nil)
        ),
        ItemAffixDefinition(
            id: "antidotal",
            title: "Antidotal",
            slot: .armor,
            keywords: [.poison, .health],
            weight: 8,
            basic: ItemAffixPower(description: "Cleanse Poison for 2 ticks.", effect: .cleanse(.poison, 2)),
            astral: ItemAffixPower(description: "Cleanse Poison for 4 ticks.", effect: .cleanse(.poison, 4))
        ),
        ItemAffixDefinition(
            id: "lifeweave",
            title: "Lifeweave",
            slot: .armor,
            keywords: [.leech, .health],
            weight: 8,
            basic: ItemAffixPower(description: "Leech restores +1 extra Health.", effect: nil),
            astral: ItemAffixPower(description: "Leech restores +3 extra Health.", effect: nil)
        ),
        ItemAffixDefinition(
            id: "emberguard",
            title: "Emberguard",
            slot: .armor,
            keywords: [.burn, .armor],
            weight: 8,
            basic: ItemAffixPower(description: "Burn effects grant Armor 15%.", effect: nil),
            astral: ItemAffixPower(description: "Burn effects grant Armor 35%.", effect: nil)
        ),
        ItemAffixDefinition(
            id: "verdant",
            title: "Verdant",
            slot: .trinket,
            keywords: [.nature, .health],
            weight: 10,
            basic: ItemAffixPower(description: "Nature effects restore 1 Health.", effect: nil),
            astral: ItemAffixPower(description: "Nature effects restore 3 Health.", effect: nil)
        ),
        ItemAffixDefinition(
            id: "lucky",
            title: "Lucky",
            slot: .trinket,
            keywords: [.gold],
            weight: 10,
            basic: ItemAffixPower(description: "Gold +1.", effect: .resourceGain(.gold, 1)),
            astral: ItemAffixPower(description: "Gold +4.", effect: .resourceGain(.gold, 4))
        ),
        ItemAffixDefinition(
            id: "sparkling",
            title: "Sparkling",
            slot: .trinket,
            keywords: [.holy],
            weight: 8,
            basic: ItemAffixPower(description: "Holy effects gain +1 damage.", effect: nil),
            astral: ItemAffixPower(description: "Holy effects gain +3 damage.", effect: nil)
        ),
        ItemAffixDefinition(
            id: "glacial",
            title: "Glacial",
            slot: .trinket,
            keywords: [.freeze, .block],
            weight: 8,
            basic: ItemAffixPower(description: "Freeze effects grant Block 2.", effect: nil),
            astral: ItemAffixPower(description: "Freeze effects grant Block 5.", effect: nil)
        ),
        ItemAffixDefinition(
            id: "heartward",
            title: "Heartward",
            slot: .trinket,
            keywords: [.health],
            weight: 8,
            basic: ItemAffixPower(description: "+1 Health and Health effects are 10% stronger.", effect: nil),
            astral: ItemAffixPower(description: "+4 Health and Health effects are 25% stronger.", effect: nil)
        ),
        ItemAffixDefinition(
            id: "bloodstone",
            title: "Bloodstone",
            slot: .trinket,
            keywords: [.leech, .health],
            weight: 8,
            basic: ItemAffixPower(description: "Leech 10% for 2 ticks.", effect: .leech(.leech, 0.10, 2)),
            astral: ItemAffixPower(description: "Leech 25% for 3 ticks.", effect: .leech(.leech, 0.25, 3))
        ),
        ItemAffixDefinition(
            id: "venomheart",
            title: "Venomheart",
            slot: .trinket,
            keywords: [.poison],
            weight: 8,
            basic: ItemAffixPower(description: "Poison 1 for 2 ticks.", effect: .damageOverTime(.poison, 1, 2)),
            astral: ItemAffixPower(description: "Poison 2 for 4 ticks.", effect: .damageOverTime(.poison, 2, 4))
        ),
        ItemAffixDefinition(
            id: "steadfast",
            title: "Steadfast",
            slot: .trinket,
            keywords: [.armor, .block],
            weight: 8,
            basic: ItemAffixPower(description: "Armor and Block effects last +1 tick.", effect: nil),
            astral: ItemAffixPower(description: "Armor and Block effects last +2 ticks.", effect: nil)
        ),
        ItemAffixDefinition(
            id: "warding",
            title: "Warding",
            slot: .trinket,
            keywords: [.block],
            weight: 8,
            basic: ItemAffixPower(description: "Block 2 for 2 ticks.", effect: .shield(.block, 2, 2)),
            astral: ItemAffixPower(description: "Block 6 for 3 ticks.", effect: .shield(.block, 6, 3))
        ),
        ItemAffixDefinition(
            id: "runed",
            title: "Runed",
            slot: .trinket,
            keywords: [.armor],
            weight: 8,
            basic: ItemAffixPower(description: "Armor 15% for 2 ticks.", effect: .mitigation(.armor, 0.15, 2)),
            astral: ItemAffixPower(description: "Armor 35% for 3 ticks.", effect: .mitigation(.armor, 0.35, 3))
        ),
        ItemAffixDefinition(
            id: "jolting",
            title: "Jolting",
            slot: .trinket,
            keywords: [.stun],
            weight: 8,
            basic: ItemAffixPower(description: "Stun effects gain +1 damage.", effect: nil),
            astral: ItemAffixPower(description: "Stun effects gain +3 damage.", effect: nil)
        ),
        ItemAffixDefinition(
            id: "fatebound",
            title: "Fatebound",
            slot: .trinket,
            keywords: [.holy, .gold],
            weight: 8,
            basic: ItemAffixPower(description: "Holy effects grant Gold +1.", effect: nil),
            astral: ItemAffixPower(description: "Holy effects grant Gold +4.", effect: nil)
        ),
        ItemAffixDefinition(
            id: "cinder",
            title: "Cinder",
            slot: .trinket,
            keywords: [.burn],
            weight: 8,
            basic: ItemAffixPower(description: "Burn 1 for 2 ticks.", effect: .damageOverTime(.burn, 1, 2)),
            astral: ItemAffixPower(description: "Burn 2 for 4 ticks.", effect: .damageOverTime(.burn, 2, 4))
        )
    ]

    static let sampleInventoryItems: [InventoryItem] = itemBaseTypes.flatMap { base in
        Rarity.allCases.map { rarity in
            var randomNumberGenerator = SeededRandomNumberGenerator(
                seed: stableSeed(for: "\(base.id)-\(rarity.rawValue)")
            )
            return ItemGenerator().generate(
                id: "\(base.id)-\(rarity.rawValue)",
                baseType: base,
                rarity: rarity,
                using: &randomNumberGenerator
            )
        }
    }

    static func itemTemplate(matching id: String) -> InventoryItem? {
        sampleInventoryItems.first { $0.id == id || $0.templateID == id }
    }

    static func stableSeed(for text: String) -> UInt64 {
        text.utf8.reduce(14695981039346656037) { hash, byte in
            (hash ^ UInt64(byte)) &* 1099511628211
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

    static let enemies: [Enemy] = [
        Enemy(combatant: Combatant(id: "goblin", name: "Goblin", role: .enemy, maxHealth: Enemy.defaultMaxHealth, abilities: [.slash, .smite, .blessedAegis])),
        Enemy(combatant: Combatant(id: "imp_enemy", name: "Imp", role: .enemy, maxHealth: Enemy.defaultMaxHealth, abilities: [.willOWisp, .fireball, .combustion])),
        Enemy(combatant: Combatant(id: "living_armor", name: "Living Armor", role: .enemy, maxHealth: Enemy.defaultMaxHealth, abilities: [.bash, .spikedShield, .crystalBulwark])),
        Enemy(combatant: Combatant(id: "mimic", name: "Mimic", role: .enemy, maxHealth: Enemy.defaultMaxHealth, abilities: [.stab, .poisonDagger, .hemorrhage])),
        Enemy(combatant: Combatant(id: "mud_elemental", name: "Mud Elemental", role: .enemy, maxHealth: Enemy.defaultMaxHealth, abilities: [.block, .briarShield, .goldenPlate])),
        Enemy(combatant: Combatant(id: "necromancer", name: "Necromancer", role: .enemy, maxHealth: Enemy.defaultMaxHealth, abilities: [.manaBerries, .darkPact, .raiseSkeleton])),
        Enemy(combatant: Combatant(id: "plague_doctor", name: "Plague Doctor", role: .enemy, maxHealth: Enemy.defaultMaxHealth, abilities: [.fangs, .venomFangs, .serratedArrowhead])),
        Enemy(combatant: Combatant(id: "skeleton", name: "Skeleton", role: .enemy, maxHealth: Enemy.defaultMaxHealth, abilities: [.slash, .smite, .blessedAegis])),
        Enemy(combatant: Combatant(id: "the_blight_treant", name: "The Blight Treant", role: .enemy, maxHealth: Enemy.defaultMaxHealth, abilities: [.apple, .graspingVines, .bloodthorn]), isBoss: true),
        Enemy(combatant: Combatant(id: "the_forge_golem", name: "The Forge Golem", role: .enemy, maxHealth: Enemy.defaultMaxHealth, abilities: [.bash, .spikedShield, .moltenBulwark]), isBoss: true),
        Enemy(combatant: Combatant(id: "the_frostwarden", name: "The Frostwarden", role: .enemy, maxHealth: Enemy.defaultMaxHealth, abilities: [.rayOfFrost, .frostbolt, .glacialWard]), isBoss: true),
        Enemy(combatant: Combatant(id: "the_iron_bear", name: "The Iron Bear", role: .enemy, maxHealth: Enemy.defaultMaxHealth, abilities: [.fangs, .spikedShield, .crystalBulwark]), isBoss: true)
    ]

    static let chapters: [Chapter] = [
        Chapter(
            id: "chapter-1",
            number: 1,
            title: "The Verdant Forest",
            theme: .verdantForest,
            stages: [
                Stage(
                    id: "chapter-1-stage-1",
                    chapterID: "chapter-1",
                    chapterNumber: 1,
                    stageNumber: 1,
                    title: "Moss Gate",
                    flavorText: "The old forest road narrows beneath a bright green canopy.",
                    encounter: .battle(enemyID: "goblin"),
                    rewards: StageReward(gold: 12, experience: 20, itemTemplateIDs: ["shortsword-basic"])
                ),
                Stage(
                    id: "chapter-1-stage-2",
                    chapterID: "chapter-1",
                    chapterNumber: 1,
                    stageNumber: 2,
                    title: "Whispering Roots",
                    flavorText: "Something beneath the trail points you toward a safer path.",
                    encounter: .event,
                    rewards: StageReward(gold: 8, experience: 12, itemTemplateIDs: [])
                ),
                Stage(
                    id: "chapter-1-stage-3",
                    chapterID: "chapter-1",
                    chapterNumber: 1,
                    stageNumber: 3,
                    title: "Tangled Thicket",
                    flavorText: "Briars close behind you as a brittle shape steps forward.",
                    encounter: .battle(enemyID: "skeleton"),
                    rewards: StageReward(gold: 14, experience: 24, itemTemplateIDs: [])
                ),
                Stage(
                    id: "chapter-1-stage-4",
                    chapterID: "chapter-1",
                    chapterNumber: 1,
                    stageNumber: 4,
                    title: "Lantern Cart",
                    flavorText: "A covered cart waits beside the trail, its little lantern still warm.",
                    encounter: .shop,
                    rewards: StageReward(gold: 5, experience: 10, itemTemplateIDs: ["leather_armor-basic"])
                ),
                Stage(
                    id: "chapter-1-stage-5",
                    chapterID: "chapter-1",
                    chapterNumber: 1,
                    stageNumber: 5,
                    title: "Sinking Glade",
                    flavorText: "The ground softens underfoot, and the glade begins to move.",
                    encounter: .battle(enemyID: "mud_elemental"),
                    rewards: StageReward(gold: 18, experience: 30, itemTemplateIDs: [])
                ),
                Stage(
                    id: "chapter-1-stage-6",
                    chapterID: "chapter-1",
                    chapterNumber: 1,
                    stageNumber: 6,
                    title: "Moonwell Rest",
                    flavorText: "Clear water gathers in a stone basin covered in silver leaves.",
                    encounter: .rest,
                    rewards: StageReward(gold: 0, experience: 16, itemTemplateIDs: [])
                ),
                Stage(
                    id: "chapter-1-stage-7",
                    chapterID: "chapter-1",
                    chapterNumber: 1,
                    stageNumber: 7,
                    title: "Spore Lanterns",
                    flavorText: "Pale lights drift between the trees, each one trailing a bitter mist.",
                    encounter: .battle(enemyID: "plague_doctor"),
                    rewards: StageReward(gold: 22, experience: 36, itemTemplateIDs: ["emerald_ring-basic"])
                ),
                Stage(
                    id: "chapter-1-stage-8",
                    chapterID: "chapter-1",
                    chapterNumber: 1,
                    stageNumber: 8,
                    title: "Foxfire Fork",
                    flavorText: "Two false trails glitter ahead before the forest reveals the true one.",
                    encounter: .event,
                    rewards: StageReward(gold: 10, experience: 18, itemTemplateIDs: [])
                ),
                Stage(
                    id: "chapter-1-stage-9",
                    chapterID: "chapter-1",
                    chapterNumber: 1,
                    stageNumber: 9,
                    title: "Ironwood Watch",
                    flavorText: "An armored sentinel blocks the last rise before the heartwood.",
                    encounter: .battle(enemyID: "living_armor"),
                    rewards: StageReward(gold: 26, experience: 42, itemTemplateIDs: [])
                ),
                Stage(
                    id: "chapter-1-stage-10",
                    chapterID: "chapter-1",
                    chapterNumber: 1,
                    stageNumber: 10,
                    title: "Heartwood Blight",
                    flavorText: "At the forest center, the oldest roots twist around a dark crown.",
                    encounter: .battle(enemyID: "the_blight_treant"),
                    rewards: StageReward(gold: 40, experience: 60, itemTemplateIDs: ["longsword-astral"])
                )
            ]
        )
    ]

    static func enemy(matching id: String) -> Enemy? {
        enemies.first { $0.id == id }
    }
}

extension Combatant {
    static var heroes: [Combatant] {
        GameContent.heroes
    }

    static var pets: [Combatant] {
        GameContent.pets
    }

    static var enemies: [Enemy] {
        GameContent.enemies
    }
}
