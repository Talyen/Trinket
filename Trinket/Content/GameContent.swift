extension GameContent {
    static let chapters: [Chapter] = GameContentChapters.chapters

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
