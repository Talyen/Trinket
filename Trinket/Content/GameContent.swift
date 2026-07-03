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

    static let heroes = GameContentRoster.heroes
    static let pets = GameContentRoster.pets
    static let enemies: [Enemy] = GameContentEnemies.enemies
    static let chapters: [Chapter] = GameContentChapters.chapters

    static func enemy(matching id: String) -> Enemy? {
        enemies.first { $0.id == id }
    }

    static func chapter(containing stage: Stage) -> Chapter {
        chapters.first { $0.id == stage.chapterID } ?? chapters[0]
    }

    static func chapter(id: String) -> Chapter? {
        chapters.first { $0.id == id }
    }

    static func nextChapter(after chapter: Chapter) -> Chapter? {
        guard let chapterIndex = chapters.firstIndex(where: { $0.id == chapter.id }),
              chapters.indices.contains(chapterIndex + 1)
        else { return nil }
        return chapters[chapterIndex + 1]
    }

    static func encounterArtID(for stage: Stage) -> String? {
        stageEncounterArt[stage.id]?.id
    }

    static func encounterArtTitle(for stage: Stage) -> String? {
        stageEncounterArt[stage.id]?.title
    }

    private static let stageEncounterArt: [String: (id: String, title: String)] = [
        "chapter-1-stage-2": ("mystery-sunlight-breaks-canopy", "Sunlit Trail"),
        "chapter-1-stage-4": ("destination-merchant-shop", "Merchant's Shop"),
        "chapter-1-stage-6": ("destination-campfire", "Campfire"),
        "chapter-1-stage-8": ("mystery-vines-carpet-mosaic-floors", "Hidden Mosaic")
    ]
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
