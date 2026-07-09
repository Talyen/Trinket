import Testing
import TrinketContent
import TrinketPersistence
import TrinketTestSupport

@Suite("AspectsProgress")
struct AspectsProgressTests {
    @Test func markFloorClearedAdvancesHighestOnly() {
        var progress = PlayerAspectsState()
        progress.markFloorCleared(1, aspectID: AspectID.ironVein.rawValue)
        progress.markFloorCleared(3, aspectID: AspectID.ironVein.rawValue)
        progress.markFloorCleared(2, aspectID: AspectID.ironVein.rawValue)
        #expect(progress.highestClearedFloor(for: AspectID.ironVein.rawValue) == 3)
        #expect(progress.activeFloor(for: AspectID.ironVein.rawValue, floorCount: 10) == 4)
    }

    @Test func sanitizeDropsUnknownAspectsAndClampsFloors() {
        let dirty = PlayerAspectsState(
            highestClearedFloorByAspectID: [
                AspectID.ironVein.rawValue: 99,
                "missingAspect": 4,
            ]
        )
        let sanitized = PlayerSaveSanitizer.sanitizeAspects(dirty)
        #expect(sanitized.highestClearedFloorByAspectID["missingAspect"] == nil)
        #expect(sanitized.highestClearedFloor(for: AspectID.ironVein.rawValue) == 10)
    }

    @Test @MainActor func aspectsProgressPersistsThroughStore() throws {
        let directory = try SaveTestSupport.makeTempDirectory(prefix: "aspects-progress")
        defer { SaveTestSupport.removeTempDirectory(directory) }

        let first = try SaveTestSupport.makeSaveStore(directoryURL: directory)
        var progress = first.aspects
        progress.markFloorCleared(4, aspectID: AspectID.cinderSpire.rawValue)
        first.aspects = progress

        let second = try SaveTestSupport.makeSaveStore(directoryURL: directory)
        #expect(second.aspects.highestClearedFloor(for: AspectID.cinderSpire.rawValue) == 4)
    }

    @Test func aspectCompletionGrantsGoldAndProgress() throws {
        var save = PlayerSave.fresh
        let floor = try #require(GameContent.aspectFloor(aspectID: .ironVein, floor: 1))
        let hero = try #require(GameContent.heroes.first { $0.id == "knight" })
        let pet = try #require(GameContent.pets.first { $0.id == "bear" })
        let goldBefore = save.roster.gold

        AspectCompletion.complete(
            floor: floor,
            hero: hero,
            pet: pet,
            battleEarnedGold: 3,
            save: &save
        )

        #expect(save.roster.gold == goldBefore + floor.rewards.gold + 3)
        #expect(save.aspects.highestClearedFloor(for: AspectID.ironVein.rawValue) == 1)
    }

    @Test func unlockGatesFollowIronVeinProgress() throws {
        var progress = PlayerAspectsState()
        let cinder = try #require(GameContent.aspect(id: .cinderSpire))
        let rime = try #require(GameContent.aspect(id: .rimeVault))
        #expect(!AspectUnlock.isUnlocked(cinder, progress: progress))
        progress.markFloorCleared(5, aspectID: AspectID.ironVein.rawValue)
        #expect(AspectUnlock.isUnlocked(cinder, progress: progress))
        #expect(!AspectUnlock.isUnlocked(rime, progress: progress))
        progress.markFloorCleared(10, aspectID: AspectID.ironVein.rawValue)
        #expect(AspectUnlock.isUnlocked(rime, progress: progress))
    }
}
