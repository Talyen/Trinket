import Testing
import TrinketContent
@testable import TrinketPersistence

struct PlayerSaveWorldSeedTests {
    @Test func freshSaveAllocatesNonZeroNonFallbackWorldSeed() {
        let first = PlayerSave.fresh
        let second = PlayerSave.fresh
        #expect(first.worldSeed != 0)
        #expect(first.worldSeed != LabyrinthGenerator.fallbackWorldSeed)
        #expect(second.worldSeed != 0)
        #expect(first.worldSeed != second.worldSeed)
    }

    @Test func sanitizeAssignsWorldSeedWhenMissingAndNoMap() {
        var save = PlayerSave.fresh
        save.worldSeed = 0
        save.labyrinth = .freshStart

        let sanitized = PlayerSaveSanitizer.sanitize(save)

        #expect(sanitized.worldSeed != 0)
        #expect(sanitized.worldSeed != LabyrinthGenerator.fallbackWorldSeed)
        #expect(sanitized.labyrinth.worldSeed == sanitized.worldSeed)
    }

    @Test func sanitizeAdoptsExistingLabyrinthSeedWhenSaveSeedIsMissing() {
        var save = PlayerSave.fresh
        save.worldSeed = 0
        save.labyrinth.ensureMap(seed: 55)

        let sanitized = PlayerSaveSanitizer.sanitize(save)

        #expect(sanitized.worldSeed == 55)
        #expect(sanitized.labyrinth.worldSeed == 55)
        #expect(sanitized.labyrinth.hasMap)
    }

    @Test func sanitizeDoesNotOverwriteUnreadableMapWorldSeed() {
        var save = PlayerSave.fresh
        save.labyrinth = PlayerLabyrinthState(
            worldSeed: 55,
            hasEntered: true,
            isMapPayloadUnreadable: true
        )

        let sanitized = PlayerSaveSanitizer.sanitize(save)

        #expect(sanitized.worldSeed == save.worldSeed)
        #expect(sanitized.labyrinth.worldSeed == 55)
        #expect(sanitized.labyrinth.isMapPayloadUnreadable)
        #expect(!sanitized.labyrinth.hasMap)
    }
}
