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

    static let itemAffixDefinitions: [ItemAffixDefinition] = ItemAffixCatalog.definitions

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
            ),
            primaryStats: PrimaryStats(strength: 8, agility: 4, toughness: 10, intellect: 2, wisdom: 3)
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
            ),
            primaryStats: PrimaryStats(strength: 6, agility: 9, toughness: 4, intellect: 3, wisdom: 2)
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
            ),
            primaryStats: PrimaryStats(strength: 2, agility: 4, toughness: 3, intellect: 10, wisdom: 4)
        ),
        Combatant(
            id: "alchemist",
            name: "Alchemist",
            role: .hero,
            maxHealth: 9,
            abilityChoices: AbilityChoices(
                basics: [.smellingSalts, .apple],
                skills: [.healthPotion, .antivenomPotion],
                ultimates: [.panaceaPotion, .luckPotion]
            ),
            primaryStats: PrimaryStats(strength: 3, agility: 5, toughness: 5, intellect: 7, wisdom: 8)
        ),
        Combatant(
            id: "druid",
            name: "Druid",
            role: .hero,
            maxHealth: 11,
            abilityChoices: AbilityChoices(
                basics: [.apple, .bread],
                skills: [.briarShield, .graspingVines],
                ultimates: [.bloodthorn, .faustianBargain]
            ),
            primaryStats: PrimaryStats(strength: 4, agility: 5, toughness: 7, intellect: 3, wisdom: 9)
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
            ),
            primaryStats: PrimaryStats(strength: 6, agility: 8, toughness: 5, intellect: 2, wisdom: 4)
        ),
        Combatant(
            id: "warlock",
            name: "Warlock",
            role: .hero,
            maxHealth: 7,
            abilityChoices: AbilityChoices(
                basics: [.kindling, .fangs],
                skills: [.bloodOffering, .darkPact],
                ultimates: [.sunburst, .faustianBargain]
            ),
            primaryStats: PrimaryStats(strength: 4, agility: 5, toughness: 4, intellect: 9, wisdom: 6)
        ),
        Combatant(
            id: "wildcard",
            name: "Wildcard",
            role: .hero,
            maxHealth: 10,
            abilityChoices: AbilityChoices(
                basics: [.gold, .manaBerries],
                skills: [.haste, .roulette],
                ultimates: [.faustianBargain, .luckPotion]
            ),
            primaryStats: PrimaryStats(strength: 5, agility: 6, toughness: 6, intellect: 5, wisdom: 6)
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
            ),
            primaryStats: PrimaryStats(strength: 8, agility: 3, toughness: 10, intellect: 1, wisdom: 3)
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
            ),
            primaryStats: PrimaryStats(strength: 2, agility: 6, toughness: 3, intellect: 9, wisdom: 3)
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
            ),
            primaryStats: PrimaryStats(strength: 5, agility: 8, toughness: 5, intellect: 3, wisdom: 3)
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
            ),
            primaryStats: PrimaryStats(strength: 7, agility: 8, toughness: 4, intellect: 2, wisdom: 3)
        ),
        Combatant(
            id: "phoenix",
            name: "Phoenix",
            role: .pet,
            maxHealth: 6,
            abilityChoices: AbilityChoices(
                basics: [.kindling, .fireArrow],
                skills: [.fireball, .cauterize],
                ultimates: [.phoenixFeather, .combustion]
            ),
            primaryStats: PrimaryStats(strength: 3, agility: 5, toughness: 4, intellect: 8, wisdom: 7)
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
            ),
            primaryStats: PrimaryStats(strength: 6, agility: 9, toughness: 5, intellect: 2, wisdom: 2)
        ),
        Combatant(
            id: "golden_retriever",
            name: "Golden Retriever",
            role: .pet,
            maxHealth: 8,
            abilityChoices: AbilityChoices(
                basics: [.gold, .bread],
                skills: [.healthPotion, .bountyShot],
                ultimates: [.luckPotion, .faustianBargain]
            ),
            primaryStats: PrimaryStats(strength: 4, agility: 5, toughness: 6, intellect: 3, wisdom: 8)
        ),
        Combatant(
            id: "library_owl",
            name: "Library Owl",
            role: .pet,
            maxHealth: 6,
            abilityChoices: AbilityChoices(
                basics: [.smellingSalts, .kindling],
                skills: [.cleanse, .prayer],
                ultimates: [.panaceaPotion, .holyRadiance]
            ),
            primaryStats: PrimaryStats(strength: 2, agility: 6, toughness: 4, intellect: 5, wisdom: 9)
        ),
        Combatant(
            id: "risen_skeleton",
            name: "Risen Skeleton",
            role: .pet,
            maxHealth: 7,
            abilityChoices: AbilityChoices(
                basics: [.slash, .fangs],
                skills: [.darkPact, .bloodOffering],
                ultimates: [.faustianBargain, .hemorrhage]
            ),
            primaryStats: PrimaryStats(strength: 6, agility: 5, toughness: 6, intellect: 5, wisdom: 3)
        ),
        Combatant(
            id: "mana_moth",
            name: "Mana Moth",
            role: .pet,
            maxHealth: 6,
            abilityChoices: AbilityChoices(
                basics: [.manaBerries, .manaCrystals],
                skills: [.manaPotion, .manaShield],
                ultimates: [.luckPotion, .sunburst]
            ),
            primaryStats: PrimaryStats(strength: 3, agility: 6, toughness: 3, intellect: 7, wisdom: 7)
        ),
        Combatant(
            id: "pixie",
            name: "Pixie",
            role: .pet,
            maxHealth: 5,
            abilityChoices: AbilityChoices(
                basics: [.apple, .bread],
                skills: [.prayer, .cleanse],
                ultimates: [.panaceaPotion, .sunburst]
            ),
            primaryStats: PrimaryStats(strength: 2, agility: 7, toughness: 3, intellect: 5, wisdom: 8)
        ),
        Combatant(
            id: "shield_scarab",
            name: "Shield Scarab",
            role: .pet,
            maxHealth: 8,
            abilityChoices: AbilityChoices(
                basics: [.block, .shieldBash],
                skills: [.spikedShield, .stoneskinPotion],
                ultimates: [.crystalBulwark, .plateMail]
            ),
            primaryStats: PrimaryStats(strength: 5, agility: 4, toughness: 11, intellect: 1, wisdom: 3)
        ),
        Combatant(
            id: "imp",
            name: "Imp",
            role: .pet,
            maxHealth: 6,
            abilityChoices: AbilityChoices(
                basics: [.kindling, .fangs],
                skills: [.fireball, .darkPact],
                ultimates: [.combustion, .faustianBargain]
            ),
            primaryStats: PrimaryStats(strength: 4, agility: 7, toughness: 2, intellect: 9, wisdom: 4)
        )
    ]

    static let enemies: [Enemy] = [
        Enemy(combatant: Combatant(id: "living_armor", name: "Living Armor", role: .enemy, maxHealth: Enemy.defaultMaxHealth, abilities: [.bash, .spikedShield, .crystalBulwark], primaryStats: PrimaryStats(strength: 6, agility: 3, toughness: 8, intellect: 1, wisdom: 2))),
        Enemy(combatant: Combatant(id: "mimic", name: "Mimic", role: .enemy, maxHealth: Enemy.defaultMaxHealth, abilities: [.stab, .poisonDagger, .hemorrhage], primaryStats: PrimaryStats(strength: 5, agility: 6, toughness: 5, intellect: 3, wisdom: 2))),
        Enemy(combatant: Combatant(id: "mud_elemental", name: "Mud Elemental", role: .enemy, maxHealth: Enemy.defaultMaxHealth, abilities: [.block, .briarShield, .goldenPlate], primaryStats: PrimaryStats(strength: 4, agility: 3, toughness: 9, intellect: 3, wisdom: 3))),
        Enemy(combatant: Combatant(id: "necromancer", name: "Necromancer", role: .enemy, maxHealth: Enemy.defaultMaxHealth, abilities: [.manaBerries, .darkPact, .hemorrhage], primaryStats: PrimaryStats(strength: 3, agility: 5, toughness: 3, intellect: 6, wisdom: 4))),
        Enemy(combatant: Combatant(id: "plague_doctor", name: "Plague Doctor", role: .enemy, maxHealth: Enemy.defaultMaxHealth, abilities: [.fangs, .venomFangs, .serratedArrowhead], primaryStats: PrimaryStats(strength: 4, agility: 6, toughness: 4, intellect: 5, wisdom: 4))),
        Enemy(combatant: Combatant(id: "skeleton", name: "Skeleton", role: .enemy, maxHealth: Enemy.defaultMaxHealth, abilities: [.slash, .smite, .blessedAegis], primaryStats: PrimaryStats(strength: 5, agility: 4, toughness: 4, intellect: 2, wisdom: 2))),
        Enemy(combatant: Combatant(id: "the_blight_treant", name: "The Blight Treant", role: .enemy, maxHealth: Enemy.defaultMaxHealth, abilities: [.apple, .graspingVines, .bloodthorn], primaryStats: PrimaryStats(strength: 7, agility: 4, toughness: 12, intellect: 5, wisdom: 8)), isBoss: true),
        Enemy(combatant: Combatant(id: "the_forge_golem", name: "The Forge Golem", role: .enemy, maxHealth: Enemy.defaultMaxHealth, abilities: [.bash, .spikedShield, .moltenBulwark], primaryStats: PrimaryStats(strength: 10, agility: 3, toughness: 14, intellect: 3, wisdom: 4)), isBoss: true),
        Enemy(combatant: Combatant(id: "the_frostwarden", name: "The Frostwarden", role: .enemy, maxHealth: Enemy.defaultMaxHealth, abilities: [.rayOfFrost, .frostbolt, .glacialWard], primaryStats: PrimaryStats(strength: 4, agility: 6, toughness: 6, intellect: 12, wisdom: 5)), isBoss: true),
        Enemy(combatant: Combatant(id: "the_iron_bear", name: "The Iron Bear", role: .enemy, maxHealth: Enemy.defaultMaxHealth, abilities: [.fangs, .spikedShield, .crystalBulwark], primaryStats: PrimaryStats(strength: 9, agility: 4, toughness: 13, intellect: 2, wisdom: 3)), isBoss: true),
        Enemy(combatant: Combatant(id: "goblin", name: "Goblin", role: .enemy, maxHealth: Enemy.defaultMaxHealth, abilities: [.slash, .steal, .packTactics], primaryStats: PrimaryStats(strength: 3, agility: 7, toughness: 2, intellect: 3, wisdom: 2))),
        Enemy(combatant: Combatant(id: "fire_elemental", name: "Fire Elemental", role: .enemy, maxHealth: Enemy.defaultMaxHealth, abilities: [.kindling, .fireball, .combustion], primaryStats: PrimaryStats(strength: 3, agility: 5, toughness: 5, intellect: 8, wisdom: 3))),
        Enemy(combatant: Combatant(id: "frost_elemental", name: "Frost Elemental", role: .enemy, maxHealth: Enemy.defaultMaxHealth, abilities: [.rayOfFrost, .coldSnap, .glacialWard], primaryStats: PrimaryStats(strength: 4, agility: 4, toughness: 8, intellect: 7, wisdom: 4))),
        Enemy(combatant: Combatant(id: "slime", name: "Slime", role: .enemy, maxHealth: Enemy.defaultMaxHealth, abilities: [.slash, .briarShield, .crystalBulwark], primaryStats: PrimaryStats(strength: 4, agility: 2, toughness: 12, intellect: 1, wisdom: 2))),
        Enemy(combatant: Combatant(id: "will_o_wisp", name: "Will-o-Wisp", role: .enemy, maxHealth: Enemy.defaultMaxHealth, abilities: [.kindling, .cauterize, .phoenixFeather], primaryStats: PrimaryStats(strength: 1, agility: 7, toughness: 2, intellect: 9, wisdom: 4)))
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
                    encounter: .battle(enemyID: "skeleton"),
                    rewards: StageReward(
                        gold: 12,
                        experience: 20,
                        itemTemplateIDs: ["shortsword-basic"],
                        materialRewards: [ResourceAmount(.wood, 8), ResourceAmount(.stone, 3)]
                    )
                ),
                Stage(
                    id: "chapter-1-stage-2",
                    chapterID: "chapter-1",
                    chapterNumber: 1,
                    stageNumber: 2,
                    title: "Whispering Roots",
                    flavorText: "Something beneath the trail points you toward a safer path.",
                    encounter: .event,
                    rewards: StageReward(
                        gold: 8,
                        experience: 12,
                        itemTemplateIDs: [],
                        materialRewards: [ResourceAmount(.food, 4), ResourceAmount(.herbs, 2)]
                    )
                ),
                Stage(
                    id: "chapter-1-stage-3",
                    chapterID: "chapter-1",
                    chapterNumber: 1,
                    stageNumber: 3,
                    title: "Tangled Thicket",
                    flavorText: "Briars close behind you as a brittle shape steps forward.",
                    encounter: .battle(enemyID: "skeleton"),
                    rewards: StageReward(
                        gold: 14,
                        experience: 24,
                        itemTemplateIDs: [],
                        materialRewards: [ResourceAmount(.wood, 10), ResourceAmount(.stone, 5)]
                    )
                ),
                Stage(
                    id: "chapter-1-stage-4",
                    chapterID: "chapter-1",
                    chapterNumber: 1,
                    stageNumber: 4,
                    title: "Lantern Cart",
                    flavorText: "A covered cart waits beside the trail, its little lantern still warm.",
                    encounter: .shop,
                    rewards: StageReward(
                        gold: 5,
                        experience: 10,
                        itemTemplateIDs: ["leather_armor-basic"],
                        materialRewards: [ResourceAmount(.wood, 6), ResourceAmount(.iron, 2)]
                    )
                ),
                Stage(
                    id: "chapter-1-stage-5",
                    chapterID: "chapter-1",
                    chapterNumber: 1,
                    stageNumber: 5,
                    title: "Sinking Glade",
                    flavorText: "The ground softens underfoot, and the glade begins to move.",
                    encounter: .battle(enemyID: "mud_elemental"),
                    rewards: StageReward(
                        gold: 18,
                        experience: 30,
                        itemTemplateIDs: [],
                        materialRewards: [ResourceAmount(.stone, 9), ResourceAmount(.herbs, 3)]
                    )
                ),
                Stage(
                    id: "chapter-1-stage-6",
                    chapterID: "chapter-1",
                    chapterNumber: 1,
                    stageNumber: 6,
                    title: "Moonwell Rest",
                    flavorText: "Clear water gathers in a stone basin covered in silver leaves.",
                    encounter: .rest,
                    rewards: StageReward(
                        gold: 0,
                        experience: 16,
                        itemTemplateIDs: [],
                        materialRewards: [ResourceAmount(.food, 8), ResourceAmount(.herbs, 5)]
                    )
                ),
                Stage(
                    id: "chapter-1-stage-7",
                    chapterID: "chapter-1",
                    chapterNumber: 1,
                    stageNumber: 7,
                    title: "Spore Lanterns",
                    flavorText: "Pale lights drift between the trees, each one trailing a bitter mist.",
                    encounter: .battle(enemyID: "plague_doctor"),
                    rewards: StageReward(
                        gold: 22,
                        experience: 36,
                        itemTemplateIDs: ["emerald_ring-basic"],
                        materialRewards: [ResourceAmount(.herbs, 7), ResourceAmount(.crystal, 1)]
                    )
                ),
                Stage(
                    id: "chapter-1-stage-8",
                    chapterID: "chapter-1",
                    chapterNumber: 1,
                    stageNumber: 8,
                    title: "Foxfire Fork",
                    flavorText: "Two false trails glitter ahead before the forest reveals the true one.",
                    encounter: .event,
                    rewards: StageReward(
                        gold: 10,
                        experience: 18,
                        itemTemplateIDs: [],
                        materialRewards: [ResourceAmount(.wood, 8), ResourceAmount(.food, 6)]
                    )
                ),
                Stage(
                    id: "chapter-1-stage-9",
                    chapterID: "chapter-1",
                    chapterNumber: 1,
                    stageNumber: 9,
                    title: "Ironwood Watch",
                    flavorText: "An armored sentinel blocks the last rise before the heartwood.",
                    encounter: .battle(enemyID: "living_armor"),
                    rewards: StageReward(
                        gold: 26,
                        experience: 42,
                        itemTemplateIDs: [],
                        materialRewards: [ResourceAmount(.stone, 12), ResourceAmount(.iron, 5)]
                    )
                ),
                Stage(
                    id: "chapter-1-stage-10",
                    chapterID: "chapter-1",
                    chapterNumber: 1,
                    stageNumber: 10,
                    title: "Heartwood Blight",
                    flavorText: "At the forest center, the oldest roots twist around a dark crown.",
                    encounter: .battle(enemyID: "the_blight_treant"),
                    rewards: StageReward(
                        gold: 40,
                        experience: 60,
                        itemTemplateIDs: ["longsword-astral"],
                        materialRewards: [ResourceAmount(.iron, 8), ResourceAmount(.crystal, 3)]
                    )
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
